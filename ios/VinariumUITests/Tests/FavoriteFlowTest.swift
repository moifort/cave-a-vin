import XCTest

final class FavoriteFlowTest: BaseUITest {

    private let wineName = "Vin Test Favori"

    // MARK: - Favorite E2E Flow

    func testFavoriteFlow() async throws {
        // 1. SCAN: open scanner, pick photo, verify review
        let tabBar = TabBarPage(app: app)
        let scanner = try tabBar.openScanner()
        try scanner.verify()

        // 2. REVIEW: land directly on the editable form, set name, toggle the inline
        // favorite then save — the popup no longer offers a "Favori" destination
        let review = try scanner.selectPhotoFromPicker()
        try review.verify()

        _ = try review.clearAndTypeName(wineName)
        _ = try review.markAsFavorite()
        try review.justSave()

        // 3. WINE LIST (FAVORIS): verify navigation to Vins tab with favorites segment selected
        let wineList = try WineListPage(app: app).verify()
        try wineList.verifyWineVisible(wineName)

        // 4. DASHBOARD: go to Home, verify the "My favorites" section contains the wine
        let dashboard = try tabBar.goToDashboard().verify()
        try dashboard.verifyFavoritesContains(wineName)

        // 5. DETAIL: tap wine in favorites dashboard → verify detail sheet
        let detail = try dashboard.tapWine(named: wineName)
        try detail.verify()
        try detail.verifyWineName(wineName)
        try detail.close()
    }
}
