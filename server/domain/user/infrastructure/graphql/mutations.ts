import { CellarCols, CellarRows, CellarZones } from '~/domain/cellar/primitives'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput } from '~/domain/shared/graphql/errors'
import { UserQuery } from '~/domain/user/query'
import { UserUseCase } from '~/domain/user/use-case'
import { CompleteOnboardingInput } from './inputs'
import { MeType } from './types'

builder.mutationField('completeOnboarding', (t) =>
  t.field({
    type: MeType,
    description:
      'Finish onboarding in one step: save the profile and provision the cellar grid.\n\n' +
      'Writes the first name and creates the cellar from the given rows, columns, and zones, then returns the updated `Me` (with `onboardingCompleted` now true). Rejects out-of-range dimensions as BAD_USER_INPUT.',
    args: {
      input: t.arg({
        type: CompleteOnboardingInput,
        required: true,
        description: 'The first name and cellar dimensions to persist.',
      }),
    },
    resolve: async (_root, { input }, { userId }) => {
      // rows/cols/zones travel as Int and are validated here; a bad value is a
      // BAD_USER_INPUT rather than a raw Zod error.
      const dimensions = parseDimensions(input.rows, input.cols, input.zones)
      await UserUseCase.completeOnboarding(userId, {
        firstName: input.firstName,
        ...dimensions,
      })
      return UserQuery.me(userId)
    },
  }),
)

builder.mutationField('deleteAccount', (t) =>
  t.boolean({
    description:
      'Permanently delete the signed-in account and all of its data.\n\n' +
      'Irreversible. Leaves any shared household (passing ownership on if needed), erases every ' +
      'collection the account owns (wines, cellar, tasting notes, gifts, recommendations, ' +
      'journal, quotas), forgets the stored entitlement, drops the profile, and deletes the ' +
      'Firebase Auth user. Does NOT cancel an active App Store subscription: Apple owns that ' +
      'lifecycle, so a subscriber must cancel separately in the App Store. Always returns `true`.',
    resolve: async (_root, _args, { userId }) => {
      await UserUseCase.deleteAccount(userId)
      return true
    },
  }),
)

const parseDimensions = (rows: number, cols: number, zones: number) => {
  try {
    return { rows: CellarRows(rows), cols: CellarCols(cols), zones: CellarZones(zones) }
  } catch {
    return badUserInput('rows/cols must be 1..100 and zones 1..3')
  }
}
