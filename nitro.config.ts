import { generateDomainInstrumentation } from './server/system/sentry/generate-domain-instrumentation'

export default defineNitroConfig({
  compatibilityDate: '2026-02-06',
  experimental: { asyncContext: true },
  srcDir: 'server',
  ignore: ['**/*.test.ts'],
  preset: 'firebase',
  firebase: {
    gen: 2,
    nodeVersion: '22',
    httpsOptions: {
      region: 'europe-west3',
      memory: '512MiB',
      timeoutSeconds: 60,
      concurrency: 80,
    },
  },
  rollupConfig: {
    treeshake: {
      moduleSideEffects: (id) => id.includes('/graphql/') || id.includes('node_modules'),
    },
  },
  virtual: {
    '#domain-instrumentation': generateDomainInstrumentation,
  },
  runtimeConfig: {
    googleApiKey: '',
    adminToken: '',
    sentryDsn: '',
    devUserId: '',
    scanStub: '',
    appleEnvironment: '',
    premiumUserIds: '',
    ascIssuerId: '',
    ascKeyId: '',
    ascPrivateKey: '',
    ascVendorNumber: '',
    gcpBillingTable: '',
  },
})
