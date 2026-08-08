import type { WriteBatch } from 'firebase-admin/firestore'
import {
  requiresColor,
  retainedSubtype,
  subtypeAllowed,
  withoutFields,
} from '~/domain/beverage/business-rules'
import * as repository from '~/domain/beverage/infrastructure/repository'
import { randomBeverageId } from '~/domain/beverage/primitives'
import type {
  Beverage,
  BeverageData,
  BeverageId,
  BeverageName,
  BeverageType,
  ErasableField,
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

  // `erase` names the fields the caller emptied. Absent from `data` means "leave
  // it alone", so emptying needs its own channel: without it no field could ever
  // be cleared once written.
  export const update = async (
    userId: UserId,
    id: BeverageId,
    data: BeverageData & { name?: BeverageName; beverageType?: BeverageType },
    erase: readonly ErasableField[] = [],
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
    // A subtype explicitly provided must fit the (possibly new) type; one merely
    // inherited from before a type change is silently dropped when it no longer fits.
    if (data.subtype && !subtypeAllowed(beverageType, data.subtype))
      return 'subtype-invalid' as const
    const subtype = data.subtype ?? retainedSubtype(beverageType, existingSubtype)

    const merged = assemble(
      { ...existingCommon, ...baseData, name: data.name ?? existing.name, updatedAt: new Date() },
      beverageType,
      subtype,
      wine,
    )
    // The erasures land last, so the colour rule judges what is actually stored:
    // emptying the colour of a wine is refused, not silently re-merged.
    const beverage = withoutFields(merged, erase)
    if (requiresColor(beverageType) && !(beverage as { wine?: WineDetails }).wine?.color)
      return 'color-required' as const
    return await repository.save(beverage)
  }

  // Store the terms this beverage can be found by. The beverage domain owns the
  // document, the search domain decides what goes in the array — this is the door
  // between the two.
  export const saveSearchIndex = async (id: BeverageId, tokens: string[]) => {
    await repository.saveSearchIndex(id, tokens)
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
