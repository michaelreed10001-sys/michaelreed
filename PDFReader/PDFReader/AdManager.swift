import GoogleMobileAds
import UIKit
import Combine

final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    // MARK: - Real Ad Unit IDs
    let bannerAdUnitID = "ca-app-pub-3879441927599218/5484689832"
    let nativeAdUnitID = "ca-app-pub-3879441927599218/8815895332"
    let interstitialAdUnitID = "ca-app-pub-3879441927599218/2777100599"
    let rewardedAdUnitID = "ca-app-pub-3879441927599218/9268289077"
    let appOpenAdUnitID = "ca-app-pub-3879441927599218/1400439748"
    
    // MARK: - Frequency Capping
    private var lastInterstitialTime: Date?
    private var interstitialCountInSession = 0
    private let minIntervalBetweenInterstitials: TimeInterval = 120 // 2 minutes
    private let maxInterstitialsPerSession = 2
    
    @Published var isAppLaunchPeriod = true // first 2 minutes no ads
    
    private override init() {
        super.init()
        // End launch period after 2 minutes
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.isAppLaunchPeriod = false
        }
    }
    
    // MARK: - Interstitial
    private var interstitial: InterstitialAd?
    
    func loadInterstitial() {
        let request = Request()
        InterstitialAd.load(with: interstitialAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial: \(error)")
                return
            }
            self?.interstitial = ad
        }
    }
    
    func showInterstitial(from viewController: UIViewController, afterScan: Bool = false) -> Bool {
        // Frequency cap check
        guard !isAppLaunchPeriod else { return false }
        guard interstitialCountInSession < maxInterstitialsPerSession else { return false }
        if let last = lastInterstitialTime, Date().timeIntervalSince(last) < minIntervalBetweenInterstitials {
            return false
        }
        
        guard let interstitial = interstitial else {
            loadInterstitial()
            return false
        }
        
        interstitial.present(from: viewController)
        self.interstitial = nil
        lastInterstitialTime = Date()
        interstitialCountInSession += 1
        loadInterstitial() // preload next
        return true
    }
    
    func resetSessionCounters() {
        interstitialCountInSession = 0
    }
    
    // MARK: - Rewarded
    private var rewardedAd: RewardedAd?
    
    func loadRewarded() {
        let request = Request()
        RewardedAd.load(with: rewardedAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded: \(error)")
                return
            }
            self?.rewardedAd = ad
        }
    }
    
    func showRewarded(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd else {
            loadRewarded()
            completion(false)
            return
        }
        rewardedAd.present(from: viewController) {
            let reward = rewardedAd.adReward
            print("Reward received: \(reward.amount) \(reward.type)")
            completion(true)
        }
        self.rewardedAd = nil
        loadRewarded()
    }
    
    // MARK: - App Open Ad
    private var appOpenAd: AppOpenAd?
    
    func loadAppOpenAd() {
        let request = Request()
        AppOpenAd.load(with: appOpenAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load app open ad: \(error)")
                return
            }
            self?.appOpenAd = ad
        }
    }
    
    func showAppOpenAd(from viewController: UIViewController) -> Bool {
        guard let appOpenAd = appOpenAd else {
            loadAppOpenAd()
            return false
        }
        
        appOpenAd.present(from: viewController)
        self.appOpenAd = nil
        loadAppOpenAd() // preload next
        return true
    }
}
