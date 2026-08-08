import { builder } from './builder'

// Custom scalars must be registered before any type that references them.
import './scalars'

// Domain GraphQL layers are imported here as they come online. Each domain
// owns enums.ts, types.ts, inputs.ts, queries.ts, mutations.ts under its
// infrastructure/graphql/ directory, mirroring the bazar layout.

// Beverage domain
import '~/domain/beverage/infrastructure/graphql/enums'
import '~/domain/beverage/infrastructure/graphql/types'
import '~/domain/beverage/infrastructure/graphql/inputs'
import '~/domain/beverage/infrastructure/graphql/queries'
import '~/domain/beverage/infrastructure/graphql/mutations'

// Cellar domain (extends BeverageType with .cellar field)
import '~/domain/cellar/infrastructure/graphql/types'
import '~/domain/cellar/infrastructure/graphql/inputs'
import '~/domain/cellar/infrastructure/graphql/queries'
import '~/domain/cellar/infrastructure/graphql/mutations'

// Journal domain (extends BeverageType with .history field)
import '~/domain/journal/infrastructure/graphql/types'
import '~/domain/journal/infrastructure/graphql/queries'

// Tasting domain (extends BeverageType with .consumption field)
import '~/domain/tasting/infrastructure/graphql/types'
import '~/domain/tasting/infrastructure/graphql/inputs'
import '~/domain/tasting/infrastructure/graphql/mutations'

// Gift domain (extends BeverageType with .gift field)
import '~/domain/gift/infrastructure/graphql/types'
import '~/domain/gift/infrastructure/graphql/inputs'
import '~/domain/gift/infrastructure/graphql/mutations'

// Recommendation domain (extends BeverageType with .recommendation field)
import '~/domain/recommendation/infrastructure/graphql/types'
import '~/domain/recommendation/infrastructure/graphql/inputs'
import '~/domain/recommendation/infrastructure/graphql/mutations'

// Dashboard domain (read-only aggregation)
import '~/domain/dashboard/infrastructure/graphql/types'
import '~/domain/dashboard/infrastructure/graphql/queries'

// Search domain (read-only, reuses BeverageType imported above)
import '~/domain/search/infrastructure/graphql/enums'
import '~/domain/search/infrastructure/graphql/inputs'
import '~/domain/search/infrastructure/graphql/types'
import '~/domain/search/infrastructure/graphql/queries'

// Changelog (application release notes)
import '~/domain/changelog/infrastructure/graphql/types'
import '~/domain/changelog/infrastructure/graphql/queries'

// Household domain (shared cellar between members of one home)
import '~/domain/household/infrastructure/graphql/enums'
import '~/domain/household/infrastructure/graphql/types'
import '~/domain/household/infrastructure/graphql/queries'
import '~/domain/household/infrastructure/graphql/mutations'

// User domain (profile + onboarding state)
import '~/domain/user/infrastructure/graphql/types'
import '~/domain/user/infrastructure/graphql/inputs'
import '~/domain/user/infrastructure/graphql/queries'
import '~/domain/user/infrastructure/graphql/mutations'

// Portability (export and import of user data)
import '~/domain/portability/infrastructure/graphql/types'
import '~/domain/portability/infrastructure/graphql/queries'
import '~/domain/portability/infrastructure/graphql/mutations'

// Entitlement domain (what the App Store sold, and the plan it grants)
import '~/domain/entitlement/infrastructure/graphql/enums'
import '~/domain/entitlement/infrastructure/graphql/types'
import '~/domain/entitlement/infrastructure/graphql/queries'
import '~/domain/entitlement/infrastructure/graphql/mutations'

// Quota domain (the monthly scan allowance, read against the plan)
import '~/domain/quota/infrastructure/graphql/types'
import '~/domain/quota/infrastructure/graphql/queries'

// Scan IA (label OCR via Claude + Gemini)
import '~/domain/scan/infrastructure/graphql/types'
import '~/domain/scan/infrastructure/graphql/mutations'

// Admin (the app's monthly economics, admin accounts only)
import '~/domain/admin/infrastructure/graphql/types'
import '~/domain/admin/infrastructure/graphql/queries'

export const schema = builder.toSchema()
