import { GivenGiftInput } from '~/domain/gift/infrastructure/graphql/inputs'
import { RecommendationInput } from '~/domain/recommendation/infrastructure/graphql/inputs'
import { builder } from '~/domain/shared/graphql/builder'
import { TastingInput } from '~/domain/tasting/infrastructure/graphql/inputs'
import { BeverageSubtypeEnum, BeverageTypeEnum, WineColorEnum } from './enums'

export const AddBeverageInput = builder.inputType('AddBeverageInput', {
  description:
    'The fields accepted when manually adding a beverage.\n\n' +
    'Only `name` is required. The wine, purchase and place fields are flat here and get ' +
    'nested into the stored `Beverage`; the wine fields are ignored for a non-wine type. ' +
    'A wine requires a `color`, and any `subtype` must be valid for the `beverageType`.',
  fields: (t) => ({
    name: t.field({ type: 'BeverageName', required: true, description: 'Display name; required' }),
    beverageType: t.field({
      type: BeverageTypeEnum,
      description: 'Kind of beverage; defaults to WINE when absent',
    }),
    color: t.field({
      type: WineColorEnum,
      description: 'Wine color; required when the beverage is a wine',
    }),
    subtype: t.field({
      type: BeverageSubtypeEnum,
      description: 'Structured subtype; must be valid for the beverage type',
    }),
    alcoholContent: t.field({ type: 'Percentage', description: 'Alcohol by volume (% vol)' }),
    vintage: t.field({ type: 'Year', description: 'Wine harvest year' }),
    producer: t.field({ type: 'Producer', description: 'Maker of the beverage' }),
    appellation: t.field({ type: 'Appellation', description: 'Wine appellation' }),
    region: t.field({ type: 'Region', description: 'Region the beverage comes from' }),
    country: t.field({ type: 'Country', description: 'Country the beverage comes from' }),
    grapeVarieties: t.field({ type: ['GrapeVariety'], description: 'Grape varieties of the wine' }),
    classification: t.field({ type: 'Classification', description: 'Wine classification' }),
    purchasePrice: t.field({ type: 'Eur', description: 'Price paid for the bottle, in euros' }),
    purchaseDate: t.field({ type: 'DateTime', description: 'Date the bottle was acquired' }),
    drinkFrom: t.field({ type: 'Year', description: 'First year the wine is ready to drink' }),
    drinkUntil: t.field({ type: 'Year', description: 'Last year the wine is at its best' }),
    notes: t.field({ type: 'Notes', description: 'Free-form personal notes' }),
    giftedBy: t.field({
      type: 'PersonName',
      description: 'Name of the person who gave the bottle',
    }),
    servingTemperature: t.field({
      type: 'Celsius',
      description: 'Recommended serving temperature, in degrees Celsius',
    }),
    latitude: t.field({ type: 'Latitude', description: 'Latitude of the purchase place' }),
    longitude: t.field({ type: 'Longitude', description: 'Longitude of the purchase place' }),
    placeName: t.field({ type: 'PlaceName', description: 'Name of the place of purchase' }),
  }),
})

export const UpdateBeverageInput = builder.inputType('UpdateBeverageInput', {
  description:
    'The fields accepted when updating an existing beverage.\n\n' +
    'Every field is optional; an absent field keeps its current value. The same wine, ' +
    'purchase and place flattening and the same color and subtype validity rules as ' +
    '`AddBeverageInput` apply.',
  fields: (t) => ({
    name: t.field({ type: 'BeverageName', description: 'New display name' }),
    beverageType: t.field({ type: BeverageTypeEnum, description: 'New kind of beverage' }),
    color: t.field({ type: WineColorEnum, description: 'New wine color' }),
    subtype: t.field({
      type: BeverageSubtypeEnum,
      description: 'New structured subtype; must be valid for the beverage type',
    }),
    alcoholContent: t.field({ type: 'Percentage', description: 'Alcohol by volume (% vol)' }),
    vintage: t.field({ type: 'Year', description: 'Wine harvest year' }),
    producer: t.field({ type: 'Producer', description: 'Maker of the beverage' }),
    appellation: t.field({ type: 'Appellation', description: 'Wine appellation' }),
    region: t.field({ type: 'Region', description: 'Region the beverage comes from' }),
    country: t.field({ type: 'Country', description: 'Country the beverage comes from' }),
    grapeVarieties: t.field({ type: ['GrapeVariety'], description: 'Grape varieties of the wine' }),
    classification: t.field({ type: 'Classification', description: 'Wine classification' }),
    purchasePrice: t.field({ type: 'Eur', description: 'Price paid for the bottle, in euros' }),
    purchaseDate: t.field({ type: 'DateTime', description: 'Date the bottle was acquired' }),
    drinkFrom: t.field({ type: 'Year', description: 'First year the wine is ready to drink' }),
    drinkUntil: t.field({ type: 'Year', description: 'Last year the wine is at its best' }),
    notes: t.field({ type: 'Notes', description: 'Free-form personal notes' }),
    giftedBy: t.field({
      type: 'PersonName',
      description: 'Name of the person who gave the bottle',
    }),
    servingTemperature: t.field({
      type: 'Celsius',
      description: 'Recommended serving temperature, in degrees Celsius',
    }),
    latitude: t.field({ type: 'Latitude', description: 'Latitude of the purchase place' }),
    longitude: t.field({ type: 'Longitude', description: 'Longitude of the purchase place' }),
    placeName: t.field({ type: 'PlaceName', description: 'Name of the place of purchase' }),
  }),
})

// The wine sheet as the app edits it: one screen spanning four records. Each part
// is optional and stands for "the user touched this"; the domains own their own
// input types, this one only assembles them.
export const BeverageSheetInput = builder.inputType('BeverageSheetInput', {
  description:
    'Everything the wine sheet can change, grouped by the record it belongs to.\n\n' +
    'Passed to `saveBeverageSheet`. Omit a part the user did not touch: sending ' +
    '`tasting` on a bottle that was never tasted creates its tasting note.',
  fields: (t) => ({
    beverage: t.field({
      type: UpdateBeverageInput,
      description: 'Fields of the bottle itself. Absent keeps, null erases.',
    }),
    tasting: t.field({
      type: TastingInput,
      description: 'The tasting note: score, date, people, comment.',
    }),
    gift: t.field({
      type: GivenGiftInput,
      description: 'Recipient and date of a bottle already given away.',
    }),
    recommendation: t.field({
      type: RecommendationInput,
      description: 'Who recommended the bottle, and what they said.',
    }),
  }),
})
