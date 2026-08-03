import type { WriteBatch } from 'firebase-admin/firestore'
import type { Beverage, BeverageId, BeverageSort, SortOrder } from '~/domain/beverage/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter } from '~/utils/firestore'

const beverages = () => db().collection('beverages').withConverter(genericDataConverter<Beverage>())

// The beverage document field each sort option maps to. Price lives under the
// purchase sub-object; vintage and color are wine details (nested under `wine`).
const sortField = (sort: BeverageSort) =>
  sort === 'price'
    ? 'purchase.price'
    : sort === 'vintage'
      ? 'wine.vintage'
      : sort === 'color'
        ? 'wine.color'
        : sort

export type BeveragePage = { beverages: Beverage[]; hasMore: boolean }
export type PageArgs = { limit: number; after?: BeverageId; sort: BeverageSort; order: SortOrder }

const allCacheKey = (userId: UserId) => `beverages:all:${userId}`

export const findAllByUser = (userId: UserId): Promise<Beverage[]> =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snap = await beverages().where('userId', '==', userId).orderBy('createdAt', 'desc').get()
    return snap.docs.map((doc) => doc.data())
  })

// Replace the search terms of one wine. A targeted update, never a full write:
// the caller recomputes the tokens, it does not hold the rest of the document.
export const saveSearchIndex = async (id: BeverageId, tokens: string[]): Promise<void> => {
  await beverages().doc(id).update({ searchIndex: tokens })
}

// The owner's wines holding at least one of the terms. Firestore allows a single
// array clause per query, so this is the only condition it carries: everything
// else (the other words, the facets, the housemate visibility rule) is settled
// in memory on the few documents that come back.
export const findBySearchTerms = async (ownerId: UserId, terms: string[]): Promise<Beverage[]> => {
  if (terms.length === 0) return []
  const snap = await beverages()
    .where('userId', '==', ownerId)
    .where('searchIndex', 'array-contains-any', terms)
    .get()
  return snap.docs.map((doc) => doc.data())
}

export const findBy = async (userId: UserId, id: BeverageId): Promise<Beverage | null> => {
  const doc = await beverages().doc(id).get()
  const data = doc.data()
  return data && data.userId === userId ? data : null
}

// Fetch a beverage without the owner guard — the caller authorizes the viewer
// (owner or a household member) before exposing it.
export const findById = async (id: BeverageId): Promise<Beverage | null> => {
  const doc = await beverages().doc(id).get()
  return doc.data() ?? null
}

// Batch-load a page of beverages owned by any of the given members (a household's
// shared-cellar wines). The member set always comes from the household scope,
// never from client input, so this is a controlled widening of the owner guard.
export const findManyByBeverageIdsForUsers = async (
  memberIds: UserId[],
  beverageIds: BeverageId[],
): Promise<Beverage[]> => {
  if (beverageIds.length === 0) return []
  const owners = new Set(memberIds)
  const refs = beverageIds.map((id) => beverages().doc(id))
  const snaps = await db().getAll(...refs)
  return snaps
    .map((snap) => snap.data())
    .filter(
      (beverage): beverage is Beverage => beverage !== undefined && owners.has(beverage.userId),
    )
}

// One page of beverages ordered by the chosen field. Reads limit+1 docs to know
// if a next page exists, then trims. Nullable sort fields (vintage/region/color/
// price) drop beverages missing that field — expected Firestore orderBy behaviour.
export const findPage = async (userId: UserId, args: PageArgs): Promise<BeveragePage> => {
  let query = beverages().where('userId', '==', userId).orderBy(sortField(args.sort), args.order)
  if (args.after) {
    const cursor = await beverages().doc(args.after).get()
    if (cursor.exists) query = query.startAfter(cursor)
  }
  const snap = await query.limit(args.limit + 1).get()
  const docs = snap.docs.map((doc) => doc.data())
  const hasMore = docs.length > args.limit
  return { beverages: hasMore ? docs.slice(0, args.limit) : docs, hasMore }
}

export const save = async (beverage: Beverage): Promise<Beverage> => {
  await beverages().doc(beverage.id).set(beverage)
  return beverage
}

export const remove = async (id: BeverageId, batch?: WriteBatch): Promise<void> => {
  const ref = beverages().doc(id)
  if (batch) batch.delete(ref)
  else await ref.delete()
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snap = await beverages().where('userId', '==', userId).get()
  await deleteInBatches(snap.docs.map((doc) => doc.ref))
}
