# Vinarium

A purely functional approach to wine cellar management.

<p align="center">
  <img src="screenshots/dashboard.png" width="250" alt="Dashboard">
  <img src="screenshots/cellar.png" width="250" alt="Cellar">
  <img src="screenshots/wine-list.png" width="250" alt="Wine list">
</p>

## Features

- **AI scan** — photograph a label, get structured wine data + price estimate (Gemini 2.5 Flash vision + Google Search grounding)
- **Cellar grid** — physical position tracking by row and column
- **Journal** — entry/exit history with tasting notes and ratings
- **Dashboard** — cellar stats, total value, ready-to-drink alerts, recent activity
- **Wine catalog** — full metadata, grape varieties, appellations, drink windows, structured subtypes for every beverage (porto, rum, blonde ale, sparkling sake…)
- **Global search** — full-screen search across names, producers, subtypes, regions, vintages and people (gifts, recommendations), ranked by relevance and grouped by match (in cellar, consumed, gifts…), with combinable facet chips
- **Household sharing** — share one cellar with the people you live with via an invite code: a common grid where any member can place, move, drink or gift any bottle. Sharing the cellar shares what it holds — its bottles, their total value, the ready-to-drink alerts and every movement in the journal, each one badged with the member behind it. Shared-cellar bottles also surface in every member's wine list and search, badged with their owner's name, while each person's out-of-cellar catalog and tasting notes stay private
- **Onboarding** — a first-launch wizard that collects the user's first name and sizes the cellar (rows A→Z × slots per row), with a searchable catalog of real consumer wine coolers (grouped by brand) for automatic dimensioning and the temperature-zone count; the grid dimensions are configurable per scope rather than fixed
- **Premium** — the app is free and the cellar, journal, sharing and manual entry stay unlimited; only the AI scan is metered (5 a month). Vinarium Premium lifts the meter, sold as an auto-renewable subscription (monthly, or yearly with a 7-day free trial and a discount badge computed from the store's own prices), purchased through StoreKit 2 and verified server-side against Apple's signed transactions
- **Localization** — the app ships in 7 languages (French, English, German, Spanish, Italian, Portuguese, Japanese) through a String Catalog. The AI scan writes its free-text values in the caller's language (driven by `Accept-Language`, with the scan cache partitioned per language), and prices show in the user's currency (stored canonically in euros, converted at display and input)
- **Admin metrics** — an admin-only banner and screen showing the month's economics: measured AI cost from real Gemini tokens, the measured GCP bill (BigQuery billing export), App Store revenue (App Store Connect Sales Reports), user and subscriber counts. AI usage is metered live at each scan; the rest is a projection a daily scheduler refreshes. Gated by a flag on the user profile
- **Account control** — full data portability (export the whole account to a JSON envelope, restore it under any account) plus account deletion: one confirmed action erases every trace of the account (cellar, journal, tastings, gifts, recommendations, quotas, entitlement, profile), leaves any shared household first so ownership passes on, and removes the Firebase identity last

<p align="center">
  <img src="screenshots/wine-detail.png" width="250" alt="Wine detail">
  <img src="screenshots/journal.png" width="250" alt="Journal">
</p>

<p align="center">
  <img src="screenshots/scan.png" width="250" alt="Scanner">
  <img src="screenshots/scan-review.png" width="250" alt="AI scan review">
</p>

## Tech Stack

| Layer    | Stack                                                                     |
| -------- | ------------------------------------------------------------------------- |
| iOS      | SwiftUI, Swift 6, iOS 26, Apollo iOS, StoreKit 2, Firebase Auth (Sign in with Apple) |
| Backend  | Nitro on Firebase Cloud Functions Gen 2, Apollo Server 5, Pothos          |
| Storage  | Firestore (multi-user, isolated by `userId`, shared cellars via households) |
| AI       | Gemini 2.5 Flash (vision + Google Search grounding)                       |
| Metrics  | App Store Connect Sales Reports API + BigQuery billing export (admin economics) |
| Infra    | Terraform (google + google-beta) — provisions everything from scratch    |
| Observability | Sentry (backend namespace tracing + iOS crash/error reporting)       |

## One-shot bootstrap

The entire stack — GCP project, Firebase, Firestore (rules + indexes),
Identity Platform with Apple Sign-In, Cloud Function Gen 2, secrets,
iOS app registration with `GoogleService-Info.plist` generated locally —
is provisioned by `bun run bootstrap`.

### Prerequisites

- `gcloud` CLI authenticated with Application Default Credentials :
  `gcloud auth application-default login`
- `bun`
- An Apple Developer account with a Service ID + Sign in with Apple enabled
  + a `.p8` private key (see [`ios/FIREBASE_SETUP.md`](ios/FIREBASE_SETUP.md))
- A GCP billing account id and either an `org_id` or `folder_id`

> `terraform` is auto-downloaded (pinned version, checksum-verified) into
> `infra/.bin/` on first `bun run bootstrap` / `bun run infra:plan|infra:apply|destroy`.
> `jq` is replaced by `bunx node-jq` (pulled in by `bun install`).

### Run

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit infra/terraform.tfvars: project_id, billing, Apple, secrets
cp ~/Downloads/AuthKey_KEY1234567.p8 infra/

bun run bootstrap
```

That single command :

1. validates prerequisites,
2. builds the Nitro firebase-preset bundle (`.output/server/`),
3. `terraform init && terraform apply` — creates the GCP project, enables
   ~15 APIs, provisions Firebase + Firestore (Native, eur3), configures
   Identity Platform + Apple OAuth, registers the iOS app and writes the
   `GoogleService-Info.plist`, stores secrets in Secret Manager, deploys
   the Cloud Function (Gen 2, nodejs22, europe-west3),
4. migrates Terraform state to a versioned GCS bucket,
5. POSTs `/admin/migrate` to apply Firestore migrations,
6. prints the function URL, the iOS plist path, and the GitHub
   secrets/vars to set for subsequent CI deploys.

After `bun run bootstrap` finishes, commit `infra/backend.tf` (generated by
the script) so the GitHub Actions deploy workflow can read the same state.

### Subsequent deploys

Push to `main`. The [`deploy.yml`](.github/workflows/deploy.yml) workflow
authenticates via Workload Identity Federation, builds the Nitro bundle,
runs `terraform apply` (which only diffs the Cloud Function source
archive), then triggers the migration endpoint.

### Teardown

```bash
bun run destroy   # removes the GCP project and all Firebase resources
```

## Local development (without Firebase)

```bash
cp .env.example .env  # fill in API keys
bun install
bunx nitro prepare
bun run dev           # http://localhost:3000

# Or with the Firebase emulator suite:
firebase emulators:start --only auth,firestore,functions
```

Required environment variables (`.env`) :

```
NITRO_GOOGLE_API_KEY=...
NITRO_ADMIN_TOKEN=...
NITRO_SENTRY_DSN=...    # optional, and ignored in dev: Sentry only runs in a built bundle
```

## iOS App

1. Open `ios/Vinarium.xcodeproj` in Xcode.
2. After `bun run bootstrap`, `GoogleService-Info.plist` is already at
   `ios/Vinarium/`. Drag it into the `Vinarium` target in Xcode.
3. Add the SPM packages and the Sign in with Apple capability — see
   [`ios/FIREBASE_SETUP.md`](ios/FIREBASE_SETUP.md).
4. Run `apollo-ios-cli generate` (from `ios/`) to regenerate typed
   GraphQL operations from `shared/schema.graphql`.
5. Build and run on the iPhone 17 simulator (iOS 26.2).
