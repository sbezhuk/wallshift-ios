//
//  GameScene+Input.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import SpriteKit

// MARK: - GameScene + Input Handling
extension GameScene {
    // MARK: - Input Handling (Tap to Jump)
    func handleTouchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let locInCamera = touch.location(in: cameraNode)
        
        // -1a. Взаємодія з відкритим вікном налаштувань (Settings)
        if let _ = settingsNode {
            handleSettingsTouchesBegan(touch: touch, locInCamera: locInCamera)
            return
        }
        
        // -1. Взаємодія з відкритим вікном досягнень
        if let _ = achievementsNode {
            let touchedNodes = cameraNode.nodes(at: locInCamera)
            for node in touchedNodes {
                let nodeName = node.name ?? node.parent?.name ?? ""
                
                if nodeName == "achievementsCloseButton" || nodeName == "achievementsDimBg" {
                    playJumpSound()
                    dismissAchievementsOverlay()
                    return
                }
                
                if nodeName == "achievementsPrevButton" {
                    playJumpSound()
                    currentAchievementsPage -= 1
                    renderAchievementsPage()
                    return
                }
                
                if nodeName == "achievementsNextButton" {
                    playJumpSound()
                    currentAchievementsPage += 1
                    renderAchievementsPage()
                    return
                }
                
                if nodeName.hasPrefix("claim_") {
                    let achId = String(nodeName.dropFirst(6))
                    handleClaimAchievement(id: achId)
                    return
                }
            }
            return
        }
        
        // 0. Взаємодія з відкритим вікном маркету/магазину
        if let shop = shopNode {
            let touchedNodes = cameraNode.nodes(at: locInCamera)
            for node in touchedNodes {
                let nodeName = node.name ?? node.parent?.name ?? ""
                
                if nodeName == "shopCloseButton" || nodeName == "shopDimBg" {
                    playJumpSound()
                    dismissShopOverlay()
                    return
                }
                
                if nodeName == "shopPrevButton" {
                    playJumpSound()
                    let count = ThemeManager.shared.themes.count
                    currentShopIndex = (currentShopIndex - 1 + count) % count
                    renderCurrentShopCard()
                    return
                }
                
                if nodeName == "shopNextButton" {
                    playJumpSound()
                    let count = ThemeManager.shared.themes.count
                    currentShopIndex = (currentShopIndex + 1) % count
                    renderCurrentShopCard()
                    return
                }
                
                if nodeName == "shopAdRewardButton" {
                    handleShopAdRewardTapped()
                    return
                }
                
                if nodeName == "shopActionButton" {
                    let themes = ThemeManager.shared.themes
                    guard currentShopIndex >= 0, currentShopIndex < themes.count else { return }
                    let theme = themes[currentShopIndex]
                    
                    // Якщо скін/тема вже вибрана — ігноруємо повторне натискання (не перебудовуємо карту)
                    guard theme.id != ThemeManager.shared.selectedThemeID else { return }
                    
                    if ThemeManager.shared.isUnlocked(theme) {
                        playJumpSound()
                        ThemeManager.shared.selectTheme(theme)
                        applyCurrentThemeToScene()
                        renderCurrentShopCard()
                    } else if ThemeManager.shared.canAfford(theme) {
                        playCoinSound()
                        ThemeManager.shared.buyTheme(theme)
                        playCoinPickupEffect(at: CGPoint(x: 0, y: -size.height * 0.15))
                        applyCurrentThemeToScene()
                        renderCurrentShopCard()
                        updateShopAdRewardButtonState()
                    } else {
                        // Не вистачає монет — похитування кнопки
                        if let card = shop.childNode(withName: "shopCard"),
                           let content = card.childNode(withName: "shopDynamicContent"),
                           let btn = content.childNode(withName: "shopActionButton") {
                            let wiggleLeft = SKAction.moveBy(x: -8.0, y: 0, duration: 0.05)
                            let wiggleRight = SKAction.moveBy(x: 16.0, y: 0, duration: 0.09)
                            let wiggleBack = SKAction.moveBy(x: -8.0, y: 0, duration: 0.05)
                            btn.run(SKAction.sequence([wiggleLeft, wiggleRight, wiggleBack]))
                        }
                    }
                    return
                }
            }
            return
        }
        
        // 1. Режим головного меню
        if gameState == .menu {
            let touchedNodes = cameraNode.nodes(at: locInCamera)
            for node in touchedNodes {
                let name = node.name ?? node.parent?.name ?? ""
                if name == "menuPlayButton" {
                    dismissMenuAndStartClimb()
                    return
                }
                if name == "menuShopButton" {
                    playJumpSound()
                    showShopOverlay()
                    return
                }
                if name == "menuAchievementsButton" || name == "menuAchievementsStarIcon" {
                    playJumpSound()
                    showAchievementsOverlay()
                    return
                }
                if name == "menuSoundButton" {
                    playJumpSound()
                    showSettingsOverlay()
                    return
                }
                if name == "menuExitButton" {
                    handleExitApp()
                    return
                }
            }
            
            // У меню гравець не тапає для зміни стіни — персонаж сам стрибає з інтервалом
            return
        }
        
        // 2. Меню анімовано зникає — ігноруємо тапи
        guard gameState != .starting else { return }
        
        // 3. Якщо гра закінчена, перевіряємо натискання на кнопки оверлею
        if gameState == .gameOver || isGameOver {
            let touchedNodes = cameraNode.nodes(at: locInCamera)
            for node in touchedNodes {
                if node.name == "adReviveButton" || node.parent?.name == "adReviveButton" {
                    handleAdReviveTapped()
                    return
                }
                if node.name == "adDoubleCoinsButton" || node.parent?.name == "adDoubleCoinsButton" {
                    handleAdDoubleCoinsTapped()
                    return
                }
                if node.name == "menuButton" || node.parent?.name == "menuButton" {
                    handleGameOverMenuTapped()
                    return
                }
                if node.name == "retryButton" || node.parent?.name == "retryButton" {
                    handleGameOverRetryTapped()
                    return
                }
            }
            return
        }
        
        // 4. Активний біг у грі
        guard !isPlayerFalling else { return }
        performJump()
    }
    
    func performJump() {
        guard !isGameOver, !isPlayerFalling else {
            hasBufferedJump = false
            return
        }
        
        // Якщо герой зараз у повітрі (в процесі стрибка) — буферизуємо тап,
        // щоб миттєво відштовхнутися від наступної стіни без втрати натискання
        if player.isJumping {
            hasBufferedJump = true
            bufferedJumpTimestamp = CACurrentMediaTime()
            return
        }
        
        // Якщо гравець знаходиться над прірвою — він не має твердої опори під ногами
        // і не може від неї відштовхнутися для стрибка (скидаємо буфер та зараховуємо потрапляння в прірву)
        if let abyss = checkAbyssUnderPlayer() {
            hasBufferedJump = false
            handleAbyssHit(abyss: abyss)
            return
        }
        
        hasBufferedJump = false
        
        // Відтворюємо звук стрибка
        playJumpSound()
        
        // Трекінг стрибків для досягнення Wall Hopper
        if gameState == .playing {
            runJumpsCount += 1
            AchievementManager.shared.trackRunProgress(
                score: score,
                runJumps: runJumpsCount,
                runCoins: coinsCollected,
                tookDamageThisRun: tookDamageThisRun,
                fellIntoAbyssThisRun: fellIntoAbyssThisRun,
                usedReviveThisRun: hasUsedAdRevive
            )
        }
        
        // Визначаємо цільову горизонтальну позицію (на протилежну стіну)
        let targetX: CGFloat = player.isOnLeftWall ? playerRightX : playerLeftX
        
        // Делегуємо виконання стрибка у PlayerNode з адаптивною тривалістю
        player.jump(to: targetX, duration: currentJumpDuration) { [weak self] in
            guard let self = self else { return }
            if self.gameState == .menu {
                self.player.setReadyStance()
                self.scheduleNextMenuAutoJump(delay: 2.0)
            } else if self.gameState == .starting {
                self.player.setReadyStance()
            } else if self.gameState == .playing {
                self.player.startRunningAnimation()
                
                // 1. Перевіряємо потрапляння у прірву при приземленні:
                // Якщо герой приземлився у розрив стіни (прірву) — відштовхнутися від неї неможливо!
                // Скидаємо буфер стрибка, зараховуємо шкоду (-1 життя) та запускаємо відновлення.
                if let abyss = self.checkAbyssUnderPlayer() {
                    self.hasBufferedJump = false
                    self.handleAbyssHit(abyss: abyss)
                    return
                }
                
                // 2. Перевіряємо приземлення або безпосереднє падіння на голову моба при завершенні стрибка
                if let mob = self.checkMobUnderPlayer() {
                    self.handleMobHit(mob: mob)
                }
                
                // 3. Перевіряємо наявність тапу в буфері введення (Input Buffer)
                let now = CACurrentMediaTime()
                if self.hasBufferedJump && (now - self.bufferedJumpTimestamp <= self.jumpBufferWindow) {
                    self.hasBufferedJump = false
                    self.performJump()
                } else {
                    self.hasBufferedJump = false
                }
            }
        }
    }
    
    func handleTouchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let locInCamera = touch.location(in: cameraNode)
        if let _ = settingsNode {
            handleSettingsTouchesMoved(touch: touch, locInCamera: locInCamera)
            return
        }
    }
    
    func handleTouchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let locInCamera = touch.location(in: cameraNode)
        if let _ = settingsNode {
            handleSettingsTouchesEnded(touch: touch, locInCamera: locInCamera)
            return
        }
    }
    
    func handleTouchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingMusicSlider = false
        isDraggingSFXSlider = false
    }
    

}
