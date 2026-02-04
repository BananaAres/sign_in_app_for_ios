import Foundation
import CoreData

extension PlanGoal {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanGoal> {
        NSFetchRequest<PlanGoal>(entityName: "PlanGoal")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var key: String
    @NSManaged public var text: String
    @NSManaged public var isCompleted: Bool
    @NSManaged public var order: Int16
    @NSManaged public var updatedAt: Date
}
