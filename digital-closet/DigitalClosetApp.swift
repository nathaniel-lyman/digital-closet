import SwiftUI
import CoreData

@main
struct DigitalClosetApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Register the custom transformer for UUID arrays
        UUIDArrayTransformer.register()
        
        // Test Core Data is working
        #if DEBUG
        testCoreDataStack()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
    
    #if DEBUG
    private func testCoreDataStack() {
        let context = persistenceController.container.viewContext
        let fetchRequest = NSFetchRequest<ClothingItem>(entityName: "ClothingItem")
        do {
            _ = try context.fetch(fetchRequest)
            print("✅ Core Data stack is working correctly")
        } catch {
            print("❌ Core Data error: \(error)")
        }
    }
    #endif
}

struct PersistenceController {
    static let shared = PersistenceController()
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        // Updated to use "DigitalCloset" model name
        container = NSPersistentContainer(name: "DigitalCloset")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unresolved error \(error.localizedDescription)")
            }
            print("Persistent store loaded successfully: \(description)")
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
} 