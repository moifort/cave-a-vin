import { type IndexableWine, searchIndexOf } from '~/domain/search/tokens'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

const BATCH_LIMIT = 400

// The personal satellite collections, paired with the field they fill. Several
// household members can hold a record on the same wine, so each field gathers
// every one of them; the cellar is handled apart, being shared and single.
const PERSONAL_SATELLITES = [
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
    const [wineSnap, cellarSnap, ...personalSnaps] = await Promise.all([
      db.collection('beverages').get(),
      db.collection('cellar').get(),
      ...PERSONAL_SATELLITES.map(([collection]) => db.collection(collection).get()),
    ])

    // Every record touching a wine, grouped by that wine. Each record carries its
    // own userId, which is what namespaces the terms it produces.
    const groupByBeverage = (docs: { data: () => Record<string, unknown> }[]) => {
      const groups = new Map<string, Record<string, unknown>[]>()
      for (const doc of docs) {
        const key = String(doc.data().beverageId)
        groups.set(key, [...(groups.get(key) ?? []), doc.data()])
      }
      return groups
    }
    const personal = personalSnaps.map((snap) => groupByBeverage(snap.docs))
    const placed = new Set(cellarSnap.docs.map((doc) => String(doc.data().beverageId)))

    for (let start = 0; start < wineSnap.docs.length; start += BATCH_LIMIT) {
      const batch = db.batch()
      for (const doc of wineSnap.docs.slice(start, start + BATCH_LIMIT)) {
        const indexable = { ...doc.data() } as Record<string, unknown>
        PERSONAL_SATELLITES.forEach(([, field], index) => {
          indexable[field] = personal[index]?.get(doc.ref.id) ?? []
        })
        // Only its presence matters to the index, so a bare marker is enough.
        if (placed.has(doc.ref.id)) indexable.cellar = { placed: true }
        batch.update(doc.ref, {
          searchIndex: searchIndexOf(indexable as unknown as IndexableWine),
        })
      }
      await batch.commit()
    }

    return { ok: true, transformed: wineSnap.docs.length }
  },
}
