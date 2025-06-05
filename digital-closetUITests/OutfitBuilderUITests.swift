import XCTest

class OutfitBuilderUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }
    
    func testCreateNewOutfit() {
        // Navigate to outfit builder
        app.buttons["New Outfit"].tap()
        
        // Add items to outfit
        app.buttons["Add Item"].tap()
        
        // Verify items can be added
        XCTAssertTrue(app.buttons["Save Outfit"].exists)
    }
} 