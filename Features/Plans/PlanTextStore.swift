import Foundation
import CoreData

enum PlanTextStore {
    private static var context: NSManagedObjectContext {
        PersistenceController.shared.viewContext
    }
    
    static func yearKey(for date: Date) -> String {
        let year = Calendar.current.component(.year, from: date)
        return "year_plan_\(year)"
    }

    static func monthKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return "month_plan_\(year)_\(month)"
    }

    static func load(key: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }

    static func save(_ text: String, key: String) {
        UserDefaults.standard.set(text, forKey: key)
    }

    static func loadList(key: String) -> [String] {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            return list
        }

        let legacyText = UserDefaults.standard.string(forKey: key) ?? ""
        let legacyItems = legacyText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return legacyItems
    }

    static func saveList(_ items: [String], key: String) {
        let sanitized = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if let data = try? JSONEncoder().encode(sanitized) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadGoals(key: String) -> [GoalItem] {
        let fetched = fetchGoals(key: key)
        if !fetched.isEmpty {
            return fetched.map { sanitizeGoal($0) }
        }
        
        let legacy = loadList(key: key)
        let migrated = legacy.map { text in
            let completed = text.contains("✓") || text.contains("✔")
            let cleaned = text.replacingOccurrences(of: "✓", with: "").replacingOccurrences(of: "✔", with: "")
            return sanitizeGoal(GoalItem(text: cleaned, isCompleted: completed))
        }
        
        if !migrated.isEmpty {
            saveGoals(migrated, key: key)
        }
        
        return migrated
    }

    static func saveGoals(_ items: [GoalItem], key: String) {
        let sanitized = items.map { sanitizeGoal($0) }
        context.performAndWait {
            let request = PlanGoal.fetchRequest()
            request.predicate = NSPredicate(format: "key == %@", key)
            
            let existing = (try? context.fetch(request)) ?? []
            existing.forEach { context.delete($0) }
            
            for (index, item) in sanitized.enumerated() {
                let goal = PlanGoal(context: context)
                goal.id = item.id
                goal.key = key
                goal.text = item.text
                goal.isCompleted = item.isCompleted
                goal.order = Int16(index)
                goal.updatedAt = Date()
            }
            
            try? context.save()
        }
    }

    private static func sanitizeGoal(_ item: GoalItem) -> GoalItem {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(trimmed.prefix(GoalItem.maxTextLength))
        return GoalItem(id: item.id, text: limited, isCompleted: item.isCompleted)
    }
    
    private static func fetchGoals(key: String) -> [GoalItem] {
        var results: [GoalItem] = []
        context.performAndWait {
            let request = PlanGoal.fetchRequest()
            request.predicate = NSPredicate(format: "key == %@", key)
            request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
            if let goals = try? context.fetch(request) {
                results = goals.map {
                    GoalItem(id: $0.id, text: $0.text, isCompleted: $0.isCompleted)
                }
            }
        }
        return results
    }
}
