# Changelog

## 1.6 (2026.08.06)

### New
- From the Settings menu, you can now report a bug or suggest improvements and new features.
- As a welcome gift, we are giving you 20 scans when you open your account, so you can try the app properly.
- Everything about your allowance is now available from the Settings.
- To make things clearer, we show how many results the search found.

### Fixes
- Search finds your bottles even when you forget the accents or the plurals: "chateaux margaux" finds "Château Margaux".

### Performance
- Search now shows its results faster, even on a large number of bottles.

## 1.5 (2026.07.29)

### New
- The Premium screen now opens on the account's own figures: the scans used, the ones left, and the date the allowance renews.
- The page of a stored bottle now states where it sits in the cellar.

### Fixes
- A subscription bought on the App Store now activates as soon as it is paid for.
- A bottle is now stored in the slot that was picked, instead of the one beside it.
- The grid shown when moving a bottle now has the cellar's own dimensions.
- Some text did not follow the app's language and always appeared in French. This is fixed on the dashboard, in the loading messages and in the settings.

## 1.4 (2026.07.22)

### New
- The label scan now draws on a monthly allowance of five free scans. When the month's allowance is spent, the scan screen presents Vinarium Premium. Everything else in the app stays free and unlimited.
- Vinarium Premium unlocks unlimited scans, as a monthly plan or a yearly plan that starts with seven days free. The offer can be found in Settings, and the subscription is managed from the App Store account.

### Performance
- The dashboard opens faster.

## 1.3 (2026.07.18)

### New
- During a scan, the photographed label stays on screen with an animated indicator while the analysis runs, instead of a blank loading screen.
- When a scan does not recognize a label, a clear screen now says so and offers to try again, instead of opening an empty form.
- The shared cellar now pools its total value, its ready-to-drink alerts and its journal across the household. Each journal movement shows the member behind it.

## 1.2 (2026.07.16)

### New
- The cellar's size can now be changed from Settings, starting from a model or by setting the number of rows and slots. Bottles stay in place.
- Bottles in the shared cellar are now searchable. The whole household's bottles appear in the list and the search, with their owner's name.
- The first name appears on the profile.

### Fixes
- Invitation links now open the app reliably.

## 1.1 (2026.07.15)

### New
- A setup flow at first launch asks for the first name, then the cellar's dimensions (number of rows and slots). The model can be picked from a catalog of retail wine coolers, searchable by brand or model, for automatic sizing, or the dimensions entered by hand. The number of temperature zones is saved too.
- Cellar size is no longer fixed. It matches the dimensions chosen during setup, and both the placement grid and the displayed capacity adapt to them.
- The tab bar collapses automatically on scroll to enlarge the content area, and the Scan button stays pinned on the right.
- On the login screen, the logo animates on open, with a mosaic of caps in the app's colors cascading in.
- Opening an invitation link now launches the app straight onto the screen to join the household. If the app isn't installed, the page offers to download it from the App Store.
- Each invitation code shows a "Pending" badge.

### Fixes
- The Copy link, Email and Revoke actions now trigger independently. A single tap no longer fires all three at once.

## 1.0 (2026.07.11)

### New
- Cellar sharing: household members are invited with a code to share a single common cellar. Everyone keeps their own library, tasting notes and journal, and only the bottles in the cellar are pooled.
- In a shared cellar, every household bottle appears in the same grid, with the owner's name on other people's bottles. Any member can place, move, consume or gift any bottle. The removal is recorded in the wine owner's journal, and each tasting note stays with its author.
- On another member's wine detail, the owner's name is shown and the reserved actions like edit, delete and recommend are hidden.
- A magnifier in the toolbar opens a full-screen search. A wine name, producer, vintage or person can be typed, and results are ranked by relevance and clearly grouped, for example in cellar, already drunk, gifts or recommended. Combinable filters (color, type, favorite, in cellar, gifts) are offered above the results.
- Lists flag at a glance the bottles that are in the cellar with a cabinet icon.
- The Gifted and Recommended views offer a new "By person" sort that groups the list by giver or recommender.
- When scanning, the add popup now offers only "Store in cellar" and "Just record". Favorite and recommendation are set directly in the wine detail.
- Every beverage now has structured subtypes (rum, port, blonde beer, sparkling sake, and more), offered in the forms and filled in by the AI analysis.
- A wine's color is once again its robe (red, white or rosé). Sparkling and Sweet become wine subtypes.
- On the dashboard, the "In cellar" widget shows cellar occupancy, with placed bottles over total capacity (for example 41/48) and the total in smaller type.
- The Settings screen is reachable from the dashboard with a top-left icon.
- A user profile allows signing out.
- The app version and changelog history are available.
- Cellar information is shown (dimensions and number of placed bottles).
- Data can be exported and imported in JSON format.

### Fixes
- The "My Wines" list shows again instead of an error message.

### Performance
- Lists, search and the dashboard are faster. The server batches and shares its reads, never loading the same wines several times nor scanning the whole cellar for a simple filter.
- The detail view opens much faster. The server now reads only the consulted wine's information instead of scanning the whole cellar.
