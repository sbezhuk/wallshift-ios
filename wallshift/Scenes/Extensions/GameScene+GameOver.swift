//
//  GameScene+GameOver.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import SpriteKit

// MARK: - GameScene + Game Over & Revive
extension GameScene {
    // MARK: - Game Over & Abyss Fall
    
    /// Запуск ефекту падіння персонажа безпосередньо всередину прірви (у розрив стіни)
    func triggerAbyssFall(targetPoint: CGPoint?, reason: String) {
        guard !isPlayerFalling, !isGameOver else { return }
        hasBufferedJump = false
        isPlayerFalling = true
        
        // Відтворюємо звук закінчення гри
        playGameOverSound()
        stopBGM(fadeDuration: 2.0)
        
        print("Game Over: \(reason)")
        
        // Точка призначення — точно всередині отвору прірви між уступами скелі (куди вказує стрілка розриву)
        let destination = targetPoint ?? CGPoint(
            x: (player.position.x < size.width / 2.0) ? 10.0 : (size.width - 10.0),
            y: player.position.y
        )
        
        // Персонаж летить безпосередньо в чорний отвір між уступами скелі
        player.fallIntoAbyss(targetPoint: destination) { [weak self] in
            self?.completeGameOver(message: "Fell into the abyss")
        }
    }
    
    /// Фінальне завершення гри та показ оверлею
    func completeGameOver(message: String) {
        guard !isGameOver else { return }
        isGameOver = true
        gameState = .gameOver
        
        // Розрахунок тривалості забігу та перевірка нового рекорду для розумної реклами
        let runDuration = runStartTime > 0 ? max(0, CACurrentMediaTime() - runStartTime) : 0
        isNewHighScoreThisRun = (score > bestScore && score > 0)
        DynamicAdManager.shared.notifyRunCompleted(
            duration: runDuration,
            score: score,
            isNewHighScore: isNewHighScoreThisRun
        )
        
        // Фінальна перевірка досягнень за сесію та довгострокової статистики
        AchievementManager.shared.trackRunProgress(
            score: score,
            runJumps: runJumpsCount,
            runCoins: coinsCollected,
            tookDamageThisRun: tookDamageThisRun,
            fellIntoAbyssThisRun: fellIntoAbyssThisRun,
            usedReviveThisRun: hasUsedAdRevive,
            clutchScore: clutchScoreThisRun
        )
        AchievementManager.shared.completeRun(score: score, coins: coinsCollected, jumps: runJumpsCount)
        
        // Якщо звук ще не почав грати, запускаємо його
        playGameOverSound()
        stopBGM(fadeDuration: 1.5)
        
        showGameOverOverlay(subtitle: message)
        
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                self?.isPaused = true
            }
        ]))
    }
    
    func showGameOverOverlay(subtitle: String = "Fell into the abyss") {
        if score > bestScore {
            bestScore = score
        }
        
        let container = SKNode()
        container.zPosition = 100
        gameOverOverlayNode = container
        
        // Затемнюючий фон оверлею
        let bgDim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        bgDim.fillColor = SKColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 0.72)
        bgDim.strokeColor = .clear
        bgDim.position = .zero
        bgDim.zPosition = 1
        container.addChild(bgDim)
        
        // Головна діалогова картка (Box_Rounded)
        let dialogW = min(320.0, size.width - 40.0)
        let dialogH: CGFloat = 430.0
        let dialogCard = SKSpriteNode(imageNamed: "gui_card_box")
        dialogCard.size = CGSize(width: dialogW, height: dialogH)
        dialogCard.position = CGPoint(x: 0, y: 15.0)
        dialogCard.zPosition = 2
        container.addChild(dialogCard)
        
        // Червоний банер GAME OVER угорі картки (Banner_Red)
        let bannerW = min(260.0, dialogW - 20.0)
        let bannerH = bannerW * (457.0 / 1139.0)
        let redBanner = SKSpriteNode(imageNamed: "gui_banner_red")
        redBanner.size = CGSize(width: bannerW, height: bannerH)
        redBanner.position = CGPoint(x: 0, y: (dialogH / 2.0) - (bannerH * 0.45))
        redBanner.zPosition = 3
        dialogCard.addChild(redBanner)
        
        let titleShadow = SKLabelNode(fontNamed: AppFont.name)
        titleShadow.text = "GAME OVER"
        titleShadow.fontSize = 30.0
        titleShadow.fontColor = SKColor(red: 0.20, green: 0.04, blue: 0.04, alpha: 0.95)
        titleShadow.position = CGPoint(x: 1.5, y: -bannerH * 0.09)
        titleShadow.zPosition = 4
        redBanner.addChild(titleShadow)
        
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.text = "GAME OVER"
        titleLabel.fontSize = 30.0
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.06)
        titleLabel.zPosition = 5
        redBanner.addChild(titleLabel)
        
        let reasonLabel = SKLabelNode(fontNamed: AppFont.name)
        reasonLabel.text = subtitle
        reasonLabel.fontSize = 15.0
        reasonLabel.fontColor = SKColor(red: 0.95, green: 0.70, blue: 0.70, alpha: 1.0)
        reasonLabel.position = CGPoint(x: 0, y: 104.0)
        reasonLabel.zPosition = 3
        dialogCard.addChild(reasonLabel)
        
        // Картка результатів
        let statsW = dialogW - 40.0
        let statsH: CGFloat = 68.0
        let statsBar = SKSpriteNode(imageNamed: currentTheme.guiStatsBarName)
        statsBar.size = CGSize(width: statsW, height: statsH)
        statsBar.position = CGPoint(x: 0, y: 44.0)
        statsBar.zPosition = 3
        dialogCard.addChild(statsBar)
        
        let star = SKSpriteNode(imageNamed: currentTheme.guiStarIconName)
        star.name = "gameOverStarIcon"
        star.size = CGSize(width: 20.0, height: 20.0)
        star.position = CGPoint(x: -statsW * 0.38, y: 12.0)
        star.zPosition = 4
        statsBar.addChild(star)
        
        let scoreSummary = SKLabelNode(fontNamed: AppFont.name)
        scoreSummary.text = "SCORE: \(score.formattedWithSeparator)   BEST: \(bestScore.formattedWithSeparator)"
        scoreSummary.fontSize = 15.5
        scoreSummary.fontColor = currentTheme.guiStatsTextColor
        scoreSummary.horizontalAlignmentMode = .left
        scoreSummary.verticalAlignmentMode = .center
        scoreSummary.position = CGPoint(x: -statsW * 0.28, y: 12.0)
        scoreSummary.zPosition = 4
        statsBar.addChild(scoreSummary)
        
        let coin = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
        coin.size = CGSize(width: 20.0, height: 20.0)
        coin.position = CGPoint(x: -statsW * 0.38, y: -14.0)
        coin.zPosition = 4
        statsBar.addChild(coin)
        
        let coinsSummary = SKLabelNode(fontNamed: AppFont.name)
        coinsSummary.text = "COINS: +\(coinsCollected.formattedWithSeparator)   TOTAL: \(totalCoins.formattedWithSeparator)"
        coinsSummary.fontSize = 14.5
        coinsSummary.fontColor = currentTheme.guiStatsTextColor
        coinsSummary.horizontalAlignmentMode = .left
        coinsSummary.verticalAlignmentMode = .center
        coinsSummary.position = CGPoint(x: -statsW * 0.28, y: -14.0)
        coinsSummary.zPosition = 4
        statsBar.addChild(coinsSummary)
        self.gameOverCoinsSummaryLabel = coinsSummary
        self.gameOverDoubleCoinsBtn = nil
        self.gameOverDoubleCoinsLabel = nil
        
        let isOnline = NetworkMonitor.shared.isConnected
        let hasAdButton = isOnline && (!hasUsedAdRevive || (coinsCollected > 0 || hasUsedAdDoubleCoins))
        let retryBtnY: CGFloat = hasAdButton ? -86.0 : -42.0
        let menuBtnY: CGFloat = hasAdButton ? -144.0 : -104.0
        
        // Кнопка 1: Рекламна нагорода (1-й раз: REVIVE, 2-й раз: DOUBLE COINS 2X) — показується лише онлайн
        if isOnline && !hasUsedAdRevive {
            // Перший випадок: відродження з 1 життям за перегляд Unity Ads
            let reviveBtnW = dialogW - 50.0
            let reviveBtnH: CGFloat = 52.0
            let reviveBtn = SKSpriteNode(imageNamed: "gui_btn_large_green")
            reviveBtn.name = "adReviveButton"
            reviveBtn.size = CGSize(width: reviveBtnW, height: reviveBtnH)
            reviveBtn.position = CGPoint(x: 0, y: -26.0)
            reviveBtn.zPosition = 3
            dialogCard.addChild(reviveBtn)
            
            let heartIcon = SKSpriteNode(imageNamed: currentTheme.heartTextureName)
            heartIcon.name = "adReviveButton"
            heartIcon.size = CGSize(width: 22.0, height: 22.0)
            heartIcon.position = CGPoint(x: -reviveBtnW * 0.30, y: 0)
            heartIcon.zPosition = 4
            reviveBtn.addChild(heartIcon)
            
            let reviveLabel = SKLabelNode(fontNamed: AppFont.name)
            reviveLabel.name = "adReviveButton"
            reviveLabel.text = "REVIVE (+1 LIFE)"
            reviveLabel.fontSize = 17.0
            reviveLabel.fontColor = .white
            reviveLabel.verticalAlignmentMode = .center
            reviveLabel.horizontalAlignmentMode = .center
            reviveLabel.position = CGPoint(x: 12.0, y: 0)
            reviveLabel.zPosition = 4
            reviveBtn.addChild(reviveLabel)
        } else if isOnline && (coinsCollected > 0 || hasUsedAdDoubleCoins) {
            // Другий випадок: подвоєння зібраних за забіг монет (x2)
            let doubleBtnW = dialogW - 50.0
            let doubleBtnH: CGFloat = 52.0
            let doubleBtn = SKSpriteNode(imageNamed: hasUsedAdDoubleCoins ? "gui_btn_large_orange" : "gui_btn_large_green")
            doubleBtn.name = hasUsedAdDoubleCoins ? "adDoubleCoinsClaimed" : "adDoubleCoinsButton"
            doubleBtn.size = CGSize(width: doubleBtnW, height: doubleBtnH)
            doubleBtn.position = CGPoint(x: 0, y: -26.0)
            doubleBtn.zPosition = 3
            doubleBtn.alpha = hasUsedAdDoubleCoins ? 0.65 : 1.0
            dialogCard.addChild(doubleBtn)
            self.gameOverDoubleCoinsBtn = doubleBtn
            
            let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
            coinIcon.name = doubleBtn.name
            coinIcon.size = CGSize(width: 22.0, height: 22.0)
            coinIcon.position = CGPoint(x: -doubleBtnW * 0.30, y: 0)
            coinIcon.zPosition = 4
            doubleBtn.addChild(coinIcon)
            
            let doubleLabel = SKLabelNode(fontNamed: AppFont.name)
            doubleLabel.name = doubleBtn.name
            doubleLabel.text = hasUsedAdDoubleCoins ? "COINS DOUBLED (2X)!" : "DOUBLE COINS (2X)"
            doubleLabel.fontSize = 17.0
            doubleLabel.fontColor = .white
            doubleLabel.verticalAlignmentMode = .center
            doubleLabel.horizontalAlignmentMode = .center
            doubleLabel.position = CGPoint(x: 12.0, y: 0)
            doubleLabel.zPosition = 4
            doubleBtn.addChild(doubleLabel)
            self.gameOverDoubleCoinsLabel = doubleLabel
        }
        
        // Кнопка 2: PLAY AGAIN
        let retryBtnW = dialogW - 50.0
        let retryBtnH: CGFloat = 50.0
        let retryBtn = SKSpriteNode(imageNamed: currentTheme.guiPrimaryBtnName)
        retryBtn.name = "retryButton"
        retryBtn.size = CGSize(width: retryBtnW, height: retryBtnH)
        retryBtn.position = CGPoint(x: 0, y: retryBtnY)
        retryBtn.zPosition = 3
        dialogCard.addChild(retryBtn)
        
        let retryIcon = SKSpriteNode(imageNamed: "gui_icon_restart")
        retryIcon.name = "retryButton"
        retryIcon.size = CGSize(width: 20.0, height: 20.0)
        retryIcon.position = CGPoint(x: -retryBtnW * 0.28, y: 0)
        retryIcon.zPosition = 4
        retryBtn.addChild(retryIcon)
        
        let retryLabel = SKLabelNode(fontNamed: AppFont.name)
        retryLabel.name = "retryButton"
        retryLabel.text = "PLAY AGAIN"
        retryLabel.fontSize = 17.0
        retryLabel.fontColor = .white
        retryLabel.verticalAlignmentMode = .center
        retryLabel.horizontalAlignmentMode = .center
        retryLabel.position = CGPoint(x: 10.0, y: 0)
        retryLabel.zPosition = 4
        retryBtn.addChild(retryLabel)
        
        // Кнопка 3: MAIN MENU
        let menuBtnW = dialogW - 64.0
        let menuBtnH: CGFloat = 46.0
        let menuBtn = SKSpriteNode(imageNamed: currentTheme.guiSecondaryBtnName)
        menuBtn.name = "menuButton"
        menuBtn.size = CGSize(width: menuBtnW, height: menuBtnH)
        menuBtn.position = CGPoint(x: 0, y: menuBtnY)
        menuBtn.zPosition = 3
        dialogCard.addChild(menuBtn)
        
        let homeIcon = SKSpriteNode(imageNamed: "gui_icon_home")
        homeIcon.name = "menuButton"
        homeIcon.size = CGSize(width: 18.0, height: 18.0)
        homeIcon.position = CGPoint(x: -menuBtnW * 0.26, y: 0)
        homeIcon.zPosition = 4
        menuBtn.addChild(homeIcon)
        
        let menuLabel = SKLabelNode(fontNamed: AppFont.name)
        menuLabel.name = "menuButton"
        menuLabel.text = "MAIN MENU"
        menuLabel.fontSize = 16.0
        menuLabel.fontColor = .white
        menuLabel.verticalAlignmentMode = .center
        menuLabel.horizontalAlignmentMode = .center
        menuLabel.position = CGPoint(x: 8.0, y: 0)
        menuLabel.zPosition = 4
        menuBtn.addChild(menuLabel)
        
        // Додаємо до cameraNode, щоб напис завжди був по центру поточного огляду камери
        cameraNode.addChild(container)
    }
    
    /// Обробка натискання кнопки перегляду реклами Unity Ads для відродження (1-й раз)
    func handleAdReviveTapped() {
        guard isGameOver, !hasUsedAdRevive, NetworkMonitor.shared.isConnected else { return }
        guard let vc = view?.window?.rootViewController ?? view?.next as? UIViewController else { return }
        
        UnityAdsManager.shared.showRewardedAd(from: vc) { [weak self] in
            guard let self = self else { return }
            DynamicAdManager.shared.notifyRewardedAdWatched()
            self.hasUsedAdRevive = true
            self.revivePlayerWithOneHeart()
        } onFailed: { message in
            print("[GameScene] Revive ad was not completed: \(message)")
        }
    }
    
    /// Обробка натискання кнопки перегляду реклами Unity Ads для подвоєння монет (2-й раз)
    func handleAdDoubleCoinsTapped() {
        guard isGameOver, hasUsedAdRevive, !hasUsedAdDoubleCoins, coinsCollected > 0, NetworkMonitor.shared.isConnected else { return }
        guard let vc = view?.window?.rootViewController ?? view?.next as? UIViewController else { return }
        
        UnityAdsManager.shared.showRewardedAd(from: vc) { [weak self] in
            guard let self = self else { return }
            self.doubleCollectedCoins()
        } onFailed: { message in
            print("[GameScene] Double coins ad was not completed: \(message)")
        }
    }
    
    /// Подвоєння зібраних за забіг монет після перегляду реклами
    func doubleCollectedCoins() {
        guard !hasUsedAdDoubleCoins, coinsCollected > 0 else { return }
        hasUsedAdDoubleCoins = true
        DynamicAdManager.shared.notifyRewardedAdWatched()
        
        // Додаємо бонусні монети до загального балансу
        let bonus = coinsCollected
        totalCoins += bonus
        coinsCollected *= 2
        
        // Оновлюємо підсумок на оверлеї
        gameOverCoinsSummaryLabel?.text = "COINS: +\(coinsCollected.formattedWithSeparator) (2X!)   TOTAL: \(totalCoins.formattedWithSeparator)"
        
        // Переводимо кнопку у деактивований стан отриманої нагороди
        gameOverDoubleCoinsBtn?.name = "adDoubleCoinsClaimed"
        gameOverDoubleCoinsBtn?.alpha = 0.65
        gameOverDoubleCoinsLabel?.name = "adDoubleCoinsClaimed"
        gameOverDoubleCoinsLabel?.text = "COINS DOUBLED (2X)!"
        
        // Звуковий ефект нарахування монет
        playCoinSound()
    }
    
    /// Відродження персонажа з 1 серцем та процедурна перегенерація карти для чесного продовження забігу:
    /// Складність (швидкість руху, розміри прірв 5-6 тайлів, частота мобів, стрільці) залишається НЕЗМІННОЮ
    /// згідно з набраними очками гравця (якщо гравець програв на Hard / Elite — він продовжує на Hard / Elite).
    /// Проте безпосередня зона появи та коридор перед гравцем очищаються від миттєвих смертельних пасток:
    /// - Обидві стіни на ділянці старту гарантовано мають суцільні монолітні скелі без розривів.
    /// - Будь-які прірви під ногами або безпосередньо перед гравцем перетворюються на суцільну породу.
    /// - Усі ворожі моби та активні стріли поруч очищаються, даючи гравцю злітну смугу для реакції.
    /// - Наступні перешкоди (прірви та моби) процедурно спавняться відразу після безпечної смуги
    ///   за повноцінною складною формулою поточного рахунку.
    func revivePlayerWithOneHeart() {
        // 1. Прибираємо оверлей GameOver
        gameOverOverlayNode?.removeFromParent()
        gameOverOverlayNode = nil
        
        // 2. Розблоковуємо сцену та ігровий стан
        isPaused = false
        isGameOver = false
        isPlayerFalling = false
        hasPlayedGameOverSound = false
        gameState = .playing
        lastUpdateTime = 0
        lastAbyssHitTime = 0
        hasBufferedJump = false
        
        // 3. Встановлюємо 1 життя та оновлюємо HUD
        currentLives = 1
        updateHUD(animated: true)
        
        // 4. Очищаємо всі активні снаряди
        activeFireArrows.forEach { $0.removeFromParent() }
        activeFireArrows.removeAll()
        
        // 5. Розраховуємо висоту відродження героя
        let pY = cameraNode.position.y + playerCameraOffsetY
        
        // Знаходимо будь-які прірви, що торкаються або перетинають зону відродження гравця
        let overlappingAbysses = (leftAbyssNodes + rightAbyssNodes).filter { abyss in
            let abyssTop = abyss.position.y + (abyss.gapHeight / 2.0) + Config.tileSize
            return abyssTop >= (pY - 144.0)
        }
        let lowestAbyssBottom = overlappingAbysses.map {
            $0.position.y - ($0.gapHeight / 2.0) - Config.tileSize
        }.min() ?? (pY - 144.0)
        
        let targetCleanY = min(pY - 144.0, lowestAbyssBottom - Config.tileSize)
        let tileIndex = Int(floor((targetCleanY - (Config.tileSize / 2.0)) / Config.tileSize))
        let cleanStartY = CGFloat(tileIndex) * Config.tileSize + (Config.tileSize / 2.0)
        
        // 6. Очищаємо старі тайли стін, прірви, декорації та мобів від cleanStartY і вище
        leftTrackNodes.removeAll { node in
            if node.position.y >= cleanStartY - 5.0 {
                node.removeFromParent()
                return true
            }
            return false
        }
        rightTrackNodes.removeAll { node in
            if node.position.y >= cleanStartY - 5.0 {
                node.removeFromParent()
                return true
            }
            return false
        }
        leftAbyssNodes.removeAll { node in
            if (node.position.y + (node.gapHeight / 2.0)) >= cleanStartY - 5.0 {
                node.removeFromParent()
                return true
            }
            return false
        }
        rightAbyssNodes.removeAll { node in
            if (node.position.y + (node.gapHeight / 2.0)) >= cleanStartY - 5.0 {
                node.removeFromParent()
                return true
            }
            return false
        }
        trackMobNodes.removeAll { mob in
            if mob.pointBY >= cleanStartY - 100.0 {
                mob.removeFromParent()
                return true
            }
            return false
        }
        decorationNodes.removeAll { node in
            if node.position.y >= cleanStartY - 5.0 {
                node.removeFromParent()
                return true
            }
            return false
        }
        trackHeartNodes.removeAll { node in
            if node.position.y >= cleanStartY - 5.0 {
                node.removeFromParent()
                return true
            }
            return false
        }
        trackCoinNodes.removeAll { node in
            if node.position.y >= cleanStartY - 5.0 {
                node.removeFromParent()
                return true
            }
            return false
        }
        
        // 7. Створюємо гарантовану злітну смугу чистого бігу (обидві стіни 100% суцільні на ~540 pt вперед)
        currentLeftY = cleanStartY
        currentRightY = cleanStartY
        lastLeftDecoY = cleanStartY
        lastRightDecoY = cleanStartY
        let safeRunwayEndY = pY + 540.0
        
        while currentLeftY < safeRunwayEndY {
            let tile = createWallTile(texture: wallTexture, yPos: currentLeftY, isLeft: true)
            addChild(tile)
            leftTrackNodes.append(tile)
            currentLeftY += Config.tileSize
        }
        while currentRightY < safeRunwayEndY {
            let tile = createWallTile(texture: wallTexture, yPos: currentRightY, isLeft: false)
            addChild(tile)
            rightTrackNodes.append(tile)
            currentRightY += Config.tileSize
        }
        
        // 8. Відновлюємо процедурну генерацію за поточною формулою складності (Hard/Elite)
        // Наступні прірви та моби з'являться відразу після безпечної смуги відповідно до поточного рахунку
        nextAbyssIsOnLeft = Bool.random()
        consecutiveAbyssesOnSameWall = 1
        nextAbyssY = currentLeftY + randomAbyssDistance()
        nextMobY = currentLeftY + randomMobDistance()
        nextTreeBackgroundY = currentLeftY + 600.0
        nextHeartY = currentLeftY + randomHeartDistance()
        nextCoinPatternY = currentLeftY + 160.0
        
        // Добудовуємо каньйон наперед на 2.0 екрана вперед за поточними формулами складності
        buildTrack(upTo: cameraNode.position.y + (size.height * 2.0))
        
        // 9. Відроджуємо персонажа на гарантовано монолітній скелі
        let onLeft = player.isOnLeftWall
        let safeX = onLeft ? playerLeftX : playerRightX
        let safePos = CGPoint(x: safeX, y: pY)
        player.respawn(onLeftWall: onLeft, at: safePos)
        
        // 10. Візуальний ефект відновлення серця та фонова музика
        playHeartPickupEffect(at: safePos)
        startBGM(lowVolume: false)
    }
    
    // MARK: - Game Over Actions with Dynamic Interstitial
    
    func handleGameOverRetryTapped() {
        guard !isTransitioningScene else { return }
        isTransitioningScene = true
        playJumpSound()
        
        guard let vc = view?.window?.rootViewController ?? view?.next as? UIViewController else {
            restartGame()
            return
        }
        
        DynamicAdManager.shared.showInterstitialIfEligible(from: vc, isNewHighScore: isNewHighScoreThisRun) { [weak self] in
            self?.restartGame()
        }
    }
    
    func handleGameOverMenuTapped() {
        guard !isTransitioningScene else { return }
        isTransitioningScene = true
        playJumpSound()
        
        guard let vc = view?.window?.rootViewController ?? view?.next as? UIViewController else {
            goToMainMenu()
            return
        }
        
        DynamicAdManager.shared.showInterstitialIfEligible(from: vc, isNewHighScore: isNewHighScoreThisRun) { [weak self] in
            self?.goToMainMenu()
        }
    }
    
    func restartGame() {
        gameOverOverlayNode?.removeFromParent()
        gameOverOverlayNode = nil
        let newScene = GameScene(size: size, initialMode: .playing)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene)
    }
    
    func goToMainMenu() {
        gameOverOverlayNode?.removeFromParent()
        gameOverOverlayNode = nil
        let newScene = GameScene(size: size, initialMode: .menu)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene)
    }
}
