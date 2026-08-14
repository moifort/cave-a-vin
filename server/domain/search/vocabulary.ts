import type { BeverageSubtype, BeverageType, WineColor } from '~/domain/beverage/types'
import { wordTokens } from './tokens'

// A facet exactly as it is written in the search index of every bottle, so a
// term read here can go straight into the Firestore clause.
export type FacetTerm = `subtype:${BeverageSubtype}` | `color:${WineColor}` | `type:${BeverageType}`

// What the user may type to designate a facet, every served language at once.
// Merged rather than picked by `Accept-Language`: a French speaker types
// "sparkling" now and then, and a phone set to English holds a cellar entered in
// French. Collisions between languages are settled by the ranking weights, never
// here — a word only ever adds results.
//
// 'other' has no entry anywhere: it designates nothing to someone searching.
const VOCABULARY: Partial<Record<FacetTerm, string[]>> = {
  'color:red': ['rouge', 'red', 'rot', 'rojo', 'tinto', 'rosso', 'vermelho', '赤'],
  'color:white': ['blanc', 'white', 'weiss', 'weiß', 'blanco', 'bianco', 'branco', '白'],
  'color:rosé': ['rosé', 'rose', 'rosado', 'rosato', 'ロゼ'],

  'type:wine': ['vin', 'wine', 'wein', 'vino', 'vinho', 'ワイン'],
  'type:spirit': [
    'spiritueux',
    'spirit',
    'spirits',
    'spirituosen',
    'destilado',
    'distillato',
    '蒸留酒',
  ],
  'type:beer': ['bière', 'beer', 'bier', 'cerveza', 'birra', 'cerveja', 'ビール'],
  'type:sake': ['saké', 'sake', '日本酒', '酒'],
  'type:cider': ['cidre', 'cider', 'apfelwein', 'sidra', 'sidro', 'シードル'],

  'subtype:sparkling': [
    'champagne',
    'crémant',
    'pétillant',
    'effervescent',
    'mousseux',
    'bulles',
    'prosecco',
    'cava',
    'spumante',
    'frizzante',
    'sparkling',
    'schaumwein',
    'sekt',
    'espumoso',
    'espumante',
    'シャンパン',
    'スパークリング',
  ],
  'subtype:sweet': [
    'moelleux',
    'liquoreux',
    'doux',
    'sweet',
    'süß',
    'dulce',
    'dolce',
    'doce',
    '甘口',
  ],
  'subtype:late-harvest': [
    'vendanges tardives',
    'late harvest',
    'spätlese',
    'vendimia tardía',
    'vendemmia tardiva',
    'colheita tardia',
    '遅摘み',
  ],
  'subtype:vin-jaune': ['vin jaune', 'yellow wine', 'vino giallo'],
  'subtype:porto': ['porto', 'port', 'oporto', 'ポート'],
  'subtype:fortified': [
    'muté',
    'vin muté',
    'fortified',
    'banyuls',
    'madère',
    'madeira',
    'xérès',
    'sherry',
    'likörwein',
    'vino generoso',
    '酒精強化',
  ],

  'subtype:rum': ['rhum', 'rum', 'ron', 'ラム'],
  'subtype:whisky': ['whisky', 'whiskey', 'bourbon', 'scotch', 'ウイスキー'],
  'subtype:gin': ['gin', 'ジン'],
  'subtype:vodka': ['vodka', 'wodka', 'ウォッカ'],
  'subtype:cognac': ['cognac', 'コニャック'],
  'subtype:armagnac': ['armagnac'],
  'subtype:tequila': ['tequila', 'mezcal', 'テキーラ'],
  'subtype:liqueur': ['liqueur', 'likör', 'licor', 'liquore', 'リキュール'],
  'subtype:eau-de-vie': ['eau de vie', 'aguardiente', 'acquavite', 'grappa', 'marc', 'obstbrand'],

  'subtype:blonde': ['blonde', 'blond', 'helles', 'rubia', 'bionda', 'loira'],
  'subtype:blanche': ['blanche', 'witbier', 'weizen', 'weissbier', 'wheat', 'blanca', 'bianca'],
  'subtype:amber': ['ambrée', 'amber', 'ámbar', 'ambrata', '琥珀'],
  'subtype:brune': ['brune', 'brown', 'dunkel', 'morena', 'scura'],
  'subtype:ipa': ['ipa', 'india pale ale'],
  'subtype:stout': ['stout', 'porter', 'スタウト'],
  'subtype:pils': ['pils', 'pilsner', 'pilsen', 'lager', 'ラガー'],
  'subtype:triple': ['triple', 'tripel'],

  'subtype:junmai': ['junmai', '純米'],
  'subtype:ginjo': ['ginjo', '吟醸'],
  'subtype:daiginjo': ['daiginjo', '大吟醸'],
  'subtype:honjozo': ['honjozo', '本醸造'],
  'subtype:nigori': ['nigori', 'にごり'],

  'subtype:brut': ['brut', 'dry', 'trocken', 'seco', 'secco', '辛口'],
  'subtype:doux': ['doux', 'dulce', 'doce', '甘口'],
  'subtype:demi-sec': ['demi-sec', 'demi sec', 'halbtrocken', 'semi seco'],
  'subtype:poire': ['poire', 'poiré', 'perry', 'birne', 'pera', '梨'],
}

// The vocabulary read backwards: the words the user types are the keys, in the
// canonical form both sides of the search agree on. A word may designate several
// facets — "doux" is a sweet wine and a sweet cider — and all of them are meant.
const FACETS_BY_PHRASE = new Map<string, FacetTerm[]>()
for (const [term, words] of Object.entries(VOCABULARY)) {
  for (const word of words) {
    const phrase = wordTokens(word).join(' ')
    if (phrase.length === 0) continue
    const facets = FACETS_BY_PHRASE.get(phrase)
    if (facets === undefined) FACETS_BY_PHRASE.set(phrase, [term as FacetTerm])
    else if (!facets.includes(term as FacetTerm)) facets.push(term as FacetTerm)
  }
}

// How many words the longest entry spans, which is how wide the query has to be
// scanned to recognize one ("india pale ale" and "eau de vie" span three).
export const LONGEST_PHRASE = Math.max(
  ...[...FACETS_BY_PHRASE.keys()].map((phrase) => phrase.split(' ').length),
)

// The facets a segment designates, empty when the vocabulary knows nothing of
// it. Whole or nothing: "champ" names no colour, a prefix would guess.
export const facetsOf = (segment: string): FacetTerm[] =>
  FACETS_BY_PHRASE.get(wordTokens(segment).join(' ')) ?? []
