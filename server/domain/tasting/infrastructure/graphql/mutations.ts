import { SearchIndexUseCase } from '~/domain/search/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { stripNulls } from '~/utils/input'
import { TastingCommand } from '../../command'
import { TastingInput } from './inputs'

builder.mutationField('markFavorite', (t) =>
  t.field({
    type: 'Boolean',
    description: 'Toggle the favorite (heart) flag on a wine, preserving any existing tasting note',
    args: {
      beverageId: t.arg({ type: 'BeverageId', required: true, description: 'Wine to flag' }),
      favorite: t.arg.boolean({ defaultValue: true, description: 'Desired favorite state' }),
    },
    resolve: async (_root, { beverageId, favorite }, { userId }) => {
      await TastingCommand.setFavorite(userId, beverageId, favorite ?? true)
      await SearchIndexUseCase.refresh(userId, beverageId)
      return true
    },
  }),
)

builder.mutationField('recordTasting', (t) =>
  t.field({
    type: 'Boolean',
    description: 'Record a tasting note (rating, notes, favorite flag) for a wine',
    args: {
      beverageId: t.arg({ type: 'BeverageId', required: true, description: 'Wine being tasted' }),
      input: t.arg({ type: TastingInput, required: true, description: 'Tasting note fields' }),
    },
    resolve: async (_root, { beverageId, input }, { userId }) => {
      await TastingCommand.create({ userId, beverageId, ...stripNulls(input) })
      await SearchIndexUseCase.refresh(userId, beverageId)
      return true
    },
  }),
)
