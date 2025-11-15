import Foundation
import UIKit
import OSLog

final class CoffeeAnalysisRepository {
    struct LoadResult {
        let analyses: [SavedCoffeeAnalysis]
        let referencedImageFilenames: Set<String>
    }

    struct SaveResult {
        let referencedImageFilenames: Set<String>
    }

    private let controller: PersistenceController
    private var store: JSONCollectionStore<PersistedCoffeeAnalysis>
    private let imagesDirectory: URL
    private let legacyImagesDirectory: URL
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.nateking.GrindLab", category: "CoffeeAnalysisRepository")
    private let legacyKey = "SavedCoffeeAnalyses"

    init(controller: PersistenceController = .shared) {
        self.controller = controller
        fileManager = controller.fileManager
        imagesDirectory = controller.directory(named: "AnalysisImages")
        legacyImagesDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("AnalysisImages") ?? imagesDirectory

        do {
            store = try JSONCollectionStore(name: "CoffeeAnalyses", baseDirectory: controller.baseDirectory, fileManager: fileManager)
        } catch {
            fatalError("Failed to create CoffeeAnalysis store: \(error)")
        }

        migrateLegacyStoreIfNeeded()
    }

    func loadAnalyses() -> LoadResult {
        do {
            let persisted = try store.loadAll()
            let analyses = persisted.map { persistedAnalysis in
                persistedAnalysis.makeSavedAnalysis(imageLoader: { [weak self] name in
                    guard let self else { return nil }
                    return self.loadImage(named: name)
                })
            }
            let referenced = Set(persisted.flatMap { $0.imageFilenames })
            return LoadResult(analyses: analyses, referencedImageFilenames: referenced)
        } catch {
            logger.error("Failed to load analyses: \(error.localizedDescription, privacy: .public)")
            return LoadResult(analyses: [], referencedImageFilenames: [])
        }
    }

    func persistAnalyses(_ analyses: [SavedCoffeeAnalysis]) throws -> SaveResult {
        let persisted = analyses.map { PersistedCoffeeAnalysis(savedAnalysis: $0) }
        try store.saveAll(persisted)
        let referenced = Set(persisted.flatMap { $0.imageFilenames })
        return SaveResult(referencedImageFilenames: referenced)
    }

    func storeImage(_ image: UIImage, identifier: String, suffix: String) -> String? {
        let filename = "\(identifier)_\(suffix).jpg"
        let destination = imagesDirectory.appendingPathComponent(filename)

        guard let data = compressedData(for: image) else {
            return nil
        }

        do {
            try data.write(to: destination, options: .atomic)
            return filename
        } catch {
            logger.error("Failed to persist analysis image: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func loadImage(named name: String) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(name)
        return UIImage(contentsOfFile: url.path)
    }

    func deleteImages(named filenames: Set<String>) {
        guard !filenames.isEmpty else { return }
        for filename in filenames {
            let url = imagesDirectory.appendingPathComponent(filename)
            do {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            } catch {
                logger.error("Failed to remove image \(filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func cleanupOrphanedImages(validFilenames: Set<String>) {
        guard let contents = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for url in contents {
            let name = url.lastPathComponent
            if !validFilenames.contains(name) {
                do {
                    try fileManager.removeItem(at: url)
                    logger.info("Removed orphaned analysis image: \(name, privacy: .public)")
                } catch {
                    logger.error("Failed to remove orphaned image \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func migrateLegacyStoreIfNeeded() {
        guard !store.hasExistingData else { return }
        guard let data = UserDefaults.standard.data(forKey: legacyKey) else { return }

        do {
            let decoder = JSONDecoder()
            let legacy = try decoder.decode([LegacyPersistedCoffeeAnalysis].self, from: data)
            let persisted = legacy.map { item in
                item.toPersisted(withImageMapper: { [weak self] name in
                    guard let self else { return nil }
                    return self.migrateLegacyImage(named: name)
                })
            }
            try store.saveAll(persisted)
            UserDefaults.standard.removeObject(forKey: legacyKey)
            controller.updateMetadata { metadata in
                metadata.legacyAnalysesMigrated = true
                metadata.lastMigrationDate = Date()
            }
        } catch {
            logger.error("Failed to migrate legacy analyses: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func migrateLegacyImage(named filename: String) -> String? {
        let source = legacyImagesDirectory.appendingPathComponent(filename)
        let destination = imagesDirectory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: source.path) else {
            return nil
        }

        if fileManager.fileExists(atPath: destination.path) {
            return filename
        }

        do {
            try fileManager.copyItem(at: source, to: destination)
            return filename
        } catch {
            logger.error("Failed to migrate analysis image \(filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func compressedData(for image: UIImage) -> Data? {
        let maxDimension: CGFloat = 800
        let maxSide = max(image.size.width, image.size.height)
        let scale = maxSide > maxDimension && maxSide > 0 ? maxDimension / maxSide : 1
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resized.jpegData(compressionQuality: 0.7) ?? image.jpegData(compressionQuality: 0.7)
    }
}
