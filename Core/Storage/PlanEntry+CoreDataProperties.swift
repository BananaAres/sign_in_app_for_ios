import Foundation
import CoreData

extension PlanEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanEntry> {
        NSFetchRequest<PlanEntry>(entityName: "PlanEntry")
    }
    
    @NSManaged public var id: String
    @NSManaged public var repeatGroupId: String?
    @NSManaged public var title: String
    @NSManaged public var note: String?
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date
    @NSManaged public var color: String
    @NSManaged public var repeatMode: String
    @NSManaged public var notificationOption: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}
