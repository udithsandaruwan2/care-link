import Foundation
import CoreData

final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = Self.createManagedObjectModel()
        container = NSPersistentContainer(name: "CareLink", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Cached Caregiver Operations

    func cacheCaregivers(_ caregivers: [Caregiver]) {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CachedCaregiver")
        if let existing = try? context.fetch(fetchRequest) {
            existing.forEach { context.delete($0) }
        }

        for caregiver in caregivers {
            let entity = NSEntityDescription.insertNewObject(forEntityName: "CachedCaregiver", into: context)
            entity.setValue(caregiver.id, forKey: "id")
            entity.setValue(caregiver.name, forKey: "name")
            entity.setValue(caregiver.specialty, forKey: "specialty")
            entity.setValue(caregiver.hourlyRate, forKey: "hourlyRate")
            entity.setValue(caregiver.rating, forKey: "rating")
            entity.setValue(caregiver.reviewCount, forKey: "reviewCount")
            entity.setValue(caregiver.isVerified, forKey: "isVerified")
            entity.setValue(caregiver.category.rawValue, forKey: "category")
            entity.setValue(caregiver.imageURL, forKey: "imageURL")
        }
        save()
    }

    func loadCachedCaregivers() -> [Caregiver] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CachedCaregiver")
        guard let results = try? container.viewContext.fetch(fetchRequest) else { return [] }

        return results.compactMap { obj in
            guard let id = obj.value(forKey: "id") as? String,
                  let name = obj.value(forKey: "name") as? String else { return nil }
            return Caregiver(
                id: id,
                userId: "",
                name: name,
                specialty: obj.value(forKey: "specialty") as? String ?? "",
                title: "",
                hourlyRate: obj.value(forKey: "hourlyRate") as? Double ?? 0,
                rating: obj.value(forKey: "rating") as? Double ?? 0,
                reviewCount: obj.value(forKey: "reviewCount") as? Int ?? 0,
                experienceYears: 0,
                distance: 0,
                bio: "",
                skills: [],
                certifications: [],
                availability: [],
                imageURL: obj.value(forKey: "imageURL") as? String ?? "",
                latitude: 0,
                longitude: 0,
                isVerified: obj.value(forKey: "isVerified") as? Bool ?? false,
                category: Caregiver.CareCategory(rawValue: obj.value(forKey: "category") as? String ?? "") ?? .all,
                phoneNumber: "",
                email: ""
            )
        }
    }

    // MARK: - User Preferences

    func savePreference(key: String, value: String) {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserPreference")
        fetchRequest.predicate = NSPredicate(format: "key == %@", key)

        let entity: NSManagedObject
        if let existing = try? context.fetch(fetchRequest).first {
            entity = existing
        } else {
            entity = NSEntityDescription.insertNewObject(forEntityName: "UserPreference", into: context)
            entity.setValue(key, forKey: "key")
        }
        entity.setValue(value, forKey: "value")
        save()
    }

    func loadPreference(key: String) -> String? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserPreference")
        fetchRequest.predicate = NSPredicate(format: "key == %@", key)
        return (try? container.viewContext.fetch(fetchRequest).first)?.value(forKey: "value") as? String
    }

    // MARK: - Model Definition

    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // CachedCaregiver entity
        let caregiverEntity = NSEntityDescription()
        caregiverEntity.name = "CachedCaregiver"
        caregiverEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        caregiverEntity.properties = [
            attribute("id", .stringAttributeType),
            attribute("name", .stringAttributeType),
            attribute("specialty", .stringAttributeType),
            attribute("hourlyRate", .doubleAttributeType),
            attribute("rating", .doubleAttributeType),
            attribute("reviewCount", .integer32AttributeType),
            attribute("isVerified", .booleanAttributeType),
            attribute("category", .stringAttributeType),
            attribute("imageURL", .stringAttributeType),
        ]

        // UserPreference entity
        let preferenceEntity = NSEntityDescription()
        preferenceEntity.name = "UserPreference"
        preferenceEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        preferenceEntity.properties = [
            attribute("key", .stringAttributeType),
            attribute("value", .stringAttributeType),
        ]

        // CachedBooking entity
        let bookingEntity = NSEntityDescription()
        bookingEntity.name = "CachedBooking"
        bookingEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        bookingEntity.properties = [
            attribute("id", .stringAttributeType),
            attribute("caregiverName", .stringAttributeType),
            attribute("date", .dateAttributeType),
            attribute("status", .stringAttributeType),
            attribute("totalCost", .doubleAttributeType),
        ]

        model.entities = [caregiverEntity, preferenceEntity, bookingEntity]
        return model
    }

    private static func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = true
        return attr
    }
}
