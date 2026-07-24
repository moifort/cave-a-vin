import type { WriteBatch } from 'firebase-admin/firestore'
import type { BeverageId } from '~/domain/beverage/types'
import type { CellarBottle, CellarConfig, OwnedBeverage } from '~/domain/cellar/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, isInRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter } from '~/utils/firestore'

const cellar = () => db().collection('cellar').withConverter(genericDataConverter<CellarBottle>())

const configs = () =>
  db().collection('cellar-configs').withConverter(genericDataConverter<CellarConfig>())

const configCacheKey = (key: string) => `cellar:config:${key}`

// The grid dimensions for a cellar scope, keyed by `hh_<householdId>` (shared) or
// `usr_<userId>` (solo). Memoized: every cellarInfo/dashboard read resolves it.
export const findConfig = (key: string): Promise<CellarConfig | null> =>
  memoizedPerRequest(configCacheKey(key), async () => {
    const doc = await configs().doc(key).get()
    return doc.data() ?? null
  })

export const saveConfig = async (
  key: string,
  config: CellarConfig,
  batch?: WriteBatch,
): Promise<CellarConfig> => {
  const ref = configs().doc(key)
  if (batch) batch.set(ref, config)
  else await ref.set(config)
  // Drop the memoized config so a read later in the same request sees the new size
  // rather than a pre-write miss cached by configureFor's existence check.
  evictFromRequestCache(configCacheKey(key))
  return config
}

// Delete a cellar config doc by key. Used by an account deletion to drop the
// solo `usr_<userId>` grid; a shared `hh_<householdId>` grid is a housemate's
// concern, never removed here. A no-op if the doc is already gone (idempotent).
export const removeConfig = async (key: string): Promise<void> => {
  await configs().doc(key).delete()
  evictFromRequestCache(configCacheKey(key))
}

const docId = (userId: UserId, beverageId: BeverageId) => `${userId}_${beverageId}`
const allCacheKey = (userId: UserId) => `cellar:all:${userId}`
// A household shares one grid, so its reads are keyed by the whole member set.
// Sorted so the key is stable regardless of member order; a solo scope ([userId])
// collapses to the same key as allCacheKey(userId), sharing that request's cache.
const allUsersCacheKey = (memberIds: UserId[]) => `cellar:all:${[...memberIds].sort().join(',')}`

export const findAllByUser = (userId: UserId): Promise<CellarBottle[]> =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snap = await cellar().where('userId', '==', userId).orderBy('createdAt', 'desc').get()
    return snap.docs.map((doc) => doc.data())
  })

export const findBy = async (
  userId: UserId,
  beverageId: BeverageId,
): Promise<CellarBottle | null> => {
  const doc = await cellar().doc(docId(userId, beverageId)).get()
  return doc.data() ?? null
}

// The single bottle occupying a grid position, if any — a targeted query, never
// a scan of the whole cellar.
export const findByPosition = async (
  userId: UserId,
  row: CellarBottle['row'],
  col: CellarBottle['col'],
): Promise<CellarBottle | null> => {
  const snap = await cellar()
    .where('userId', '==', userId)
    .where('row', '==', row)
    .where('col', '==', col)
    .limit(1)
    .get()
  return snap.docs[0]?.data() ?? null
}

// Aggregation query: Firestore counts server-side without returning documents.
export const countByUser = async (userId: UserId): Promise<number> => {
  const snap = await cellar().where('userId', '==', userId).count().get()
  return snap.data().count
}

// One page of cellar bottles in grid order (row then column): the cave screen
// groups by row, so pages must fill the grid top-to-bottom — paginating by date
// would make rows appear incomplete and sections jump around while scrolling.
export const findBottlesPage = async (
  userId: UserId,
  { limit, after }: { limit: number; after?: BeverageId },
): Promise<{ bottles: CellarBottle[]; hasMore: boolean }> => {
  let query = cellar().where('userId', '==', userId).orderBy('row', 'asc').orderBy('col', 'asc')
  if (after) {
    const cursor = await cellar().doc(docId(userId, after)).get()
    if (cursor.exists) query = query.startAfter(cursor)
  }
  const snap = await query.limit(limit + 1).get()
  const bottles = snap.docs.map((doc) => doc.data())
  const hasMore = bottles.length > limit
  return { bottles: hasMore ? bottles.slice(0, limit) : bottles, hasMore }
}

// Batch-load cellar placements for a page of wines with a single getAll. When
// the full scan already ran in this request, reuse it: zero extra reads.
export const findManyByBeverageIds = async (
  userId: UserId,
  beverageIds: BeverageId[],
): Promise<CellarBottle[]> => {
  if (beverageIds.length === 0) return []
  if (isInRequestCache(allCacheKey(userId))) {
    const wanted = new Set(beverageIds)
    return (await findAllByUser(userId)).filter((bottle) => wanted.has(bottle.beverageId))
  }
  const refs = beverageIds.map((beverageId) => cellar().doc(docId(userId, beverageId)))
  const snaps = await db().getAll(...refs)
  return snaps.map((snap) => snap.data()).filter((b): b is CellarBottle => b !== undefined)
}

// --- Household-scoped reads -------------------------------------------------
// Each mirrors the single-user function above but spans a household's members.
// When the scope is a lone user ([userId]) they degenerate to that user's view,
// so callers can always route through these with the scope from cellarScope().

export const findAllByUsers = (memberIds: UserId[]): Promise<CellarBottle[]> =>
  memoizedPerRequest(allUsersCacheKey(memberIds), async () => {
    const snap = await cellar().where('userId', 'in', memberIds).orderBy('createdAt', 'desc').get()
    return snap.docs.map((doc) => doc.data())
  })

export const countByUsers = async (memberIds: UserId[]): Promise<number> => {
  const snap = await cellar().where('userId', 'in', memberIds).count().get()
  return snap.data().count
}

// The bottle occupying a grid position anywhere in the household, if any — the
// conflict guard for placement and moves. A targeted query, never a full scan.
export const findByPositionForUsers = async (
  memberIds: UserId[],
  row: CellarBottle['row'],
  col: CellarBottle['col'],
): Promise<CellarBottle | null> => {
  const snap = await cellar()
    .where('userId', 'in', memberIds)
    .where('row', '==', row)
    .where('col', '==', col)
    .limit(1)
    .get()
  return snap.docs[0]?.data() ?? null
}

// The bottle holding a beverage, whichever member owns it — a getAll probe over
// the composed doc ids (one read per member), never a scan of the grid.
export const findByForUsers = async (
  memberIds: UserId[],
  beverageId: BeverageId,
): Promise<CellarBottle | null> => {
  const refs = memberIds.map((userId) => cellar().doc(docId(userId, beverageId)))
  const snaps = await db().getAll(...refs)
  return snaps.map((snap) => snap.data()).find((b): b is CellarBottle => b !== undefined) ?? null
}

// One page of the shared grid in (row, col) order. The cursor bottle may belong
// to any member, so its doc is resolved by probing the composed ids.
export const findBottlesPageForUsers = async (
  memberIds: UserId[],
  { limit, after }: { limit: number; after?: BeverageId },
): Promise<{ bottles: CellarBottle[]; hasMore: boolean }> => {
  let query = cellar().where('userId', 'in', memberIds).orderBy('row', 'asc').orderBy('col', 'asc')
  if (after) {
    const refs = memberIds.map((userId) => cellar().doc(docId(userId, after)))
    const snaps = await db().getAll(...refs)
    const cursor = snaps.find((snap) => snap.exists)
    if (cursor) query = query.startAfter(cursor)
  }
  const snap = await query.limit(limit + 1).get()
  const bottles = snap.docs.map((doc) => doc.data())
  const hasMore = bottles.length > limit
  return { bottles: hasMore ? bottles.slice(0, limit) : bottles, hasMore }
}

// Bottles for a page of wines read at each wine's owner slot — one getAll of
// exactly one ref per wine, whoever owns it. No household scan, no misses on
// housemate ids, so the personal library list never amplifies its reads.
export const findManyByExactIds = async (wines: OwnedBeverage[]): Promise<CellarBottle[]> => {
  if (wines.length === 0) return []
  const refs = wines.map((wine) => cellar().doc(docId(wine.userId, wine.id)))
  const snaps = await db().getAll(...refs)
  return snaps.map((snap) => snap.data()).filter((b): b is CellarBottle => b !== undefined)
}

export const save = async (entry: CellarBottle, batch?: WriteBatch): Promise<CellarBottle> => {
  const ref = cellar().doc(docId(entry.userId, entry.beverageId))
  if (batch) batch.set(ref, entry)
  else await ref.set(entry)
  return entry
}

export const remove = async (
  userId: UserId,
  beverageId: BeverageId,
  batch?: WriteBatch,
): Promise<void> => {
  const ref = cellar().doc(docId(userId, beverageId))
  if (batch) batch.delete(ref)
  else await ref.delete()
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snap = await cellar().where('userId', '==', userId).get()
  await deleteInBatches(snap.docs.map((doc) => doc.ref))
}
