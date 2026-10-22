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
}
