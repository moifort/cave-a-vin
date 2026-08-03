import { searchIndexOf } from '~/domain/search/tokens'
import type { SearchableWine } from '~/domain/search/types'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

const BATCH_LIMIT = 400

// The satellite collections, paired with the field they fill on a searchable wine.
const SATELLITES = [
  ['cellar', 'cellar'],
  ['tasting', 'consumption'],
  ['gift', 'gift'],
  ['recommendation', 'recommendation'],
] as const

// Wines predate the search index, so each one needs its terms computed once.
// The satellite collections are read whole rather than per wine: one pass each,
// instead of four lookups per bottle.
export const migration0007: Migration = {
  version: MigrationVersion(7),
  name: MigrationName('search-index'),
  migrate: async ({ db }) => {
    const [wineSnap, ...satelliteSnaps] = await Promise.all([
      db.collection('beverages').get(),
      ...SATELLITES.map(([collection]) => db.collection(collection).get()),
    ])

    // One map per collection, keyed `${owner}_${beverageId}` — the document id.
    // Keying by beverage alone would let a housemate's tasting note land on the
    // wine as if it were the owner's.
    const byOwnedBeverage = satelliteSnaps.map(
      (snap) => new Map(snap.docs.map((doc) => [doc.ref.id, doc.data()])),
    )

    for (let start = 0; start < wineSnap.docs.length; start += BATCH_LIMIT) {
      const batch = db.batch()
      for (const doc of wineSnap.docs.slice(start, start + BATCH_LIMIT)) {
        const wine = doc.data()
        const searchable = { ...wine } as Record<string, unknown>
        SATELLITES.forEach(([, field], index) => {
          const record = byOwnedBeverage[index]?.get(`${wine.userId}_${doc.ref.id}`)
          if (record) searchable[field] = record
        })
        batch.update(doc.ref, {
          searchIndex: searchIndexOf(searchable as unknown as SearchableWine),
        })
      }
      await batch.commit()
    }

    return { ok: true, transformed: wineSnap.docs.length }
  },
}
