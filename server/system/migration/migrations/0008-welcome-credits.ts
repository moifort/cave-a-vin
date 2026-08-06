import { WELCOME_SCANS } from '~/domain/quota/business-rules'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

const BATCH_LIMIT = 400

// The scans granted at the end of onboarding are handed by the onboarding
// itself, so every account that finished it before this shipped would be the
// only one never to get them. One balance per existing profile, set to the full
// grant.
//
// Idempotent by omission rather than by overwrite: an account that already holds
// a balance is left alone, so a re-run never refills what has been spent.
export const migration0008: Migration = {
  version: MigrationVersion(8),
  name: MigrationName('welcome-credits'),
  migrate: async ({ db }) => {
    const [profileSnap, creditSnap] = await Promise.all([
      db.collection('user-profiles').get(),
      db.collection('ai-credits').get(),
    ])
    const alreadyGranted = new Set(creditSnap.docs.map((doc) => doc.ref.id))
    const pending = profileSnap.docs.filter((doc) => !alreadyGranted.has(doc.ref.id))

    for (let start = 0; start < pending.length; start += BATCH_LIMIT) {
      const batch = db.batch()
      for (const doc of pending.slice(start, start + BATCH_LIMIT))
        batch.set(db.collection('ai-credits').doc(doc.ref.id), {
          userId: doc.ref.id,
          scans: WELCOME_SCANS,
        })
      await batch.commit()
    }

    return { ok: true, transformed: pending.length }
  },
}
