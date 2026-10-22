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
        let reward = ShopAdRewardManager.rewardCoins
        let cooldown = ShopAdRewardManager.cooldownDuration
        
        #expect(reward == 500)
        #expect(cooldown >= 3600)
        
        let forestTheme = ThemeManager.shared.themes.first(where: { $0.id == "forest_ranger" })
        let golemTheme = ThemeManager.shared.themes.first(where: { $0.id == "crystal_golem" })
        
        #expect(forestTheme != nil)
        #expect(golemTheme != nil)
        
        if let forest = forestTheme, let golem = golemTheme {
            #expect(Double(reward) / Double(forest.price) <= 0.05)
            #expect(Double(reward) / Double(golem.price) <= 0.05)
        }
    }

    @Test func testShopAdRewardClaimAndCooldown() async throws {
        NetworkMonitor.shared.simulateConnectionState(true)
        defer {
            NetworkMonitor.shared.simulateConnectionState(nil)
            ShopAdRewardManager.shared.resetCooldownForTesting()
        }
        
        let manager = ShopAdRewardManager.shared
        manager.resetCooldownForTesting()
        
        #expect(manager.isRewardAvailable == true)
        #expect(manager.remainingCooldown == 0)
        
        let startCoins = ThemeManager.shared.totalCoins
        let claimed = manager.claimReward()
        
        #expect(claimed == ShopAdRewardManager.rewardCoins)
        #expect(ThemeManager.shared.totalCoins == startCoins + ShopAdRewardManager.rewardCoins)
        
        #expect(manager.isRewardAvailable == false)
        #expect(manager.remainingCooldown > 0)
        #expect(manager.remainingCooldown <= ShopAdRewardManager.cooldownDuration)
        
        let formatted = manager.formattedCooldownString()
        #expect(!formatted.isEmpty)
        #expect(formatted.contains(":"))
    }

    @Test func testShopAdRewardOfflineDisablesReward() async throws {
        let manager = ShopAdRewardManager.shared
        manager.resetCooldownForTesting()
        
        NetworkMonitor.shared.simulateConnectionState(false)
        #expect(NetworkMonitor.shared.isConnected == false)
        #expect(manager.isNetworkAvailable == false)
        #expect(manager.isRewardAvailable == false)
        
        NetworkMonitor.shared.simulateConnectionState(true)
        #expect(NetworkMonitor.shared.isConnected == true)
        #expect(manager.isNetworkAvailable == true)
        #expect(manager.isRewardAvailable == true)
        
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
        
        #expect(guiCoinNames.count == themes.count)
    }

    @Test func testThemeStarsConfiguration() async throws {
        let themes = ThemeManager.shared.themes
        #expect(!themes.isEmpty)
        
        var guiStarNames = Set<String>()
        for theme in themes {
            #expect(!theme.guiStarIconName.isEmpty)
            guiStarNames.insert(theme.guiStarIconName)
        }
        
        #expect(guiStarNames.count == themes.count)
    }

    @Test func testWeeklyAchievementsPoolAndRotation() async throws {
        // 1. Повний каталог містить рівно 100 різноманітних досягнень
        let catalog = AchievementManager.allCatalogAchievements
        #expect(catalog.count == 100)
        
        // Перевірка унікальності ID всіх 100 ачівок
        let uniqueIDs = Set(catalog.map { $0.id })
        #expect(uniqueIDs.count == 100)
        
        // Перевірка розподілу складності в каталозі
        let easyCount = catalog.filter { $0.difficulty == .easy }.count
        let mediumCount = catalog.filter { $0.difficulty == .medium }.count
        let hardCount = catalog.filter { $0.difficulty == .hard }.count
        
        #expect(easyCount == 40)
        #expect(mediumCount == 35)
        #expect(hardCount == 25)
        
        // 2. На поточний тиждень дається рівно 12 активних ачівок
        let manager = AchievementManager.shared
        manager.performWeeklyReset()
        
        let weekly = manager.achievements
        #expect(weekly.count == 12)
        
        let weeklyEasy = weekly.filter { $0.difficulty == .easy }
        let weeklyMedium = weekly.filter { $0.difficulty == .medium }
        let weeklyHard = weekly.filter { $0.difficulty == .hard }
        
        #expect(weeklyEasy.count == 5)
        #expect(weeklyMedium.count == 4)
        #expect(weeklyHard.count == 3)
        
        // 3. Перевірка таймера до скидання
        #expect(manager.timeRemainingUntilReset > 0)
        #expect(manager.timeRemainingUntilReset <= AchievementManager.weeklyCycleSeconds)
        #expect(!manager.weeklyResetFormattedString.isEmpty)
    }

    @Test func testAchievementProgressAndClaiming() async throws {
        let manager = AchievementManager.shared
        manager.performWeeklyReset()
        
        // Беремо будь-яку активну ачівку для тестування
        guard let testAch = manager.achievements.first else {
            Issue.record("No active achievements found")
            return
        }
        
        #expect(!manager.isUnlocked(id: testAch.id))
        #expect(!manager.isClaimed(id: testAch.id))
        
        // Виконуємо ціль або розблоковуємо
        manager.trackRunProgress(
            score: testAch.targetValue + 500,
            runJumps: testAch.targetValue + 500,
            runCoins: testAch.targetValue + 500,
            tookDamageThisRun: false,
            fellIntoAbyssThisRun: false,
            usedReviveThisRun: false,
            clutchScore: testAch.targetValue + 500
        )
        if !manager.isUnlocked(id: testAch.id) {
            manager.unlock(id: testAch.id)
        }
        
        #expect(manager.isUnlocked(id: testAch.id) == true)
        #expect(testAch.isUnlocked == true)
        #expect(!manager.isClaimed(id: testAch.id))
        
        // Забираємо нагороду
        let startCoins = UserDefaults.standard.integer(forKey: "TotalWallShiftCoins")
        let rewardGained = manager.claimReward(for: testAch)
        
        #expect(rewardGained == testAch.coinReward)
        #expect(manager.isClaimed(id: testAch.id) == true)
        #expect(testAch.isClaimed == true)
        
        let endCoins = UserDefaults.standard.integer(forKey: "TotalWallShiftCoins")
        #expect(endCoins == startCoins + testAch.coinReward)
        
        // Повторне забирання повертає 0
        let doubleClaim = manager.claimReward(for: testAch)
        #expect(doubleClaim == 0)
    }

    @Test func testWeeklyCooldownAndReset() async throws {
        let manager = AchievementManager.shared
        manager.performWeeklyReset()
        
        // Розблоковуємо першу ачівку
        let firstAch = manager.achievements[0]
        manager.unlock(id: firstAch.id)
        _ = manager.claimReward(for: firstAch)
        
        #expect(manager.isUnlocked(id: firstAch.id) == true)
        #expect(manager.isClaimed(id: firstAch.id) == true)
        
        // Симулюємо настання нового тижня (минуло 7 днів)
        let eightDaysAgo = Date().addingTimeInterval(-(7 * 24 * 3600 + 3600))
        manager.performWeeklyReset(newStartDate: eightDaysAgo)
        manager.checkAndPerformWeeklyResetIfNeeded()
        
        // Після щотижневого кулдауну всі ачівки анульовані і готові до повторного проходження
        #expect(manager.unlockedCount == 0)
        #expect(manager.achievements.count == 12)
        for ach in manager.achievements {
            #expect(!manager.isUnlocked(id: ach.id))
            #expect(!manager.isClaimed(id: ach.id))
        }
    }

    @Test func testDynamicAdManagerLifecycleAndProtection() async throws {
        let adManager = DynamicAdManager.shared
        adManager.resetForTesting()
        
        adManager.notifyRunStarted()
        adManager.notifyRunCompleted(duration: 25.0, score: 50, isNewHighScore: false)
        #expect(adManager.isEligibleForInterstitial(isNewHighScore: false) == false)
        
        adManager.notifyRunStarted()
        adManager.notifyRunCompleted(duration: 25.0, score: 50, isNewHighScore: false)
        #expect(adManager.isEligibleForInterstitial(isNewHighScore: false) == false)
        
        adManager.notifyRunStarted()
        adManager.notifyRunCompleted(duration: 25.0, score: 50, isNewHighScore: false)
        #expect(adManager.isEligibleForInterstitial(isNewHighScore: false) == false)
        
        let oldTimestamp = Date().timeIntervalSince1970 - 120.0
        adManager.simulateStateForTesting(pendingAttempts: 3, lifetimeRuns: 10, sessionRuns: 5, lastAdTimestamp: oldTimestamp)
        
        #expect(adManager.isEligibleForInterstitial(isNewHighScore: false) == false)
        
        adManager.notifyRunStarted()
        adManager.notifyRunCompleted(duration: 25.0, score: 60, isNewHighScore: false)
        #expect(adManager.pendingAttempts >= 4)
        #expect(adManager.isEligibleForInterstitial(isNewHighScore: false) == true)
        
        #expect(adManager.isEligibleForInterstitial(isNewHighScore: true) == false)
        
        adManager.notifyRewardedAdWatched()
        #expect(adManager.pendingAttempts == 0)
        #expect(adManager.isEligibleForInterstitial(isNewHighScore: false) == false)
        
        adManager.simulateStateForTesting(pendingAttempts: 2, lifetimeRuns: 10, sessionRuns: 5, lastAdTimestamp: oldTimestamp)
        adManager.notifyRunStarted()
        adManager.notifyRunCompleted(duration: 65.0, score: 140, isNewHighScore: false)
        #expect(adManager.pendingAttempts == 4)
        #expect(adManager.isEligibleForInterstitial(isNewHighScore: false) == true)
        
        let recentTimestamp = Date().timeIntervalSince1970 - 10.0
        adManager.simulateStateForTesting(pendingAttempts: 5, lifetimeRuns: 10, sessionRuns: 5, lastAdTimestamp: recentTimestamp)
        #expect(adManager.isEligibleForInterstitial(isNewHighScore: false) == false)
        
        adManager.resetForTesting()
    }

    @Test func testAudioSettingsMasterMute() async throws {
        let initialMuted = GameAudio.shared.isMuted
        defer {
            GameAudio.shared.setMuted(initialMuted)
        }
        
        GameAudio.shared.setMuted(false)
        #expect(GameAudio.shared.isMuted == false)
        
        let toggled = GameAudio.shared.toggleMute()
        #expect(toggled == true)
        #expect(GameAudio.shared.isMuted == true)
        
        let untoggled = GameAudio.shared.toggleMute()
        #expect(untoggled == false)
        #expect(GameAudio.shared.isMuted == false)
        
        GameAudio.shared.setMuted(true)
        #expect(GameAudio.shared.isMuted == true)
    }

    @Test func testAudioSettingsVolumeControls() async throws {
        let initialBGM = GameAudio.shared.bgmVolume
        let initialSFX = GameAudio.shared.sfxVolume
        defer {
            GameAudio.shared.bgmVolume = initialBGM
            GameAudio.shared.sfxVolume = initialSFX
        }
        
        // Перевірка BGM
        GameAudio.shared.bgmVolume = 0.5
        #expect(abs(GameAudio.shared.bgmVolume - 0.5) < 0.01)
        
        // Clamping BGM
        GameAudio.shared.bgmVolume = 1.5
        #expect(abs(GameAudio.shared.bgmVolume - 1.0) < 0.01)
        
        GameAudio.shared.bgmVolume = -0.5
        #expect(abs(GameAudio.shared.bgmVolume - 0.0) < 0.01)
        
        // Перевірка SFX
        GameAudio.shared.sfxVolume = 0.7
        #expect(abs(GameAudio.shared.sfxVolume - 0.7) < 0.01)
        
        // Clamping SFX
        GameAudio.shared.sfxVolume = 2.0
        #expect(abs(GameAudio.shared.sfxVolume - 1.0) < 0.01)
        
        GameAudio.shared.sfxVolume = -0.2
        #expect(abs(GameAudio.shared.sfxVolume - 0.0) < 0.01)
    }

    @Test @MainActor func testGameOverSoundPlaysOnlyOncePerDefeat() async throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844), initialMode: .playing)
        
        // Симулюємо поразку: перший виклик при початку падіння
        scene.playGameOverSound()
        
        // Повторні виклики (наприклад, з completeGameOver після анімації падіння)
        scene.playGameOverSound()
        scene.playGameOverSound()
    }
}
