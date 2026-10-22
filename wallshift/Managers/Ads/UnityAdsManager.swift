//
//  UnityAdsManager.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 20.10.2026.
//

import Foundation
import UIKit
import UnityAds

final class UnityAdsManager: NSObject {
    static let shared = UnityAdsManager()
    
    // Unity Ads configuration (WallShift iOS)
    var gameId: String = "800405075"
    var rewardedPlacementId: String = "BP_Rewarded_iOS"
    var interstitialPlacementId: String = "BP_Interstitial_iOS"
    var bannerPlacementId: String = "BP_Banner_iOS"
    
    #if DEBUG
    var testMode: Bool = true
    #else
    var testMode: Bool = false
    #endif
    
    private(set) var isInitialized: Bool = false
    private(set) var isRewardedAdLoaded: Bool = false
    private(set) var isInterstitialAdLoaded: Bool = false
    private var isAdShowing: Bool = false
    
    private var onAdSuccess: (() -> Void)?
    private var onAdFailure: ((String) -> Void)?
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            forName: .networkStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self else { return }
            let connected = (notif.userInfo?["isConnected"] as? Bool) ?? false
            if connected {
                if !self.isInitialized {
                    print("[UnityAdsManager] Network restored: initializing Unity Ads SDK")
                    self.initialize()
                } else if !self.isRewardedAdLoaded {
                    print("[UnityAdsManager] Network restored: loading rewarded ad")
                    self.loadRewardedAd()
                }
            }
        }
    }
    
    /// Initializes Unity Ads SDK
    func initialize(gameId: String? = nil, testMode: Bool? = nil) {
        if let gId = gameId, !gId.isEmpty {
            self.gameId = gId
        }
        if let tMode = testMode {
            self.testMode = tMode
        }
        
        guard NetworkMonitor.shared.isConnected else {
            print("[UnityAdsManager] Postponing initialization: no internet connection")
            return
        }
        
        print("[UnityAdsManager] Initializing Unity Ads with gameId: \(self.gameId), testMode: \(self.testMode)")
        UnityAds.initialize(self.gameId, testMode: self.testMode, initializationDelegate: self)
    }
    
    /// Preloads rewarded video ad for revival
    func loadRewardedAd() {
        guard NetworkMonitor.shared.isConnected else {
            print("[UnityAdsManager] Postponing ad load: no internet connection")
            return
        }
        guard isInitialized else {
            print("[UnityAdsManager] Postponing ad load: SDK not yet initialized")
            return
        }
        print("[UnityAdsManager] Loading rewarded ad for placement: \(rewardedPlacementId)")
        UnityAds.load(rewardedPlacementId, loadDelegate: self)
    }
    
    /// Preloads interstitial ad
    func loadInterstitialAd() {
        guard NetworkMonitor.shared.isConnected, isInitialized else { return }
        print("[UnityAdsManager] Loading interstitial ad for placement: \(interstitialPlacementId)")
        UnityAds.load(interstitialPlacementId, loadDelegate: self)
    }
    
    /// Shows rewarded ad. If completed, onRewarded closure is called.
    func showRewardedAd(
        from viewController: UIViewController,
        customMessage: String? = nil,
        actionTitle: String = "Watch Ad",
        onRewarded: @escaping () -> Void,
        onFailed: @escaping (String) -> Void
    ) {
        guard NetworkMonitor.shared.isConnected else {
            onFailed("No internet connection")
            return
        }
        guard !isAdShowing else {
            onFailed("Ad is already showing")
            return
        }
        
        self.onAdSuccess = onRewarded
        self.onAdFailure = onFailed
        
        #if targetEnvironment(simulator)
        if !isRewardedAdLoaded {
            print("[UnityAdsManager] Running in Simulator: presenting simulated rewarded ad dialog")
            isAdShowing = true
            GameAudio.shared.notifyAdWillPresent()
            showSimulatorAdAlert(from: viewController, message: customMessage, actionTitle: actionTitle)
            return
        }
        #endif
        
        if isRewardedAdLoaded {
            isAdShowing = true
            GameAudio.shared.notifyAdWillPresent()
            UnityAds.show(viewController, placementId: rewardedPlacementId, showDelegate: self)
        } else {
            #if targetEnvironment(simulator)
            isAdShowing = true
            GameAudio.shared.notifyAdWillPresent()
            showSimulatorAdAlert(from: viewController, message: customMessage, actionTitle: actionTitle)
            #else
            isAdShowing = true
            GameAudio.shared.notifyAdWillPresent()
            UnityAds.show(viewController, placementId: rewardedPlacementId, showDelegate: self)
            #endif
        }
    }
    
    /// Shows interstitial ad
    func showInterstitialAd(
        from viewController: UIViewController,
        onCompleted: (() -> Void)? = nil,
        onFailed: ((String) -> Void)? = nil
    ) {
        guard !isAdShowing else {
            onFailed?("Ad is already showing")
            return
        }
        
        self.onAdSuccess = onCompleted
        self.onAdFailure = onFailed
        
        if isInterstitialAdLoaded {
            isAdShowing = true
            GameAudio.shared.notifyAdWillPresent()
            UnityAds.show(viewController, placementId: interstitialPlacementId, showDelegate: self)
        } else {
            #if targetEnvironment(simulator)
            print("[UnityAdsManager] Running in Simulator: presenting simulated interstitial ad dialog")
            isAdShowing = true
            GameAudio.shared.notifyAdWillPresent()
            showSimulatorInterstitialAlert(from: viewController)
            #else
            loadInterstitialAd()
            onFailed?("Interstitial ad is not ready yet")
            #endif
        }
    }
    
    #if targetEnvironment(simulator)
    private func showSimulatorInterstitialAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Unity Ads (Simulator)",
            message: "Simulating Interstitial Ad playback.\nPress 'Close Ad' to return to game.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Close Ad", style: .default, handler: { [weak self] _ in
            self?.isAdShowing = false
            GameAudio.shared.notifyAdDidDismiss()
            self?.onAdSuccess?()
            self?.onAdSuccess = nil
            self?.onAdFailure = nil
        }))
        viewController.present(alert, animated: true)
    }
    #endif
    
    #if targetEnvironment(simulator)
    private func showSimulatorAdAlert(
        from viewController: UIViewController,
        message: String? = nil,
        actionTitle: String = "Watch Ad"
    ) {
        let alert = UIAlertController(
            title: "Unity Ads (Simulator)",
            message: message ?? "Simulating Rewarded Video Ad playback.\nPress '\(actionTitle)' to continue and claim your reward.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
            self?.isAdShowing = false
            GameAudio.shared.notifyAdDidDismiss()
            self?.onAdSuccess?()
            self?.onAdSuccess = nil
            self?.onAdFailure = nil
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            self?.isAdShowing = false
            GameAudio.shared.notifyAdDidDismiss()
            self?.onAdFailure?("Ad was cancelled")
            self?.onAdSuccess = nil
            self?.onAdFailure = nil
        }))
        viewController.present(alert, animated: true)
    }
    #endif
}

// MARK: - UnityAdsInitializationDelegate
extension UnityAdsManager: UnityAdsInitializationDelegate {
    func initializationComplete() {
        print("[UnityAdsManager] Unity Ads initialized successfully!")
        isInitialized = true
        loadRewardedAd()
        loadInterstitialAd()
    }
    
    func initializationFailed(_ error: UnityAdsInitializationError, withMessage message: String) {
        print("[UnityAdsManager] Unity Ads initialization failed: \(error) - \(message)")
        isInitialized = false
    }
}

// MARK: - UnityAdsLoadDelegate
extension UnityAdsManager: UnityAdsLoadDelegate {
    func unityAdsAdLoaded(_ placementId: String) {
        print("[UnityAdsManager] Ad loaded for placement: \(placementId)")
        if placementId == rewardedPlacementId {
            isRewardedAdLoaded = true
        } else if placementId == interstitialPlacementId {
            isInterstitialAdLoaded = true
        }
    }
    
    func unityAdsAdFailed(toLoad placementId: String, withError error: UnityAdsLoadError, withMessage message: String) {
        print("[UnityAdsManager] Failed to load ad for \(placementId): \(error) - \(message)")
        if placementId == rewardedPlacementId {
            isRewardedAdLoaded = false
        } else if placementId == interstitialPlacementId {
            isInterstitialAdLoaded = false
        }
    }
}

// MARK: - UnityAdsShowDelegate
extension UnityAdsManager: UnityAdsShowDelegate {
    func unityAdsShowComplete(_ placementId: String, withFinish state: UnityAdsShowCompletionState) {
        print("[UnityAdsManager] Ad show complete for \(placementId) with state: \(state.rawValue)")
        isAdShowing = false
        if placementId == rewardedPlacementId {
            isRewardedAdLoaded = false
            loadRewardedAd() // Preload next
        } else if placementId == interstitialPlacementId {
            isInterstitialAdLoaded = false
            loadInterstitialAd()
        }
        
        DispatchQueue.main.async { [weak self] in
            GameAudio.shared.notifyAdDidDismiss()
            if state == .showCompletionStateCompleted || placementId == self?.interstitialPlacementId {
                self?.onAdSuccess?()
            } else {
                self?.onAdFailure?("Ad was skipped before completion")
            }
            self?.onAdSuccess = nil
            self?.onAdFailure = nil
        }
    }
    
    func unityAdsShowFailed(_ placementId: String, withError error: UnityAdsShowError, withMessage message: String) {
        print("[UnityAdsManager] Ad show failed for \(placementId): \(error) - \(message)")
        isAdShowing = false
        if placementId == interstitialPlacementId {
            isInterstitialAdLoaded = false
            loadInterstitialAd()
        } else if placementId == rewardedPlacementId {
            isRewardedAdLoaded = false
            loadRewardedAd()
        }
        
        DispatchQueue.main.async { [weak self] in
            GameAudio.shared.notifyAdDidDismiss()
            #if targetEnvironment(simulator)
            self?.onAdSuccess?()
            #else
            self?.onAdFailure?(message)
            #endif
            self?.onAdSuccess = nil
            self?.onAdFailure = nil
        }
    }
    
    func unityAdsShowStart(_ placementId: String) {
        print("[UnityAdsManager] Ad show started for \(placementId)")
        GameAudio.shared.notifyAdWillPresent()
    }
    
    func unityAdsShowClick(_ placementId: String) {
        print("[UnityAdsManager] Ad clicked for \(placementId)")
    }
}
