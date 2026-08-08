import { match } from 'ts-pattern'
import { GiftCommand } from '~/domain/gift/command'
import { builder } from '~/domain/shared/graphql/builder'
import { notFound } from '~/domain/shared/graphql/errors'
import { stripNulls } from '~/utils/input'
import { GivenGiftInput } from './inputs'

builder.mutationField('updateGift', (t) =>
  t.field({
    type: 'Boolean',
    description:
      'Correct the gift record of a bottle already given away, and return true.\n\n' +
      'Only the recipient and the date change; the bottle stays out of the cellar. ' +
      'Fails with not-found when the bottle was never given away — recording a gift ' +
      'is `giftBottle`, which also takes the bottle out.',
    args: {
      beverageId: t.arg({ type: 'BeverageId', required: true, description: 'Bottle given away' }),
      input: t.arg({
        type: GivenGiftInput,
        required: true,
        description: 'Corrected recipient and date',
      }),
    },
    resolve: async (_root, { beverageId, input }, { userId }) => {
      const { giftedDate, recipientName } = stripNulls(input)
      const result = await GiftCommand.correctGiven(userId, beverageId, {
        date: giftedDate,
        recipientName,
      })
      return match(result)
        .with('not-found', () => notFound('This bottle was not given away'))
        .with(undefined, () => true)
        .exhaustive()
    },
  }),
)
