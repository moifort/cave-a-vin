import { match, P } from 'ts-pattern'
import { SearchIndexUseCase } from '~/domain/search/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, notFound } from '~/domain/shared/graphql/errors'
import { stripNulls } from '~/utils/input'
import type { BeverageData, ErasableField, WineDetails } from '../../types'
import { BeverageUseCase } from '../../use-case'
import { AddBeverageInput, UpdateBeverageInput } from './inputs'
import { BeverageType } from './types'

// Drop null/undefined entries; return undefined if nothing survives — so an
// all-empty sub-object never reaches Firestore (which rejects undefined values).
const compact = <T extends Record<string, unknown>>(obj: T): T | undefined => {
  const cleaned = Object.fromEntries(
    Object.entries(obj).filter(([, value]) => value !== undefined && value !== null),
  ) as T
  return Object.keys(cleaned).length > 0 ? cleaned : undefined
}

// The flat input carries wine/purchase/place fields at the top level; the write
// model nests them. A wine's details are only meaningful for a wine, but harmless
// to pass otherwise (the command drops them for non-wine types).
type BeverageFlatInput = {
  color?: unknown
  vintage?: unknown
  appellation?: unknown
  classification?: unknown
  grapeVarieties?: unknown
  servingTemperature?: unknown
  drinkFrom?: unknown
  drinkUntil?: unknown
  purchasePrice?: unknown
  purchaseDate?: unknown
  latitude?: unknown
  longitude?: unknown
  placeName?: unknown
  alcoholContent?: unknown
  producer?: unknown
  region?: unknown
  country?: unknown
  notes?: unknown
  subtype?: unknown
}

const toData = (input: BeverageFlatInput): BeverageData => {
  const drinkWindow = compact({ from: input.drinkFrom, until: input.drinkUntil })
  const wine = compact({
    color: input.color,
    vintage: input.vintage,
    appellation: input.appellation,
    classification: input.classification,
    grapeVarieties: input.grapeVarieties,
    drinkWindow,
    servingTemperature: input.servingTemperature,
  }) as WineDetails | undefined
  const purchase = compact({ price: input.purchasePrice, date: input.purchaseDate })
  const place = compact({
    latitude: input.latitude,
    longitude: input.longitude,
    name: input.placeName,
  })
  const base = compact({
    alcoholContent: input.alcoholContent,
    producer: input.producer,
    region: input.region,
    country: input.country,
    notes: input.notes,
  })
  return {
    ...(base ?? {}),
    ...(input.subtype !== undefined ? { subtype: input.subtype } : {}),
    ...(purchase ? { purchase } : {}),
    ...(place ? { place } : {}),
    ...(wine ? { wine } : {}),
  } as BeverageData
}

// A field the caller sent as an explicit null is one it wants emptied — the only
// way to tell that apart from a field it simply did not send.
const erasedBy = (input: Record<string, unknown>): ErasableField[] =>
  Object.keys(input).filter((key): key is ErasableField => input[key] === null && key in ERASABLE)

const ERASABLE: Record<ErasableField, true> = {
  alcoholContent: true,
  producer: true,
  region: true,
  country: true,
  notes: true,
  subtype: true,
  purchasePrice: true,
  purchaseDate: true,
  latitude: true,
  longitude: true,
  placeName: true,
  color: true,
  vintage: true,
  appellation: true,
  classification: true,
  grapeVarieties: true,
  servingTemperature: true,
  drinkFrom: true,
  drinkUntil: true,
}

const colorRequired = () => badUserInput('A wine requires a color')
const subtypeInvalid = () => badUserInput('This subtype does not fit the beverage type')

builder.mutationField('addBeverage', (t) =>
  t.field({
    type: BeverageType,
    description:
      'Add a new beverage to the collection and return it.\n\n' +
      'Fails with a bad-user-input error when a wine is missing its color, or when the ' +
      'subtype does not fit the beverage type.',
    args: {
      input: t.arg({
        type: AddBeverageInput,
        required: true,
        description: 'Fields of the new beverage',
      }),
    },
    resolve: async (_root, { input }, { userId }) => {
      const clean = stripNulls(input)
      const result = await BeverageUseCase.add(
        userId,
        clean.name,
        clean.beverageType ?? 'wine',
        toData(clean),
        clean.giftedBy,
      )
      if (typeof result !== 'string') await SearchIndexUseCase.refresh(userId, result.id)
      return match(result)
        .with('color-required', colorRequired)
        .with('subtype-invalid', subtypeInvalid)
        .with(P.not(P.string), (beverage) => beverage)
        .exhaustive()
    },
  }),
)

builder.mutationField('updateBeverage', (t) =>
  t.field({
    type: BeverageType,
    description:
      'Update an existing beverage and return it.\n\n' +
      'Absent input fields keep their current value. Fails with not-found when the ' +
      'beverage does not exist, or with bad-user-input when a wine is missing its color ' +
      'or the subtype does not fit the beverage type.',
    args: {
      id: t.arg({
        type: 'BeverageId',
        required: true,
        description: 'Id of the beverage to update',
      }),
      input: t.arg({
        type: UpdateBeverageInput,
        required: true,
        description: 'Fields to overwrite',
      }),
    },
    resolve: async (_root, { id, input }, { userId }) => {
      const clean = stripNulls(input)
      const data = { ...toData(clean), name: clean.name, beverageType: clean.beverageType }
      const result = await BeverageUseCase.update(userId, id, data, clean.giftedBy, erasedBy(input))
      if (typeof result !== 'string') await SearchIndexUseCase.refresh(userId, id)
      return match(result)
        .with('not-found', () => notFound('Beverage not found'))
        .with('color-required', colorRequired)
        .with('subtype-invalid', subtypeInvalid)
        .with(P.not(P.string), (beverage) => beverage)
        .exhaustive()
    },
  }),
)

builder.mutationField('deleteBeverage', (t) =>
  t.field({
    type: 'Boolean',
    description:
      'Delete a beverage and every related satellite record, then return true.\n\n' +
      'Cascades to the cellar slot, tasting note, gift, recommendation and journal. ' +
      'Fails with not-found when the beverage does not exist.',
    args: {
      id: t.arg({
        type: 'BeverageId',
        required: true,
        description: 'Id of the beverage to delete',
      }),
    },
    resolve: async (_root, { id }, { userId }) => {
      const result = await BeverageUseCase.removeCompletely(userId, id)
      return match(result)
        .with('not-found', () => notFound('Beverage not found'))
        .with(undefined, () => true)
        .exhaustive()
    },
  }),
)
