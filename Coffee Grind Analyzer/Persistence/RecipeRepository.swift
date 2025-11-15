import Foundation
import OSLog

final class RecipeRepository {
    private let logger = Logger(subsystem: "com.nateking.GrindLab", category: "RecipeRepository")
    private let legacyKey = "SavedRecipes"
    private var store: JSONCollectionStore<Recipe>

    init(controller: PersistenceController = .shared) {
        do {
            store = try JSONCollectionStore(name: "Recipes", baseDirectory: controller.baseDirectory, fileManager: controller.fileManager)
        } catch {
            fatalError("Failed to create Recipe store: \(error)")
        }

        migrateLegacyRecipesIfNeeded()
    }

    func loadRecipes() -> [Recipe] {
        do {
            let recipes = try store.loadAll()
            if recipes.isEmpty {
                return Recipe.allDefaults
            }
            return recipes
        } catch {
            logger.error("Failed to load recipes: \(error.localizedDescription, privacy: .public)")
            return Recipe.allDefaults
        }
    }

    func persist(recipes: [Recipe]) {
        do {
            try store.saveAll(recipes)
        } catch {
            logger.error("Failed to persist recipes: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func migrateLegacyRecipesIfNeeded() {
        guard !store.hasExistingData else { return }
        guard let data = UserDefaults.standard.data(forKey: legacyKey) else { return }

        do {
            let decoded = try JSONDecoder().decode([Recipe].self, from: data)
            try store.saveAll(decoded)
            UserDefaults.standard.removeObject(forKey: legacyKey)
        } catch {
            logger.error("Failed to migrate legacy recipes: \(error.localizedDescription, privacy: .public)")
        }
    }
}
