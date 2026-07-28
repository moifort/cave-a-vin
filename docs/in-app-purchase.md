# In-App Purchase — Vinarium Premium

How the subscription works end to end, and the App Store Connect setup it needs. What Premium
unlocks and why it costs what it costs is in [freemium-economics.md](./freemium-economics.md).

## The flow, once

```
app                         Apple                        server
 │                            │                            │
 │ 1. entitlement { appAccountToken }  ─────────────────────▶
 │ ◀──────────────────────────────────────  the account's UUID │
 │                            │                            │
 │ 2. product.purchase(.appAccountToken(uuid))              │
 │ ───────────────────────────▶  Face ID, payment           │
 │ ◀─────────  signed transaction (JWS)                     │
 │                            │                            │
 │ 3. syncEntitlement(signedTransaction) ───────────────────▶
 │                            │        verify signature vs Apple roots
 │                            │        check appAccountToken is this account's
 │                            │        write entitlements/{userId}
 │ ◀──────────────────────────────────────────  plan: PREMIUM │
 │                            │                            │
 │                            │ 4. renewal / refund        │
 │                            │ ──── POST /apple/notifications ──▶
```

**The client is never believed.** `syncEntitlement` is the only way in, and all it accepts is a
transaction the App Store signed. `EntitlementQuery.planOf` reads the resulting document and
nothing else (bar the `NITRO_PREMIUM_USER_IDS` comp list).

**A purchase names its buyer** through `appAccountToken`, a version-5 UUID derived from the
Firebase uid in `entitlement/business-rules.ts`. Derived, not stored: no write, stable across
reinstalls, and one-way, so the token reveals nothing as it travels through Apple's servers. The
app never computes it, it asks the `entitlement` query, so there is a single implementation in one
language. **The derivation is frozen**: changing the namespace or the algorithm detaches every
subscription already sold from its owner. A unit test pins a vector as a tripwire.

**Renewals arrive twice.** Apple pushes them to `POST /apple/notifications`, and the app resyncs
its current entitlements on every launch. Either is enough; both is belt and braces. A
notification for an account we have never recorded is acknowledged and dropped: the token is
one-way, so there is nobody to attach it to until the app syncs the purchase itself.

## What is metered

Only the AI scan, which is the only thing that costs money to serve. Free accounts get
`FREE_MONTHLY_SCANS` a month (`server/domain/quota/business-rules.ts`); subscribers get
`PREMIUM_MONTHLY_SCANS`, a fair-use ceiling high enough never to meet in normal use, so that no
single account can cost more than it pays.

A cache hit and a failed Gemini call both leave the counter untouched: the quota is spent after
the model answered, never before.

## Products

Two auto-renewable subscriptions in one subscription group, so a subscriber can switch between
them:

| Product id | Duration | Price | Introductory offer |
|---|---|---|---|
| `com.polyforms.vinarium.app.premium.monthly` | 1 month | 2,99 € | — |
| `com.polyforms.vinarium.app.premium.yearly` | 1 year | 24,99 € | 7 days free |

The ids are declared in `ios/Vinarium/Features/Subscription/SubscriptionProducts.swift` and in
`ios/Vinarium/Vinarium.storekit`; they must match App Store Connect exactly.

## Local testing (no App Store Connect needed)

`ios/Vinarium/Vinarium.storekit` describes both products locally. Purchases made against it are
signed by a throwaway Xcode certificate, which cannot chain to Apple's roots — so the server must
be told to expect them:

```
NITRO_APPLE_ENVIRONMENT=Xcode
```

Then, **in Xcode** (the StoreKit configuration is applied by Xcode when it launches the app, so
`xcrun simctl launch` will not do): Product → Scheme → Edit Scheme → Run → Options → StoreKit
Configuration → `Vinarium.storekit`. Run, open Réglages → Découvrir Premium, buy. The Transactions
inspector (Debug → StoreKit → Manage Transactions) fakes renewals, refunds and expiries.

## App Store Connect setup — to do once, by a human

Credential-gated; none of it is scriptable.

1. **App Store Connect → Vinarium → Subscriptions** → create a subscription group
   `Vinarium Premium`.
2. Add **`com.polyforms.vinarium.app.premium.yearly`**, duration 1 year, price 24,99 € (France;
   Apple fills the other storefronts). Add a **localized display name and description** in French:
   both are shown on Apple's payment sheet.
3. Add **`com.polyforms.vinarium.app.premium.monthly`**, duration 1 month, price 2,99 €, same
   localization.
4. On the yearly product → **Introductory Offer** → Free trial, 7 days, all territories.
5. **Agreements, Tax and Banking** must be complete (Paid Apps agreement signed, bank and tax
   details filled) or the products stay in `Missing Metadata` and never load in the app.
6. Apply to the **Small Business Program** (App Store Connect → Business): 15 % commission instead
   of 30 % under 1 M$ a year. Every net figure in the economics doc assumes it, and enrolment is
   **not** automatic.
7. **App Store Server Notifications V2** → set the production URL to
   `https://<the deployed function host>/apple/notifications`, and the sandbox URL to the same.
   Version **V2**, not V1.
8. Check the app's **numeric Apple id** (App Information → General → Apple ID) against
   `APP_STORE_ID` in `server/system/apple/types.ts`. Apple's verifier needs it to check a
   Production signature, so it lives in the code next to the bundle id: an id that had to be
   deployed was once left unset, and every real App Store purchase came back unverifiable.
9. Set the repository variable `PREMIUM_USER_IDS` to the comped Firebase uids (the owner's, a
   reviewer's) before the backend deploy — see the rollout note below.
10. Submit both products **with the app build** that contains the paywall: Apple reviews
    subscriptions alongside a build, and rejects them if the reviewer cannot reach the purchase.

## Configuration

| Variable | Purpose |
|---|---|
| `NITRO_APPLE_ENVIRONMENT` | Pins verification to one environment. Blank tries Production then Sandbox, which is what a shipped app needs since TestFlight and review sign in Sandbox. `Xcode` for the local StoreKit file |
| `NITRO_PREMIUM_USER_IDS` | Comped accounts, granted Premium without paying. An access list, not a credential — also a plain environment variable |

Terraform is applied by CI, which writes `infra/terraform.tfvars` from GitHub secrets and
variables on every push to `main`. A value that only exists in a local `terraform.tfvars` never
reaches production: `premium_user_ids` comes from the repository variable `PREMIUM_USER_IDS`.

The app's numeric App Store id is deliberately **not** among them: it is a published, permanent
fact about the app, so it is `APP_STORE_ID` in `server/system/apple/types.ts` and no deployment
can be missing it.

## Rolling it out

The scan gate is **not** conditional on the client's build: the moment the backend deploys, every
build in the wild is metered, including the ones that predate the paywall and would show the raw
server message in a generic error alert rather than the offer.

So, in order:

1. Set `PREMIUM_USER_IDS` **before** the backend deploy, so the accounts in use are unaffected.
2. Deploy the backend. The webhook is live and idle; nothing can be bought yet.
3. Ship the iOS release carrying the paywall.
4. Once it has cleared review, bump `MINIMUM_SUPPORTED_IOS_BUILD` in
   `server/system/app-support.ts` to that release's build number, so the pre-paywall builds are
   sent to the update screen instead of meeting a wall they cannot explain.

## What is deliberately not built

- **No App Store Server API calls.** We never poll Apple for a status; we act on what the app
  hands us and on what Apple pushes. One less credential (the private key) to hold, and the two
  channels already cover every case.
- **No receipt refresh, no `restoreCompletedTransactions`.** StoreKit 2's
  `Transaction.currentEntitlements` is the modern replacement, and the app walks it on launch and
  on the "Restaurer mes achats" button.
- **No proration or upgrade logic of our own.** Switching between monthly and yearly inside one
  subscription group is Apple's business; we only ever read the resulting expiry date.
- **No account deletion hook.** The app has no account deletion yet; when it lands, it must erase
  `entitlements/{userId}` and the account's `ai-quotas` documents.
