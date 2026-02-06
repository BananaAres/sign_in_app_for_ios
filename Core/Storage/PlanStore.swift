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
        await scheduleNotificationIfNeeded(for: plan)
    }
    
    func updatePlan(_ plan: Plan) async throws {
        try await context.perform {
            let request = PlanEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", plan.id)
            let entry = try self.context.fetch(request).first ?? PlanEntry(context: self.context)
            entry.apply(plan: plan)
            try self.context.save()
        }
        await updateNotification(for: plan)
    }
    
    func deletePlan(id: String) async throws {
        try await context.perform {
            let request = PlanEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            let entries = try self.context.fetch(request)
            entries.forEach { self.context.delete($0) }
            try self.context.save()
        }
        NotificationManager.shared.cancelNotifications(for: id)
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
            let ids = filtered.map { $0.id }
            filtered.forEach { self.context.delete($0) }
            try self.context.save()
            ids.forEach { NotificationManager.shared.cancelNotifications(for: $0) }
        }
    }
}

private extension PlanStore {
    var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: "notifications_enabled") as? Bool ?? true
    }

    func scheduleNotificationIfNeeded(for plan: Plan) async {
        guard notificationsEnabled else { return }
        await NotificationManager.shared.scheduleNotifications(for: plan)
    }

    func updateNotification(for plan: Plan) async {
        NotificationManager.shared.cancelNotifications(for: plan.id)
        guard !plan.isCompleted else { return }
        await scheduleNotificationIfNeeded(for: plan)
    }
}

private func parseNotificationOptions(_ raw: String?) -> [PlanNotificationOption] {
    guard let raw else { return [.endTime] }
    if raw.isEmpty { return [] }
    let options = raw
        .split(separator: ",")
        .compactMap { PlanNotificationOption(rawValue: String($0)) }
    return options.isEmpty ? [.endTime] : Array(Set(options)).sorted { $0.sortOrder < $1.sortOrder }
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
        notificationOption = plan.notificationOptions.isEmpty
        ? ""
        : plan.notificationOptions.map { $0.rawValue }.joined(separator: ",")
        isCompleted = plan.isCompleted
        createdAt = plan.createdAt
        updatedAt = plan.updatedAt
    }
    
    func toPlan() -> Plan? {
        guard let planColor = PlanColor(rawValue: color),
              let repeatMode = RepeatMode(rawValue: repeatMode) else {
            return nil
        }
        let notificationOptions = parseNotificationOptions(notificationOption)
        return Plan(
            id: id,
            repeatGroupId: repeatGroupId,
            title: title,
            note: note,
            startTime: startTime,
            endTime: endTime,
            color: planColor,
            repeatMode: repeatMode,
            notificationOptions: notificationOptions,
            isCompleted: isCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
