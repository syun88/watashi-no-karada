import SwiftUI
import SwiftData

@main
struct WatashiNoKaradaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([BodyRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
