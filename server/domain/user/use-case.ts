import { BeverageCommand } from '~/domain/beverage/command'
import { CellarCommand } from '~/domain/cellar/command'
import type { CellarCols, CellarRows, CellarZones } from '~/domain/cellar/types'
import { EntitlementCommand } from '~/domain/entitlement/command'
import { GiftCommand } from '~/domain/gift/command'
import { HouseholdCommand } from '~/domain/household/command'
import { JournalCommand } from '~/domain/journal/command'
import { QuotaCommand } from '~/domain/quota/command'
import { RecommendationCommand } from '~/domain/recommendation/command'
import type { PersonName, UserId } from '~/domain/shared/types'
import { TastingCommand } from '~/domain/tasting/command'
import { UserCommand } from '~/domain/user/command'
import { UserQuery } from '~/domain/user/query'
import { atomically } from '~/utils/firestore'

export namespace UserUseCase {
  // Finish onboarding: persist the profile (firstName + timestamp), the cellar
  // dimensions and the scans the account starts with, in one batch, so a partial
  // failure never leaves the user "half onboarded" — either all of it lands or
  // none of it does.
  //
  // The scans are granted only the FIRST time, on an account that has no profile
  // yet: the mutation is reachable again afterwards (a user re-sizing their
  // cellar through the wizard), and re-granting there would be a renewable gift.
  // The read is the one the auth gate already did, memoized, so it costs nothing.
  export const completeOnboarding = async (
    userId: UserId,
    input: { firstName: PersonName; rows: CellarRows; cols: CellarCols; zones: CellarZones },
  ) => {
    const firstTime = (await UserQuery.me(userId)).onboardingCompletedAt === undefined
    return atomically(async (batch) => {
      await CellarCommand.configureFor(userId, input.rows, input.cols, input.zones, batch)
      if (firstTime) await QuotaCommand.grantWelcomeCredit(userId, batch)
      return UserCommand.completeOnboarding(userId, input.firstName, batch)
    })
  }

  // Delete the account and every trace of it. Each step reaches a domain through
  // its public Command surface, never a repository — the domains own their storage.
  // The order matters and the whole thing is idempotent (a retry after a partial
  // failure is safe):
  //  1. Leave the household first, so a shared cellar's config stays with the
  //     remaining members and ownership passes on before the caller's data goes.
  //  2. Wipe every per-user collection in parallel (independent domains). This
  //     forgets our entitlement record but does NOT cancel the App Store
  //     subscription — Apple owns that lifecycle; the app warns the user.
  //  3. Drop the profile.
  //  4. Delete the Firebase Auth user LAST: if an earlier step fails the user is
  //     still signed in and can retry; deleting auth first would strand the data.
  export const deleteAccount = async (userId: UserId) => {
    await HouseholdCommand.leave(userId)
    await Promise.all([
      BeverageCommand.deleteAllForUser(userId),
      CellarCommand.deleteAllForUser(userId),
      TastingCommand.deleteAllForUser(userId),
      GiftCommand.deleteAllForUser(userId),
      RecommendationCommand.deleteAllForUser(userId),
      JournalCommand.deleteAllForUser(userId),
      EntitlementCommand.deleteForUser(userId),
      QuotaCommand.deleteAllForUser(userId),
    ])
    await UserCommand.deleteProfile(userId)
    await UserCommand.deleteAuthAccount(userId)
  }
}
