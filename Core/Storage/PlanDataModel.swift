import CoreData

enum PlanDataModel {
    static let appGroupId = "group.ocm.SignInAPP-for-ios"

    static func storeURL() -> URL? {
        let fm = FileManager.default
        guard let containerURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        return containerURL.appendingPathComponent("PlanData.sqlite")
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
            attribute("notificationOption", .stringAttributeType, optional: true, defaultValue: "end_time"),
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

    private static func attribute(
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
