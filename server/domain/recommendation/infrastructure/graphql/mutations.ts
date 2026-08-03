import { SearchIndexUseCase } from '~/domain/search/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { stripNulls } from '~/utils/input'
import { RecommendationCommand } from '../../command'
import { RecommendationInput } from './inputs'

builder.mutationField('addRecommendation', (t) =>
  t.field({
    type: 'Boolean',
    description:
      'Attach a recommendation to a wine, recording who suggested it and an optional comment.\n\n' +
      'Surfaces afterwards as the `Beverage.recommendation` satellite field. Returns true on success.',
    args: {
      beverageId: t.arg({
        type: 'BeverageId',
        required: true,
        description: 'The wine the recommendation is attached to.',
      }),
      input: t.arg({
        type: RecommendationInput,
        required: true,
        description: 'The recommender name and/or comment to save.',
      }),
    },
    resolve: async (_root, { beverageId, input }, { userId }) => {
      await RecommendationCommand.create({ userId, beverageId, ...stripNulls(input) })
      await SearchIndexUseCase.refresh(userId, beverageId)
      return true
    },
  }),
)
