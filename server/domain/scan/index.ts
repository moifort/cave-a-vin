import { createHash } from 'node:crypto'
import type { AiStepUsage } from '~/domain/admin/types'
import { SUBTYPES_BY_BEVERAGE } from '~/domain/beverage/business-rules'
import { BEVERAGE_SUBTYPE_VALUES } from '~/domain/beverage/primitives'
import * as repository from '~/domain/scan/infrastructure/repository'
import {
  EnrichSchema,
  ImageHash,
  parseScanResponse,
  ScanResultSchema,
} from '~/domain/scan/primitives'
import type { ImageHash as ImageHashType, ScanLanguage, ScanResult } from '~/domain/scan/types'
import { Count } from '~/domain/shared/primitives'
import { config } from '~/system/config/index'
import { createLogger } from '~/system/logger'

const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'

const logger = createLogger('scan')

// What Gemini says the call cost. Thinking tokens bill at the output rate and
// are the largest line on a scan, so they are kept apart: the free allowance
// and the price are sized on these numbers (docs/freemium-economics.md), and
// the admin metrics recalibrate them against what is captured here.
type GeminiUsage = {
  promptTokenCount?: number
  candidatesTokenCount?: number
  thoughtsTokenCount?: number
  totalTokenCount?: number
}

// What the two Gemini calls of one scan consumed, absent for a step that never
// ran (a cache hit, an unrecognized label skipping enrichment).
export type ScanUsage = { vision?: AiStepUsage; enrichment?: AiStepUsage }

const capturedUsage = (
  step: 'vision' | 'enrichment',
  usage: GeminiUsage | undefined,
): AiStepUsage | undefined => {
  if (!usage) return undefined
  logger.info(
    `${step}: ${usage.promptTokenCount ?? 0} in, ${usage.candidatesTokenCount ?? 0} out, ${usage.thoughtsTokenCount ?? 0} thinking`,
  )
  return {
    promptTokens: Count(usage.promptTokenCount ?? 0),
    outputTokens: Count(usage.candidatesTokenCount ?? 0),
    thinkingTokens: Count(usage.thoughtsTokenCount ?? 0),
  }
}

export namespace Scan {
  // `cacheHit` is what the quota is metered on: a cached label costs nothing, so
  // it must not spend anyone's allowance. Only a scan that really reached Gemini
  // is billed to us, and only that one is billed to the caller. `usage` carries
  // what the calls that did run consumed, for the admin cost metrics.
  export const scanWithCache = async (
    imageBuffer: Buffer,
    language: ScanLanguage,
  ): Promise<{ result: ScanResult; cacheHit: boolean; usage: ScanUsage }> => {
    // End-to-end runs answer with a fixed label instead of calling Gemini: the
    // models cost money, take seconds and never answer twice the same, none of
    // which a release gate can rely on. Counted as a real scan (cacheHit false)
    // so the quota path stays the one production takes.
    //
    // `import.meta.dev` is compile-time, so this whole branch is tree-shaken out
    // of a built bundle: no environment variable can turn the stub on in
    // production. Same gate as the dev auth bypass in middleware/auth.ts.
    if (import.meta.dev && config().scanStub)
      return { result: STUBBED_LABEL, cacheHit: false, usage: {} }
    const imageHash = hashImage(imageBuffer)
    // The cache is keyed by image AND language: the same label scanned in two
    // languages must not serve one language's text to the other.
    const cached = await repository.findBy(imageHash, language)
    // Re-parse cached results: entries written before multi-beverage support
    // have no beverageType and get the wine default.
    if (cached) return { result: ScanResultSchema.parse(cached.result), cacheHit: true, usage: {} }
    const { result: scanResult, usage: vision } = await scanLabel(imageBuffer, language)
    // Nothing recognized: skip the enrichment search (pointless) and skip caching
    // so a fresh attempt on the same image starts over rather than reusing a miss.
    if (!scanResult.recognized) return { result: scanResult, cacheHit: false, usage: { vision } }
    const { result: enriched, usage: enrichment } = await enrichWithSearch(scanResult, language)
    // Best-effort cache: a failed write only costs a re-scan on the next hit.
    repository.save({ imageHash, language, result: enriched, cachedAt: new Date() }).catch(() => {})
    return { result: enriched, cacheHit: false, usage: { vision, enrichment } }
  }

  // What a stubbed scan returns. A complete wine — the review form shows every
  // field, so a partial one would leave the end-to-end scenario blind to half
  // of it.
  const STUBBED_LABEL: ScanResult = {
    recognized: true,
    name: 'Château Vinarium',
    beverageType: 'wine',
    color: 'red',
    alcoholContent: 13.5,
    domain: 'Château Vinarium',
    vintage: 2020,
    appellation: 'Saint-Émilion Grand Cru',
    region: 'Bordeaux',
    country: 'France',
    grapeVarieties: ['Merlot', 'Cabernet Franc'],
    classification: 'Grand Cru',
    drinkFrom: 2025,
    drinkUntil: 2035,
    estimatedPrice: 42,
  }

  // The language name is written into the (French) prompt so Gemini emits every
  // free-text value in the caller's language. Prices stay in euros regardless
  // (canonical storage currency; the client converts for display).
  const LANGUAGE_NAMES: Record<ScanLanguage, string> = {
    fr: 'français',
    en: 'anglais',
    de: 'allemand',
    es: 'espagnol',
    it: 'italien',
    pt: 'portugais',
    ja: 'japonais',
  }

  const scanLabel = async (
    imageBuffer: Buffer,
    language: ScanLanguage,
  ): Promise<{ result: ScanResult; usage?: AiStepUsage }> => {
    const { googleApiKey } = config()
    const base64 = imageBuffer.toString('base64')

    const response = await $fetch<{
      candidates: { content: { parts: { text?: string }[] } }[]
      usageMetadata?: GeminiUsage
    }>(`${GEMINI_API_URL}?key=${googleApiKey}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: {
        contents: [
          {
            parts: [
              { inline_data: { mime_type: 'image/jpeg', data: base64 } },
              {
                text: `Analyse cette image d'étiquette de boisson alcoolisée et extrais toutes les informations visibles.\n\nÉTAPE 0 — Détermine recognized : mets recognized=false et name="" si l'image n'est PAS une étiquette de boisson identifiable (aucune étiquette lisible, objet quelconque, photo floue ou illisible). Sinon mets recognized=true et poursuis. Ne mets recognized=false que si tu ne peux vraiment rien identifier.\n\nÉTAPE 1 — Détermine d'abord beverageType parmi : wine (vin), spirit (spiritueux/alcool fort distillé), beer (bière), sake (saké japonais), cider (cidre/poiré), other. Indices de classification :\n- wine : mention de cépages, d'appellation (AOC/AOP/DOC), millésime, ~11-15% vol, bouteille bordelaise/bourguignonne.\n- spirit : whisky, rhum, gin, vodka, cognac, armagnac, tequila, mezcal, liqueur — souvent 37,5-50%+ vol, mention d'âge (ex : 12 ans) ou de distillerie.\n- beer : brasserie, IPA/Lager/Stout/Pils/Triple, ~4-9% vol, canette ou bouteille capsulée.\n- sake : texte japonais, mention 純米/吟醸/大吟醸 (Junmai/Ginjo/Daiginjo), kura (brasserie de saké), ~14-17% vol.\n- cider : pomme/poire, cidrerie, Brut/Doux/Fermier, ~2-8% vol.\nSi le type est réellement indéterminable, mets 'other'.\n\nÉTAPE 2 — Selon le type :\n- Pour un vin : color est OBLIGATOIRE parmi red/white/rosé — c'est la robe. Un champagne, crémant ou autre effervescent garde sa robe en color (white ou rosé) et reçoit subtype 'sparkling'. Estime drinkFrom/drinkUntil selon le type de vin, le millésime, la région et la classification.\n- Pour toute autre boisson : mets color à null et laisse les champs spécifiques au vin (grapeVarieties, appellation, classification, drinkFrom, drinkUntil) à null.\n\nÉTAPE 3 — Renseigne subtype avec une valeur COHÉRENTE avec beverageType, ou null si incertain :\n- wine → sparkling (effervescent), sweet (moelleux/liquoreux), late-harvest (vendanges tardives), vin-jaune, porto, fortified (autre vin muté : Banyuls, Madère, Xérès…)\n- spirit → rum, whisky, gin, vodka, cognac, armagnac, tequila (ou mezcal), liqueur, eau-de-vie\n- beer → blonde, blanche, amber (ambrée), brune, ipa, stout, pils (ou lager), triple\n- sake → junmai, ginjo, daiginjo, honjozo, nigori, sparkling (saké pétillant)\n- cider → brut, doux, demi-sec, poire (poiré)\n- 'other' si aucune valeur ne convient.\n\nLe champ domain désigne le producteur : domaine, distillerie, brasserie ou kura. Pour alcoholContent, indique le degré d'alcool en % vol s'il est visible. Pour estimatedPrice, estime le prix actuel du marché en euros selon le producteur et les caractéristiques. Toutes les valeurs textuelles (nom, producteur, région, pays, cépages, appellation, classification) doivent être en ${LANGUAGE_NAMES[language]}. Si une information n'est pas visible ou estimable, mets la valeur à null (ou un tableau vide pour grapeVarieties).`,
              },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: {
            type: 'object',
            properties: {
              recognized: {
                type: 'boolean',
                description:
                  "false si l'image n'est pas une étiquette de boisson identifiable, true sinon",
              },
              name: {
                type: 'string',
                description: "Nom de la boisson tel qu'indiqué sur l'étiquette",
              },
              beverageType: {
                type: 'string',
                enum: ['wine', 'spirit', 'beer', 'sake', 'cider', 'other'],
                description: "Type de boisson ; 'other' si indéterminable",
              },
              subtype: {
                type: 'string',
                enum: [...BEVERAGE_SUBTYPE_VALUES],
                nullable: true,
                description: 'Sous-type structuré, cohérent avec beverageType ; null si incertain',
              },
              alcoholContent: {
                type: 'number',
                nullable: true,
                description: "Degré d'alcool en % vol",
              },
              domain: {
                type: 'string',
                nullable: true,
                description: 'Producteur : domaine, distillerie, brasserie ou kura',
              },
              vintage: { type: 'integer', nullable: true, description: 'Année du millésime' },
              appellation: {
                type: 'string',
                nullable: true,
                description: 'Appellation (ex : Bordeaux, Bourgogne)',
              },
              region: {
                type: 'string',
                nullable: true,
                description: 'Région viticole',
              },
              country: {
                type: 'string',
                nullable: true,
                description: "Pays d'origine (ex : France, Espagne, Italie)",
              },
              color: {
                type: 'string',
                enum: ['red', 'white', 'rosé'],
                nullable: true,
                description: 'Robe du vin — obligatoire pour un vin, null sinon',
              },
              grapeVarieties: {
                type: 'array',
                items: { type: 'string' },
                description: 'Cépages mentionnés',
              },
              classification: {
                type: 'string',
                nullable: true,
                description: 'Classification (ex : Grand Cru, Premier Cru, AOC, AOP, IGP)',
              },
              drinkFrom: {
                type: 'integer',
                nullable: true,
                description: 'Année estimée à partir de laquelle le vin peut être apprécié',
              },
              drinkUntil: {
                type: 'integer',
                nullable: true,
                description: "Année estimée jusqu'à laquelle le vin devrait être consommé",
              },
              estimatedPrice: {
                type: 'number',
                nullable: true,
                description:
                  "Prix estimé en euros basé sur les caractéristiques, le millésime, l'appellation, la classification et la réputation du producteur",
              },
            },
            required: ['recognized', 'name', 'beverageType'],
            propertyOrdering: [
              'recognized',
              'name',
              'beverageType',
              'subtype',
              'alcoholContent',
              'domain',
              'vintage',
              'appellation',
              'region',
              'country',
              'color',
              'grapeVarieties',
              'classification',
              'drinkFrom',
              'drinkUntil',
              'estimatedPrice',
            ],
          },
        },
      },
    })

    const usage = capturedUsage('vision', response.usageMetadata)

    const text = response.candidates?.[0]?.content?.parts?.find((p) => p.text)?.text
    if (!text) throw new Error('Gemini did not return structured wine data')

    return { result: parseScanResponse(text), usage }
  }

  const BEVERAGE_LABELS: Record<ScanResult['beverageType'], string> = {
    wine: 'vin',
    spirit: 'spiritueux',
    beer: 'bière',
    sake: 'saké',
    cider: 'cidre',
    other: 'boisson',
  }

  const enrichWithSearch = async (
    scanResult: ScanResult,
    language: ScanLanguage,
  ): Promise<{ result: ScanResult; usage?: AiStepUsage }> => {
    const { googleApiKey } = config()

    const description = [
      scanResult.name,
      scanResult.domain,
      scanResult.subtype,
      scanResult.vintage ? `millésime ${scanResult.vintage}` : null,
      scanResult.appellation,
      scanResult.region,
      scanResult.country,
    ]
      .filter(Boolean)
      .join(', ')

    // The structured subtype the enrichment may fill: only the values valid for
    // this beverage type are offered to the model.
    const subtypeField = `  "subtype": string ou null (sous-type, uniquement parmi : ${SUBTYPES_BY_BEVERAGE[scanResult.beverageType].join(', ')}),`

    const wineFields = `${subtypeField}
  "drinkFrom": number ou null (année à partir de laquelle boire),
  "drinkUntil": number ou null (année limite pour le boire),
  "grapeVarieties": string[] (cépages principaux),
  "classification": string ou null (classification officielle),
  "appellation": string ou null (appellation),`

    const otherFields = subtypeField

    const prompt = `Recherche des informations sur ce ${BEVERAGE_LABELS[scanResult.beverageType]} : ${description}.

Donne-moi les informations suivantes au format JSON strict (sans markdown, juste le JSON) :
{
  "estimatedPrice": number ou null (prix moyen actuel en euros),
  "alcoholContent": number ou null (degré d'alcool en % vol),
${scanResult.beverageType === 'wine' ? wineFields : otherFields}
  "region": string ou null (région de production),
  "country": string ou null (pays)
}

Toutes les valeurs textuelles doivent être en ${LANGUAGE_NAMES[language]} (noms de pays, régions, cépages, etc.).
Utilise les données les plus récentes disponibles sur le web. Si tu ne trouves pas une information, mets null.`

    const response = await $fetch<{
      candidates: { content: { parts: { text?: string }[] } }[]
      usageMetadata?: GeminiUsage
    }>(`${GEMINI_API_URL}?key=${googleApiKey}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: {
        contents: [{ parts: [{ text: prompt }] }],
        tools: [{ google_search: {} }],
      },
    })

    const usage = capturedUsage('enrichment', response.usageMetadata)

    const text = response.candidates?.[0]?.content?.parts?.find((p) => p.text)?.text
    if (!text) return { result: scanResult, usage }

    try {
      const jsonMatch = text.match(/\{[\s\S]*\}/)
      if (!jsonMatch) return { result: scanResult, usage }
      const enriched = EnrichSchema.parse(JSON.parse(jsonMatch[0]))

      return {
        result: {
          ...scanResult,
          estimatedPrice: enriched.estimatedPrice ?? scanResult.estimatedPrice,
          alcoholContent: enriched.alcoholContent ?? scanResult.alcoholContent,
          subtype: enriched.subtype ?? scanResult.subtype,
          drinkFrom: enriched.drinkFrom ?? scanResult.drinkFrom,
          drinkUntil: enriched.drinkUntil ?? scanResult.drinkUntil,
          grapeVarieties:
            enriched.grapeVarieties && enriched.grapeVarieties.length > 0
              ? enriched.grapeVarieties
              : scanResult.grapeVarieties,
          region: enriched.region ?? scanResult.region,
          country: enriched.country ?? scanResult.country,
          classification: enriched.classification ?? scanResult.classification,
          appellation: enriched.appellation ?? scanResult.appellation,
        },
        usage,
      }
    } catch {
      return { result: scanResult, usage }
    }
  }

  const hashImage = (imageBuffer: Buffer): ImageHashType =>
    ImageHash(createHash('sha256').update(imageBuffer).digest('hex'))
}
