import XCTest
import CoreData
@testable import digital_closet

class ClothingItemTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // Create an in-memory store for testing
        container = NSPersistentContainer(name: "ClothingItem")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { description, error in
            XCTAssertNil(error, "Failed to load test store")
        }
        
        context = container.viewContext
    }
    
    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }
    
    func testCreateClothingItem() {
        // Create a new clothing item
        let item = ClothingItem(context: context)
        item.title = "Test Item"
        item.category = "Tops"
        
        // Save the context
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
        
        // Fetch the item back
        let fetchRequest: NSFetchRequest<ClothingItem> = ClothingItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", "Test Item")
        
        do {
            let results = try context.fetch(fetchRequest)
            XCTAssertEqual(results.count, 1, "Should find exactly one item")
            XCTAssertEqual(results.first?.title, "Test Item")
            XCTAssertEqual(results.first?.category, "Tops")
        } catch {
            XCTFail("Failed to fetch item: \(error)")
        }
    }
} 