//
//  AchievementManager.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import Foundation
import SpriteKit

// MARK: - Achievement Difficulty
enum AchievementDifficulty: String, Codable, CaseIterable {
    case easy = "EASY"
    case medium = "MEDIUM"
    case hard = "HARD"
    
    var color: SKColor {
        switch self {
        case .easy:
            return SKColor(red: 0.32, green: 0.82, blue: 0.40, alpha: 1.0)
        case .medium:
            return SKColor(red: 1.0, green: 0.68, blue: 0.18, alpha: 1.0)
        case .hard:
            return SKColor(red: 0.95, green: 0.28, blue: 0.38, alpha: 1.0)
        }
    }
}

// MARK: - Achievement Definition
struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let difficulty: AchievementDifficulty
    let coinReward: Int
    let targetValue: Int
    
    var isUnlocked: Bool {
        return AchievementManager.shared.isUnlocked(id: id)
    }
    
    var isClaimed: Bool {
        return AchievementManager.shared.isClaimed(id: id)
    }
    
    var currentProgress: Int {
        return AchievementManager.shared.getProgress(for: id)
    }
    
    var progressRatio: CGFloat {
        guard targetValue > 0 else { return 0 }
        let progress = CGFloat(min(currentProgress, targetValue))
        return progress / CGFloat(targetValue)
    }
}

// MARK: - Achievement Manager
final class AchievementManager {
    static let shared = AchievementManager()
    
    // MARK: - Keys
    private let unlockedKey = "WallShiftUnlockedAchievements"
    private let claimedKey = "WallShiftClaimedAchievements"
    private let totalRunsKey = "WallShiftTotalRunsCount"
    private let lifetimeScoreKey = "WallShiftLifetimeScore"
    private let totalDodgedArrowsKey = "WallShiftTotalDodgedArrows"
    private let bestRunJumpsKey = "WallShiftBestRunJumps"
    private let bestRunCoinsKey = "WallShiftBestRunCoins"
    private let bestUntouchableKey = "WallShiftBestUntouchableScore"
    private let bestIronWillKey = "WallShiftBestIronWillScore"
    
    // MARK: - State
    private(set) var unlockedIDs: Set<String> = []
    private(set) var claimedIDs: Set<String> = []
    
    /// Досягнення, розблоковані саме під час останнього забігу (для екрана Game Over)
    private(set) var newlyUnlockedThisRun: [Achievement] = []
    
    /// Колбек для сповіщення UI (викликається безпосередньо при розблокуванні)
    var onAchievementUnlocked: ((Achievement) -> Void)?
    
    // MARK: - Hardcore & Engaging Catalog (13 довгострокових челенджів)
    let achievements: [Achievement] = [
        // --- EASY (Справжні початкові челенджі) ---
        Achievement(
            id: "trailblazer",
            title: "Trailblazer",
            description: "Reach 300 score in a single run",
            difficulty: .easy,
            coinReward: 500,
            targetValue: 300
        ),
        Achievement(
            id: "coin_enthusiast",
            title: "Coin Enthusiast",
            description: "Collect 100 coins in a single run",
            difficulty: .easy,
            coinReward: 500,
            targetValue: 100
        ),
        Achievement(
            id: "wall_master",
            title: "Wall Master",
            description: "Make 120 wall jumps in a single run",
            difficulty: .easy,
            coinReward: 600,
            targetValue: 120
        ),
        
        // --- MEDIUM (Вимагають серйозного скілу або 20-50 забігів) ---
        Achievement(
            id: "canyon_conqueror",
            title: "Canyon Conqueror",
            description: "Reach 1,000 score in a single run",
            difficulty: .medium,
            coinReward: 2000,
            targetValue: 1000
        ),
        Achievement(
            id: "treasure_hoarder",
            title: "Treasure Hoarder",
            description: "Collect 300 coins in a single run",
            difficulty: .medium,
            coinReward: 2500,
            targetValue: 300
        ),
        Achievement(
            id: "ghost_runner",
            title: "Ghost Runner",
            description: "Reach 500 score without taking any damage",
            difficulty: .medium,
            coinReward: 3000,
            targetValue: 500
        ),
        Achievement(
            id: "seasoned_climber",
            title: "Seasoned Climber",
            description: "Complete 50 full runs (Lifetime: 50)",
            difficulty: .medium,
            coinReward: 3500,
            targetValue: 50
        ),
        Achievement(
            id: "arrow_matrix",
            title: "Arrow Matrix",
            description: "Dodge 60 mob projectiles across your runs",
            difficulty: .medium,
            coinReward: 3000,
            targetValue: 60
        ),
        
        // --- HARD (Елітні досягнення: 50-100 ігор, висока майстерність) ---
        Achievement(
            id: "apex_legend",
            title: "Apex Legend",
            description: "Reach 2,500 score in a single run",
            difficulty: .hard,
            coinReward: 8000,
            targetValue: 2500
        ),
        Achievement(
            id: "golden_king",
            title: "Golden King",
            description: "Collect 600 coins in a single run",
            difficulty: .hard,
            coinReward: 7000,
            targetValue: 600
        ),
        Achievement(
            id: "untouchable_titan",
            title: "Untouchable Titan",
            description: "Reach 1,200 score without falling or reviving",
            difficulty: .hard,
            coinReward: 8000,
            targetValue: 1200
        ),
        Achievement(
            id: "marathon_master",
            title: "Marathon Master",
            description: "Accumulate 30,000 total score across all runs",
            difficulty: .hard,
            coinReward: 10000,
            targetValue: 30000
        ),
        Achievement(
            id: "centurion",
            title: "Centurion",
            description: "Complete 100 runs in Wallshift",
            difficulty: .hard,
            coinReward: 10000,
            targetValue: 100
        )
    ]
    
    // MARK: - Initializer
    private init() {
        loadData()
    }
    
    // MARK: - Persistence
    private func loadData() {
        if let savedUnlocked = UserDefaults.standard.stringArray(forKey: unlockedKey) {
            unlockedIDs = Set(savedUnlocked)
        }
        if let savedClaimed = UserDefaults.standard.stringArray(forKey: claimedKey) {
            claimedIDs = Set(savedClaimed)
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
    
    func getProgress(for id: String) -> Int {
        if isUnlocked(id: id) {
            if let ach = achievements.first(where: { $0.id == id }) {
                return ach.targetValue
            }
        }
        
        switch id {
        case "trailblazer", "canyon_conqueror", "apex_legend":
            return UserDefaults.standard.integer(forKey: "BestWallShiftScore")
        case "wall_master":
            return UserDefaults.standard.integer(forKey: bestRunJumpsKey)
        case "coin_enthusiast", "treasure_hoarder", "golden_king":
            return UserDefaults.standard.integer(forKey: bestRunCoinsKey)
        case "ghost_runner":
            return UserDefaults.standard.integer(forKey: bestUntouchableKey)
        case "seasoned_climber", "centurion":
            return UserDefaults.standard.integer(forKey: totalRunsKey)
        case "arrow_matrix":
            return UserDefaults.standard.integer(forKey: totalDodgedArrowsKey)
        case "untouchable_titan":
            return UserDefaults.standard.integer(forKey: bestIronWillKey)
        case "marathon_master":
            return UserDefaults.standard.integer(forKey: lifetimeScoreKey)
        default:
            return 0
        }
    }
    
    var unlockedCount: Int {
        return unlockedIDs.count
    }
    
    var totalAchievementsCount: Int {
        return achievements.count
    }
    
    var hasUnclaimedRewards: Bool {
        for ach in achievements {
            if isUnlocked(id: ach.id) && !isClaimed(id: ach.id) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Reset All Achievements
    /// Повне анулювання всіх розблокованих досягнень, забраних нагород та накопиченого прогресу
    func resetAllAchievements() {
        unlockedIDs.removeAll()
        claimedIDs.removeAll()
        newlyUnlockedThisRun.removeAll()
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: unlockedKey)
        defaults.removeObject(forKey: claimedKey)
        defaults.removeObject(forKey: totalRunsKey)
        defaults.removeObject(forKey: lifetimeScoreKey)
        defaults.removeObject(forKey: totalDodgedArrowsKey)
        defaults.removeObject(forKey: bestRunJumpsKey)
        defaults.removeObject(forKey: bestRunCoinsKey)
        defaults.removeObject(forKey: bestUntouchableKey)
        defaults.removeObject(forKey: bestIronWillKey)
        defaults.removeObject(forKey: "WallShiftBestClutchScore")
        defaults.synchronize()
    }
    
    // MARK: - Run Session Lifecycle
    func startNewRun() {
        newlyUnlockedThisRun.removeAll()
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
        
        // Додаємо монети на баланс гравця
        let currentTotal = UserDefaults.standard.integer(forKey: "TotalWallShiftCoins")
        UserDefaults.standard.set(currentTotal + ach.coinReward, forKey: "TotalWallShiftCoins")
        
        return ach.coinReward
    }
    
    // MARK: - Event Trackers
    
    /// Оновлення прогресу під час забігу
    func trackRunProgress(
        score: Int,
        runJumps: Int,
        runCoins: Int,
        tookDamageThisRun: Bool,
        fellIntoAbyssThisRun: Bool,
        usedReviveThisRun: Bool
    ) {
        // 1. Дистанція в забігу (Score)
        if score >= 300 {
            unlock(id: "trailblazer")
        }
        if score >= 1000 {
            unlock(id: "canyon_conqueror")
        }
        if score >= 2500 {
            unlock(id: "apex_legend")
        }
        
        // 2. Стрибки в забігу (Wall Jumps: 120)
        let savedBestJumps = UserDefaults.standard.integer(forKey: bestRunJumpsKey)
        if runJumps > savedBestJumps {
            UserDefaults.standard.set(runJumps, forKey: bestRunJumpsKey)
        }
        if runJumps >= 120 {
            unlock(id: "wall_master")
        }
        
        // 3. Монети в забігу (Coins: 100, 300, 600)
        let savedBestCoins = UserDefaults.standard.integer(forKey: bestRunCoinsKey)
        if runCoins > savedBestCoins {
            UserDefaults.standard.set(runCoins, forKey: bestRunCoinsKey)
        }
        if runCoins >= 100 {
            unlock(id: "coin_enthusiast")
        }
        if runCoins >= 300 {
            unlock(id: "treasure_hoarder")
        }
        if runCoins >= 600 {
            unlock(id: "golden_king")
        }
        
        // 4. Ghost Runner (500 score without damage)
        if !tookDamageThisRun {
            let savedGhost = UserDefaults.standard.integer(forKey: bestUntouchableKey)
            if score > savedGhost {
                UserDefaults.standard.set(score, forKey: bestUntouchableKey)
            }
            if score >= 500 {
                unlock(id: "ghost_runner")
            }
        }
        
        // 5. Untouchable Titan (1,200 score without abyss fall and without revive)
        if !fellIntoAbyssThisRun && !usedReviveThisRun {
            let savedTitan = UserDefaults.standard.integer(forKey: bestIronWillKey)
            if score > savedTitan {
                UserDefaults.standard.set(score, forKey: bestIronWillKey)
            }
            if score >= 1200 {
                unlock(id: "untouchable_titan")
            }
        }
    }
    
    /// Оновлення довгострокової статистики при завершенні гри (Game Over)
    func completeRun(score: Int) {
        guard score >= 10 else { return }
        
        // Кількість забігів (+1)
        let totalRuns = UserDefaults.standard.integer(forKey: totalRunsKey) + 1
        UserDefaults.standard.set(totalRuns, forKey: totalRunsKey)
        
        if totalRuns >= 50 {
            unlock(id: "seasoned_climber")
        }
        if totalRuns >= 100 {
            unlock(id: "centurion")
        }
        
        // Сумарна дистанція за всі часи (+score)
        let lifetime = UserDefaults.standard.integer(forKey: lifetimeScoreKey) + score
        UserDefaults.standard.set(lifetime, forKey: lifetimeScoreKey)
        
        if lifetime >= 30000 {
            unlock(id: "marathon_master")
        }
    }
    
    /// Трекінг ухилення від снаряда моба
    func trackArrowDodged() {
        let current = UserDefaults.standard.integer(forKey: totalDodgedArrowsKey) + 1
        UserDefaults.standard.set(current, forKey: totalDodgedArrowsKey)
        if current >= 60 {
            unlock(id: "arrow_matrix")
        }
    }
}
