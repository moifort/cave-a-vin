import type { WriteBatch } from 'firebase-admin/firestore'
import { requiresColor, retainedSubtype, subtypeAllowed } from '~/domain/beverage/business-rules'
import * as repository from '~/domain/beverage/infrastructure/repository'
import { randomBeverageId } from '~/domain/beverage/primitives'
import type {
  Beverage,
  BeverageData,
  BeverageId,
  BeverageName,
  BeverageType,
  WineDetails,
} from '~/domain/beverage/types'
import type { UserId } from '~/domain/shared/types'
import { bulkSave } from '~/utils/firestore'

// A loose view of a beverage's common fields (everything but the variant keys),
// used to carry forward only the keys a document actually holds.
type CommonFields = Record<string, unknown>

export namespace BeverageCommand {
  export const add = async (
    userId: UserId,
    name: BeverageName,
    beverageType: BeverageType,
    data: BeverageData,
  ) => {
    if (requiresColor(beverageType) && !data.wine?.color) return 'color-required' as const
    if (data.subtype && !subtypeAllowed(beverageType, data.subtype))
      return 'subtype-invalid' as const
    const { subtype, wine, ...base } = data
    const now = new Date()
    const beverage = assemble(
      { id: randomBeverageId(), userId, name, ...base, createdAt: now, updatedAt: now },
      beverageType,
      retainedSubtype(beverageType, subtype),
      wine,
    )
    return await repository.save(beverage)
  }

  export const update = async (
    userId: UserId,
    id: BeverageId,
    data: BeverageData & { name?: BeverageName; beverageType?: BeverageType },
  ) => {
    const existing = await repository.findBy(userId, id)
    if (!existing) return 'not-found' as const
    const loose = existing as { subtype?: Beverage['subtype']; wine?: WineDetails } & CommonFields
    const beverageType = data.beverageType ?? existing.beverageType
    const { subtype: _s, wine: _w, name: _n, beverageType: _bt, ...baseData } = data
    const {
      beverageType: _ebt,
      subtype: existingSubtype,
      wine: existingWine,
      ...existingCommon
    } = loose

    // A wine keeps its existing details merged with the provided ones; any other
    // type drops the details object entirely (a beer has no wine specifics).
    const wine =
      beverageType === 'wine' ? { ...(existingWine ?? {}), ...(data.wine ?? {}) } : undefined
    if (requiresColor(beverageType) && !wine?.color) return 'color-required' as const
    // A subtype explicitly provided must fit the (possibly new) type; one merely
    // inherited from before a type change is silently dropped when it no longer fits.
    if (data.subtype && !subtypeAllowed(beverageType, data.subtype))
      return 'subtype-invalid' as const
    const subtype = data.subtype ?? retainedSubtype(beverageType, existingSubtype)

    const beverage = assemble(
      { ...existingCommon, ...baseData, name: data.name ?? existing.name, updatedAt: new Date() },
      beverageType,
      subtype,
      wine,
    )
    return await repository.save(beverage)
  }

  export const remove = async (userId: UserId, id: BeverageId, batch?: WriteBatch) => {
    const existing = await repository.findBy(userId, id)
    if (!existing) return 'not-found' as const
    await repository.remove(id, batch)
    return undefined
  }

  // Erase the user's beverages — an account deletion wipes them outright.
  export const deleteAllForUser = async (userId: UserId) => {
    await repository.removeAllByUser(userId)
  }

  // Wipe the user's beverages and restore the given set — the write half of an
  // account import (records are pre-stamped with the importing user).
  export const replaceAllForUser = async (userId: UserId, beverages: Beverage[]) => {
    await deleteAllForUser(userId)
    await bulkSave(beverages, repository.save)
  }

  // Compose the discriminated union from validated parts. Only a wine carries a
  // details object; the subtype has already been checked against the type.
  const assemble = (
    common: CommonFields,
    beverageType: BeverageType,
    subtype: Beverage['subtype'] | undefined,
    wine: WineDetails | undefined,
  ): Beverage => {
    const withSubtype = subtype ? { ...common, subtype } : common
    if (beverageType === 'wine')
      return { ...withSubtype, beverageType, wine: wine ?? {} } as Beverage
    return { ...withSubtype, beverageType } as Beverage
  }
}
