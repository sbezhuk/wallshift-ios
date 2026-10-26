//
//  DynamicAdManager.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import Foundation
import UIKit

/// Розумний менеджер динамічного показу міжсторінкової реклами (Interstitial Ads).
/// Адаптує частоту показу під поведінку гравця, емоції та тривалість забігів:
/// - Базова частота: кожні 4 спроби (з вагами за тривалість забігу).
/// - Session Warmup: перші 3 забіги поточної ігрової сесії (після запуску гри) ЗАВЖДИ без реклами.
/// - Cooldown: мінімум 75 секунд між показами реального часу (також рахується від запуску гри).
/// - FTUE: перші 3 спроби після першого встановлення без реклами.
/// - High Score Protection: новий рекорд звільняє від реклами для збереження емоції перемоги.
/// - Rewarded Protection: якщо гравець подивився рекламу заради воскресіння/подвоєння монет,
///   лічильник спроб скидається на 0 і запускається новий кулдаун.
/// - Rage-Quit Protection: дуже короткі спроби (< 10 сек) не зараховуються як повні спроби.
/// - Marathon Runs: забіги довше 55 секунд або рахунок 350+ зараховуються як 2 спроби.
final class DynamicAdManager {
    static let shared = DynamicAdManager()
    
    // MARK: - Constants
    enum Config {
        /// Цільова кількість спроб для показу реклами
        static let targetAttemptsThreshold: Int = 4
        
        /// Мінімальна кількість зіграних забігів у поточній сесії (після запуску програми)
        /// перед тим, як може бути показана будь-яка міжсторінкова реклама
        static let minSessionRunsBeforeAd: Int = 3
        
        /// Мінімальний інтервал між показами міжсторінкової реклами (секунди)
        static let minimumCooldownSeconds: TimeInterval = 75.0
        
        /// Тривалість забігу, менше якої смерть вважається передчасною помилкою
        static let quickDeathThreshold: TimeInterval = 10.0
        
        /// Кількість швидких смертей поспіль, що разом утворюють 1 спробу
        static let quickDeathsPerAttempt: Int = 3
        
        /// Тривалість забігу, більше якої забіг вважається великим марафоном (+2 спроби)
        static let marathonRunThreshold: TimeInterval = 55.0
        
        /// Рахунок забігу для визнання марафоном (+2 спроби)
        static let marathonScoreThreshold: Int = 350
        
        /// Кількість початкових спроб без реклами для новачків (FTUE)
        static let ftueImmunityAttempts: Int = 3
    }
    
    // MARK: - Storage Keys
    private let pendingAttemptsKey = "WallShiftDynamicAdPendingAttempts"
    private let totalLifetimeRunsKey = "WallShiftDynamicAdLifetimeRuns"
    private let lastAdShowTimestampKey = "WallShiftDynamicAdLastShowTime"
    private let quickDeathsKey = "WallShiftDynamicAdQuickDeaths"
    
    // MARK: - Persistent State
    private(set) var pendingAttempts: Int
    private(set) var totalLifetimeRuns: Int
    private(set) var lastAdShowTimestamp: TimeInterval
    private var quickDeathsCount: Int
    
    // MARK: - Session (In-Memory) State
    /// Кількість забігів, завершених у поточній сесії запуску гри
    private(set) var sessionRunsCount: Int = 0
    
    /// Прапорець, чи була показана або переглянута реклама за винагороду в поточному раунді
    private var didWatchRewardedInCurrentRun: Bool = false
    
    // MARK: - Initialization
    private init() {
        let savedPending = UserDefaults.standard.integer(forKey: pendingAttemptsKey)
        self.totalLifetimeRuns = UserDefaults.standard.integer(forKey: totalLifetimeRunsKey)
        let savedTimestamp = UserDefaults.standard.double(forKey: lastAdShowTimestampKey)
        self.quickDeathsCount = UserDefaults.standard.integer(forKey: quickDeathsKey)
        
        // Захист від застарілих накопичених спроб: якщо збережене значення перевищувало поріг
        // або накопичилося з минулої сесії, скидаємо його на безпечний старт
        if savedPending >= Config.targetAttemptsThreshold {
            self.pendingAttempts = 0
        } else {
            self.pendingAttempts = max(0, savedPending)
        }
        
        // При кожному запуску гри встановлюємо точку відліку кулдауну не раніше за поточний момент,
        // щоб гравець не міг отримати рекламу одразу після старту гри
        let now = Date().timeIntervalSince1970
        self.lastAdShowTimestamp = max(savedTimestamp, now)
        UserDefaults.standard.set(self.lastAdShowTimestamp, forKey: lastAdShowTimestampKey)
        UserDefaults.standard.set(self.pendingAttempts, forKey: pendingAttemptsKey)
        
        print("[DynamicAdManager] Initialized. Session runs: 0, Pending attempts: \(pendingAttempts)/\(Config.targetAttemptsThreshold), Lifetime runs: \(totalLifetimeRuns)")
    }
    
    // MARK: - Gameplay Lifecycle Hooks
    
    /// Викликається на початку кожного нового забігу
    func notifyRunStarted() {
        didWatchRewardedInCurrentRun = false
    }
    
    /// Викликається при успішному перегляді добровільної реклами (Revive, Double Coins, тощо)
    func notifyRewardedAdWatched() {
        didWatchRewardedInCurrentRun = true
        pendingAttempts = 0
        quickDeathsCount = 0
        lastAdShowTimestamp = Date().timeIntervalSince1970
        saveState()
        print("[DynamicAdManager] Rewarded ad watched! Pending attempts reset to 0, cooldown refreshed.")
    }
    
    /// Фіксація завершення забігу з аналізом показників
    func notifyRunCompleted(duration: TimeInterval, score: Int, isNewHighScore: Bool) {
        totalLifetimeRuns += 1
        sessionRunsCount += 1
        
        print("[DynamicAdManager] Run completed: duration=\(String(format: "%.1f", duration))s, score=\(score), isHighScore=\(isNewHighScore), sessionRun=\(sessionRunsCount)")
        
        // 1. Якщо гравець скористався Rewarded Ad у цьому раунді — лічильник уже обнулено
        if didWatchRewardedInCurrentRun {
            saveState()
            return
        }
        
        // 2. Якщо встановлено новий рекорд — сповіщення про пропуск реклами
        if isNewHighScore {
            print("[DynamicAdManager] New High Score (\(score))! Interstitial will be skipped for celebration.")
        }
        
        // 3. Динамічне нарахування ваги спроби
        if duration < Config.quickDeathThreshold {
            quickDeathsCount += 1
            if quickDeathsCount >= Config.quickDeathsPerAttempt {
                pendingAttempts += 1
                quickDeathsCount = 0
                print("[DynamicAdManager] Accumulated \(Config.quickDeathsPerAttempt) quick deaths -> +1 pending attempt (\(pendingAttempts))")
            } else {
                print("[DynamicAdManager] Quick death (\(String(format: "%.1f", duration))s). Ad counter preserved (\(pendingAttempts)).")
            }
        } else if duration >= Config.marathonRunThreshold || score >= Config.marathonScoreThreshold {
            pendingAttempts += 2
            quickDeathsCount = 0
            print("[DynamicAdManager] Marathon run (\(String(format: "%.1f", duration))s, score \(score))! +2 pending attempts (\(pendingAttempts)).")
        } else {
            pendingAttempts += 1
            quickDeathsCount = 0
            print("[DynamicAdManager] Normal run (\(String(format: "%.1f", duration))s). +1 pending attempt (\(pendingAttempts)).")
        }
        
        saveState()
    }
    
    // MARK: - Ad Decision Logic
    
    /// Перевіряє, чи настав правильний момент для показу міжсторінкової реклами
    func isEligibleForInterstitial(isNewHighScore: Bool) -> Bool {
        // 1. Захист від показу, якщо гравець щойно подивився Rewarded Ad (Revive або Double Coins)
        if didWatchRewardedInCurrentRun {
            print("[DynamicAdManager] Denied: Player watched rewarded ad in this run.")
            return false
        }
        
        // 2. Захист сесії (Session Warmup): ніколи не показувати рекламу на перших 3 забігах сесії
        if sessionRunsCount < Config.minSessionRunsBeforeAd {
            print("[DynamicAdManager] Denied: Session warmup active (\(sessionRunsCount)/\(Config.minSessionRunsBeforeAd) session runs). No ad.")
            return false
        }
        
        // 3. Захист новачка (FTUE): перші спроби після встановлення взагалі без реклами
        if totalLifetimeRuns <= Config.ftueImmunityAttempts {
            print("[DynamicAdManager] Denied: FTUE active (\(totalLifetimeRuns)/\(Config.ftueImmunityAttempts) lifetime runs). No ad.")
            return false
        }
        
        // 4. Захист емоції перемоги: новий рекорд ніколи не переривається рекламою
        if isNewHighScore {
            print("[DynamicAdManager] Denied: New high score achieved this run!")
            return false
        }
        
        // 5. Перевірка лічильника спроб (потрібно мінімум 4 спроби)
        guard pendingAttempts >= Config.targetAttemptsThreshold else {
            print("[DynamicAdManager] Denied: Not enough attempts (\(pendingAttempts)/\(Config.targetAttemptsThreshold)).")
            return false
        }
        
        // 6. Перевірка кулдауну реального часу (мінімум 75 секунд між показами)
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastAdShowTimestamp
        guard elapsed >= Config.minimumCooldownSeconds else {
            print("[DynamicAdManager] Denied: Attempts met (\(pendingAttempts)), but cooldown active (\(Int(elapsed))s / \(Int(Config.minimumCooldownSeconds))s).")
            return false
        }
        
        print("[DynamicAdManager] All criteria MET! Eligible for interstitial ad.")
        return true
    }
    
    /// Показує міжсторінкову рекламу, якщо виконані всі динамічні умови.
    /// Завжди викликає `onFinished` після завершення показу (або негайно, якщо показ не потрібен / не вдався).
    func showInterstitialIfEligible(
        from viewController: UIViewController,
        isNewHighScore: Bool,
        onFinished: @escaping () -> Void
    ) {
        guard isEligibleForInterstitial(isNewHighScore: isNewHighScore) else {
            onFinished()
            return
        }
        
        #if targetEnvironment(simulator)
        let canShow = true
        #else
        let canShow = NetworkMonitor.shared.isConnected && (UnityAdsManager.shared.isInterstitialAdLoaded || UnityAdsManager.shared.isInitialized)
        #endif
        
        guard canShow else {
            print("[DynamicAdManager] Interstitial eligible, but ads not ready or offline. Resetting counter and proceeding.")
            markInterstitialConsumed()
            onFinished()
            return
        }
        
        print("[DynamicAdManager] Triggering dynamic interstitial ad!")
        
        // Одразу скидаємо лічильник спроб, щоб унеможливити показ на кожній наступній поразці
        markInterstitialConsumed()
        
        var hasFinished = false
        let safeCompletion: () -> Void = {
            guard !hasFinished else { return }
            hasFinished = true
            DispatchQueue.main.async {
                onFinished()
            }
        }
        
        UnityAdsManager.shared.showInterstitialAd(
            from: viewController,
            onCompleted: { [weak self] in
                self?.markInterstitialShown()
                safeCompletion()
            },
            onFailed: { [weak self] error in
                print("[DynamicAdManager] Interstitial failed or cancelled: \(error)")
                self?.markInterstitialFailed()
                safeCompletion()
            }
        )
    }
    
    // MARK: - Private State Helpers
    
    /// Скидання лічильника спроб при запуску показу реклами
    private func markInterstitialConsumed() {
        pendingAttempts = 0
        quickDeathsCount = 0
        saveState()
    }
    
    /// Фіксація успішного показу реклами
    private func markInterstitialShown() {
        pendingAttempts = 0
        quickDeathsCount = 0
        lastAdShowTimestamp = Date().timeIntervalSince1970
        saveState()
        print("[DynamicAdManager] Interstitial finished successfully. Reset pending attempts to 0, cooldown started.")
    }
    
    /// Фіксація помилки або скасування показу
    private func markInterstitialFailed() {
        pendingAttempts = 0
        quickDeathsCount = 0
        // Встановлюємо кулдаун на 45 секунд, щоб гравець не отримував рекламу одразу на наступній поразці
        lastAdShowTimestamp = Date().timeIntervalSince1970 - (Config.minimumCooldownSeconds - 45.0)
        saveState()
    }
    
    private func saveState() {
        UserDefaults.standard.set(pendingAttempts, forKey: pendingAttemptsKey)
        UserDefaults.standard.set(totalLifetimeRuns, forKey: totalLifetimeRunsKey)
        UserDefaults.standard.set(lastAdShowTimestamp, forKey: lastAdShowTimestampKey)
        UserDefaults.standard.set(quickDeathsCount, forKey: quickDeathsKey)
    }
    
    // MARK: - Testing Helpers
    #if DEBUG
    func resetForTesting() {
        pendingAttempts = 0
        totalLifetimeRuns = 0
        sessionRunsCount = 0
        quickDeathsCount = 0
        lastAdShowTimestamp = 0
        didWatchRewardedInCurrentRun = false
        saveState()
        print("[DynamicAdManager] Testing state reset completely.")
    }
    
    func simulateStateForTesting(pendingAttempts: Int, lifetimeRuns: Int, sessionRuns: Int, lastAdTimestamp: TimeInterval) {
        self.pendingAttempts = pendingAttempts
        self.totalLifetimeRuns = lifetimeRuns
        self.sessionRunsCount = sessionRuns
        self.lastAdShowTimestamp = lastAdTimestamp
        saveState()
    }
    #endif
}
