import type { WriteBatch } from 'firebase-admin/firestore'
import type { BeverageId } from '~/domain/beverage/types'
import type { UserId } from '~/domain/shared/types'
import * as repository from '~/domain/tasting/infrastructure/repository'
import type { TastingNote } from '~/domain/tasting/types'
import { bulkSave } from '~/utils/firestore'

export namespace TastingCommand {
  // Upsert a tasting note: overlay the provided fields onto any existing note
  // rather than overwriting the whole document. Since `favorite`, `rating` and
  // the consumption details all share one doc, a plain overwrite would silently
  // drop, e.g., a favorite flag when later recording a consumption. Callers pass
  // only the fields they mean to set (nulls stripped at the API boundary), so
  // the merge preserves everything they leave untouched.
  export const create = async (note: TastingNote) => {
    const existing = await repository.findBy(note.userId, note.beverageId)
    return repository.save(existing ? { ...existing, ...note } : note)
  }

  // Toggle the favorite (heart) flag without clobbering an existing note:
  // read-modify-write so the rating and tasting notes survive the toggle.
  export const setFavorite = async (userId: UserId, beverageId: BeverageId, favorite: boolean) => {
    const existing = await repository.findBy(userId, beverageId)
    await repository.save({ ...(existing ?? { userId, beverageId }), favorite })
  }

  export const removeBeverage = async (
    userId: UserId,
    beverageId: BeverageId,
    batch?: WriteBatch,
  ) => {
    await repository.remove(userId, beverageId, batch)
  }

  // Erase the user's tasting notes — an account deletion wipes them outright.
  export const deleteAllForUser = async (userId: UserId) => {
    await repository.removeAllByUser(userId)
  }

  // Wipe the user's tasting notes and restore the given records (account import).
  export const replaceAllForUser = async (userId: UserId, notes: TastingNote[]) => {
    await deleteAllForUser(userId)
    await bulkSave(notes, repository.save)
  }
}
