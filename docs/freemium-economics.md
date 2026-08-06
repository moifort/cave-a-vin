# Freemium economics — what a user costs, what the subscription must be worth

> Written 2026.07.21, before any monetization code. Supersedes the Q4 economics of
> [freemium-plan.md](./freemium-plan.md): that pass costed a scan at ~$0.003 by counting only the
> visible tokens. Gemini 2.5 Flash is a **reasoning** model and neither scan call pins a thinking
> budget, so the thinking tokens — billed at the output rate — are the largest line on a scan.
> The corrected figure is **~4x higher**, which is what moves the price.

The model decided here: **AI scans are metered monthly, everything else stays free and
unlimited**. Adding a bottle by hand, the cellar, the tastings, the dashboard and the shared
household cost a rounding error to serve, and gating them would cost acquisition for nothing.

## 1. What is actually billed

### The fixed floor

| Component | Configuration | Cost / month |
|---|---|---|
| Apple Developer Program | $99 / year | **~€7.70** |
| Secret Manager | 3 secrets (`google-api-key`, `admin-token`, `sentry-dsn`) | ~€0.20 |
| Cloud Functions gen2 / Cloud Run | `europe-west3`, 512 MiB, min 0, max 100 | ~€0, scale-to-zero under the 2M-request free tier |
| Firestore | `eur3` multi-region, free tier 50K reads + 20K writes / day | ~€0 below ~1,000 users |
| Firebase Auth | Sign in with Apple only, no SMS | €0 |
| Sentry | free tier | €0 |

**Floor ≈ €8 / month.** Apple is the whole of it.

Two notes that only matter later. Firestore `eur3` is **multi-region**, so past the free tier it
bills ~$0.09 / 100K reads and ~$0.27 / 100K writes: about 50% more than a regional database. And
`server/plugins/00-sentry.ts` traces at `tracesSampleRate: 1.0`; 100% transaction sampling is
harmless today and becomes a per-event bill with traffic. Lower it before any growth push.

### The variable cost: one scan

`server/domain/scan/index.ts` makes **two** Gemini 2.5 Flash calls per cache miss. Rates: $0.30
per M input tokens, $2.50 per M output tokens, Google Search grounding free for the first 1,500
requests a day then $35 per 1,000.

The image reaches the server at 800 px max / JPEG q0.6 (`ScanView.swift`, `CameraView.swift`),
which Gemini tiles into roughly 800 image tokens. Neither call sets `thinkingConfig`, so dynamic
thinking runs and its tokens bill as output.

| | Input | Output (incl. thinking) | Cost |
|---|---|---|---|
| Vision (image + prompt + 3.3 KB response schema) | ~2.6K tok | ~250 tok + ~1.5K thinking | **~$0.005** |
| Enrichment (`google_search` grounding) | ~5K tok (prompt + retrieved pages) | ~200 tok + ~1.5K thinking | ~$0.006 |
| Grounding request | | | $0 under 1,500/day, then **$0.035** |

**Per scan: ~$0.011 (≈ €0.010) while grounding is free, ~$0.046 (≈ €0.042) once it is billed.**

Order of magnitude, not a measurement: dynamic thinking varies with how confusing the label is.
The scan refactor should capture `usageMetadata` from both responses (ignored today) so the caps
and the price can be recalibrated against real tokens.

Two dampeners already exist: the SHA-256 `scan-cache` (rarely hits, since lossy recompression
changes the hash) and the early exit that skips enrichment when nothing was recognized.

## 2. What a subscriber is worth

Apple commissions the price **excluding VAT** (20% in France), and the Small Business Program cuts
its share from 30% to 15% — **enrollment is manual and is worth ~15% of every figure below**.

| Sticker | Net proceeds / month |
|---|---|
| €2.99 / month | **€2.12** |
| €24.99 / year | **€1.48** |
| €4.99 / month | €3.53 |
| €39.99 / year | €2.36 |

Prices were lowered from €4.99 / €39.99 to €2.99 / €24.99 on 2026.07.22, before launch: the
monthly sits inside the €3–5 band of competing cellar apps rather than above it, and the annual
carries a visible 30% discount against twelve months of it. The figures below use the current
prices.

## 3. The numbers that decide the quota

Cost of a free user who empties their monthly allowance, and of a subscriber who scans hard:

| Profile | Scans / month | While grounding is free | Once grounding is billed |
|---|---|---|---|
| Free at the cap (3) | 3 | €0.03 | €0.13 |
| Free at the cap (5) | 5 | €0.05 | €0.21 |
| Subscriber, stocking a cellar | 30 | €0.30 | €1.26 |
| Subscriber, abusive | 100 | €1.00 | €4.20 |

The first three rows are comfortable against €1.48 of net revenue. The last one is not: past
~35 scans a month with grounding billed, a subscriber on the annual plan costs more than they
bring. Unlimited must therefore mean *fair use with a ceiling*, not literally unlimited.

Scenarios at 5% conversion, a free base averaging 2 scans a month, subscribers 15:

| Base | Subscribers | Scans / month | Cost / month | Net revenue | Result |
|---|---|---|---|---|---|
| 100 free | 5 | ~265 | ~€12 | ~€9 | **-€3** |
| 1,000 free | 50 | ~2,650 | ~€37 | ~€87 | **+€50** |
| 10,000 free | 500 | ~26,500 | ~€305 | ~€870 | **+€565** |

**Break-even: about 5 subscribers** against the fixed floor; the 100-free scenario dips slightly
negative because the free base's scans outweigh five subscriptions at the lowered price. The grounding free tier (1,500 requests a day, i.e. ~45,000 a
month) only runs out around 17,000 monthly active users, so the €0.042 scan stays a distant
scenario. When it arrives, pinning `thinkingConfig.thinkingBudget` low or off halves the token
half of the bill without any expected loss on a structured extraction.

## 4. What is recommended

| | **Free** | **Premium — €2.99 / month · €24.99 / year** |
|---|---|---|
| AI scans | **5 / month**, plus **20 granted once** at the end of onboarding | unlimited (fair use, safety ceiling ~100 / month) |
| Bottles, cellar, tastings, dashboard, sharing | unlimited | unlimited |
| Manual entry | unlimited | unlimited |

Why these numbers:

- **5 scans a month** caps the free tier at €0.05 per user (€0.21 in the worst case) and is enough
  to judge whether the scan is any good. The wall it creates is the conversion moment.
- **20 scans granted once**, at the end of onboarding (`WELCOME_SCANS`, added 2026.08.04). The
  monthly cap is sized for a steady month, and a brand-new account is not in one: its cellar is
  empty and stocking it is ~30 scans, so five would put the wall before the app had shown anything.
  The grant is a balance of its own (`ai-credits`, one document per account), drawn down only once
  the month is spent and never refilled by the calendar — the month goes first because it comes
  back on the 1st and the grant never does. It costs **~€0.20 per account created**, once
  (~€0.84 with grounding billed): at 1,000 signups, €200 against a €8/month floor, which is a
  one-off acquisition cost rather than a recurring one. Sizing rule: enough for a real stocking
  session, not enough for a whole cellar, so the wall that converts still arrives — after the value
  rather than before it. One grant per account, on the first onboarding only; a deleted and
  recreated account gets a fresh one, which the friction of a new Apple ID keeps theoretical.
- **Manual entry stays free and unlimited.** This is what keeps the wall from being a wall: a free
  user who has run out of scans can still fill their cellar, just by typing. Gating the bottles
  themselves would have turned a monetization limit into a reason to uninstall.
- **€2.99 / €24.99** sits well under Vivino Premium (~€50 / year) and inside the €3–5 monthly
  band of competing cellar apps, and it still carries the corrected scan cost with ~80% margin
  while grounding is free. The annual plan is 30% off twelve months of the monthly one, the
  saving the paywall displays, and it carries the 7-day free trial: the plan worth pushing for
  cash flow and retention.
- The **safety ceiling on Premium** is not a product feature and does not need to be shown; it
  exists so no single account can ever cost more than it pays. Its sizing rule: a month at the
  ceiling may cost at most **70% of the cheapest plan's net proceeds** — the annual plan's
  €1.48 / month, so a €1.03 budget, i.e. ~100 scans at the current ~€0.01 scan
  (`PREMIUM_MONTHLY_SCANS` in `server/domain/quota/business-rules.ts`). Recompute it when the
  scan cost moves, e.g. once grounding is billed.

## 5. Guard rails to put in place

1. Enforce the quota **server-side**, on the caller's identity — never in the app alone.
2. A cache hit costs nothing and must never consume a scan.
3. Count only calls that really reached Gemini: a failed scan must not bill the user their quota.
4. Capture `usageMetadata` on both calls and recalibrate this document against real tokens.
5. Enroll in the **Small Business Program** before launch.
6. Lower `tracesSampleRate` before any growth push.
7. GCP budget alerts at ~€10 / €25 / €50.
