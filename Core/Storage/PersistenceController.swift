import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    init(inMemory: Bool = false, useCloudKit: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentCloudKitContainer(name: "PlanData", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
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

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        let planEntry = NSEntityDescription()
        planEntry.name = "PlanEntry"
        planEntry.managedObjectClassName = String(describing: PlanEntry.self)
        planEntry.properties = [
            attribute("id", .stringAttributeType),
            attribute("repeatGroupId", .stringAttributeType, optional: true),
            attribute("title", .stringAttributeType),
            attribute("note", .stringAttributeType, optional: true),
            attribute("startTime", .dateAttributeType),
            attribute("endTime", .dateAttributeType),
            attribute("color", .stringAttributeType),
            attribute("repeatMode", .stringAttributeType),
            attribute("isCompleted", .booleanAttributeType, defaultValue: false),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]
        
        let planGoal = NSEntityDescription()
        planGoal.name = "PlanGoal"
        planGoal.managedObjectClassName = String(describing: PlanGoal.self)
        planGoal.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("key", .stringAttributeType),
            attribute("text", .stringAttributeType),
            attribute("isCompleted", .booleanAttributeType, defaultValue: false),
            attribute("order", .integer16AttributeType, defaultValue: 0),
            attribute("updatedAt", .dateAttributeType)
        ]
        
        model.entities = [planEntry, planGoal]
        return model
    }
    
    static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
