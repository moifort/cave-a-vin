import XCTest

final class GiveAsGiftFlowTest: BaseUITest {

    private let wineName = "Vin Test Cadeau"

    func testGiveAsGiftFlow() async throws {
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
        let giftPage = try cellarDetail.tapRemoveAndChooseGift()
        try giftPage.verify()

        // 4. Fill recipient name and confirm
        _ = giftPage.typeRecipientName("Marie Dupont")
        try giftPage.tapConfirm()

        // Should return to cellar
        try app.navigationBars["My Cellar"].waitOrFail()

        // 5. WINE LIST: the bottle left the cellar, so look for it in the full
        // list. Not under "Offerts": that filter holds bottles received as a gift
        // (gift.received), not the ones given away.
        _ = try tabBar.goToWineList().verify()
        let wineList = WineListPage(app: app)
        try wineList.verifyWineVisible(wineName)

        // 6. Tap wine, verify gift section in detail
        let listDetail = try wineList.tapWine(named: wineName)
        try listDetail.verify()
        try listDetail.verifyWineName(wineName)
        try listDetail.verifyGiftSection()
        
    }
}
