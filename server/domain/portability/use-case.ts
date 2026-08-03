import { z } from 'zod'
import { BeverageCommand } from '~/domain/beverage/command'
import { BeverageQuery } from '~/domain/beverage/query'
import type { Beverage } from '~/domain/beverage/types'
import { CellarCommand } from '~/domain/cellar/command'
import { bottleView, CellarQuery } from '~/domain/cellar/query'
import type { CellarBottle } from '~/domain/cellar/types'
import { GiftCommand } from '~/domain/gift/command'
import { GiftQuery } from '~/domain/gift/query'
import type { Gift } from '~/domain/gift/types'
import { JournalCommand } from '~/domain/journal/command'
import { JournalQuery } from '~/domain/journal/query'
import type { JournalEntry } from '~/domain/journal/types'
import {
  EXPORT_SCHEMA_VERSION,
  type ExportEnvelope,
  type ImportResult,
} from '~/domain/portability/types'
import { RecommendationCommand } from '~/domain/recommendation/command'
import { RecommendationQuery } from '~/domain/recommendation/query'
import type { Recommendation } from '~/domain/recommendation/types'
import { searchIndexOf } from '~/domain/search/tokens'
import type { SearchableWine } from '~/domain/search/types'
import type { UserId } from '~/domain/shared/types'
import { TastingCommand } from '~/domain/tasting/command'
import { TastingQuery } from '~/domain/tasting/query'
import type { TastingNote } from '~/domain/tasting/types'

// Backup/restore orchestrator: it reads and replaces each domain's data through
// that domain's public Query/Command surface (raw records, no view enrichment) —
// never its repository. The domains own their storage; portability only moves it.
export namespace PortabilityUseCase {
  export const exportAll = async (userId: UserId): Promise<ExportEnvelope> => {
    const [wines, cellar, tasting, recommendation, gift, journal] = await Promise.all([
      BeverageQuery.findAll(userId),
      CellarQuery.allRecords(userId),
      TastingQuery.all(userId),
      RecommendationQuery.all(userId),
      GiftQuery.all(userId),
      JournalQuery.allEntries(userId),
    ])
    return {
      schemaVersion: EXPORT_SCHEMA_VERSION,
      exportedAt: new Date(),
      userId,
      wines,
      cellar,
      tasting,
      recommendation,
      gift,
      journal,
    }
  }

  export const importAll = async (
    userId: UserId,
    rawJson: string,
  ): Promise<ImportResult | { error: string }> => {
    let parsed: unknown
    try {
      parsed = JSON.parse(rawJson)
    } catch {
      return { error: 'invalid-json' }
    }

    const validation = envelopeSchema.safeParse(parsed)
    if (!validation.success) return { error: 'invalid-schema' }
    const envelope = validation.data

    if (envelope.schemaVersion !== EXPORT_SCHEMA_VERSION) {
      return { error: `unsupported-schema-version:${envelope.schemaVersion}` }
    }

    // Stamp the importing user across every record so a user can restore
    // an export taken under a different account (account migration).
    const stamp = <T extends { userId: string }>(rows: T[]) =>
      rows.map((row) => ({ ...row, userId }))

    const wines = stamp(envelope.wines) as Beverage[]
    const cellar = stamp(envelope.cellar) as CellarBottle[]
    const tasting = stamp(envelope.tasting) as TastingNote[]
    const recommendation = stamp(envelope.recommendation) as Recommendation[]
    const gift = stamp(envelope.gift) as Gift[]
    const journal = stamp(envelope.journal) as JournalEntry[]

    // The search terms are computed here rather than by reindexing each wine
    // afterwards: everything the index needs is already in hand, so a join in
    // memory replaces five reads and a write per imported bottle.
    const indexed = withSearchIndex(wines, { cellar, tasting, gift, recommendation })

    // Each domain wipes then restores its own collection (independent, so the
    // whole restore runs in parallel).
    await Promise.all([
      BeverageCommand.replaceAllForUser(userId, indexed),
      CellarCommand.replaceAllForUser(userId, cellar),
      TastingCommand.replaceAllForUser(userId, tasting),
      RecommendationCommand.replaceAllForUser(userId, recommendation),
      GiftCommand.replaceAllForUser(userId, gift),
      JournalCommand.replaceAllForUser(userId, journal),
    ])

    return {
      wines: wines.length,
      cellar: cellar.length,
      tasting: tasting.length,
      recommendation: recommendation.length,
      gift: gift.length,
      journal: journal.length,
    }
  }
}

// Join each imported wine with its satellites and stamp the terms it can be
// found by, so a restored account is searchable without a second pass.
const withSearchIndex = (
  wines: Beverage[],
  satellites: {
    cellar: CellarBottle[]
    tasting: TastingNote[]
    gift: Gift[]
    recommendation: Recommendation[]
  },
): Beverage[] => {
  const byBeverage = <T extends { beverageId: string }>(rows: T[]) =>
    new Map(rows.map((row) => [String(row.beverageId), row]))
  const cellar = byBeverage(satellites.cellar)
  const tasting = byBeverage(satellites.tasting)
  const gift = byBeverage(satellites.gift)
  const recommendation = byBeverage(satellites.recommendation)
  return wines.map((wine) => {
    const searchable: SearchableWine = { ...wine }
    const bottle = cellar.get(String(wine.id))
    if (bottle) searchable.cellar = bottleView(bottle)
    const note = tasting.get(String(wine.id))
    if (note) searchable.consumption = note
    const given = gift.get(String(wine.id))
    if (given) searchable.gift = given
    const recommended = recommendation.get(String(wine.id))
    if (recommended) searchable.recommendation = recommended
    return { ...wine, searchIndex: searchIndexOf(searchable) }
  })
}

const dateSchema = z
  .union([z.string(), z.number(), z.date()])
  .transform((value) => (value instanceof Date ? value : new Date(value)))

const looseRecord = z.looseObject({ userId: z.string() })

const envelopeSchema = z.object({
  // Any number parses; the explicit version guard in importAll returns a precise
  // `unsupported-schema-version:X` rather than a generic shape error.
  schemaVersion: z.number(),
  exportedAt: dateSchema,
  userId: z.string(),
  wines: z.array(looseRecord),
  cellar: z.array(looseRecord),
  tasting: z.array(looseRecord),
  recommendation: z.array(looseRecord),
  gift: z.array(looseRecord),
  journal: z.array(looseRecord),
})
