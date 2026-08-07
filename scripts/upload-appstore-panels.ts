#!/usr/bin/env bun
/**
 * Uploads the App Store panels of screenshots/appstore/<lang>/ to the editable
 * version of the app, one language at a time.
 *
 * It replaces rather than adds: the 6.9" set of each locale is emptied first, the
 * five panels go up in filename order, and the run ends by counting what the store
 * actually holds. That counting is the point — `fastlane deliver` did this job until
 * 2026-08-07 and put every panel up twice, on a run it reported as green.
 *
 * Needs an App Store Connect API key: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH.
 */
import { createHash, createSign } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { readdir, readFile } from 'node:fs/promises'
import { basename, join } from 'node:path'

const BUNDLE_ID = 'com.polyforms.vinarium.app'

// The panels are 1320x2868, the 6.9" size; App Store Connect files that size under
// the 6.7" display type, which covers every large iPhone.
const DISPLAY_TYPE = 'APP_IPHONE_67'

// The App Store locales the listing is written in, keyed by the language code the
// capture pipeline uses (scripts/screenshots.sh, docs/screenshots.md).
const LOCALES: Record<string, string> = {
  fr: 'fr-FR',
  en: 'en-US',
  de: 'de-DE',
  es: 'es-ES',
  it: 'it',
  pt: 'pt-PT',
  ja: 'ja',
}

const token = () => {
  const keyId = process.env.ASC_KEY_ID
  const issuerId = process.env.ASC_ISSUER_ID
  const keyPath = process.env.ASC_KEY_PATH
  if (!keyId || !issuerId || !keyPath)
    throw new Error('ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH must be set')
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url')
  const now = Math.floor(Date.now() / 1000)
  const head = encode({ alg: 'ES256', kid: keyId, typ: 'JWT' })
  const claims = encode({ iss: issuerId, iat: now, exp: now + 20 * 60, aud: 'appstoreconnect-v1' })
  const signer = createSign('SHA256')
  signer.update(`${head}.${claims}`)
  const signature = signer
    .sign({ key: readFileSync(keyPath, 'utf8'), dsaEncoding: 'ieee-p1363' })
    .toString('base64url')
  return `${head}.${claims}.${signature}`
}

const bearer = token()

/** What the App Store Connect API answers: resources carrying typed attributes. */
type Resource<Attributes> = { id: string; attributes: Attributes }
type Collection<Attributes> = { data: Resource<Attributes>[] }
type Single<Attributes> = { data: Resource<Attributes> }
type Version = { versionString: string; appStoreState: string }
type Screenshot = { fileName: string }
type UploadOperation = {
  method: string
  url: string
  offset: number
  length: number
  requestHeaders: { name: string; value: string }[]
}

const api = async <T>(path: string, init: RequestInit = {}): Promise<T> => {
  const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${bearer}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  })
  if (!response.ok)
    throw new Error(`${init.method ?? 'GET'} ${path} → ${response.status} ${await response.text()}`)
  return (response.status === 204 ? undefined : await response.json()) as T
}

/** The version the store lets us edit — the one a release is preparing. */
const editableVersion = async () => {
  const apps = await api<Collection<{ bundleId: string }>>(`/v1/apps?filter[bundleId]=${BUNDLE_ID}`)
  const appId = apps.data[0]?.id
  if (!appId) throw new Error(`No app for ${BUNDLE_ID}`)
  const versions = await api<Collection<Version>>(`/v1/apps/${appId}/appStoreVersions?limit=10`)
  // Anything but these four states is a version already handed to Apple, whose
  // screenshots are frozen; failing here beats uploading into a void.
  const editable = ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED']
  const version = versions.data.find((v) => editable.includes(v.attributes.appStoreState))
  if (!version)
    throw new Error(
      `No editable version: ${versions.data
        .map((v) => `${v.attributes.versionString} is ${v.attributes.appStoreState}`)
        .join(', ')}`,
    )
  return version
}

const screenshotSet = async (localizationId: string) => {
  const sets = await api<Collection<{ screenshotDisplayType: string }>>(
    `/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets`,
  )
  const existing = sets.data.find((s) => s.attributes.screenshotDisplayType === DISPLAY_TYPE)
  if (existing) return existing.id
  const created = await api<Single<{ screenshotDisplayType: string }>>('/v1/appScreenshotSets', {
    method: 'POST',
    body: JSON.stringify({
      data: {
        type: 'appScreenshotSets',
        attributes: { screenshotDisplayType: DISPLAY_TYPE },
        relationships: {
          appStoreVersionLocalization: {
            data: { type: 'appStoreVersionLocalizations', id: localizationId },
          },
        },
      },
    }),
  })
  return created.data.id
}

const upload = async (setId: string, path: string) => {
  const bytes = await readFile(path)
  const reserved = await api<Single<{ uploadOperations: UploadOperation[] }>>(
    '/v1/appScreenshots',
    {
      method: 'POST',
      body: JSON.stringify({
        data: {
          type: 'appScreenshots',
          attributes: { fileSize: bytes.length, fileName: basename(path) },
          relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: setId } } },
        },
      }),
    },
  )
  // The store hands back the byte ranges it wants and where to PUT each of them.
  for (const operation of reserved.data.attributes.uploadOperations) {
    const headers = Object.fromEntries(operation.requestHeaders.map((h) => [h.name, h.value]))
    const response = await fetch(operation.url, {
      method: operation.method,
      headers,
      body: bytes.subarray(operation.offset, operation.offset + operation.length),
    })
    if (!response.ok) throw new Error(`${operation.method} ${basename(path)} → ${response.status}`)
  }
  await api(`/v1/appScreenshots/${reserved.data.id}`, {
    method: 'PATCH',
    body: JSON.stringify({
      data: {
        type: 'appScreenshots',
        id: reserved.data.id,
        attributes: {
          uploaded: true,
          sourceFileChecksum: createHash('md5').update(bytes).digest('hex'),
        },
      },
    }),
  })
  return reserved.data.id
}

const version = await editableVersion()
console.log(`Version ${version.attributes.versionString} (${version.attributes.appStoreState})`)

const localizations = await api<Collection<{ locale: string }>>(
  `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`,
)

for (const [language, locale] of Object.entries(LOCALES)) {
  const directory = join(import.meta.dir, '..', 'screenshots', 'appstore', language)
  const panels = (await readdir(directory)).filter((f) => f.endsWith('.png')).sort()
  if (panels.length === 0)
    throw new Error(
      `No panels in screenshots/appstore/${language} — run \`bun scripts/generate-appstore-previews.ts\` first`,
    )

  const localization = localizations.data.find((l) => l.attributes.locale === locale)
  if (!localization) throw new Error(`The version has no ${locale} localization`)
  const setId = await screenshotSet(localization.id)

  const before = await api<Collection<Screenshot>>(
    `/v1/appScreenshotSets/${setId}/appScreenshots?limit=50`,
  )
  for (const screenshot of before.data)
    await api(`/v1/appScreenshots/${screenshot.id}`, { method: 'DELETE' })

  const uploaded: string[] = []
  for (const panel of panels) uploaded.push(await upload(setId, join(directory, panel)))

  // Order is the reading order in the store, and it is not the upload order.
  await api(`/v1/appScreenshotSets/${setId}/relationships/appScreenshots`, {
    method: 'PATCH',
    body: JSON.stringify({ data: uploaded.map((id) => ({ type: 'appScreenshots', id })) }),
  })

  const after = await api<Collection<Screenshot>>(
    `/v1/appScreenshotSets/${setId}/appScreenshots?limit=50`,
  )
  const names = after.data.map((s) => s.attributes.fileName)
  if (names.length !== panels.length)
    throw new Error(
      `${locale}: ${names.length} screenshots on the store for ${panels.length} panels`,
    )
  console.log(`${locale}: ${names.join(' ')}`)
}
