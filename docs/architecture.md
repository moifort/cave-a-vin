# Backend Architecture

## Overview

The backend follows a Domain-Driven Design (DDD) architecture built on [Nitro](https://nitro.build/) with TypeScript, native Firestore storage, and branded types. The public API is GraphQL only (a single `POST /graphql`), plus one operational route (`POST /admin/migrate`).

## Theoretical Foundations

This architecture draws from two foundational DDD books:

- **Eric Evans** — *Domain-Driven Design: Tackling Complexity in the Heart of Software* (2003)
- **Scott Wlashin** — *Domain Modeling Made Functional: Tackle Software Complexity with Domain-Driven Design and F#* (2018)

**Evans concepts used in this project:**

| Concept | Where |
|---------|-------|
| Bounded Context | Each `server/domain/{domain}/` is a self-contained context with clear boundaries |
| Ubiquitous Language | Function and type names carry business meaning, not technical jargon |
| Value Objects | Branded types in `types.ts` — identity through value, not reference |
| Entities | Domain types with an `id` field in `types.ts` |
| Repository | `infrastructure/repository.ts` — abstracts Firestore, private to the bounded context |
| Application Services | `query.ts`, `command.ts`, `use-case.ts` — orchestrate domain operations |
| Anti-Corruption Layer | Zod validation at domain boundaries prevents invalid data from entering |

**Wlashin concepts used in this project:**

| Concept | Where |
|---------|-------|
| Making illegal states unrepresentable | Branded types + Zod constructors in `primitives.ts`, discriminated unions in `types.ts` |
| Railway-Oriented Programming | String-literal outcomes returned from commands — reserved for expected business outcomes only, not technical errors. `throw` for impossible states. |
| Types as documentation | Branded types make the domain model self-documenting |
| Pure domain functions | `business-rules.ts` — no IO, no async, pure input/output |

## Directory Structure

```
server/
├── domain/                     # Business logic (DDD bounded contexts)
│   ├── shared/                 # Cross-domain types + GraphQL infra
│   │   ├── types.ts            # Shared branded types (Eur, Year, Country, UserId …)
│   │   ├── primitives.ts       # Their Zod constructors
│   │   └── graphql/            # Pothos builder, scalars, schema, loaders, errors
│   └── {domain}/               # One folder per domain (beverage, cellar, gift …)
│       ├── types.ts            # Domain types (branded)
│       ├── primitives.ts       # Zod validation constructors
│       ├── command.ts          # Write operations (public namespace)
│       ├── query.ts            # Read operations (public namespace)
│       ├── use-case.ts         # (optional) Multi-domain orchestrations
│       ├── business-rules.ts   # (optional) Pure functions, no IO
│       └── infrastructure/
│           ├── repository.ts   # Firestore access (private to the domain)
│           └── graphql/        # Pothos types, queries, mutations, inputs, enums
├── routes/                     # HTTP endpoints (auto-scanned by Nitro)
│   ├── graphql.ts              # The single GraphQL endpoint (Apollo Server)
│   └── admin/migrate.post.ts   # Runs pending Firestore migrations
├── middleware/                 # Request middleware (auth → sets event.context.userId)
├── plugins/                    # Nitro plugins (Sentry, Apollo bootstrap)
├── system/                     # Infrastructure (firebase, logger, migration, request-cache, sentry)
├── utils/                      # firestore.ts helpers, input helpers
└── test/                       # fake-firestore.ts, bdd.ts, shared test setup
```

There is **no `read-model/` layer and no event bus**. Composite, cross-domain reads live in two places: the domain `query.ts` (which may call other domains' public `Query` namespaces) and the GraphQL nested resolvers (which fan out through per-request loaders). See [Cross-Domain Reads](#cross-domain-reads) below.

## Layers

### Domain Layer (`server/domain/`)

Each domain is a self-contained bounded context:

- **types.ts** — Branded types using `ts-brand`, plus discriminated unions. Evans: Value Objects (identity through value) and Entities (types with an `id`).
- **primitives.ts** — Zod constructors that validate and brand raw values. Wlashin: making illegal states unrepresentable — if it parses, it's valid.
- **infrastructure/repository.ts** — Firestore access (private, never imported from outside the domain). A module of bare exported functions, imported as `* as repository` from `command.ts`/`query.ts`. Evans: Repository pattern — abstracts persistence behind a domain-oriented interface.
- **query.ts** — Public read operations (exported `XxxQuery` namespace). Evans: the public contract of the bounded context.
- **command.ts** — Public write operations (exported `XxxCommand` namespace). Evans: Application Service — orchestrates domain logic and exposes it to the outside.
- **use-case.ts** — (optional) Multi-domain orchestrations. Names carry business intent (`addWithTasting`, `removeCompletely` — never `handleCreate`). No direct storage access. Evans: Application Service coordinating multiple bounded contexts.
- **business-rules.ts** — (optional) Pure functions (no IO, no async). Function names ARE the business concept (`beverageStatus`, `readyToDrink` — never `computeBeverageStatus`). 100% test coverage required. Wlashin: pure domain functions — all logic is testable without infrastructure.

### GraphQL Layer (`server/domain/{domain}/infrastructure/graphql/` + `server/domain/shared/graphql/`)

Code-first GraphQL API using Apollo Server + [Pothos](https://pothos-graphql.dev/). The schema is assembled from per-domain `infrastructure/graphql/` folders; the shared infrastructure lives in `server/domain/shared/graphql/`:

- **builder.ts** — the Pothos `SchemaBuilder`, `GraphQLContext` type (`event`, `userId`, `loaders`), and the `Scalars` map. `DefaultFieldNullability: false` — every field is non-null unless it opts in with `nullable: true`.
- **scalars.ts** — one custom scalar per branded type. Resolvers receive pre-validated branded args; invalid input becomes a `BAD_USER_INPUT` GraphQL error at parse time.
- **schema.ts** — imports every domain's GraphQL module (registering its types/queries/mutations on the shared `builder`) and exports the assembled schema.
- **errors.ts** — `notFound`, `badUserInput`, `domainError` — `never`-returning helpers that throw a `GraphQLError` with an `extensions.code`. They sit in `match()` arms while the success arm keeps the resolver's inferred type.
- **loaders.ts** — per-request satellite loaders (see below).
- **Types** reference domain types as Pothos backing models — no type duplication (`builder.objectRef<Beverage>('Beverage')`).
- **Queries/Mutations** delegate to domain `Query`/`Command`/`UseCase` namespaces and map string-literal outcomes to HTTP-shaped GraphQL errors with `match().exhaustive()`.
- **Schema SDL** exported to `shared/schema.graphql` (`bun run generate:graphql`) for Apollo iOS codegen.

See [api-patterns.md](./api-patterns.md) for resolver patterns and [error-handling.md](./error-handling.md) for outcome mapping.

### Route Layer (`server/routes/`)

Only two routes exist. `graphql.ts` builds a fresh loader set per request and hands the H3 event to Apollo Server. `admin/migrate.post.ts` runs pending migrations (see [migrations.md](./migrations.md)). Auth is handled in middleware, which sets `event.context.userId`.

### System Layer (`server/system/`)

Infrastructure concerns: `firebase.ts` (the `db()` accessor), `logger.ts`, `request-cache.ts` (per-request memoization), `migration/` (runner + migrations), `sentry/`.

## Cross-Domain Rules

1. **Repositories are private** — A repository is only used within its own domain (`command.ts`, `query.ts`). Other domains access data through public `Query` namespaces. Evans: Bounded Context integrity — each context owns its data and protects its invariants.
2. **Validation at domain boundary** — All data entering a domain is validated/branded (at the GraphQL scalar or in `primitives.ts`). No re-validation internally. Evans: Anti-Corruption Layer.
3. **No domain-to-domain imports of internals** — Domains communicate through public `Query`/`Command` namespaces, never by importing each other's repositories or `infrastructure/`. Evans: contexts communicate through well-defined public interfaces.

## Data Flow

**Simple operation (single domain):**
```
GraphQL request → routes/graphql.ts → Apollo → resolver → domain command/query → repository → Firestore
```

**Orchestrated operation (multi-domain):**
```
GraphQL request → resolver → use-case → multiple commands/queries → Firestore
```

**Query with nested satellite fields:**
```
GraphQL query → resolver (list of beverages) → domain query
             → nested resolver per field (cellar, gift, …) → per-request loader → one batched read
```

## Storage

Native Firestore via `firebase-admin`. The single accessor is `db()` from `server/system/firebase.ts`; it is only called inside `infrastructure/repository.ts`. Each collection is opened with a typed converter:

```ts
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'

const beverages = () => db().collection('beverages').withConverter(genericDataConverter<Beverage>())
```

`genericDataConverter<T>()` (in `server/utils/firestore.ts`) recursively turns Firestore `Timestamp` values back into JS `Date` on read. Other helpers in the same file:

- **`atomically(batch => …)`** — runs the callback against a fresh `WriteBatch` and commits it once: every enlisted write lands or none does. Reads inside the callback see pre-batch state.
- **`deleteInBatches(refs)`** — deletes many document refs, chunked under the 500-op batch cap.
- **`bulkSave(rows, save)`** — persists many records with bounded write concurrency (used by import/restore, where the row count can exceed a single batch).
- **`userBeverageRecordRepository<T>(collection)`** — a ready-made repository for the satellite collections keyed by the deterministic doc id `${userId}_${beverageId}` (tasting, gift, recommendation).

### Satellite collections & the N+1 rule

Nested `Beverage` fields (`cellar`, `consumption`, `gift`, `recommendation`, `history`) must **never** scan a collection or read one doc per parent row. They resolve through the per-request loaders in `server/domain/shared/graphql/loaders.ts`: each loader is memoized and micro-batched by `beverageId`, so a page of 40 beverages costs **one batched read per selected satellite**, and an unselected satellite costs nothing. Read budgets are asserted in tests via `fake.docReads` / `fake.queryReads` (see [error-handling.md](./error-handling.md) and the testing notes below).

### Per-request cache

`server/system/request-cache.ts` exposes `memoizedPerRequest(key, fn)`: a domain query called several times within the same request reads once. The cache lives on the H3 event context, so it is request-scoped and discarded when the request ends — no cross-request staleness. `isInRequestCache(key)` lets a batched read reuse an already-run full scan for zero extra reads.

A write followed by a read in the same request would otherwise see pre-write state, which is why every write in `userBeverageRecordRepository` calls `evictFromRequestCache` on its scan key. Search reindexing depends on it: a mutation writes a satellite, then rebuilds the wine's terms from that satellite in the same request.

### The search index (`searchIndex` on `beverages`)

Firestore has no full-text search, so each beverage document carries a `searchIndex: string[]` of everything it can be found by: the canonical words of its name, producer, subtype, appellation and region, its vintage with prefixes, and its facets (`type:…`, `color:…`, `subtype:…`, `incellar`, `fav:<uid>`, `gift:<uid>`, `consumed:<uid>`, `p:<uid>:<word>` for people). A search asks Firestore for one `array-contains-any` — the only array clause a query may hold — and settles the remaining words, the facets, the household visibility rule and the ranking in memory, on the handful of documents that come back. One composite index covers every combination of filters: `userId + searchIndex`.

Terms that belong to a person rather than to the wine carry their owner's id, because a shared bottle holds the notes of several household members at once and nobody's favourites may surface in someone else's search.

**The rule to remember:** any mutation that can change one of those terms must call `SearchIndexUseCase.refresh(viewerId, beverageId)` afterwards, from the GraphQL resolver. The array is rebuilt whole, never patched, so a term that no longer applies disappears on its own — but a forgotten call leaves a wine that works everywhere except in the search, with no error and no log. `server/domain/search/infrastructure/graphql/reindexing.feat.test.ts` covers each mutation; add a case there when you add one.

## Cross-Domain Reads

Because there is no read-model layer, composite views are assembled in two ways:

1. **In `query.ts`** — a domain query may call another domain's public `Query` namespace. Example: `BeverageQuery.list` filters by favorite/gifted/recommended/in-cellar by calling `TastingQuery`, `GiftQuery`, `RecommendationQuery`, `CellarQuery`. Each of those is a memoized full scan, so the request never pays for it twice.
2. **In GraphQL nested resolvers** — the satellite fields on `Beverage` resolve independently through the per-request loaders, so clients pay only for the fields they select.

## Observability

- **Logging** — structured logging via [consola](https://github.com/unjs/consola). Each module creates a tagged logger:
  ```ts
  import { createLogger } from '~/system/logger'
  const log = createLogger('migration')
  log.info('Applied migration', { version })
  ```
  The factory is in `server/system/logger.ts`. Never use raw `console.log`.
- **Sentry** — initialised in `server/plugins/00-sentry.ts` with the instrumentation in `server/system/sentry/`. Unexpected errors (thrown from resolvers/commands) are captured automatically.
