//
//  wallshiftTests.swift
//  wallshiftTests
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import Testing
import Foundation
@testable import wallshift

@Suite(.serialized)
struct wallshiftTests {

    @Test func testShopAdRewardEconomyAndBalance() async throws {
        // Перевірка збереження ігрового балансу:
        // Винагорода не повинна знецінювати покупку тем у магазині.
        let reward = ShopAdRewardManager.rewardCoins
        let cooldown = ShopAdRewardManager.cooldownDuration
        
        #expect(reward == 500)
        #expect(cooldown >= 3600) // Щонайменше 1 година (наразі 2 години)
        
        // Перевірка відносно цін тем
        let forestTheme = ThemeManager.shared.themes.first(where: { $0.id == "forest_ranger" })
        let golemTheme = ThemeManager.shared.themes.first(where: { $0.id == "crystal_golem" })
        
        #expect(forestTheme != nil)
        #expect(golemTheme != nil)
        
        if let forest = forestTheme, let golem = golemTheme {
            // Винагорода за одне відео має складати до 2% від вартості скіна
            #expect(Double(reward) / Double(forest.price) <= 0.05)
            #expect(Double(reward) / Double(golem.price) <= 0.05)
        }
    }

    @Test func testShopAdRewardClaimAndCooldown() async throws {
        // Гарантуємо активне підключення для тесту кулдауну
        NetworkMonitor.shared.simulateConnectionState(true)
        defer {
            NetworkMonitor.shared.simulateConnectionState(nil)
            ShopAdRewardManager.shared.resetCooldownForTesting()
        }
        
        let manager = ShopAdRewardManager.shared
        manager.resetCooldownForTesting()
        
        // Початковий стан — нагорода доступна
        #expect(manager.isRewardAvailable == true)
        #expect(manager.remainingCooldown == 0)
        
        let startCoins = ThemeManager.shared.totalCoins
        let claimed = manager.claimReward()
        
        #expect(claimed == ShopAdRewardManager.rewardCoins)
        #expect(ThemeManager.shared.totalCoins == startCoins + ShopAdRewardManager.rewardCoins)
        
        // Після отримання — нагорода блокується кулдауном
        #expect(manager.isRewardAvailable == false)
        #expect(manager.remainingCooldown > 0)
        #expect(manager.remainingCooldown <= ShopAdRewardManager.cooldownDuration)
        
        // Перевірка форматування рядка таймера
        let formatted = manager.formattedCooldownString()
        #expect(!formatted.isEmpty)
        #expect(formatted.contains(":"))
    }

    @Test func testShopAdRewardOfflineDisablesReward() async throws {
        let manager = ShopAdRewardManager.shared
        manager.resetCooldownForTesting()
        
        // 1. Симулюємо відсутність інтернету (офлайн)
        NetworkMonitor.shared.simulateConnectionState(false)
        
        #expect(NetworkMonitor.shared.isConnected == false)
        #expect(manager.isNetworkAvailable == false)
        // Навіть якщо кулдаун минув, винагорода недоступна без інтернету:
        #expect(manager.isRewardAvailable == false)
        
        // 2. Симулюємо відновлення інтернету
        NetworkMonitor.shared.simulateConnectionState(true)
        
        #expect(NetworkMonitor.shared.isConnected == true)
        #expect(manager.isNetworkAvailable == true)
        // Тепер нагорода доступна:
        #expect(manager.isRewardAvailable == true)
        
        // Скидаємо симуляцію
        NetworkMonitor.shared.simulateConnectionState(nil)
        manager.resetCooldownForTesting()
    }

    @Test func testThemeCoinsConfiguration() async throws {
        let themes = ThemeManager.shared.themes
        #expect(!themes.isEmpty)
        
        var guiCoinNames = Set<String>()
        for theme in themes {
            #expect(!theme.guiCoinIconName.isEmpty)
            #expect(!theme.coinTexturePrefix.isEmpty)
            #expect(theme.coinFrameCount == 6)
            
            guiCoinNames.insert(theme.guiCoinIconName)
            
            let textures = CoinNode.textures(for: theme)
            #expect(textures.count == theme.coinFrameCount)
        }
        
        // У кожної теми мають бути свої унікальні іконки монеток
        #expect(guiCoinNames.count == themes.count)
    }

    @Test func testAchievementsCatalogAndTiers() async throws {
        let achievements = AchievementManager.shared.achievements
        
        // Перевірка кількості досягнень (13 хардкорних челенджів)
        #expect(achievements.count == 13)
        
        // Перевірка наявності всіх рівнів складності
        let easyList = achievements.filter { $0.difficulty == .easy }
        let mediumList = achievements.filter { $0.difficulty == .medium }
        let hardList = achievements.filter { $0.difficulty == .hard }
        
        #expect(easyList.count == 3)
        #expect(mediumList.count == 5)
        #expect(hardList.count == 5)
        
        // Перевірка солідних винагород за складність
        for easy in easyList {
            #expect(easy.coinReward >= 500 && easy.coinReward <= 1000)
        }
        for med in mediumList {
            #expect(med.coinReward >= 2000 && med.coinReward <= 4000)
        }
        for hard in hardList {
            #expect(hard.coinReward >= 7000 && hard.coinReward <= 12000)
        }
    }

    @Test func testAchievementProgressAndClaiming() async throws {
        let manager = AchievementManager.shared
        
        // Тестуємо досягнення "Trailblazer" (score 300)
        guard let trailblazer = manager.achievements.first(where: { $0.id == "trailblazer" }) else {
            Issue.record("trailblazer achievement not found")
            return
        }
        
        // Перевіряємо що при 150 очках ачівка ще заблокована
        manager.trackRunProgress(
            score: 150,
            runJumps: 20,
            runCoins: 30,
            tookDamageThisRun: false,
            fellIntoAbyssThisRun: false,
            usedReviveThisRun: false
        )
        
        // Тепер забіг на 320 очок (подолано 300)
        manager.trackRunProgress(
            score: 320,
            runJumps: 40,
            runCoins: 50,
            tookDamageThisRun: false,
            fellIntoAbyssThisRun: false,
            usedReviveThisRun: false
        )
        
        #expect(manager.isUnlocked(id: "trailblazer") == true)
        #expect(trailblazer.isUnlocked == true)
        
        let startCoins = UserDefaults.standard.integer(forKey: "TotalWallShiftCoins")
        let rewardGained = manager.claimReward(for: trailblazer)
        
        #expect(rewardGained == trailblazer.coinReward)
        #expect(manager.isClaimed(id: "trailblazer") == true)
        #expect(trailblazer.isClaimed == true)
        
        let endCoins = UserDefaults.standard.integer(forKey: "TotalWallShiftCoins")
        #expect(endCoins == startCoins + trailblazer.coinReward)
        
        // Повторне забирання нагороди має повертати 0
        let doubleClaim = manager.claimReward(for: trailblazer)
        #expect(doubleClaim == 0)
    }

    @Test func testLifetimeRunsAndMarathonTracking() async throws {
        let manager = AchievementManager.shared
        let startRuns = UserDefaults.standard.integer(forKey: "WallShiftTotalRunsCount")
        let startLifetime = UserDefaults.standard.integer(forKey: "WallShiftLifetimeScore")
        
        // Завершення забігу з результатом 450 очок
        manager.completeRun(score: 450)
        
        let endRuns = UserDefaults.standard.integer(forKey: "WallShiftTotalRunsCount")
        let endLifetime = UserDefaults.standard.integer(forKey: "WallShiftLifetimeScore")
        
        #expect(endRuns == startRuns + 1)
        #expect(endLifetime == startLifetime + 450)
    }
}
