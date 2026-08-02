import XCTest

final class CellarFlowTest: BaseUITest {

    private let wineName = "Vin Test Nominal"

    // MARK: - Cellar E2E Flow

    func testCellarFlow() async throws {
        // 1. SCAN: open scanner, pick photo, save
        let tabBar = TabBarPage(app: app)
        let scanner = try tabBar.openScanner()
        try scanner.verify()

        let review = try scanner.selectPhotoFromPicker()
        try review.verify()

        _ = try review.clearAndTypeName(wineName)
        let placement = try review.addToCellar()

        // 2. PLACEMENT: verify, select position, done
        try placement.verify()
        let confirmation = try placement.selectPosition("A1")
        try confirmation.verify()
        try confirmation.tapDone()

        // 3. CAVE: verify wine visible, tap → detail, check "Cave", close
        let cellar = try CellarPage(app: app).verify()
        let cellarDetail = try cellar.tapWine(named: wineName)
        try cellarDetail.verify()
        try cellarDetail.verifyWineName(wineName)
        try cellarDetail.verifyCellarSection()
        try cellarDetail.close()

        // Cave Journal: switch to Journal, verify the entry row
        let journal = try cellar.switchToJournal()
        try journal.verifyJournalShowsEntry()

        // Tap journal entry → detail → close
        let journalDetail = try journal.tapWine(named: wineName)
        try journalDetail.verify()
        try journalDetail.verifyWineName(wineName)
        try journalDetail.close()

        // 4. WINE LIST: go to Vins tab, verify wine visible, tap → detail → close
        let wineList = try tabBar.goToWineList().verify()
        try wineList.verifyWineVisible(wineName)
        let listDetail = try wineList.tapWine(named: wineName)
        try listDetail.verify()
        try listDetail.verifyWineName(wineName)
        try listDetail.close()

        // 5. DASHBOARD: go to Home, verify stats and journal
        let dashboard = try tabBar.goToDashboard().verify()
        try dashboard.verifyBottleCount("1")
        try dashboard.verifyJournalContains(wineName)
        try dashboard.verifyJournalShowsEntry()

        // 6. CONSUMPTION: back to Cave, tap wine, remove, rate 5 stars + comment
        // The segment is still on Journal from step 3, and the title follows the
        // segment — switch back before expecting "My Cellar".
        _ = try tabBar.goToCellar()
        try cellar.switchToCave().verify()
        let detailForRemoval = try cellar.tapWine(named: wineName)
        try detailForRemoval.verify()
        let consumption = try detailForRemoval.tapRemoveFromCellar()
        try consumption.verify()
        try consumption
            .tapStar(5)
            .typeTastingNotes("Excellent")
            .tapConfirm()

        // Should return to cellar
        try app.navigationBars["My Cellar"].waitOrFail()

        // 7. FAVORITES: flag the bottle from its detail menu, then check it shows
        // under "❤️ Favoris". The flag is its own field — a 5-star rating alone
        // does not make a favorite.
        _ = try tabBar.goToWineList().verify()
        let detailForFavorite = try wineList.tapWine(named: wineName)
        try detailForFavorite.verify()
        try detailForFavorite.addToFavorites()
        try detailForFavorite.close()

        let favorites = try WineListPage(app: app).switchToFavorites()
        try favorites.verifyWineVisible(wineName)


        // 8. Open wine detail, delete and confirm
        let detail = try wineList.tapWine(named: wineName)
        try detail.verify()
        try detail.tapDelete()

        // 9. Verify wine no longer appears in the list. Back to "Tous" first: the
        // filter is still on Favoris, the title follows it, and a wine gone from
        // the whole list is the stronger check anyway.
        try wineList.switchToAll().verify()
        wineList.verifyWineNotVisible(wineName)
    }
}
