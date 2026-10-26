//
//  GameScene+Menu.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import SpriteKit

// MARK: - GameScene + Seamless Menu
extension GameScene {
    // MARK: - In-Scene Seamless Main Menu
    
    /// Автоматичний періодичний стрибок героя між стінами під час перебування у головному меню
    func scheduleNextMenuAutoJump(delay: TimeInterval = 2.0) {
        removeAction(forKey: "menuAutoJump")
        guard gameState == .menu else { return }
        
        let wait = SKAction.wait(forDuration: delay)
        let jump = SKAction.run { [weak self] in
            guard let self = self, self.gameState == .menu, !self.player.isJumping else { return }
            self.performJump()
        }
        run(SKAction.sequence([wait, jump]), withKey: "menuAutoJump")
    }
    
    /// Відображення GUI головного меню безпосередньо поверх живого рівня
    func showMainMenu(animated: Bool = false) {
        menuNode?.removeFromParent()
        removeAction(forKey: "menuAutoJump")
        
        gameState = .menu
        isGameOver = false
        hudNode.alpha = 1.0
        hudNode.isHidden = true
        player.setReadyStance()
        
        // Запускаємо перший автоматичний стрибок через 1.8 с
        scheduleNextMenuAutoJump(delay: 1.8)
        
        let container = SKNode()
        container.zPosition = 150
        menuNode = container
        cameraNode.addChild(container)
        
        // 1. Логотип WALLSHIFT (на помаранчевому банері)
        let titleContainer = SKNode()
        titleContainer.name = "menuTitle"
        titleContainer.position = CGPoint(x: 0, y: size.height * 0.24)
        titleContainer.zPosition = 5
        container.addChild(titleContainer)
        
        let bannerW = min(310.0, size.width - 50.0)
        let bannerH = bannerW * (457.0 / 1139.0)
        let banner = SKSpriteNode(imageNamed: currentTheme.guiBannerName)
        banner.name = "menuBanner"
        banner.size = CGSize(width: bannerW, height: bannerH)
        banner.position = .zero
        banner.zPosition = 1
        titleContainer.addChild(banner)
        
        let shadowLabel = SKLabelNode(fontNamed: AppFont.name)
        shadowLabel.name = "menuBannerShadow"
        shadowLabel.text = "WALLSHIFT"
        shadowLabel.fontSize = min(46.0, size.width * 0.115)
        shadowLabel.fontColor = currentTheme.guiBannerShadowColor
        shadowLabel.position = CGPoint(x: 1.5, y: -bannerH * 0.08)
        shadowLabel.zPosition = 2
        titleContainer.addChild(shadowLabel)
        
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.text = "WALLSHIFT"
        titleLabel.fontSize = min(46.0, size.width * 0.115)
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.05)
        titleLabel.zPosition = 3
        titleContainer.addChild(titleLabel)
        
        let floatUp = SKAction.moveBy(x: 0, y: 4.0, duration: 1.8)
        let floatDown = SKAction.moveBy(x: 0, y: -4.0, duration: 1.8)
        floatUp.timingMode = .easeInEaseOut
        floatDown.timingMode = .easeInEaseOut
        titleContainer.run(SKAction.repeatForever(SKAction.sequence([floatUp, floatDown])))
        
        // 2. Картка статистики (Best Score & Coins) із GUI Bundle
        let cardW: CGFloat = min(280.0, size.width - 70.0)
        let cardH: CGFloat = 54.0
        let card = SKSpriteNode(imageNamed: currentTheme.guiStatsBarName)
        card.name = "menuCard"
        card.size = CGSize(width: cardW, height: cardH)
        card.position = CGPoint(x: 0, y: size.height * 0.08)
        card.zPosition = 5
        container.addChild(card)
        
        let starIcon = SKSpriteNode(imageNamed: currentTheme.guiStarIconName)
        starIcon.name = "menuStarIcon"
        starIcon.size = CGSize(width: 22.0, height: 22.0)
        starIcon.position = CGPoint(x: -cardW * 0.36, y: 0.0)
        starIcon.zPosition = 2
        card.addChild(starIcon)
        
        let bestScoreText = SKLabelNode(fontNamed: AppFont.name)
        bestScoreText.name = "menuBestScoreText"
        bestScoreText.text = "BEST: \(bestScore.formattedWithSeparator)"
        bestScoreText.fontSize = 16.0
        bestScoreText.fontColor = currentTheme.guiStatsTextColor
        bestScoreText.horizontalAlignmentMode = .left
        bestScoreText.verticalAlignmentMode = .center
        bestScoreText.position = CGPoint(x: -cardW * 0.26, y: 0.0)
        bestScoreText.zPosition = 2
        card.addChild(bestScoreText)
        
        let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
        coinIcon.name = "menuCoinsIcon"
        coinIcon.size = CGSize(width: 22.0, height: 22.0)
        coinIcon.position = CGPoint(x: cardW * 0.12, y: 0.0)
        coinIcon.zPosition = 2
        card.addChild(coinIcon)
        
        let coinsText = SKLabelNode(fontNamed: AppFont.name)
        coinsText.name = "menuCoinsText"
        coinsText.text = totalCoins.formattedWithSeparator
        coinsText.fontSize = 16.0
        coinsText.fontColor = currentTheme.guiStatsTextColor
        coinsText.horizontalAlignmentMode = .left
        coinsText.verticalAlignmentMode = .center
        coinsText.position = CGPoint(x: cardW * 0.21, y: 0.0)
        coinsText.zPosition = 2
        card.addChild(coinsText)
        self.menuCoinsText = coinsText
        
        // 3. Кнопка START GAME із GUI Bundle
        let btnW: CGFloat = min(250.0, size.width - 80.0)
        let btnH: CGFloat = 66.0
        let playBtn = SKSpriteNode(imageNamed: currentTheme.guiPrimaryBtnName)
        playBtn.name = "menuPlayButton"
        playBtn.size = CGSize(width: btnW, height: btnH)
        playBtn.position = CGPoint(x: 0, y: -size.height * 0.045)
        playBtn.zPosition = 5
        container.addChild(playBtn)
        
        let playArrow = SKSpriteNode(imageNamed: "gui_icon_play")
        playArrow.name = "menuPlayButton"
        playArrow.size = CGSize(width: 22.0, height: 22.0)
        playArrow.position = CGPoint(x: -btnW * 0.30, y: 1.0)
        playArrow.zPosition = 2
        playBtn.addChild(playArrow)
        
        let playLabel = SKLabelNode(fontNamed: AppFont.name)
        playLabel.name = "menuPlayButton"
        playLabel.text = "START GAME"
        playLabel.fontSize = 23.0
        playLabel.fontColor = .white
        playLabel.verticalAlignmentMode = .center
        playLabel.horizontalAlignmentMode = .center
        playLabel.position = CGPoint(x: 8.0, y: 1.0)
        playLabel.zPosition = 2
        playBtn.addChild(playLabel)
        
        let pulseUp = SKAction.scale(to: 1.04, duration: 0.85)
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.85)
        pulseUp.timingMode = .easeInEaseOut
        pulseDown.timingMode = .easeInEaseOut
        playBtn.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))
        
        // 4. Кнопка МАРКЕТ із Basic_GUI_Bundle
        let shopBtnW: CGFloat = min(220.0, size.width - 90.0)
        let shopBtnH: CGFloat = 56.0
        let shopBtn = SKSpriteNode(imageNamed: currentTheme.guiSecondaryBtnName)
        shopBtn.name = "menuShopButton"
        shopBtn.size = CGSize(width: shopBtnW, height: shopBtnH)
        shopBtn.position = CGPoint(x: 0, y: -size.height * 0.165)
        shopBtn.zPosition = 5
        container.addChild(shopBtn)
        
        let shopIcon = SKSpriteNode(imageNamed: "gui_icon_shop")
        shopIcon.name = "menuShopButton"
        shopIcon.size = CGSize(width: 24.0, height: 24.0)
        shopIcon.position = CGPoint(x: -shopBtnW * 0.28, y: 1.0)
        shopIcon.zPosition = 2
        shopBtn.addChild(shopIcon)
        
        let shopLabel = SKLabelNode(fontNamed: AppFont.name)
        shopLabel.name = "menuShopButton"
        shopLabel.text = "MARKET"
        shopLabel.fontSize = 21.0
        shopLabel.fontColor = .white
        shopLabel.verticalAlignmentMode = .center
        shopLabel.horizontalAlignmentMode = .center
        shopLabel.position = CGPoint(x: 12.0, y: 1.0)
        shopLabel.zPosition = 2
        shopBtn.addChild(shopLabel)
        
        // 5. Кнопка звуку із GUI Bundle (гучність вкл/викл)
        let soundBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        soundBtn.name = "menuSoundButton"
        soundBtn.size = CGSize(width: 48.0, height: 48.0)
        soundBtn.position = CGPoint(
            x: (size.width / 2.0) - 44.0,
            y: (size.height / 2.0) - 58.0
        )
        soundBtn.zPosition = 10
        container.addChild(soundBtn)
        
        let iconName = isMuted ? "gui_icon_audio_off" : "gui_icon_audio_on"
        let soundIcon = SKSpriteNode(imageNamed: iconName)
        soundIcon.name = "menuSoundButton"
        soundIcon.size = CGSize(width: 26.0, height: 26.0)
        soundIcon.position = .zero
        soundIcon.zPosition = 2
        soundBtn.addChild(soundIcon)
        self.soundIconSprite = soundIcon
        
        // 5b. Кнопка досягнень із зіркою (симетрично до кнопки звуку вгорі ліворуч)
        let achBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        achBtn.name = "menuAchievementsButton"
        achBtn.size = CGSize(width: 48.0, height: 48.0)
        achBtn.position = CGPoint(
            x: -(size.width / 2.0) + 44.0,
            y: (size.height / 2.0) - 58.0
        )
        achBtn.zPosition = 10
        container.addChild(achBtn)
        
        let achIcon = SKSpriteNode(imageNamed: currentTheme.guiStarIconName)
        achIcon.name = "menuAchievementsStarIcon"
        achIcon.size = CGSize(width: 24.0, height: 24.0)
        achIcon.position = .zero
        achIcon.zPosition = 2
        achBtn.addChild(achIcon)
        
        updateAchievementsBadge()
        
        // 6. Кнопка EXIT у самому низу меню із Basic_GUI_Bundle
        let exitBtnW: CGFloat = min(170.0, size.width - 120.0)
        let exitBtnH: CGFloat = exitBtnW * (304.0 / 983.0)
        let exitBtn = SKSpriteNode(imageNamed: "gui_btn_exit_red")
        exitBtn.name = "menuExitButton"
        exitBtn.size = CGSize(width: exitBtnW, height: exitBtnH)
        exitBtn.position = CGPoint(x: 0, y: -size.height * 0.285)
        exitBtn.zPosition = 5
        container.addChild(exitBtn)
        
        if animated {
            container.alpha = 0.0
            container.run(SKAction.fadeIn(withDuration: 0.30))
        }
    }
    
    /// Анімоване зникнення GUI меню та плавний старт бігу персонажа
    func dismissMenuAndStartClimb() {
        guard gameState == .menu else { return }
        gameState = .starting
        removeAction(forKey: "menuAutoJump")
        
        playJumpSound()
        
        // Ініціалізація статистики забігу заздалегідь під час згасання меню, щоб не навантажувати перший кадр гри
        AchievementManager.shared.startNewRun()
        DynamicAdManager.shared.notifyRunStarted()
        
        guard let menu = menuNode else {
            startClimb()
            return
        }
        
        // Швидке і плавне згасання меню як єдиного вузла для максимальної швидкодії
        menu.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.18),
            SKAction.removeFromParent()
        ]))
        self.menuNode = nil
        
        // Запуск підйому після завершення згасання меню
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.20),
            SKAction.run { [weak self] in
                self?.startClimb()
            }
        ]))
    }
    


    /// Оновлення лічильника монет у меню після покупок
    func updateMenuCoinsDisplay() {
        menuCoinsText?.text = totalCoins.formattedWithSeparator
    }
    


    /// Обробка виходу з гри при натисканні на кнопку Exit
    func handleExitApp() {
        playJumpSound()
        if let exitBtn = menuNode?.childNode(withName: "menuExitButton") {
            exitBtn.run(SKAction.sequence([
                SKAction.scale(to: 0.90, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.08),
                SKAction.run {
                    UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        exit(0)
                    }
                }
            ]))
        } else {
            UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                exit(0)
            }
        }
    }

}
