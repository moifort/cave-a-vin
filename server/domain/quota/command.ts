import { consumed, monthOf } from '~/domain/quota/business-rules'
import * as repository from '~/domain/quota/infrastructure/repository'
import type { Quota } from '~/domain/quota/types'
import type { UserId } from '~/domain/shared/types'

export namespace QuotaCommand {
  // Write down one scan that actually happened. Called AFTER Gemini answered,
  // never before: a failed scan must not cost anyone a quota, and a refused
  // request never reaches this point. The increment reads and writes in one
  // transaction — two scans finishing together must count two, and a plain
  // read-then-set counted one.
  export const record = async (userId: UserId): Promise<Quota> =>
    repository.consume(userId, monthOf(new Date()), consumed)

  // Erase the account's monthly scan counters (account deletion).
  export const deleteAllForUser = async (userId: UserId) => {
    await repository.removeAllByUser(userId)
  }
}
