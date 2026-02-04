import Foundation
import CoreData
import Combine

@MainActor
final class PlanStore: ObservableObject {
    private let context: NSManagedObjectContext
    
    @Published var plans: [Plan] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.context = context
    }
    
    func loadPlans(from: Date?, to: Date?) async {
        do {
            plans = try await fetchPlans(from: from, to: to)
        } catch {
            plans = []
        }
    }
    
    func fetchPlans(from: Date?, to: Date?) async throws -> [Plan] {
        let request = PlanEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        if let from = from, let to = to {
            request.predicate = NSPredicate(format: "startTime >= %@ AND startTime <= %@", from as NSDate, to as NSDate)
        }
        
        return try await context.perform {
            let entries = try self.context.fetch(request)
            return entries.compactMap { $0.toPlan() }
        }
    }
    
    func createPlan(_ plan: Plan) async throws {
        try await context.perform {
            let entry = PlanEntry(context: self.context)
            entry.apply(plan: plan)
            try self.context.save()
        }
    }
    
    func updatePlan(_ plan: Plan) async throws {
        try await context.perform {
            let request = PlanEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", plan.id)
            let entry = try self.context.fetch(request).first ?? PlanEntry(context: self.context)
            entry.apply(plan: plan)
            try self.context.save()
        }
    }
    
    func deletePlan(id: String) async throws {
        try await context.perform {
            let request = PlanEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            let entries = try self.context.fetch(request)
            entries.forEach { self.context.delete($0) }
            try self.context.save()
        }
    }

    func deletePlansInRepeatGroup(groupId: String, from date: Date, excluding keepId: String? = nil) async throws {
        try await context.perform {
            let request = PlanEntry.fetchRequest()
            request.predicate = NSPredicate(format: "repeatGroupId == %@ AND startTime >= %@", groupId, date as NSDate)
            let entries = try self.context.fetch(request)
            let filtered = entries.filter { entry in
                guard let keepId = keepId else { return true }
                return entry.id != keepId
            }
            filtered.forEach { self.context.delete($0) }
            try self.context.save()
        }
    }
}

private extension PlanEntry {
    func apply(plan: Plan) {
        id = plan.id
        repeatGroupId = plan.repeatGroupId
        title = plan.title
        note = plan.note
        startTime = plan.startTime
        endTime = plan.endTime
        color = plan.color.rawValue
        repeatMode = plan.repeatMode.rawValue
        isCompleted = plan.isCompleted
        createdAt = plan.createdAt
        updatedAt = plan.updatedAt
    }
    
    func toPlan() -> Plan? {
        guard let planColor = PlanColor(rawValue: color),
              let repeatMode = RepeatMode(rawValue: repeatMode) else {
            return nil
        }
        return Plan(
            id: id,
            repeatGroupId: repeatGroupId,
            title: title,
            note: note,
            startTime: startTime,
            endTime: endTime,
            color: planColor,
            repeatMode: repeatMode,
            isCompleted: isCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
