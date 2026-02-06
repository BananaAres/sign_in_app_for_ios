import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    init(inMemory: Bool = false, useCloudKit: Bool = false) {
        let model = PlanDataModel.makeModel()
        container = NSPersistentCloudKitContainer(name: "PlanData", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let storeURL = PlanDataModel.storeURL() {
            container.persistentStoreDescriptions.first?.url = storeURL
        }
        
        let storeDescription = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        if useCloudKit, let containerId = Self.cloudKitContainerId {
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerId)
        }
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

private extension PersistenceController {
    static var cloudKitContainerId: String? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        return "iCloud.\(bundleId)"
    }
}
