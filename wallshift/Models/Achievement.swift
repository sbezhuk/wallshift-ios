//
//  Achievement.swift
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

// MARK: - Achievement Metric Types
enum AchievementMetric: String, Codable {
    case singleRunScore         // Набрати X очок за один забіг
    case weeklyScore            // Сумарно набрати X очок за тиждень
    case singleRunCoins         // Зібрати X монет за один забіг
    case weeklyCoins            // Сумарно зібрати X монет за тиждень
    case singleRunJumps         // Зробити X стрибків за один забіг
    case weeklyJumps            // Сумарно зробити X стрибків за тиждень
    case singleRunDodgedArrows  // Ухилитися від X вогняних стріл за один забіг
    case weeklyDodgedArrows     // Сумарно ухилитися від X вогняних стріл за тиждень
    case singleRunHearts        // Підібрати X додаткових сердець за один забіг
    case weeklyHearts           // Сумарно підібрати X сердець за тиждень
    case singleRunNoDamageScore // Очки за один забіг без отримання будь-якої шкоди
    case singleRunNoAbyssScore  // Очки за один забіг без жодного падіння в прірву
    case singleRunNoReviveScore // Очки за один забіг без використання відродження (revive)
    case singleRunClutchScore   // Пройти X очок у стані з 1 HP (на межі вибування)
    case weeklyRunsCount        // Зіграти / завершити X забігів за тиждень
}

// MARK: - Achievement Definition
struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let difficulty: AchievementDifficulty
    let metric: AchievementMetric
    let coinReward: Int
    let targetValue: Int
    
    var isUnlocked: Bool {
        return AchievementManager.shared.isUnlocked(id: id)
    }
    
    var isClaimed: Bool {
        return AchievementManager.shared.isClaimed(id: id)
    }
    
    var currentProgress: Int {
        return AchievementManager.shared.getProgress(for: self)
    }
    
    var progressRatio: CGFloat {
        guard targetValue > 0 else { return 0 }
        let progress = CGFloat(min(currentProgress, targetValue))
        return progress / CGFloat(targetValue)
    }
}
