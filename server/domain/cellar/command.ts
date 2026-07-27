import type { WriteBatch } from 'firebase-admin/firestore'
import { BeverageQuery } from '~/domain/beverage/query'
import type { BeverageId } from '~/domain/beverage/types'
import * as repository from '~/domain/cellar/infrastructure/repository'
import {
  type CellarBottle,
  type CellarCol,
  type CellarCols,
  type CellarRow,
  type CellarRows,
  type CellarZones,
  DEFAULT_CELLAR_SIZE,
} from '~/domain/cellar/types'
import { HouseholdQuery } from '~/domain/household/query'
import { JournalCommand } from '~/domain/journal/command'
import type { UserId } from '~/domain/shared/types'
import { atomically, bulkSave } from '~/utils/firestore'

// A solo user's own cellar config doc id. Deterministic, no membership read.
export const soloCellarConfigKey = (userId: UserId) => `usr_${userId}`

// A cellar's config doc id: the whole household shares one grid, a solo user has
// their own. Resolve this before opening a batch — it reads the membership doc.
export const cellarConfigKey = async (userId: UserId) => {
  const membership = await HouseholdQuery.membershipOf(userId)
  return membership ? `hh_${membership.householdId}` : soloCellarConfigKey(userId)
}

// The grid the app draws for this cellar scope, falling back to the default size
// until onboarding sets it. `zones` defaults to 1 for configs written before the
// field existed. Lives here rather than in the query so the placement guards can
// read it without importing back into CellarQuery.
export const cellarGrid = async (userId: UserId) => {
  const stored = await repository.findConfig(await cellarConfigKey(userId))
  if (!stored) return DEFAULT_CELLAR_SIZE
  return {
    rows: stored.rows,
    cols: stored.cols,
    zones: stored.zones ?? DEFAULT_CELLAR_SIZE.zones,
  }
}

// Positions are 0-based, so the last slot of a rows x cols grid is
// (rows - 1, cols - 1). A bottle written past that is unreachable: no screen
// draws the slot, and it would later block a resize as out of bounds.
const outsideGrid = async (userId: UserId, row: CellarRow, col: CellarCol) => {
  const { rows, cols } = await cellarGrid(userId)
  return row >= rows || col >= cols
}

export namespace CellarCommand {
  // Initialise the grid dimensions for the caller's cellar scope during onboarding.
  // Never overwrites an existing config: the grid is shared, so a housemate who
  // onboards after the household already sized its cave must not resize (or shrink,
  // stranding placed bottles) it. Returns the effective config either way.
  export const configureFor = async (
    userId: UserId,
    rows: CellarRows,
    cols: CellarCols,
    zones: CellarZones,
    batch?: WriteBatch,
  ) => {
    const key = await cellarConfigKey(userId)
    const existing = await repository.findConfig(key)
    if (existing) return existing
    return repository.saveConfig(key, { rows, cols, zones }, batch)
  }

  // Resize/retune an already-configured cellar from the settings screen. Unlike
  // configureFor's onboarding no-op, this is a deliberate action, so it OVERWRITES
  // the shared grid. Refuses to shrink below a placed bottle: positions are 0-based,
  // so any bottle at row >= rows or col >= cols would fall outside the new grid and
  // be stranded. The check spans every household member's bottles via findAllByUsers.
  export const reconfigure = async (
    userId: UserId,
    rows: CellarRows,
    cols: CellarCols,
    zones: CellarZones,
  ) => {
    const scope = await HouseholdQuery.cellarScope(userId)
    const bottles = await repository.findAllByUsers(scope.memberIds)
    const outOfBounds = bottles.filter((b) => b.row >= rows || b.col >= cols).length
    if (outOfBounds > 0) return { outOfBounds } as const
    return repository.saveConfig(await cellarConfigKey(userId), { rows, cols, zones })
  }

  export const placeBeverage = async (
    userId: UserId,
    beverageId: BeverageId,
    row: CellarRow,
    col: CellarCol,
  ) => {
    // You only place your own wine into the shared grid — placing a housemate's
    // beverage would write a second, mis-attributed bottle for it.
    if ((await BeverageQuery.byId(userId, beverageId)) === 'not-found')
      return 'not-your-beverage' as const

    if (await outsideGrid(userId, row, col)) return 'out-of-grid' as const

    // The grid is shared: a slot filled by any household member is taken. The
    // bottle's owner stays the caller (their own wine).
    const scope = await HouseholdQuery.cellarScope(userId)
    const occupant = await repository.findByPositionForUsers(scope.memberIds, row, col)
    if (occupant && occupant.beverageId !== beverageId) return 'position-occupied' as const

    const now = new Date()
    const entry = await repository.save({
      userId,
      beverageId,
      row,
      col,
      createdAt: now,
      updatedAt: now,
    })
    await JournalCommand.bottleIn(userId, {
      type: 'in',
      beverageId,
      row,
      col,
      date: now,
    })
    return entry
  }

  // Remove a bottle from the shared grid. Any member may remove any bottle, but
  // the cellar doc and the journal 'out' belong to the bottle's owner. Returns
  // the owner so the use-case can attribute a gift to them.
  export const removeBeverage = async (actorId: UserId, beverageId: BeverageId) => {
    const scope = await HouseholdQuery.cellarScope(actorId)
    const existing = await repository.findByForUsers(scope.memberIds, beverageId)
    if (!existing) return 'not-in-cellar' as const
    await JournalCommand.bottleOut(existing.userId, {
      type: 'out',
      beverageId: existing.beverageId,
      row: existing.row,
      col: existing.col,
      date: new Date(),
    })
    await repository.remove(existing.userId, beverageId)
    return { ownerId: existing.userId }
  }

  export const moveBottle = async (
    actorId: UserId,
    beverageId: BeverageId,
    targetRow: CellarRow,
    targetCol: CellarCol,
  ) => {
    if (await outsideGrid(actorId, targetRow, targetCol)) return 'out-of-grid' as const

    // Both the moved bottle and the target's occupant may belong to a housemate,
    // so both are located across the household — never a scan of the whole cellar.
    const scope = await HouseholdQuery.cellarScope(actorId)
    const [source, atTarget] = await Promise.all([
      repository.findByForUsers(scope.memberIds, beverageId),
      repository.findByPositionForUsers(scope.memberIds, targetRow, targetCol),
    ])
    if (!source) return 'not-in-cellar' as const
    if (source.row === targetRow && source.col === targetCol) return source

    const now = new Date()
    const occupant = atTarget && atTarget.beverageId !== beverageId ? atTarget : undefined

    // The swap (cellar saves) and its journal trail commit as one batch: a
    // partial failure can no longer leave the cellar half-moved or the journal
    // out of sync with the bottle positions. This guards against partial
    // writes, not concurrent moves — the occupant lookup above is not locked
    // (a Firestore transaction would be needed for that). Each bottle keeps its
    // own owner, and its movement is journaled under that owner, not the actor.
    return await atomically(async (batch) => {
      await JournalCommand.bottleOut(
        source.userId,
        { type: 'out', beverageId: source.beverageId, row: source.row, col: source.col, date: now },
        batch,
      )
      const movedSource = await repository.save(
        { ...source, row: targetRow, col: targetCol, updatedAt: now },
        batch,
      )
      await JournalCommand.bottleIn(
        source.userId,
        {
          type: 'in',
          beverageId: movedSource.beverageId,
          row: targetRow,
          col: targetCol,
          date: now,
        },
        batch,
      )
      if (occupant) {
        await JournalCommand.bottleOut(
          occupant.userId,
          {
            type: 'out',
            beverageId: occupant.beverageId,
            row: occupant.row,
            col: occupant.col,
            date: now,
          },
          batch,
        )
        await repository.save(
          { ...occupant, row: source.row, col: source.col, updatedAt: now },
          batch,
        )
        await JournalCommand.bottleIn(
          occupant.userId,
          {
            type: 'in',
            beverageId: occupant.beverageId,
            row: source.row,
            col: source.col,
            date: now,
          },
          batch,
        )
      }
      return movedSource
    })
  }

  // Deletes the wine's bottle without journaling a bottle-out movement: used when
  // the wine and its entire journal are erased together in the same batch (see
  // BeverageUseCase.removeCompletely) — a freshly written journal entry would survive
  // the journal wipe, since batched writes are invisible to the wipe's query.
  export const eraseBeverage = async (
    userId: UserId,
    beverageId: BeverageId,
    batch: WriteBatch,
  ) => {
    await repository.remove(userId, beverageId, batch)
  }

  // Erase every trace of the user's cellar: their bottles and their solo grid
  // config. Only the deterministic solo `usr_<userId>` config is dropped, never a
  // shared `hh_<householdId>` grid: that belongs to the remaining members, and the
  // caller (account deletion) has already left the household. Resolving the key by
  // membership would be wrong here anyway, the just-removed membership can still be
  // memoized as present, pointing back at the shared grid.
  export const deleteAllForUser = async (userId: UserId) => {
    await repository.removeAllByUser(userId)
    await repository.removeConfig(soloCellarConfigKey(userId))
  }

  // Wipe the user's cellar and restore the given bottles (account import).
  export const replaceAllForUser = async (userId: UserId, bottles: CellarBottle[]) => {
    await repository.removeAllByUser(userId)
    await bulkSave(bottles, repository.save)
  }
}
