import { builder } from '~/domain/shared/graphql/builder'

export const GivenGiftInput = builder.inputType('GivenGiftInput', {
  description:
    'Who a bottle was given to, and when.\n\n' +
    'Passed to `updateGift` to correct a gift already recorded. Unlike `giftBottle`, ' +
    'this touches nothing but the gift record: the bottle has already left the cellar.',
  fields: (t) => ({
    giftedDate: t.field({ type: 'DateTime', description: 'When the bottle was given away.' }),
    recipientName: t.field({ type: 'PersonName', description: 'Who received the bottle.' }),
  }),
})
