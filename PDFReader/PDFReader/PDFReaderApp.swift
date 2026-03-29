import SwiftUI
import GoogleMobileAds
import CoreData

@main
struct PDFReaderApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        MobileAds.shared.start(completionHandler: nil)
        AdManager.shared.loadInterstitial()
        AdManager.shared.loadRewarded()
        AdManager.shared.loadAppOpenAd()
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
