import { builder } from '~/domain/shared/graphql/builder'

export const SearchMatchedFieldEnum = builder.enumType('SearchMatchedField', {
  description:
    'Which attribute of a wine a search query matched.\n\n' +
    'A hit can carry several matched fields at once. The client groups results by them ' +
    '(a person match reads as "gift", a name match reads as "wine") and can highlight the ' +
    'matching text. Empty when only facet filters were applied.',
  values: {
    NAME: { value: 'name', description: 'Matched the beverage name' },
    PRODUCER: { value: 'producer', description: 'Matched the producer / domain' },
    SUBTYPE: { value: 'subtype', description: 'Matched the beverage subtype' },
    COLOR: { value: 'color', description: 'Matched the robe of a wine' },
    BEVERAGE_TYPE: { value: 'beverage-type', description: 'Matched the kind of beverage' },
    APPELLATION: { value: 'appellation', description: 'Matched the appellation' },
    REGION: { value: 'region', description: 'Matched the region' },
    VINTAGE: { value: 'vintage', description: 'Matched the vintage year' },
    GIFTED_BY: {
      value: 'gifted-by',
      description: 'Matched the person who gave the wine as a gift',
    },
    GIFT_RECIPIENT: {
      value: 'gift-recipient',
      description: 'Matched the person the wine was given to',
    },
    RECOMMENDER: {
      value: 'recommender',
      description: 'Matched the person who recommended the wine',
    },
    TASTING_CONTACT: {
      value: 'tasting-contact',
      description: 'Matched a person recorded on a tasting note',
    },
  } as const,
})
