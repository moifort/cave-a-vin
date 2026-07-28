import {
  AdminToken,
  ApiToken,
  AppleEnvironment,
  AscIssuerId,
  AscKeyId,
  AscPrivateKey,
  AscVendorNumber,
  GcpBillingTable,
  GoogleApiKey,
  PremiumUserIds,
  SentryDsn,
} from '~/system/config/primitives'

export const config = () => {
  const runtimeConfig = useRuntimeConfig()
  return {
    apiToken: runtimeConfig.apiToken ? ApiToken(runtimeConfig.apiToken) : undefined,
    adminToken: runtimeConfig.adminToken ? AdminToken(runtimeConfig.adminToken) : undefined,
    googleApiKey: GoogleApiKey(runtimeConfig.googleApiKey),
    sentryDsn: runtimeConfig.sentryDsn ? SentryDsn(runtimeConfig.sentryDsn) : undefined,
    devUserId: runtimeConfig.devUserId || undefined,
    appleEnvironment: runtimeConfig.appleEnvironment
      ? AppleEnvironment(runtimeConfig.appleEnvironment)
      : undefined,
    premiumUserIds: PremiumUserIds(runtimeConfig.premiumUserIds),
    ascIssuerId: runtimeConfig.ascIssuerId ? AscIssuerId(runtimeConfig.ascIssuerId) : undefined,
    ascKeyId: runtimeConfig.ascKeyId ? AscKeyId(runtimeConfig.ascKeyId) : undefined,
    ascPrivateKey: runtimeConfig.ascPrivateKey
      ? AscPrivateKey(runtimeConfig.ascPrivateKey)
      : undefined,
    ascVendorNumber: runtimeConfig.ascVendorNumber
      ? AscVendorNumber(runtimeConfig.ascVendorNumber)
      : undefined,
    gcpBillingTable: runtimeConfig.gcpBillingTable
      ? GcpBillingTable(runtimeConfig.gcpBillingTable)
      : undefined,
  }
}
