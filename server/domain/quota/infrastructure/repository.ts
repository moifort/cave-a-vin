import { freshQuota } from '~/domain/quota/business-rules'
import type { Quota, QuotaMonth } from '~/domain/quota/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter, transactionally } from '~/utils/firestore'

const quotas = () => db().collection('ai-quotas').withConverter(genericDataConverter<Quota>())

// One document per account and per month, keyed deterministically: the month's
// quota is read by key, never by query, and last month's document is simply never
// read again — no purge, no scheduled job.
const quotaDocId = (userId: UserId, month: QuotaMonth) => `${userId}_${month}`

const cacheKey = (userId: UserId, month: QuotaMonth) => `quota:${userId}:${month}`

// Memoized for the request: the scan checks the quota before calling Gemini and
// records it after, and both must share the same single read.
export const findBy = (userId: UserId, month: QuotaMonth): Promise<Quota> =>
  memoizedPerRequest(cacheKey(userId, month), async () => {
    const doc = await quotas().doc(quotaDocId(userId, month)).get()
    // An absent document is a month nobody has spent anything in — the storage
    // boundary defaults it rather than making every caller handle absence.
    return doc.data() ?? freshQuota(userId, month)
  })

// Spend against the month's counter, atomically. The read has to happen inside
// the transaction — the memoized one is the pre-call value the caller already
// checked the limit against, and reusing it is exactly how two scans landing
// together would both write "one spent" and record only one.
export const consume = async (
  userId: UserId,
  month: QuotaMonth,
  spend: (quota: Quota) => Quota,
): Promise<Quota> => {
  const ref = quotas().doc(quotaDocId(userId, month))
  const spent = await transactionally(async (tx) => {
    const doc = await tx.get(ref)
    // Same storage boundary as `findBy`: an absent document is a fresh month.
    const spent = spend(doc.data() ?? freshQuota(userId, month))
    tx.set(ref, spent)
    return spent
  })
  // Drop the memoized pre-write value so anything reading the quota later in the
  // same request (the `me` query alongside a scan) sees what was just spent.
  evictFromRequestCache(cacheKey(userId, month))
  return spent
}

// Delete every monthly quota document the account has accrued (account deletion).
// One doc per month, so this queries by userId rather than reconstructing keys.
export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snap = await quotas().where('userId', '==', userId).get()
  await deleteInBatches(snap.docs.map((doc) => doc.ref))
}
