//
//  AchievementManager.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import Foundation
import SpriteKit

// MARK: - Achievement Manager
final class AchievementManager {
    static let shared = AchievementManager()
    
    // MARK: - Configuration
    static let weeklyCycleSeconds: TimeInterval = 7 * 24 * 60 * 60 // 7 днів (щотижневий кулдаун)
    static let weeklyActiveCount = 12 // Рівно 12 випадкових ачівок на тиждень
    
    // MARK: - Storage Keys
    private let unlockedKey = "WallShiftWeeklyUnlockedAchievements"
    private let claimedKey = "WallShiftWeeklyClaimedAchievements"
    private let cycleStartDateKey = "WallShiftWeeklyCycleStartDate"
    private let activeWeeklyIDsKey = "WallShiftActiveWeeklyIDs"
    
    // Метрики поточного тижневого циклу
    private let weeklyScoreKey = "WallShiftWeeklyAccumulatedScore"
    private let weeklyCoinsKey = "WallShiftWeeklyAccumulatedCoins"
    private let weeklyJumpsKey = "WallShiftWeeklyAccumulatedJumps"
    private let weeklyDodgedArrowsKey = "WallShiftWeeklyAccumulatedDodgedArrows"
    private let weeklyHeartsKey = "WallShiftWeeklyAccumulatedHearts"
    private let weeklyRunsKey = "WallShiftWeeklyAccumulatedRuns"
    
    // Найкращі рекорди забігів за поточний тиждень
    private let weeklyBestScoreKey = "WallShiftWeeklyBestRunScore"
    private let weeklyBestCoinsKey = "WallShiftWeeklyBestRunCoins"
    private let weeklyBestJumpsKey = "WallShiftWeeklyBestRunJumps"
    private let weeklyBestDodgedKey = "WallShiftWeeklyBestRunDodged"
    private let weeklyBestHeartsKey = "WallShiftWeeklyBestRunHearts"
    private let weeklyBestNoDamageKey = "WallShiftWeeklyBestRunNoDamage"
    private let weeklyBestNoAbyssKey = "WallShiftWeeklyBestRunNoAbyss"
    private let weeklyBestNoReviveKey = "WallShiftWeeklyBestRunNoRevive"
    private let weeklyBestClutchKey = "WallShiftWeeklyBestRunClutch"
    
    // MARK: - State
    private(set) var unlockedIDs: Set<String> = []
    private(set) var claimedIDs: Set<String> = []
    private(set) var activeWeeklyIDs: [String] = []
    private(set) var cycleStartDate: Date = Date()
    
    /// Тимчасова статистика поточного забігу
    private var currentRunDodgedArrows: Int = 0
    private var currentRunHearts: Int = 0
    
    /// Досягнення, розблоковані під час поточного забігу
    private(set) var newlyUnlockedThisRun: [Achievement] = []
    
    /// Колбек для сповіщення UI
    var onAchievementUnlocked: ((Achievement) -> Void)?
    
    // MARK: - Поточні 12 активних досягнень тижня
    var achievements: [Achievement] {
        return activeWeeklyIDs.compactMap { id in
            Self.allCatalogAchievements.first(where: { $0.id == id })
        }
    }
    
    // MARK: - Initializer
    private init() {
        loadData()
        checkAndPerformWeeklyResetIfNeeded()
    }
    
    // MARK: - Weekly Cooldown & Reset Lifecycle
    
    /// Перевірка та скидання щотижневого кулдауну кожні 7 днів
    func checkAndPerformWeeklyResetIfNeeded() {
        let now = Date()
        let elapsed = now.timeIntervalSince(cycleStartDate)
        
        if activeWeeklyIDs.isEmpty || elapsed >= Self.weeklyCycleSeconds {
            performWeeklyReset(newStartDate: now)
        }
    }
    
    /// Примусове або планове скидання на новий тиждень (кулдаун та ротація)
    func performWeeklyReset(newStartDate: Date = Date()) {
        cycleStartDate = newStartDate
        
        // Анулювання статусів розблокування та забору нагород (кулдаун)
        unlockedIDs.removeAll()
        claimedIDs.removeAll()
        newlyUnlockedThisRun.removeAll()
        
        // Скидання накопиченої статистики та тижневих рекордів
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: unlockedKey)
        defaults.removeObject(forKey: claimedKey)
        defaults.removeObject(forKey: weeklyScoreKey)
        defaults.removeObject(forKey: weeklyCoinsKey)
        defaults.removeObject(forKey: weeklyJumpsKey)
        defaults.removeObject(forKey: weeklyDodgedArrowsKey)
        defaults.removeObject(forKey: weeklyHeartsKey)
        defaults.removeObject(forKey: weeklyRunsKey)
        defaults.removeObject(forKey: weeklyBestScoreKey)
        defaults.removeObject(forKey: weeklyBestCoinsKey)
        defaults.removeObject(forKey: weeklyBestJumpsKey)
        defaults.removeObject(forKey: weeklyBestDodgedKey)
        defaults.removeObject(forKey: weeklyBestHeartsKey)
        defaults.removeObject(forKey: weeklyBestNoDamageKey)
        defaults.removeObject(forKey: weeklyBestNoAbyssKey)
        defaults.removeObject(forKey: weeklyBestNoReviveKey)
        defaults.removeObject(forKey: weeklyBestClutchKey)
        
        // Вибираємо 12 нових рандомних досягнень із каталогу зі 100 шт:
        // Баланс складності: 5 Easy, 4 Medium, 3 Hard = 12 шт на тиждень
        let easyPool = Self.allCatalogAchievements.filter { $0.difficulty == .easy }.shuffled()
        let mediumPool = Self.allCatalogAchievements.filter { $0.difficulty == .medium }.shuffled()
        let hardPool = Self.allCatalogAchievements.filter { $0.difficulty == .hard }.shuffled()
        
        var selected: [Achievement] = []
        selected.append(contentsOf: easyPool.prefix(5))
        selected.append(contentsOf: mediumPool.prefix(4))
        selected.append(contentsOf: hardPool.prefix(3))
        
        // Якщо раптом з якихось причин не набралося 12, добираємо випадкові
        if selected.count < Self.weeklyActiveCount {
            let existingIDs = Set(selected.map { $0.id })
            let remaining = Self.allCatalogAchievements.filter { !existingIDs.contains($0.id) }.shuffled()
            selected.append(contentsOf: remaining.prefix(Self.weeklyActiveCount - selected.count))
        }
        
        activeWeeklyIDs = selected.map { $0.id }
        
        defaults.set(activeWeeklyIDs, forKey: activeWeeklyIDsKey)
        defaults.set(cycleStartDate.timeIntervalSince1970, forKey: cycleStartDateKey)
        defaults.synchronize()
    }
    
    /// Час, що залишився до наступного щотижневого скидання (у секундах)
    var timeRemainingUntilReset: TimeInterval {
        let elapsed = Date().timeIntervalSince(cycleStartDate)
        let remaining = Self.weeklyCycleSeconds - elapsed
        return max(0, remaining)
    }
    
    /// Відформатований рядок таймера до кулдауну (наприклад, "5d 14h" або "18h 42m")
    var weeklyResetFormattedString: String {
        let seconds = Int(timeRemainingUntilReset)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(max(1, minutes))m"
        }
    }
    
    // MARK: - Persistence
    private func loadData() {
        let defaults = UserDefaults.standard
        
        if let savedUnlocked = defaults.stringArray(forKey: unlockedKey) {
            unlockedIDs = Set(savedUnlocked)
        }
        if let savedClaimed = defaults.stringArray(forKey: claimedKey) {
            claimedIDs = Set(savedClaimed)
        }
        if let savedActiveIDs = defaults.stringArray(forKey: activeWeeklyIDsKey), !savedActiveIDs.isEmpty {
            activeWeeklyIDs = savedActiveIDs
        }
        
        let startTimestamp = defaults.double(forKey: cycleStartDateKey)
        if startTimestamp > 0 {
            cycleStartDate = Date(timeIntervalSince1970: startTimestamp)
        } else {
            cycleStartDate = Date()
            defaults.set(cycleStartDate.timeIntervalSince1970, forKey: cycleStartDateKey)
        }
    }
    
    private func saveUnlocked() {
        UserDefaults.standard.set(Array(unlockedIDs), forKey: unlockedKey)
    }
    
    private func saveClaimed() {
        UserDefaults.standard.set(Array(claimedIDs), forKey: claimedKey)
    }
    
    // MARK: - Queries
    func isUnlocked(id: String) -> Bool {
        return unlockedIDs.contains(id)
    }
    
    func isClaimed(id: String) -> Bool {
        return claimedIDs.contains(id)
    }
    
    func getProgress(for ach: Achievement) -> Int {
        if isUnlocked(id: ach.id) {
            return ach.targetValue
        }
        
        let defaults = UserDefaults.standard
        switch ach.metric {
        case .singleRunScore:
            return defaults.integer(forKey: weeklyBestScoreKey)
        case .weeklyScore:
            return defaults.integer(forKey: weeklyScoreKey)
        case .singleRunCoins:
            return defaults.integer(forKey: weeklyBestCoinsKey)
        case .weeklyCoins:
            return defaults.integer(forKey: weeklyCoinsKey)
        case .singleRunJumps:
            return defaults.integer(forKey: weeklyBestJumpsKey)
        case .weeklyJumps:
            return defaults.integer(forKey: weeklyJumpsKey)
        case .singleRunDodgedArrows:
            return defaults.integer(forKey: weeklyBestDodgedKey)
        case .weeklyDodgedArrows:
            return defaults.integer(forKey: weeklyDodgedArrowsKey)
        case .singleRunHearts:
            return defaults.integer(forKey: weeklyBestHeartsKey)
        case .weeklyHearts:
            return defaults.integer(forKey: weeklyHeartsKey)
        case .singleRunNoDamageScore:
            return defaults.integer(forKey: weeklyBestNoDamageKey)
        case .singleRunNoAbyssScore:
            return defaults.integer(forKey: weeklyBestNoAbyssKey)
        case .singleRunNoReviveScore:
            return defaults.integer(forKey: weeklyBestNoReviveKey)
        case .singleRunClutchScore:
            return defaults.integer(forKey: weeklyBestClutchKey)
        case .weeklyRunsCount:
            return defaults.integer(forKey: weeklyRunsKey)
        }
    }
    
    var unlockedCount: Int {
        return achievements.filter { isUnlocked(id: $0.id) }.count
    }
    
    var totalAchievementsCount: Int {
        return achievements.count // Завжди 12 у поточному тижні
    }
    
    var hasUnclaimedRewards: Bool {
        for ach in achievements {
            if isUnlocked(id: ach.id) && !isClaimed(id: ach.id) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Run Session Lifecycle
    func startNewRun() {
        checkAndPerformWeeklyResetIfNeeded()
        newlyUnlockedThisRun.removeAll()
        currentRunDodgedArrows = 0
        currentRunHearts = 0
    }
    
    // MARK: - Unlocking & Claiming
    func unlock(id: String) {
        guard !unlockedIDs.contains(id) else { return }
        guard let ach = achievements.first(where: { $0.id == id }) else { return }
        
        unlockedIDs.insert(id)
        newlyUnlockedThisRun.append(ach)
        saveUnlocked()
        
        DispatchQueue.main.async { [weak self] in
            self?.onAchievementUnlocked?(ach)
        }
    }
    
    /// Забрати нагороду за досягнення. Повертає кількість отриманих монет.
    func claimReward(for ach: Achievement) -> Int {
        guard isUnlocked(id: ach.id), !isClaimed(id: ach.id) else { return 0 }
        
        claimedIDs.insert(ach.id)
        saveClaimed()
        
        // Додаємо монети на загальний баланс гравця
        let currentTotal = UserDefaults.standard.integer(forKey: "TotalWallShiftCoins")
        UserDefaults.standard.set(currentTotal + ach.coinReward, forKey: "TotalWallShiftCoins")
        
        return ach.coinReward
    }
    
    // MARK: - Event Trackers
    
    /// Оновлення прогресу під час забігу в реальному часі
    func trackRunProgress(
        score: Int,
        runJumps: Int,
        runCoins: Int,
        tookDamageThisRun: Bool,
        fellIntoAbyssThisRun: Bool,
        usedReviveThisRun: Bool,
        clutchScore: Int = 0
    ) {
        checkAndPerformWeeklyResetIfNeeded()
        let defaults = UserDefaults.standard
        
        // 1. Оновлення тижневих рекордів забігу
        let curBestScore = defaults.integer(forKey: weeklyBestScoreKey)
        if score > curBestScore {
            defaults.set(score, forKey: weeklyBestScoreKey)
        }
        
        let curBestCoins = defaults.integer(forKey: weeklyBestCoinsKey)
        if runCoins > curBestCoins {
            defaults.set(runCoins, forKey: weeklyBestCoinsKey)
        }
        
        let curBestJumps = defaults.integer(forKey: weeklyBestJumpsKey)
        if runJumps > curBestJumps {
            defaults.set(runJumps, forKey: weeklyBestJumpsKey)
        }
        
        let curBestDodged = defaults.integer(forKey: weeklyBestDodgedKey)
        if currentRunDodgedArrows > curBestDodged {
            defaults.set(currentRunDodgedArrows, forKey: weeklyBestDodgedKey)
        }
        
        let curBestHearts = defaults.integer(forKey: weeklyBestHeartsKey)
        if currentRunHearts > curBestHearts {
            defaults.set(currentRunHearts, forKey: weeklyBestHeartsKey)
        }
        
        if !tookDamageThisRun {
            let bestNoDamage = defaults.integer(forKey: weeklyBestNoDamageKey)
            if score > bestNoDamage {
                defaults.set(score, forKey: weeklyBestNoDamageKey)
            }
        }
        
        if !fellIntoAbyssThisRun {
            let bestNoAbyss = defaults.integer(forKey: weeklyBestNoAbyssKey)
            if score > bestNoAbyss {
                defaults.set(score, forKey: weeklyBestNoAbyssKey)
            }
        }
        
        if !usedReviveThisRun {
            let bestNoRevive = defaults.integer(forKey: weeklyBestNoReviveKey)
            if score > bestNoRevive {
                defaults.set(score, forKey: weeklyBestNoReviveKey)
            }
        }
        
        if clutchScore > 0 {
            let bestClutch = defaults.integer(forKey: weeklyBestClutchKey)
            if clutchScore > bestClutch {
                defaults.set(clutchScore, forKey: weeklyBestClutchKey)
            }
        }
        
        // 2. Перевірка розблокування активних ачівок поточного тижня
        evaluateActiveAchievements()
    }
    
    /// Оновлення при підборі серця гравцем
    func trackHeartCollected() {
        currentRunHearts += 1
        
        let curBestHearts = UserDefaults.standard.integer(forKey: weeklyBestHeartsKey)
        if currentRunHearts > curBestHearts {
            UserDefaults.standard.set(currentRunHearts, forKey: weeklyBestHeartsKey)
        }
        
        let totalHearts = UserDefaults.standard.integer(forKey: weeklyHeartsKey) + 1
        UserDefaults.standard.set(totalHearts, forKey: weeklyHeartsKey)
        
        evaluateActiveAchievements()
    }
    
    /// Трекінг ухилення від вогняної стріли моба
    func trackArrowDodged() {
        currentRunDodgedArrows += 1
        
        let curBestDodged = UserDefaults.standard.integer(forKey: weeklyBestDodgedKey)
        if currentRunDodgedArrows > curBestDodged {
            UserDefaults.standard.set(currentRunDodgedArrows, forKey: weeklyBestDodgedKey)
        }
        
        let totalDodged = UserDefaults.standard.integer(forKey: weeklyDodgedArrowsKey) + 1
        UserDefaults.standard.set(totalDodged, forKey: weeklyDodgedArrowsKey)
        
        evaluateActiveAchievements()
    }
    
    /// Оновлення тижневої накопичувальної статистики при завершенні гри (Game Over)
    func completeRun(score: Int, coins: Int = 0, jumps: Int = 0) {
        checkAndPerformWeeklyResetIfNeeded()
        guard score >= 10 else { return }
        
        let defaults = UserDefaults.standard
        
        // Тижнева кількість забігів
        let totalRuns = defaults.integer(forKey: weeklyRunsKey) + 1
        defaults.set(totalRuns, forKey: weeklyRunsKey)
        
        // Тижнева накопичувальна дистанція / очки
        let totalScore = defaults.integer(forKey: weeklyScoreKey) + score
        defaults.set(totalScore, forKey: weeklyScoreKey)
        
        // Тижневі монети
        if coins > 0 {
            let totalCoins = defaults.integer(forKey: weeklyCoinsKey) + coins
            defaults.set(totalCoins, forKey: weeklyCoinsKey)
        }
        
        // Тижневі стрибки
        if jumps > 0 {
            let totalJumps = defaults.integer(forKey: weeklyJumpsKey) + jumps
            defaults.set(totalJumps, forKey: weeklyJumpsKey)
        }
        
        evaluateActiveAchievements()
    }
    
    /// Перевірка умов розблокування для всіх 12 активних тижневих ачівок
    private func evaluateActiveAchievements() {
        for ach in achievements {
            guard !isUnlocked(id: ach.id) else { continue }
            if getProgress(for: ach) >= ach.targetValue {
                unlock(id: ach.id)
            }
        }
    }
    
    // MARK: - Hard Reset (для налаштувань / дебагу)
    func resetAllAchievements() {
        performWeeklyReset(newStartDate: Date())
    }
}

// MARK: - Full 100 Unique Achievements Catalog
extension AchievementManager {
    static let allCatalogAchievements: [Achievement] = [
        
        // ==========================================
        // --- EASY (40 різноманітних досягнень) ---
        // ==========================================
        
        Achievement(
            id: "e01_first_hop",
            title: "First Hop",
            description: "Make 30 wall jumps in a single run",
            difficulty: .easy,
            metric: .singleRunJumps,
            coinReward: 150,
            targetValue: 30
        ),
        Achievement(
            id: "e02_coin_scout",
            title: "Coin Scout",
            description: "Collect 50 coins in a single run",
            difficulty: .easy,
            metric: .singleRunCoins,
            coinReward: 150,
            targetValue: 50
        ),
        Achievement(
            id: "e03_morning_run",
            title: "Morning Run",
            description: "Reach 400 score in a single run",
            difficulty: .easy,
            metric: .singleRunScore,
            coinReward: 150,
            targetValue: 400
        ),
        Achievement(
            id: "e04_arrow_glance",
            title: "Arrow Glance",
            description: "Dodge 5 mob arrows in a single run",
            difficulty: .easy,
            metric: .singleRunDodgedArrows,
            coinReward: 150,
            targetValue: 5
        ),
        Achievement(
            id: "e05_vital_spark",
            title: "Vital Spark",
            description: "Pick up 1 heart during a run",
            difficulty: .easy,
            metric: .singleRunHearts,
            coinReward: 150,
            targetValue: 1
        ),
        Achievement(
            id: "e06_steady_jumper",
            title: "Steady Jumper",
            description: "Make 60 wall jumps in a single run",
            difficulty: .easy,
            metric: .singleRunJumps,
            coinReward: 180,
            targetValue: 60
        ),
        Achievement(
            id: "e07_pocket_stash",
            title: "Pocket Stash",
            description: "Collect 100 coins in a single run",
            difficulty: .easy,
            metric: .singleRunCoins,
            coinReward: 180,
            targetValue: 100
        ),
        Achievement(
            id: "e08_breeze_runner",
            title: "Breeze Runner",
            description: "Reach 600 score in a single run",
            difficulty: .easy,
            metric: .singleRunScore,
            coinReward: 180,
            targetValue: 600
        ),
        Achievement(
            id: "e09_arrow_evader",
            title: "Arrow Evader",
            description: "Dodge 10 mob arrows in a single run",
            difficulty: .easy,
            metric: .singleRunDodgedArrows,
            coinReward: 180,
            targetValue: 10
        ),
        Achievement(
            id: "e10_weekly_warmup",
            title: "Weekly Warmup",
            description: "Complete 5 runs this week",
            difficulty: .easy,
            metric: .weeklyRunsCount,
            coinReward: 200,
            targetValue: 5
        ),
        Achievement(
            id: "e11_weekly_piggybank",
            title: "Weekly Piggybank",
            description: "Accumulate 300 coins this week",
            difficulty: .easy,
            metric: .weeklyCoins,
            coinReward: 200,
            targetValue: 300
        ),
        Achievement(
            id: "e12_cadet_springs",
            title: "Cadet Springs",
            description: "Make 200 total jumps this week",
            difficulty: .easy,
            metric: .weeklyJumps,
            coinReward: 200,
            targetValue: 200
        ),
        Achievement(
            id: "e13_weekly_explorer",
            title: "Weekly Explorer",
            description: "Accumulate 3,000 total score this week",
            difficulty: .easy,
            metric: .weeklyScore,
            coinReward: 200,
            targetValue: 3000
        ),
        Achievement(
            id: "e14_abyss_watcher",
            title: "Abyss Watcher",
            description: "Reach 350 score without falling into the abyss",
            difficulty: .easy,
            metric: .singleRunNoAbyssScore,
            coinReward: 200,
            targetValue: 350
        ),
        Achievement(
            id: "e15_clean_streak",
            title: "Clean Streak",
            description: "Reach 350 score without taking any damage",
            difficulty: .easy,
            metric: .singleRunNoDamageScore,
            coinReward: 200,
            targetValue: 350
        ),
        Achievement(
            id: "e16_heart_seeker",
            title: "Heart Seeker",
            description: "Pick up 2 hearts in a single run",
            difficulty: .easy,
            metric: .singleRunHearts,
            coinReward: 220,
            targetValue: 2
        ),
        Achievement(
            id: "e17_arrow_deflector",
            title: "Arrow Deflector",
            description: "Dodge 25 total arrows this week",
            difficulty: .easy,
            metric: .weeklyDodgedArrows,
            coinReward: 220,
            targetValue: 25
        ),
        Achievement(
            id: "e18_wall_hopper",
            title: "Wall Hopper",
            description: "Make 100 wall jumps in a single run",
            difficulty: .easy,
            metric: .singleRunJumps,
            coinReward: 220,
            targetValue: 100
        ),
        Achievement(
            id: "e19_shiny_pockets",
            title: "Shiny Pockets",
            description: "Collect 150 coins in a single run",
            difficulty: .easy,
            metric: .singleRunCoins,
            coinReward: 220,
            targetValue: 150
        ),
        Achievement(
            id: "e20_trailblazer",
            title: "Trailblazer",
            description: "Reach 800 score in a single run",
            difficulty: .easy,
            metric: .singleRunScore,
            coinReward: 250,
            targetValue: 800
        ),
        Achievement(
            id: "e21_edge_cautious",
            title: "Edge Cautious",
            description: "Reach 500 score without falling into the abyss",
            difficulty: .easy,
            metric: .singleRunNoAbyssScore,
            coinReward: 250,
            targetValue: 500
        ),
        Achievement(
            id: "e22_phantom_glide",
            title: "Phantom Glide",
            description: "Reach 500 score without taking damage",
            difficulty: .easy,
            metric: .singleRunNoDamageScore,
            coinReward: 250,
            targetValue: 500
        ),
        Achievement(
            id: "e23_clutch_impulse",
            title: "Clutch Impulse",
            description: "Survive for 200 score with only 1 life remaining",
            difficulty: .easy,
            metric: .singleRunClutchScore,
            coinReward: 250,
            targetValue: 200
        ),
        Achievement(
            id: "e24_weekly_strider",
            title: "Weekly Strider",
            description: "Make 400 total jumps this week",
            difficulty: .easy,
            metric: .weeklyJumps,
            coinReward: 250,
            targetValue: 400
        ),
        Achievement(
            id: "e25_copper_collector",
            title: "Copper Collector",
            description: "Accumulate 600 coins this week",
            difficulty: .easy,
            metric: .weeklyCoins,
            coinReward: 250,
            targetValue: 600
        ),
        Achievement(
            id: "e26_swift_reflex",
            title: "Swift Reflex",
            description: "Dodge 40 total arrows this week",
            difficulty: .easy,
            metric: .weeklyDodgedArrows,
            coinReward: 250,
            targetValue: 40
        ),
        Achievement(
            id: "e27_weekly_regular",
            title: "Weekly Regular",
            description: "Complete 10 runs this week",
            difficulty: .easy,
            metric: .weeklyRunsCount,
            coinReward: 250,
            targetValue: 10
        ),
        Achievement(
            id: "e28_heart_cache",
            title: "Heart Cache",
            description: "Collect 5 total hearts this week",
            difficulty: .easy,
            metric: .weeklyHearts,
            coinReward: 250,
            targetValue: 5
        ),
        Achievement(
            id: "e29_rising_star",
            title: "Rising Star",
            description: "Reach 1,000 score in a single run",
            difficulty: .easy,
            metric: .singleRunScore,
            coinReward: 280,
            targetValue: 1000
        ),
        Achievement(
            id: "e30_coin_magnet",
            title: "Coin Magnet",
            description: "Collect 200 coins in a single run",
            difficulty: .easy,
            metric: .singleRunCoins,
            coinReward: 280,
            targetValue: 200
        ),
        Achievement(
            id: "e31_air_acrobat",
            title: "Air Acrobat",
            description: "Make 150 wall jumps in a single run",
            difficulty: .easy,
            metric: .singleRunJumps,
            coinReward: 280,
            targetValue: 150
        ),
        Achievement(
            id: "e32_nimble_feet",
            title: "Nimble Feet",
            description: "Dodge 15 arrows in a single run",
            difficulty: .easy,
            metric: .singleRunDodgedArrows,
            coinReward: 280,
            targetValue: 15
        ),
        Achievement(
            id: "e33_safe_path",
            title: "Safe Path",
            description: "Reach 700 score without falling into the abyss",
            difficulty: .easy,
            metric: .singleRunNoAbyssScore,
            coinReward: 280,
            targetValue: 700
        ),
        Achievement(
            id: "e34_pure_evasion",
            title: "Pure Evasion",
            description: "Reach 700 score without taking damage",
            difficulty: .easy,
            metric: .singleRunNoDamageScore,
            coinReward: 280,
            targetValue: 700
        ),
        Achievement(
            id: "e35_hearty_trio",
            title: "Hearty Trio",
            description: "Pick up 3 hearts in a single run",
            difficulty: .easy,
            metric: .singleRunHearts,
            coinReward: 300,
            targetValue: 3
        ),
        Achievement(
            id: "e36_clutch_nerve",
            title: "Clutch Nerve",
            description: "Survive for 350 score with only 1 life remaining",
            difficulty: .easy,
            metric: .singleRunClutchScore,
            coinReward: 300,
            targetValue: 350
        ),
        Achievement(
            id: "e37_weekly_mileage",
            title: "Weekly Mileage",
            description: "Accumulate 6,000 total score this week",
            difficulty: .easy,
            metric: .weeklyScore,
            coinReward: 300,
            targetValue: 6000
        ),
        Achievement(
            id: "e38_coin_enthusiast",
            title: "Coin Enthusiast",
            description: "Collect 250 coins in a single run",
            difficulty: .easy,
            metric: .singleRunCoins,
            coinReward: 300,
            targetValue: 250
        ),
        Achievement(
            id: "e39_no_revive_pawn",
            title: "Natural Reflex",
            description: "Reach 800 score without using a revive",
            difficulty: .easy,
            metric: .singleRunNoReviveScore,
            coinReward: 300,
            targetValue: 800
        ),
        Achievement(
            id: "e40_daily_habit",
            title: "Daily Habit",
            description: "Complete 15 runs this week",
            difficulty: .easy,
            metric: .weeklyRunsCount,
            coinReward: 320,
            targetValue: 15
        ),
        
        // ==========================================
        // --- MEDIUM (35 збалансованих челенджів) ---
        // ==========================================
        
        Achievement(
            id: "m01_wall_master",
            title: "Wall Master",
            description: "Make 250 wall jumps in a single run",
            difficulty: .medium,
            metric: .singleRunJumps,
            coinReward: 500,
            targetValue: 250
        ),
        Achievement(
            id: "m02_rich_climber",
            title: "Rich Climber",
            description: "Collect 350 coins in a single run",
            difficulty: .medium,
            metric: .singleRunCoins,
            coinReward: 500,
            targetValue: 350
        ),
        Achievement(
            id: "m03_canyon_conqueror",
            title: "Canyon Conqueror",
            description: "Reach 1,500 score in a single run",
            difficulty: .medium,
            metric: .singleRunScore,
            coinReward: 500,
            targetValue: 1500
        ),
        Achievement(
            id: "m04_bullet_time",
            title: "Bullet Time",
            description: "Dodge 25 mob arrows in a single run",
            difficulty: .medium,
            metric: .singleRunDodgedArrows,
            coinReward: 550,
            targetValue: 25
        ),
        Achievement(
            id: "m05_heart_guardian",
            title: "Heart Guardian",
            description: "Pick up 4 hearts in a single run",
            difficulty: .medium,
            metric: .singleRunHearts,
            coinReward: 550,
            targetValue: 4
        ),
        Achievement(
            id: "m06_pure_ascent",
            title: "Pure Ascent",
            description: "Reach 1,000 score without taking any damage",
            difficulty: .medium,
            metric: .singleRunNoDamageScore,
            coinReward: 550,
            targetValue: 1000
        ),
        Achievement(
            id: "m07_edge_dancer",
            title: "Edge Dancer",
            description: "Reach 1,000 score without falling into the abyss",
            difficulty: .medium,
            metric: .singleRunNoAbyssScore,
            coinReward: 550,
            targetValue: 1000
        ),
        Achievement(
            id: "m08_clean_ascent",
            title: "Clean Ascent",
            description: "Reach 1,200 score without using a revive",
            difficulty: .medium,
            metric: .singleRunNoReviveScore,
            coinReward: 550,
            targetValue: 1200
        ),
        Achievement(
            id: "m09_clutch_hero",
            title: "Clutch Hero",
            description: "Survive for 500 score with only 1 life remaining",
            difficulty: .medium,
            metric: .singleRunClutchScore,
            coinReward: 600,
            targetValue: 500
        ),
        Achievement(
            id: "m10_weekly_sprinter",
            title: "Weekly Sprinter",
            description: "Make 800 total jumps this week",
            difficulty: .medium,
            metric: .weeklyJumps,
            coinReward: 600,
            targetValue: 800
        ),
        Achievement(
            id: "m11_golden_stash",
            title: "Golden Stash",
            description: "Accumulate 1,200 coins this week",
            difficulty: .medium,
            metric: .weeklyCoins,
            coinReward: 600,
            targetValue: 1200
        ),
        Achievement(
            id: "m12_high_strider",
            title: "High Strider",
            description: "Accumulate 12,000 total score this week",
            difficulty: .medium,
            metric: .weeklyScore,
            coinReward: 600,
            targetValue: 12000
        ),
        Achievement(
            id: "m13_arrow_matrix",
            title: "Arrow Matrix",
            description: "Dodge 70 total arrows this week",
            difficulty: .medium,
            metric: .weeklyDodgedArrows,
            coinReward: 650,
            targetValue: 70
        ),
        Achievement(
            id: "m14_weekly_grinder",
            title: "Weekly Grinder",
            description: "Complete 25 runs this week",
            difficulty: .medium,
            metric: .weeklyRunsCount,
            coinReward: 650,
            targetValue: 25
        ),
        Achievement(
            id: "m15_life_reservoir",
            title: "Life Reservoir",
            description: "Pick up 10 total hearts this week",
            difficulty: .medium,
            metric: .weeklyHearts,
            coinReward: 650,
            targetValue: 10
        ),
        Achievement(
            id: "m16_cliff_glider",
            title: "Cliff Glider",
            description: "Reach 1,800 score in a single run",
            difficulty: .medium,
            metric: .singleRunScore,
            coinReward: 700,
            targetValue: 1800
        ),
        Achievement(
            id: "m17_treasure_hoarder",
            title: "Treasure Hoarder",
            description: "Collect 450 coins in a single run",
            difficulty: .medium,
            metric: .singleRunCoins,
            coinReward: 700,
            targetValue: 450
        ),
        Achievement(
            id: "m18_wall_veteran",
            title: "Wall Veteran",
            description: "Make 320 wall jumps in a single run",
            difficulty: .medium,
            metric: .singleRunJumps,
            coinReward: 700,
            targetValue: 320
        ),
        Achievement(
            id: "m19_ghost_runner",
            title: "Ghost Runner",
            description: "Reach 1,200 score without taking any damage",
            difficulty: .medium,
            metric: .singleRunNoDamageScore,
            coinReward: 750,
            targetValue: 1200
        ),
        Achievement(
            id: "m20_abyss_defier",
            title: "Abyss Defier",
            description: "Reach 1,400 score without falling into the abyss",
            difficulty: .medium,
            metric: .singleRunNoAbyssScore,
            coinReward: 750,
            targetValue: 1400
        ),
        Achievement(
            id: "m21_iron_grit",
            title: "Iron Grit",
            description: "Reach 1,600 score without using a revive",
            difficulty: .medium,
            metric: .singleRunNoReviveScore,
            coinReward: 750,
            targetValue: 1600
        ),
        Achievement(
            id: "m22_wire_walker",
            title: "Wire Walker",
            description: "Survive for 700 score with only 1 life remaining",
            difficulty: .medium,
            metric: .singleRunClutchScore,
            coinReward: 750,
            targetValue: 700
        ),
        Achievement(
            id: "m23_arrow_whirlwind",
            title: "Arrow Whirlwind",
            description: "Dodge 35 mob arrows in a single run",
            difficulty: .medium,
            metric: .singleRunDodgedArrows,
            coinReward: 750,
            targetValue: 35
        ),
        Achievement(
            id: "m24_cloud_climber",
            title: "Cloud Climber",
            description: "Reach 2,200 score in a single run",
            difficulty: .medium,
            metric: .singleRunScore,
            coinReward: 800,
            targetValue: 2200
        ),
        Achievement(
            id: "m25_golden_tycoon",
            title: "Golden Tycoon",
            description: "Collect 550 coins in a single run",
            difficulty: .medium,
            metric: .singleRunCoins,
            coinReward: 800,
            targetValue: 550
        ),
        Achievement(
            id: "m26_spring_master",
            title: "Spring Master",
            description: "Make 400 wall jumps in a single run",
            difficulty: .medium,
            metric: .singleRunJumps,
            coinReward: 800,
            targetValue: 400
        ),
        Achievement(
            id: "m27_weekly_marathoner",
            title: "Weekly Marathoner",
            description: "Make 1,200 total jumps this week",
            difficulty: .medium,
            metric: .weeklyJumps,
            coinReward: 800,
            targetValue: 1200
        ),
        Achievement(
            id: "m28_wealthy_scout",
            title: "Wealthy Scout",
            description: "Accumulate 2,000 coins this week",
            difficulty: .medium,
            metric: .weeklyCoins,
            coinReward: 800,
            targetValue: 2000
        ),
        Achievement(
            id: "m29_summit_seeker",
            title: "Summit Seeker",
            description: "Accumulate 20,000 total score this week",
            difficulty: .medium,
            metric: .weeklyScore,
            coinReward: 800,
            targetValue: 20000
        ),
        Achievement(
            id: "m30_sniper_bane",
            title: "Sniper Bane",
            description: "Dodge 100 total arrows this week",
            difficulty: .medium,
            metric: .weeklyDodgedArrows,
            coinReward: 850,
            targetValue: 100
        ),
        Achievement(
            id: "m31_seasoned_climber",
            title: "Seasoned Climber",
            description: "Complete 35 runs this week",
            difficulty: .medium,
            metric: .weeklyRunsCount,
            coinReward: 850,
            targetValue: 35
        ),
        Achievement(
            id: "m32_heart_harvester",
            title: "Heart Harvester",
            description: "Pick up 5 hearts in a single run",
            difficulty: .medium,
            metric: .singleRunHearts,
            coinReward: 850,
            targetValue: 5
        ),
        Achievement(
            id: "m33_untouchable_step",
            title: "Untouchable Step",
            description: "Reach 1,500 score without taking damage",
            difficulty: .medium,
            metric: .singleRunNoDamageScore,
            coinReward: 850,
            targetValue: 1500
        ),
        Achievement(
            id: "m34_void_immune",
            title: "Void Immune",
            description: "Reach 1,800 score without falling into the abyss",
            difficulty: .medium,
            metric: .singleRunNoAbyssScore,
            coinReward: 850,
            targetValue: 1800
        ),
        Achievement(
            id: "m35_pure_grit",
            title: "Pure Grit",
            description: "Reach 2,000 score without using a revive",
            difficulty: .medium,
            metric: .singleRunNoReviveScore,
            coinReward: 900,
            targetValue: 2000
        ),
        
        // ==========================================
        // --- HARD (25 елітних досягнень майстерності) ---
        // ==========================================
        
        Achievement(
            id: "h01_apex_predator",
            title: "Apex Predator",
            description: "Reach 3,000 score in a single run",
            difficulty: .hard,
            metric: .singleRunScore,
            coinReward: 1200,
            targetValue: 3000
        ),
        Achievement(
            id: "h02_golden_king",
            title: "Golden King",
            description: "Collect 700 coins in a single run",
            difficulty: .hard,
            metric: .singleRunCoins,
            coinReward: 1200,
            targetValue: 700
        ),
        Achievement(
            id: "h03_boundless_hops",
            title: "Boundless Hops",
            description: "Make 500 wall jumps in a single run",
            difficulty: .hard,
            metric: .singleRunJumps,
            coinReward: 1200,
            targetValue: 500
        ),
        Achievement(
            id: "h04_arrow_phantom",
            title: "Arrow Phantom",
            description: "Dodge 50 mob arrows in a single run",
            difficulty: .hard,
            metric: .singleRunDodgedArrows,
            coinReward: 1300,
            targetValue: 50
        ),
        Achievement(
            id: "h05_untouchable_titan",
            title: "Untouchable Titan",
            description: "Reach 2,000 score without taking any damage",
            difficulty: .hard,
            metric: .singleRunNoDamageScore,
            coinReward: 1400,
            targetValue: 2000
        ),
        Achievement(
            id: "h06_abyss_master",
            title: "Abyss Master",
            description: "Reach 2,400 score without falling into the abyss",
            difficulty: .hard,
            metric: .singleRunNoAbyssScore,
            coinReward: 1400,
            targetValue: 2400
        ),
        Achievement(
            id: "h07_true_veteran",
            title: "True Veteran",
            description: "Reach 2,500 score without using a revive",
            difficulty: .hard,
            metric: .singleRunNoReviveScore,
            coinReward: 1400,
            targetValue: 2500
        ),
        Achievement(
            id: "h08_clutch_god",
            title: "Clutch God",
            description: "Survive for 1,000 score with only 1 life remaining",
            difficulty: .hard,
            metric: .singleRunClutchScore,
            coinReward: 1500,
            targetValue: 1000
        ),
        Achievement(
            id: "h09_heart_magnet",
            title: "Heart Magnet",
            description: "Pick up 6 hearts in a single run",
            difficulty: .hard,
            metric: .singleRunHearts,
            coinReward: 1500,
            targetValue: 6
        ),
        Achievement(
            id: "h10_sky_strider",
            title: "Sky Strider",
            description: "Reach 3,800 score in a single run",
            difficulty: .hard,
            metric: .singleRunScore,
            coinReward: 1600,
            targetValue: 3800
        ),
        Achievement(
            id: "h11_dragon_vault",
            title: "Dragon Vault",
            description: "Collect 900 coins in a single run",
            difficulty: .hard,
            metric: .singleRunCoins,
            coinReward: 1600,
            targetValue: 900
        ),
        Achievement(
            id: "h12_perpetual_motion",
            title: "Perpetual Motion",
            description: "Make 650 wall jumps in a single run",
            difficulty: .hard,
            metric: .singleRunJumps,
            coinReward: 1600,
            targetValue: 650
        ),
        Achievement(
            id: "h13_weekly_colossus",
            title: "Weekly Colossus",
            description: "Accumulate 35,000 total score this week",
            difficulty: .hard,
            metric: .weeklyScore,
            coinReward: 1750,
            targetValue: 35000
        ),
        Achievement(
            id: "h14_weekly_hoarder",
            title: "Weekly Hoarder",
            description: "Accumulate 3,500 coins this week",
            difficulty: .hard,
            metric: .weeklyCoins,
            coinReward: 1750,
            targetValue: 3500
        ),
        Achievement(
            id: "h15_weekly_springs",
            title: "Weekly Springs",
            description: "Make 2,000 total jumps this week",
            difficulty: .hard,
            metric: .weeklyJumps,
            coinReward: 1750,
            targetValue: 2000
        ),
        Achievement(
            id: "h16_arrow_storm_survivor",
            title: "Arrow Storm",
            description: "Dodge 160 total arrows this week",
            difficulty: .hard,
            metric: .weeklyDodgedArrows,
            coinReward: 1800,
            targetValue: 160
        ),
        Achievement(
            id: "h17_centurion",
            title: "Centurion",
            description: "Complete 50 runs this week",
            difficulty: .hard,
            metric: .weeklyRunsCount,
            coinReward: 1800,
            targetValue: 50
        ),
        Achievement(
            id: "h18_void_walker",
            title: "Void Walker",
            description: "Reach 3,000 score without falling into the abyss",
            difficulty: .hard,
            metric: .singleRunNoAbyssScore,
            coinReward: 1900,
            targetValue: 3000
        ),
        Achievement(
            id: "h19_shadow_ghost",
            title: "Shadow Ghost",
            description: "Reach 2,500 score without taking damage",
            difficulty: .hard,
            metric: .singleRunNoDamageScore,
            coinReward: 2000,
            targetValue: 2500
        ),
        Achievement(
            id: "h20_pure_instinct",
            title: "Pure Instinct",
            description: "Reach 3,200 score without using a revive",
            difficulty: .hard,
            metric: .singleRunNoReviveScore,
            coinReward: 2000,
            targetValue: 3200
        ),
        Achievement(
            id: "h21_clutch_deity",
            title: "Clutch Deity",
            description: "Survive for 1,400 score with only 1 life remaining",
            difficulty: .hard,
            metric: .singleRunClutchScore,
            coinReward: 2100,
            targetValue: 1400
        ),
        Achievement(
            id: "h22_arrow_tornado",
            title: "Arrow Tornado",
            description: "Dodge 65 mob arrows in a single run",
            difficulty: .hard,
            metric: .singleRunDodgedArrows,
            coinReward: 2200,
            targetValue: 65
        ),
        Achievement(
            id: "h23_apex_legend",
            title: "Apex Legend",
            description: "Reach 5,000 score in a single run",
            difficulty: .hard,
            metric: .singleRunScore,
            coinReward: 2300,
            targetValue: 5000
        ),
        Achievement(
            id: "h24_king_of_gold",
            title: "King of Gold",
            description: "Collect 1,200 coins in a single run",
            difficulty: .hard,
            metric: .singleRunCoins,
            coinReward: 2300,
            targetValue: 1200
        ),
        Achievement(
            id: "h25_marathon_master",
            title: "Marathon Master",
            description: "Accumulate 50,000 total score this week",
            difficulty: .hard,
            metric: .weeklyScore,
            coinReward: 2500,
            targetValue: 50000
        )
    ]
}
