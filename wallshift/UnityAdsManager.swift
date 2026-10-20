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
    }
    
    /// Initializes Unity Ads SDK
    func initialize(gameId: String? = nil, testMode: Bool? = nil) {
        if let gId = gameId, !gId.isEmpty {
            self.gameId = gId
        }
        if let tMode = testMode {
            self.testMode = tMode
        }
        
        print("[UnityAdsManager] Initializing Unity Ads with gameId: \(self.gameId), testMode: \(self.testMode)")
        UnityAds.initialize(self.gameId, testMode: self.testMode, initializationDelegate: self)
    }
    
    /// Preloads rewarded video ad for revival
    func loadRewardedAd() {
        guard isInitialized else {
            print("[UnityAdsManager] Postponing ad load: SDK not yet initialized")
            return
        }
        print("[UnityAdsManager] Loading rewarded ad for placement: \(rewardedPlacementId)")
        UnityAds.load(rewardedPlacementId, loadDelegate: self)
    }
    
    /// Preloads interstitial ad
    func loadInterstitialAd() {
        guard isInitialized else { return }
        print("[UnityAdsManager] Loading interstitial ad for placement: \(interstitialPlacementId)")
        UnityAds.load(interstitialPlacementId, loadDelegate: self)
    }
    
    /// Shows rewarded ad. If completed, onRewarded closure is called.
    func showRewardedAd(
        from viewController: UIViewController,
        onRewarded: @escaping () -> Void,
        onFailed: @escaping (String) -> Void
    ) {
        guard !isAdShowing else {
            onFailed("Ad is already showing")
            return
        }
        
        self.onAdSuccess = onRewarded
        self.onAdFailure = onFailed
        
        #if targetEnvironment(simulator)
        if !isRewardedAdLoaded {
            print("[UnityAdsManager] Running in Simulator: presenting simulated rewarded ad dialog")
            showSimulatorAdAlert(from: viewController)
            return
        }
        #endif
        
        if isRewardedAdLoaded {
            isAdShowing = true
            UnityAds.show(viewController, placementId: rewardedPlacementId, showDelegate: self)
        } else {
            #if targetEnvironment(simulator)
            showSimulatorAdAlert(from: viewController)
            #else
            isAdShowing = true
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
            UnityAds.show(viewController, placementId: interstitialPlacementId, showDelegate: self)
        } else {
            loadInterstitialAd()
            onFailed?("Interstitial ad is not ready yet")
        }
    }
    
    #if targetEnvironment(simulator)
    private func showSimulatorAdAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Unity Ads (Simulator)",
            message: "Simulating Rewarded Video Ad playback.\nPress 'Watch & Revive' to continue playing with 1 heart.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Watch & Revive", style: .default, handler: { [weak self] _ in
            self?.isAdShowing = false
            self?.onAdSuccess?()
            self?.onAdSuccess = nil
            self?.onAdFailure = nil
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            self?.isAdShowing = false
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
            if state == .showCompletionStateCompleted {
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
        isRewardedAdLoaded = false
        loadRewardedAd()
        
        DispatchQueue.main.async { [weak self] in
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
    }
    
    func unityAdsShowClick(_ placementId: String) {
        print("[UnityAdsManager] Ad clicked for \(placementId)")
    }
}
