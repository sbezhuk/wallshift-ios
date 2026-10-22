//
//  GameScene+Achievements.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import SpriteKit

// MARK: - GameScene Achievements Extension
extension GameScene {
    
    // MARK: - Toast Banner Presentation (Тільки поза активним геймплеєм)
    
    /// Додавання досягнення в чергу сповіщень (заблоковано під час бігу, щоб не закривати огляд)
    func enqueueAchievementToast(_ achievement: Achievement) {
        guard gameState != .playing, !isGameOver else { return }
        toastQueue.append(achievement)
        presentNextToastIfNeeded()
    }
    
    /// Показ банера досягнення із черги
    private func presentNextToastIfNeeded() {
        guard !isShowingToast, !toastQueue.isEmpty else { return }
        let achievement = toastQueue.removeFirst()
        isShowingToast = true
        
        let bannerW = min(320.0, size.width - 32.0)
        let bannerH: CGFloat = 62.0
        
        let toastNode = SKNode()
        toastNode.name = "achievementToast"
        toastNode.zPosition = 350
        
        let startY = (size.height / 2.0) + bannerH
        let targetY = (size.height / 2.0) - 65.0
        toastNode.position = CGPoint(x: 0, y: startY)
        
        // 1. Фон банера
        let bg = SKShapeNode(rectOf: CGSize(width: bannerW, height: bannerH), cornerRadius: 14.0)
        bg.fillColor = SKColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 0.94)
        bg.strokeColor = achievement.difficulty.color
        bg.lineWidth = 2.0
        toastNode.addChild(bg)
        
        // 2. Іконка зірки
        let starIcon = SKSpriteNode(imageNamed: currentTheme.guiStarIconName)
        starIcon.size = CGSize(width: 28.0, height: 28.0)
        starIcon.position = CGPoint(x: -bannerW * 0.38, y: 0)
        toastNode.addChild(starIcon)
        
        let pulseUp = SKAction.scale(to: 1.25, duration: 0.4)
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.4)
        pulseUp.timingMode = .easeInEaseOut
        pulseDown.timingMode = .easeInEaseOut
        starIcon.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))
        
        // 3. Текст "ACHIEVEMENT UNLOCKED!"
        let headerLabel = SKLabelNode(fontNamed: AppFont.name)
        headerLabel.text = "ACHIEVEMENT UNLOCKED!"
        headerLabel.fontSize = 12.0
        headerLabel.fontColor = achievement.difficulty.color
        headerLabel.horizontalAlignmentMode = .left
        headerLabel.verticalAlignmentMode = .center
        headerLabel.position = CGPoint(x: -bannerW * 0.26, y: 12.0)
        toastNode.addChild(headerLabel)
        
        // 4. Назва досягнення та нагорода
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.text = "\(achievement.title)  (+\(achievement.coinReward.formattedWithSeparator) ¢)"
        titleLabel.fontSize = 15.0
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: -bannerW * 0.26, y: -10.0)
        toastNode.addChild(titleLabel)
        
        cameraNode.addChild(toastNode)
        playCoinSound()
        
        let slideDown = SKAction.moveTo(y: targetY, duration: 0.35)
        slideDown.timingMode = .easeOut
        let wait = SKAction.wait(forDuration: 2.8)
        let slideUp = SKAction.moveTo(y: startY, duration: 0.30)
        slideUp.timingMode = .easeIn
        let remove = SKAction.run { [weak self, weak toastNode] in
            toastNode?.removeFromParent()
            self?.isShowingToast = false
            self?.presentNextToastIfNeeded()
        }
        
        toastNode.run(SKAction.sequence([slideDown, wait, slideUp, remove]))
    }
    
    // MARK: - Achievements Overlay
    
    /// Відкриття повнорозмірного вікна списку досягнень
    func showAchievementsOverlay() {
        guard achievementsNode == nil else { return }
        removeAction(forKey: "menuAutoJump")
        
        let container = SKNode()
        container.name = "achievementsContainer"
        container.zPosition = 200
        achievementsNode = container
        cameraNode.addChild(container)
        
        // 1. Напівпрозоре затемнення фону
        let dimBg = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.72), size: CGSize(width: size.width * 1.5, height: size.height * 1.5))
        dimBg.name = "achievementsDimBg"
        dimBg.position = .zero
        dimBg.zPosition = 1
        container.addChild(dimBg)
        
        // 2. Основна плашка-картка
        let cardW: CGFloat = min(340.0, size.width - 24.0)
        let cardH: CGFloat = min(560.0, size.height * 0.82)
        let card = SKSpriteNode(imageNamed: "gui_card_box")
        card.name = "achievementsCard"
        card.size = CGSize(width: cardW, height: cardH)
        card.position = .zero
        card.zPosition = 2
        container.addChild(card)
        
        // 3. Заголовок "ACHIEVEMENTS"
        let bannerW = min(240.0, cardW - 40.0)
        let bannerH = bannerW * (457.0 / 1139.0)
        let banner = SKSpriteNode(imageNamed: currentTheme.guiBannerName)
        banner.name = "achievementsBanner"
        banner.size = CGSize(width: bannerW, height: bannerH)
        banner.position = CGPoint(x: 0, y: cardH * 0.44)
        banner.zPosition = 5
        card.addChild(banner)
        
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.name = "achievementsTitleLabel"
        titleLabel.text = "ACHIEVEMENTS"
        titleLabel.fontSize = 22.0
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.05)
        titleLabel.zPosition = 6
        banner.addChild(titleLabel)
        
        // 4. Кнопка закриття [X]
        let closeBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        closeBtn.name = "achievementsCloseButton"
        closeBtn.size = CGSize(width: 40.0, height: 40.0)
        closeBtn.position = CGPoint(x: (cardW / 2.0) - 26.0, y: (cardH / 2.0) - 26.0)
        closeBtn.zPosition = 10
        card.addChild(closeBtn)
        
        let closeIcon = SKSpriteNode(imageNamed: "gui_icon_close")
        closeIcon.name = "achievementsCloseButton"
        closeIcon.size = CGSize(width: 22.0, height: 22.0)
        closeIcon.position = .zero
        closeIcon.zPosition = 2
        closeBtn.addChild(closeIcon)
        
        // 5. Загальний лічильник завершених досягнень
        let statsNode = SKNode()
        statsNode.name = "achievementsStatsNode"
        statsNode.position = CGPoint(x: 0, y: cardH * 0.32)
        statsNode.zPosition = 5
        card.addChild(statsNode)
        
        let totalCount = AchievementManager.shared.totalAchievementsCount
        let unlockedCount = AchievementManager.shared.unlockedCount
        
        let completedLabel = SKLabelNode(fontNamed: AppFont.name)
        completedLabel.name = "achievementsCompletedCountLabel"
        completedLabel.text = "UNLOCKED: \(unlockedCount) / \(totalCount)"
        completedLabel.fontSize = 15.0
        completedLabel.fontColor = SKColor(red: 0.95, green: 0.85, blue: 0.65, alpha: 1.0)
        completedLabel.verticalAlignmentMode = .center
        completedLabel.horizontalAlignmentMode = .center
        completedLabel.position = CGPoint(x: 0, y: 10.0)
        statsNode.addChild(completedLabel)
        
        // Загальний прогрес-бар
        let barW: CGFloat = cardW - 70.0
        let barH: CGFloat = 8.0
        let barBg = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 4.0)
        barBg.fillColor = SKColor(white: 0.15, alpha: 0.8)
        barBg.strokeColor = .clear
        barBg.position = CGPoint(x: 0, y: -6.0)
        statsNode.addChild(barBg)
        
        let fillRatio = totalCount > 0 ? CGFloat(unlockedCount) / CGFloat(totalCount) : 0
        if fillRatio > 0 {
            let fillW = max(8.0, barW * fillRatio)
            let fillBar = SKShapeNode(rectOf: CGSize(width: fillW, height: barH), cornerRadius: 4.0)
            fillBar.fillColor = currentTheme.guiAccentColor
            fillBar.strokeColor = .clear
            fillBar.position = CGPoint(x: -barW / 2.0 + (fillW / 2.0), y: -6.0)
            statsNode.addChild(fillBar)
        }
        
        // 6. Динамічний контейнер сторінки
        let contentNode = SKNode()
        contentNode.name = "achievementsContentNode"
        contentNode.zPosition = 6
        card.addChild(contentNode)
        
        // 7. Нижня навігація сторінок (< Page X / Y >)
        setupAchievementsNavigation(on: card, cardW: cardW, cardH: cardH)
        
        // Рендеримо поточну сторінку досягнень
        renderAchievementsPage()
        
        // Анімація відкриття
        container.alpha = 0.0
        card.setScale(0.92)
        container.run(SKAction.fadeIn(withDuration: 0.20))
        card.run(SKAction.scale(to: 1.0, duration: 0.22))
    }
    
    /// Навігаційні кнопки перемикання сторінок
    private func setupAchievementsNavigation(on card: SKNode, cardW: CGFloat, cardH: CGFloat) {
        let navY = -cardH * 0.40
        
        // Кнопка вліво [<]
        let prevBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        prevBtn.name = "achievementsPrevButton"
        prevBtn.size = CGSize(width: 42.0, height: 42.0)
        prevBtn.position = CGPoint(x: -cardW * 0.34, y: navY)
        prevBtn.zPosition = 10
        card.addChild(prevBtn)
        
        let prevIcon = SKSpriteNode(imageNamed: "gui_icon_arrow_left")
        prevIcon.name = "achievementsPrevButton"
        prevIcon.size = CGSize(width: 22.0, height: 22.0)
        prevIcon.position = .zero
        prevIcon.zPosition = 2
        prevBtn.addChild(prevIcon)
        
        // Кнопка вправо [>]
        let nextBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        nextBtn.name = "achievementsNextButton"
        nextBtn.size = CGSize(width: 42.0, height: 42.0)
        nextBtn.position = CGPoint(x: cardW * 0.34, y: navY)
        nextBtn.zPosition = 10
        card.addChild(nextBtn)
        
        let nextIcon = SKSpriteNode(imageNamed: "gui_icon_arrow_right")
        nextIcon.name = "achievementsNextButton"
        nextIcon.size = CGSize(width: 22.0, height: 22.0)
        nextIcon.position = .zero
        nextIcon.zPosition = 2
        nextBtn.addChild(nextIcon)
        
        // Текст сторінки
        let pageLabel = SKLabelNode(fontNamed: AppFont.name)
        pageLabel.name = "achievementsPageLabel"
        pageLabel.fontSize = 15.0
        pageLabel.fontColor = .white
        pageLabel.verticalAlignmentMode = .center
        pageLabel.horizontalAlignmentMode = .center
        pageLabel.position = CGPoint(x: 0, y: navY)
        pageLabel.zPosition = 10
        card.addChild(pageLabel)
    }
    
    /// Рендеринг елементів досягнень поточної сторінки (по 3 досягнення на сторінку)
    func renderAchievementsPage() {
        guard let card = achievementsNode?.childNode(withName: "achievementsCard") else { return }
        guard let contentNode = card.childNode(withName: "achievementsContentNode") else { return }
        
        contentNode.removeAllChildren()
        
        let allAchievements = AchievementManager.shared.achievements
        let pageSize = 3
        let totalPages = max(1, (allAchievements.count + pageSize - 1) / pageSize)
        
        if currentAchievementsPage < 0 {
            currentAchievementsPage = totalPages - 1
        } else if currentAchievementsPage >= totalPages {
            currentAchievementsPage = 0
        }
        
        // Оновлюємо підпис сторінки
        if let pageLabel = card.childNode(withName: "achievementsPageLabel") as? SKLabelNode {
            pageLabel.text = "PAGE \(currentAchievementsPage + 1) / \(totalPages)"
        }
        
        let startIndex = currentAchievementsPage * pageSize
        let endIndex = min(startIndex + pageSize, allAchievements.count)
        let pageItems = Array(allAchievements[startIndex..<endIndex])
        
        let cardW: CGFloat = min(340.0, size.width - 24.0)
        let itemW: CGFloat = cardW - 36.0
        let itemH: CGFloat = 86.0
        let startY: CGFloat = 84.0
        let spacing: CGFloat = 94.0
        
        for (i, ach) in pageItems.enumerated() {
            let itemNode = SKNode()
            itemNode.name = "achItem_\(ach.id)"
            itemNode.position = CGPoint(x: 0, y: startY - (CGFloat(i) * spacing))
            contentNode.addChild(itemNode)
            
            // 1. Фон картки
            let itemBg = SKShapeNode(rectOf: CGSize(width: itemW, height: itemH), cornerRadius: 10.0)
            let isUnlocked = ach.isUnlocked
            itemBg.fillColor = isUnlocked ? SKColor(red: 0.14, green: 0.11, blue: 0.08, alpha: 0.92) : SKColor(red: 0.08, green: 0.06, blue: 0.05, alpha: 0.88)
            itemBg.strokeColor = isUnlocked ? ach.difficulty.color.withAlphaComponent(0.8) : SKColor(white: 0.25, alpha: 0.6)
            itemBg.lineWidth = isUnlocked ? 1.5 : 1.0
            itemNode.addChild(itemBg)
            
            // 2. Бейджик складності
            let badgeNode = SKShapeNode(rectOf: CGSize(width: 58.0, height: 18.0), cornerRadius: 5.0)
            badgeNode.fillColor = ach.difficulty.color.withAlphaComponent(0.20)
            badgeNode.strokeColor = ach.difficulty.color
            badgeNode.lineWidth = 1.0
            badgeNode.position = CGPoint(x: -itemW / 2.0 + 38.0, y: itemH / 2.0 - 15.0)
            itemNode.addChild(badgeNode)
            
            let badgeText = SKLabelNode(fontNamed: AppFont.name)
            badgeText.text = ach.difficulty.rawValue
            badgeText.fontSize = 10.5
            badgeText.fontColor = ach.difficulty.color
            badgeText.verticalAlignmentMode = .center
            badgeText.horizontalAlignmentMode = .center
            badgeText.position = .zero
            badgeNode.addChild(badgeText)
            
            // 3. Назва досягнення
            let title = SKLabelNode(fontNamed: AppFont.name)
            title.text = ach.title
            title.fontSize = 16.0
            title.fontColor = .white
            title.horizontalAlignmentMode = .left
            title.verticalAlignmentMode = .center
            title.position = CGPoint(x: -itemW / 2.0 + 74.0, y: itemH / 2.0 - 15.0)
            itemNode.addChild(title)
            
            // 4. Опис завдання
            let desc = SKLabelNode(fontNamed: AppFont.name)
            desc.text = ach.description
            desc.fontSize = 11.5
            desc.fontColor = SKColor(red: 0.80, green: 0.76, blue: 0.70, alpha: 1.0)
            desc.horizontalAlignmentMode = .left
            desc.verticalAlignmentMode = .center
            desc.position = CGPoint(x: -itemW / 2.0 + 12.0, y: 3.0)
            itemNode.addChild(desc)
            
            // 5. Прогрес-бар досягнення
            let pBarW: CGFloat = itemW - 120.0
            let pBarH: CGFloat = 6.0
            let pBarBg = SKShapeNode(rectOf: CGSize(width: pBarW, height: pBarH), cornerRadius: 3.0)
            pBarBg.fillColor = SKColor(white: 0.18, alpha: 0.9)
            pBarBg.strokeColor = .clear
            pBarBg.position = CGPoint(x: -itemW / 2.0 + 12.0 + (pBarW / 2.0), y: -itemH / 2.0 + 16.0)
            itemNode.addChild(pBarBg)
            
            let progress = ach.progressRatio
            if progress > 0 {
                let fillW = max(6.0, pBarW * progress)
                let pFill = SKShapeNode(rectOf: CGSize(width: fillW, height: pBarH), cornerRadius: 3.0)
                pFill.fillColor = ach.difficulty.color
                pFill.strokeColor = .clear
                pFill.position = CGPoint(x: -itemW / 2.0 + 12.0 + (fillW / 2.0), y: -itemH / 2.0 + 16.0)
                itemNode.addChild(pFill)
            }
            
            // Текст прогресу (напр. "75 / 100")
            let progressLabel = SKLabelNode(fontNamed: AppFont.name)
            let curVal = min(ach.currentProgress, ach.targetValue)
            progressLabel.text = "\(curVal.formattedWithSeparator) / \(ach.targetValue.formattedWithSeparator)"
            progressLabel.fontSize = 11.0
            progressLabel.fontColor = ach.isUnlocked ? ach.difficulty.color : SKColor(white: 0.65, alpha: 1.0)
            progressLabel.horizontalAlignmentMode = .left
            progressLabel.verticalAlignmentMode = .center
            progressLabel.position = CGPoint(x: -itemW / 2.0 + 18.0 + pBarW, y: -itemH / 2.0 + 16.0)
            itemNode.addChild(progressLabel)
            
            // 6. Права зона дії: CLAIM, CLAIMED або LOCK
            let actionX = itemW / 2.0 - 46.0
            let actionY: CGFloat = 0.0
            
            if ach.isUnlocked && !ach.isClaimed {
                let claimBtn = SKSpriteNode(imageNamed: "gui_btn_small_green")
                claimBtn.name = "claim_\(ach.id)"
                claimBtn.size = CGSize(width: 82.0, height: 34.0)
                claimBtn.position = CGPoint(x: actionX + 2.0, y: actionY)
                claimBtn.zPosition = 8
                itemNode.addChild(claimBtn)
                
                let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
                coinIcon.name = claimBtn.name
                coinIcon.size = CGSize(width: 14.0, height: 14.0)
                coinIcon.position = CGPoint(x: -26.0, y: 0)
                coinIcon.zPosition = 2
                claimBtn.addChild(coinIcon)
                
                let claimText = SKLabelNode(fontNamed: AppFont.name)
                claimText.name = claimBtn.name
                claimText.text = "+\(ach.coinReward.formattedWithSeparator)"
                claimText.fontSize = 12.5
                claimText.fontColor = .white
                claimText.verticalAlignmentMode = .center
                claimText.horizontalAlignmentMode = .center
                claimText.position = CGPoint(x: 10.0, y: 0)
                claimText.zPosition = 2
                claimBtn.addChild(claimText)
                
                let pUp = SKAction.scale(to: 1.05, duration: 0.6)
                let pDown = SKAction.scale(to: 0.98, duration: 0.6)
                claimBtn.run(SKAction.repeatForever(SKAction.sequence([pUp, pDown])))
                
            } else if ach.isClaimed {
                let checkIcon = SKSpriteNode(imageNamed: "gui_icon_check")
                checkIcon.size = CGSize(width: 22.0, height: 22.0)
                checkIcon.position = CGPoint(x: actionX + 4.0, y: actionY + 8.0)
                itemNode.addChild(checkIcon)
                
                let doneLabel = SKLabelNode(fontNamed: AppFont.name)
                doneLabel.text = "CLAIMED"
                doneLabel.fontSize = 11.0
                doneLabel.fontColor = SKColor(red: 0.35, green: 0.85, blue: 0.45, alpha: 1.0)
                doneLabel.verticalAlignmentMode = .center
                doneLabel.horizontalAlignmentMode = .center
                doneLabel.position = CGPoint(x: actionX + 4.0, y: actionY - 12.0)
                itemNode.addChild(doneLabel)
                
            } else {
                let lockIcon = SKSpriteNode(imageNamed: "gui_icon_lock")
                let lockH: CGFloat = 21.0
                let lockW: CGFloat = lockH * (130.0 / 164.0)
                lockIcon.size = CGSize(width: lockW, height: lockH)
                lockIcon.position = CGPoint(x: actionX + 4.0, y: actionY + 8.0)
                itemNode.addChild(lockIcon)
                
                let rewardText = SKLabelNode(fontNamed: AppFont.name)
                rewardText.text = "+\(ach.coinReward.formattedWithSeparator) ¢"
                rewardText.fontSize = 11.5
                rewardText.fontColor = SKColor(white: 0.7, alpha: 1.0)
                rewardText.verticalAlignmentMode = .center
                rewardText.horizontalAlignmentMode = .center
                rewardText.position = CGPoint(x: actionX + 4.0, y: actionY - 12.0)
                itemNode.addChild(rewardText)
            }
        }
    }
    
    /// Закриття оверлею списку досягнень
    func dismissAchievementsOverlay() {
        guard let container = achievementsNode else { return }
        
        container.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.20),
            SKAction.run { [weak self] in
                container.removeFromParent()
                self?.achievementsNode = nil
                self?.updateMenuCoinsDisplay()
                self?.updateAchievementsBadge()
                if self?.gameState == .menu {
                    self?.scheduleNextMenuAutoJump(delay: 2.0)
                }
            }
        ]))
    }
    
    /// Оновлення бейджика на кнопці досягнень у головному меню
    func updateAchievementsBadge() {
        guard let menu = menuNode else { return }
        guard let btn = menu.childNode(withName: "menuAchievementsButton") else { return }
        
        btn.childNode(withName: "achievementsUnclaimedBadge")?.removeFromParent()
        
        if AchievementManager.shared.hasUnclaimedRewards {
            let badge = SKShapeNode(circleOfRadius: 6.0)
            badge.name = "achievementsUnclaimedBadge"
            badge.fillColor = SKColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)
            badge.strokeColor = .white
            badge.lineWidth = 1.5
            badge.position = CGPoint(x: 15.0, y: 15.0)
            badge.zPosition = 5
            btn.addChild(badge)
            
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            badge.run(SKAction.repeatForever(pulse))
        }
    }
    
    /// Обробка забору нагороди за досягнення
    func handleClaimAchievement(id: String) {
        guard let ach = AchievementManager.shared.achievements.first(where: { $0.id == id }) else { return }
        let coinsGained = AchievementManager.shared.claimReward(for: ach)
        guard coinsGained > 0 else { return }
        
        playCoinSound()
        playCoinPickupEffect(at: .zero)
        
        updateMenuCoinsDisplay()
        renderAchievementsPage()
        
        if let card = achievementsNode?.childNode(withName: "achievementsCard"),
           let statsNode = card.childNode(withName: "achievementsStatsNode"),
           let countLabel = statsNode.childNode(withName: "achievementsCompletedCountLabel") as? SKLabelNode {
            let total = AchievementManager.shared.totalAchievementsCount
            let unl = AchievementManager.shared.unlockedCount
            countLabel.text = "UNLOCKED: \(unl) / \(total)"
        }
    }
}
