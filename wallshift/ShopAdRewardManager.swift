//
//  ShopAdRewardManager.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import Foundation

final class ShopAdRewardManager {
    static let shared = ShopAdRewardManager()
    
    // MARK: - Game Economy & Balance Settings
    /// Кількість монет за один перегляд відеореклами в магазині.
    /// Збалансовано: 500 монет (відповідає цінам скінів 25 000 / 50 000 і дає відчутну винагороду)
    static let rewardCoins: Int = 500
    
    /// Інтервал перезарядки (раз на N час): 2 години (7200 секунд)
    /// Дозволяє гравцеві переглядати рекламу 3-4 рази на день, мотивуючи повертатися до гри.
    static let cooldownDuration: TimeInterval = 2 * 60 * 60
    
    // MARK: - Storage Keys
    private let lastClaimTimestampKey = "WallShiftShopAdLastClaimTimestamp"
    
    private init() {}
    
    // MARK: - Properties
    
    /// Дата останнього отримання безкоштовних монет за рекламу
    var lastClaimDate: Date? {
        let ts = UserDefaults.standard.double(forKey: lastClaimTimestampKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }
    
    /// Залишок часу кулдауну в секундах
    var remainingCooldown: TimeInterval {
        guard let lastDate = lastClaimDate else { return 0 }
        let now = Date()
        let elapsed = now.timeIntervalSince(lastDate)
        
        // Захист від маніпуляцій з системним часом (переведення годинника назад)
        if elapsed < 0 {
            return Self.cooldownDuration
        }
        
        let remaining = Self.cooldownDuration - elapsed
        return max(0, remaining)
    }
    
    /// Чи готова нагорода до отримання прямо зараз
    var isRewardAvailable: Bool {
        return isNetworkAvailable && remainingCooldown <= 0
    }
    
    /// Чи доступний інтернет для показу реклами
    var isNetworkAvailable: Bool {
        return NetworkMonitor.shared.isConnected
    }
    
    // MARK: - Actions
    
    /// Зарахування нагороди після успішного перегляду відеореклами
    @discardableResult
    func claimReward() -> Int {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastClaimTimestampKey)
        ThemeManager.shared.totalCoins += Self.rewardCoins
        DynamicAdManager.shared.notifyRewardedAdWatched()
        print("[ShopAdRewardManager] Claimed \(Self.rewardCoins) coins! New total: \(ThemeManager.shared.totalCoins)")
        return Self.rewardCoins
    }
    
    /// Форматований рядок таймера: "01:45:20" (якщо > 1 год) або "45:20" (якщо < 1 год)
    func formattedCooldownString() -> String {
        let totalSeconds = max(0, Int(ceil(remainingCooldown)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Текстовий опис для підказки користувачеві
    func cooldownDescriptionString() -> String {
        let totalSeconds = max(0, Int(ceil(remainingCooldown)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(max(1, minutes))m"
        }
    }
    
    #if DEBUG
    /// Скидання кулдауну для швидкого тестування розробником
    func resetCooldownForTesting() {
        UserDefaults.standard.removeObject(forKey: lastClaimTimestampKey)
    }
    #endif
}
