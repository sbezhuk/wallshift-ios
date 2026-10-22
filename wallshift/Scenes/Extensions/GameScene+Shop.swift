//
//  GameScene+Shop.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import SpriteKit

// MARK: - GameScene + Market & Shop System
extension GameScene {
    // MARK: - Market / Shop System
    
    /// Відкриття оверлею магазину персонажів та тем
    func showShopOverlay() {
        guard shopNode == nil else { return }
        removeAction(forKey: "menuAutoJump")
        
        // Знаходимо індекс поточної обраної теми для каруселі
        let themes = ThemeManager.shared.themes
        if let idx = themes.firstIndex(where: { $0.id == ThemeManager.shared.selectedThemeID }) {
            currentShopIndex = idx
        } else {
            currentShopIndex = 0
        }
        
        let container = SKNode()
        container.name = "shopContainer"
        container.zPosition = 200
        shopNode = container
        cameraNode.addChild(container)
        
        // 1. Напівпрозоре затемнення фону
        let dimBg = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.65), size: CGSize(width: size.width * 1.5, height: size.height * 1.5))
        dimBg.name = "shopDimBg"
        dimBg.position = .zero
        dimBg.zPosition = 1
        container.addChild(dimBg)
        
        // 2. Основна плашка магазину
        let cardW: CGFloat = min(330.0, size.width - 32.0)
        let cardH: CGFloat = min(530.0, size.height * 0.78)
        let card = SKSpriteNode(imageNamed: "gui_card_box")
        card.name = "shopCard"
        card.size = CGSize(width: cardW, height: cardH)
        card.position = .zero
        card.zPosition = 2
        container.addChild(card)
        
        // 3. Заголовок "MARKET"
        let bannerW = min(230.0, cardW - 40.0)
        let bannerH = bannerW * (457.0 / 1139.0)
        let banner = SKSpriteNode(imageNamed: currentTheme.guiBannerName)
        banner.name = "shopBanner"
        banner.size = CGSize(width: bannerW, height: bannerH)
        banner.position = CGPoint(x: 0, y: cardH * 0.44)
        banner.zPosition = 5
        card.addChild(banner)
        
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.name = "shopTitleLabel"
        titleLabel.text = "MARKET"
        titleLabel.fontSize = 25.0
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.05)
        titleLabel.zPosition = 6
        banner.addChild(titleLabel)
        
        // 4. Кнопка закриття [X]
        let closeBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        closeBtn.name = "shopCloseButton"
        closeBtn.size = CGSize(width: 40.0, height: 40.0)
        closeBtn.position = CGPoint(x: (cardW / 2.0) - 26.0, y: (cardH / 2.0) - 26.0)
        closeBtn.zPosition = 10
        card.addChild(closeBtn)
        
        let closeIcon = SKSpriteNode(imageNamed: "gui_icon_close")
        closeIcon.name = "shopCloseButton"
        closeIcon.size = CGSize(width: 22.0, height: 22.0)
        closeIcon.position = .zero
        closeIcon.zPosition = 2
        closeBtn.addChild(closeIcon)
        
        // 5. Баланс монет у верхній частині картки
        let balanceNode = SKNode()
        balanceNode.name = "shopBalanceNode"
        balanceNode.position = CGPoint(x: 0, y: cardH * 0.31)
        balanceNode.zPosition = 5
        card.addChild(balanceNode)
        
        let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
        coinIcon.name = "shopCoinIcon"
        coinIcon.size = CGSize(width: 24.0, height: 24.0)
        
        let balanceLabel = SKLabelNode(fontNamed: AppFont.name)
        balanceLabel.name = "shopBalanceLabel"
        balanceLabel.text = totalCoins.formattedWithSeparator
        balanceLabel.fontSize = 21.0
        balanceLabel.fontColor = SKColor(red: 1.0, green: 0.88, blue: 0.30, alpha: 1.0)
        balanceLabel.horizontalAlignmentMode = .left
        balanceLabel.verticalAlignmentMode = .center
        
        let balSpacing: CGFloat = 8.0
        let totalBalW = coinIcon.size.width + balSpacing + balanceLabel.frame.width
        coinIcon.position = CGPoint(x: -totalBalW / 2.0 + coinIcon.size.width / 2.0, y: 0)
        balanceLabel.position = CGPoint(x: coinIcon.position.x + coinIcon.size.width / 2.0 + balSpacing, y: 0)
        
        balanceNode.addChild(coinIcon)
        balanceNode.addChild(balanceLabel)
        
        // 6. Стрілки перемикання ліворуч / праворуч
        let arrowLeft = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        arrowLeft.name = "shopPrevButton"
        arrowLeft.size = CGSize(width: 44.0, height: 44.0)
        arrowLeft.position = CGPoint(x: -cardW * 0.40, y: cardH * 0.08)
        arrowLeft.zPosition = 8
        card.addChild(arrowLeft)
        
        let arrowLeftIcon = SKSpriteNode(imageNamed: "gui_icon_arrow_left")
        arrowLeftIcon.name = "shopPrevButton"
        arrowLeftIcon.size = CGSize(width: 20.0, height: 20.0)
        arrowLeftIcon.position = .zero
        arrowLeftIcon.zPosition = 2
        arrowLeft.addChild(arrowLeftIcon)
        
        let arrowRight = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        arrowRight.name = "shopNextButton"
        arrowRight.name = "shopNextButton"
        arrowRight.size = CGSize(width: 44.0, height: 44.0)
        arrowRight.position = CGPoint(x: cardW * 0.40, y: cardH * 0.08)
        arrowRight.zPosition = 8
        card.addChild(arrowRight)
        
        let arrowRightIcon = SKSpriteNode(imageNamed: "gui_icon_arrow_right")
        arrowRightIcon.name = "shopNextButton"
        arrowRightIcon.size = CGSize(width: 20.0, height: 20.0)
        arrowRightIcon.position = .zero
        arrowRightIcon.zPosition = 2
        arrowRight.addChild(arrowRightIcon)
        
        // 7. Контейнер динамічного вмісту теми
        let contentContainer = SKNode()
        contentContainer.name = "shopDynamicContent"
        contentContainer.zPosition = 5
        card.addChild(contentContainer)
        
        // 8. Кнопка перегляду реклами для отримання безкоштовних монет
        setupShopAdRewardButton(on: card, cardW: cardW, cardH: cardH)
        
        // Рендеримо картку ДО застосування початкового масштабу появи,
        // щоб розміри та позиції не спотворювалися масштабуванням картки
        renderCurrentShopCard()
        
        // Анімація появи
        container.alpha = 0.0
        card.setScale(0.85)
        container.run(SKAction.fadeIn(withDuration: 0.20))
        card.run(SKAction.scale(to: 1.0, duration: 0.20))
    }
    
    /// Рендеринг поточного персонажа/теми у вікні магазину
    func renderCurrentShopCard() {
        guard let shop = shopNode,
              let card = shop.childNode(withName: "shopCard"),
              let content = card.childNode(withName: "shopDynamicContent") else { return }
        
        content.removeAllChildren()
        
        // Оновлюємо лічильник балансу
        if let balance = card.childNode(withName: "shopBalanceNode")?.childNode(withName: "shopBalanceLabel") as? SKLabelNode,
           let coin = card.childNode(withName: "shopBalanceNode")?.childNode(withName: "shopCoinIcon") as? SKSpriteNode {
            coin.texture = SKTexture(imageNamed: ThemeManager.shared.currentTheme.guiCoinIconName)
            balance.text = totalCoins.formattedWithSeparator
            let balSpacing: CGFloat = 8.0
            let totalW = coin.size.width + balSpacing + balance.frame.width
            coin.position = CGPoint(x: -totalW / 2.0 + coin.size.width / 2.0, y: 0)
            balance.position = CGPoint(x: coin.position.x + coin.size.width / 2.0 + balSpacing, y: 0)
        }
        
        let themes = ThemeManager.shared.themes
        guard currentShopIndex >= 0, currentShopIndex < themes.count else { return }
        let theme = themes[currentShopIndex]
        let isUnlocked = ThemeManager.shared.isUnlocked(theme)
        let isSelected = (theme.id == ThemeManager.shared.selectedThemeID)
        let canAfford = ThemeManager.shared.canAfford(theme)
        
        let cardSprite = card as? SKSpriteNode
        let scaleY = abs(cardSprite?.yScale ?? 1.0)
        let currentScaleY = scaleY > 0.001 ? scaleY : 1.0
        let cardH = (cardSprite?.size.height ?? 530.0) / currentScaleY
        let cardW = (cardSprite?.size.width ?? 330.0)
        
        // А. П'єдестал та аватар персонажа
        let avatarBg = SKSpriteNode(imageNamed: theme.guiCardFrameName)
        avatarBg.size = CGSize(width: 122.0, height: 122.0)
        avatarBg.position = CGPoint(x: 0, y: cardH * 0.08)
        avatarBg.zPosition = 1
        content.addChild(avatarBg)
        
        let heroAvatar = SKSpriteNode(imageNamed: theme.previewImageName)
        heroAvatar.size = CGSize(width: 86.0, height: 86.0)
        heroAvatar.position = CGPoint(x: 0, y: -4.0)
        heroAvatar.zPosition = 2
        avatarBg.addChild(heroAvatar)
        
        // Пульсація аватара
        let breatheUp = SKAction.scale(to: 1.05, duration: 1.1)
        let breatheDown = SKAction.scale(to: 0.98, duration: 1.1)
        breatheUp.timingMode = .easeInEaseOut
        breatheDown.timingMode = .easeInEaseOut
        heroAvatar.run(SKAction.repeatForever(SKAction.sequence([breatheUp, breatheDown])))
        
        // Статусний бейдж на кутку аватара
        if isSelected {
            let badge = SKSpriteNode(imageNamed: "gui_icon_check")
            badge.size = CGSize(width: 24.0, height: 24.0)
            badge.position = CGPoint(x: 46.0, y: 46.0)
            badge.zPosition = 5
            avatarBg.addChild(badge)
        } else if !isUnlocked {
            let lock = SKSpriteNode(imageNamed: "gui_icon_lock")
            let lockH: CGFloat = 24.0
            let lockW: CGFloat = lockH * (130.0 / 164.0)
            lock.size = CGSize(width: lockW, height: lockH)
            lock.position = CGPoint(x: 46.0, y: 46.0)
            lock.zPosition = 5
            avatarBg.addChild(lock)
        }
        
        // Б. Назва теми (позиціонується з безпечним відступом під п'єдесталом аватара)
        let avatarBottomY = avatarBg.position.y - (avatarBg.size.height / 2.0)
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.text = theme.name
        titleLabel.fontSize = 17.0
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: avatarBottomY - 18.0)
        titleLabel.zPosition = 2
        content.addChild(titleLabel)
        
        // В. Опис характеристик
        let subtitleLabel = SKLabelNode(fontNamed: AppFont.name)
        subtitleLabel.text = theme.subtitle
        subtitleLabel.fontSize = 12.0
        subtitleLabel.fontColor = SKColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 0.90)
        subtitleLabel.position = CGPoint(x: 0, y: titleLabel.position.y - 17.0)
        subtitleLabel.zPosition = 2
        content.addChild(subtitleLabel)
        
        // Г. Індикатор пагінації (точки 1 2 3)
        let dotsContainer = SKNode()
        dotsContainer.position = CGPoint(x: 0, y: subtitleLabel.position.y - 17.0)
        dotsContainer.zPosition = 2
        content.addChild(dotsContainer)
        
        let dotSpacing: CGFloat = 16.0
        let totalDotsW = CGFloat(themes.count - 1) * dotSpacing
        for i in 0..<themes.count {
            let dot = SKShapeNode(circleOfRadius: (i == currentShopIndex) ? 4.5 : 3.0)
            dot.fillColor = (i == currentShopIndex) ? theme.guiAccentColor : SKColor.white.withAlphaComponent(0.35)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: -totalDotsW / 2.0 + CGFloat(i) * dotSpacing, y: 0)
            dotsContainer.addChild(dot)
        }
        
        // Д. Кнопка дії (ОБРАНО / ОБРАТИ / КУПИТИ)
        let btnW: CGFloat = min(220.0, cardW - 60.0)
        let btnH: CGFloat = 46.0
        let actionBtnNode = SKNode()
        actionBtnNode.name = isSelected ? "shopAlreadySelected" : "shopActionButton"
        actionBtnNode.position = CGPoint(x: 0, y: -cardH * 0.24)
        actionBtnNode.zPosition = 3
        content.addChild(actionBtnNode)
        
        if isSelected {
            let btnBg = SKSpriteNode(imageNamed: theme.guiSecondaryBtnName)
            btnBg.name = "shopAlreadySelected"
            btnBg.size = CGSize(width: btnW, height: btnH)
            btnBg.zPosition = 1
            actionBtnNode.addChild(btnBg)
            
            let checkIcon = SKSpriteNode(imageNamed: "gui_icon_check")
            checkIcon.name = "shopAlreadySelected"
            checkIcon.size = CGSize(width: 18.0, height: 18.0)
            checkIcon.position = CGPoint(x: -42.0, y: 1.0)
            checkIcon.zPosition = 3
            btnBg.addChild(checkIcon)
            
            let label = SKLabelNode(fontNamed: AppFont.name)
            label.name = "shopAlreadySelected"
            label.text = "SELECTED"
            label.fontSize = 18.0
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 10.0, y: 1.0)
            label.zPosition = 3
            btnBg.addChild(label)
        } else if isUnlocked {
            let btnBg = SKSpriteNode(imageNamed: theme.guiPrimaryBtnName)
            btnBg.name = "shopActionButton"
            btnBg.size = CGSize(width: btnW, height: btnH)
            btnBg.zPosition = 1
            actionBtnNode.addChild(btnBg)
            
            let label = SKLabelNode(fontNamed: AppFont.name)
            label.name = "shopActionButton"
            label.text = "SELECT"
            label.fontSize = 18.0
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 1.0)
            label.zPosition = 3
            btnBg.addChild(label)
        } else {
            // Заблокована тема — покупка
            let btnBg = SKSpriteNode(imageNamed: theme.guiPrimaryBtnName)
            btnBg.name = "shopActionButton"
            btnBg.size = CGSize(width: btnW, height: btnH)
            btnBg.alpha = canAfford ? 1.0 : 0.65
            if !canAfford {
                btnBg.color = .darkGray
                btnBg.colorBlendFactor = 0.35
            }
            btnBg.zPosition = 1
            actionBtnNode.addChild(btnBg)
            
            let coin = SKSpriteNode(imageNamed: theme.guiCoinIconName)
            coin.name = "shopActionButton"
            coin.size = CGSize(width: 19.0, height: 19.0)
            coin.zPosition = 3
            
            let label = SKLabelNode(fontNamed: AppFont.name)
            label.name = "shopActionButton"
            let formattedPrice = theme.price.formattedWithSeparator
            label.text = canAfford ? "BUY (\(formattedPrice))" : "\(formattedPrice) (NOT ENOUGH)"
            label.fontSize = canAfford ? 17.0 : 13.5
            label.fontColor = canAfford ? .white : SKColor(white: 0.95, alpha: 1.0)
            label.verticalAlignmentMode = .center
            label.zPosition = 3
            
            // Динамічне центроване розміщення: монетка + гарантований відступ + текст (наїзд неможливий)
            let spacing: CGFloat = 8.0
            let totalContentW = coin.size.width + spacing + label.frame.width
            let startX = -totalContentW / 2.0
            
            coin.position = CGPoint(x: startX + (coin.size.width / 2.0), y: 1.0)
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: startX + coin.size.width + spacing, y: 1.0)
            
            btnBg.addChild(coin)
            btnBg.addChild(label)
        }
    }
    
    /// Закриття оверлею магазину та повернення до головного меню
    func dismissShopOverlay() {
        guard let shop = shopNode else { return }
        shop.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.18),
            SKAction.removeFromParent()
        ]))
        self.shopNode = nil
        self.shopAdRewardBtnNode = nil
        self.shopAdRewardBgSprite = nil
        self.shopAdRewardLabel = nil
        self.shopAdRewardPlayIcon = nil
        self.shopAdRewardCoinIcon = nil
        
        // Оновлюємо лічильник монет у меню
        updateMenuCoinsDisplay()
        
        // Відновлюємо інтервал автострибка в меню
        if gameState == .menu {
            scheduleNextMenuAutoJump(delay: 2.0)
        }
    }
    


    // MARK: - Shop Ad Reward Feature
    
    /// Налаштування кнопки перегляду реклами для отримання безкоштовних монет
    func setupShopAdRewardButton(on card: SKNode, cardW: CGFloat, cardH: CGFloat) {
        let btnW: CGFloat = min(220.0, cardW - 60.0)
        let btnH: CGFloat = 44.0
        
        let container = SKNode()
        container.name = "shopAdRewardButton"
        container.position = CGPoint(x: 0, y: -cardH * 0.385)
        container.zPosition = 8
        card.addChild(container)
        self.shopAdRewardBtnNode = container
        
        let bgSprite = SKSpriteNode(imageNamed: "gui_btn_large_green")
        bgSprite.name = "shopAdRewardButton"
        bgSprite.size = CGSize(width: btnW, height: btnH)
        bgSprite.zPosition = 1
        container.addChild(bgSprite)
        self.shopAdRewardBgSprite = bgSprite
        
        let playIcon = SKSpriteNode(imageNamed: "gui_icon_play")
        playIcon.name = "shopAdRewardButton"
        playIcon.size = CGSize(width: 16.0, height: 16.0)
        playIcon.zPosition = 3
        bgSprite.addChild(playIcon)
        self.shopAdRewardPlayIcon = playIcon
        
        let label = SKLabelNode(fontNamed: AppFont.name)
        label.name = "shopAdRewardButton"
        label.fontSize = 16.0
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 3
        bgSprite.addChild(label)
        self.shopAdRewardLabel = label
        
        let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
        coinIcon.name = "shopAdRewardButton"
        coinIcon.size = CGSize(width: 20.0, height: 20.0)
        coinIcon.zPosition = 3
        bgSprite.addChild(coinIcon)
        self.shopAdRewardCoinIcon = coinIcon
        
        // Початкове налаштування стану (доступно чи кулдаун)
        updateShopAdRewardButtonState()
        
        // Таймер для щосекундного оновлення кулдауну
        container.removeAction(forKey: "shopAdTimer")
        let timerAction = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                self?.updateShopAdRewardTimerTick()
            }
        ]))
        container.run(timerAction, withKey: "shopAdTimer")
    }
    
    /// Оновлення візуального стану кнопки реклами в магазині
    func updateShopAdRewardButtonState() {
        guard let container = shopAdRewardBtnNode,
              let bg = shopAdRewardBgSprite,
              let label = shopAdRewardLabel,
              let coin = shopAdRewardCoinIcon,
              let play = shopAdRewardPlayIcon else { return }
        
        // 1. Якщо відсутнє інтернет-підключення — кнопка вимкнена
        guard NetworkMonitor.shared.isConnected else {
            container.removeAction(forKey: "adPulse")
            container.setScale(1.0)
            
            bg.texture = SKTexture(imageNamed: currentTheme.guiSecondaryBtnName)
            bg.color = .black
            bg.colorBlendFactor = 0.35
            bg.alpha = 0.60
            
            play.isHidden = true
            coin.isHidden = true
            label.text = "NO INTERNET"
            label.fontColor = SKColor(white: 0.82, alpha: 0.85)
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 1.0)
            return
        }
        
        let isAvailable = ShopAdRewardManager.shared.isRewardAvailable
        coin.texture = SKTexture(imageNamed: currentTheme.guiCoinIconName)
        coin.isHidden = false
        
        if isAvailable {
            bg.texture = SKTexture(imageNamed: "gui_btn_large_green")
            bg.color = .clear
            bg.colorBlendFactor = 0.0
            bg.alpha = 1.0
            
            play.isHidden = false
            label.text = "FREE +\(ShopAdRewardManager.rewardCoins)"
            label.fontColor = .white
            
            // Центроване розташування [Play] [Text] [Coin]
            let spacing: CGFloat = 6.0
            let totalW = play.size.width + spacing + label.frame.width + spacing + coin.size.width
            let startX = -totalW / 2.0
            
            play.position = CGPoint(x: startX + (play.size.width / 2.0), y: 1.0)
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: play.position.x + (play.size.width / 2.0) + spacing, y: 1.0)
            coin.position = CGPoint(x: label.position.x + label.frame.width + spacing + (coin.size.width / 2.0), y: 1.0)
            
            // М'яка пульсація для привернення уваги, що нагорода доступна
            container.removeAction(forKey: "adPulse")
            let pulseUp = SKAction.scale(to: 1.035, duration: 0.85)
            let pulseDown = SKAction.scale(to: 0.975, duration: 0.85)
            pulseUp.timingMode = .easeInEaseOut
            pulseDown.timingMode = .easeInEaseOut
            container.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])), withKey: "adPulse")
        } else {
            container.removeAction(forKey: "adPulse")
            container.setScale(1.0)
            
            bg.texture = SKTexture(imageNamed: currentTheme.guiSecondaryBtnName)
            bg.color = .black
            bg.colorBlendFactor = 0.25
            bg.alpha = 0.85
            
            play.isHidden = true
            label.text = ShopAdRewardManager.shared.formattedCooldownString()
            label.fontColor = SKColor(white: 0.92, alpha: 1.0)
            
            // Центроване розташування [Coin] [Cooldown Text]
            let spacing: CGFloat = 8.0
            let totalW = coin.size.width + spacing + label.frame.width
            let startX = -totalW / 2.0
            
            coin.position = CGPoint(x: startX + (coin.size.width / 2.0), y: 1.0)
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: startX + coin.size.width + spacing, y: 1.0)
        }
    }
    
    /// Щосекундний тік таймера кулдауну
    func updateShopAdRewardTimerTick() {
        guard let label = shopAdRewardLabel,
              let coin = shopAdRewardCoinIcon,
              let container = shopAdRewardBtnNode else { return }
        
        let isConnected = NetworkMonitor.shared.isConnected
        let wasOffline = (coin.isHidden == true)
        
        if !isConnected {
            if !wasOffline {
                updateShopAdRewardButtonState()
            }
            return
        }
        
        if wasOffline {
            // Мережа щойно відновилась
            updateShopAdRewardButtonState()
            return
        }
        
        let isAvailable = ShopAdRewardManager.shared.isRewardAvailable
        let wasAvailable = (shopAdRewardPlayIcon?.isHidden == false)
        
        if isAvailable {
            if !wasAvailable {
                // Завершення кулдауну: оновлюємо вигляд та запускаємо анімацію появи готовності
                updateShopAdRewardButtonState()
                container.run(SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.15),
                    SKAction.scale(to: 1.0, duration: 0.15)
                ]))
            }
        } else {
            label.text = ShopAdRewardManager.shared.formattedCooldownString()
            let spacing: CGFloat = 8.0
            let totalW = coin.size.width + spacing + label.frame.width
            let startX = -totalW / 2.0
            coin.position = CGPoint(x: startX + (coin.size.width / 2.0), y: 1.0)
            label.position = CGPoint(x: startX + coin.size.width + spacing, y: 1.0)
        }
    }
    
    /// Обробка натискання кнопки реклами в магазині
    func handleShopAdRewardTapped() {
        guard let shop = shopNode,
              let card = shop.childNode(withName: "shopCard") else { return }
        
        // 1. Перевірка наявності інтернет-з'єднання
        guard NetworkMonitor.shared.isConnected else {
            playJumpSound()
            if let btn = shopAdRewardBtnNode {
                let left = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
                let right = SKAction.moveBy(x: 12, y: 0, duration: 0.08)
                let back = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
                btn.run(SKAction.sequence([left, right, back]))
            }
            showShopAdToast(on: card, text: "NO INTERNET CONNECTION", isSuccess: false)
            return
        }
        
        // 2. Перевірка кулдауну
        if !ShopAdRewardManager.shared.isRewardAvailable {
            // Кулдаун ще активний: похитування кнопки та підказка з часом до наступної нагороди
            playJumpSound()
            if let btn = shopAdRewardBtnNode {
                let left = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
                let right = SKAction.moveBy(x: 12, y: 0, duration: 0.08)
                let back = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
                btn.run(SKAction.sequence([left, right, back]))
            }
            showShopAdToast(on: card, text: "READY IN \(ShopAdRewardManager.shared.cooldownDescriptionString())", isSuccess: false)
            return
        }
        
        guard let vc = view?.window?.rootViewController ?? view?.next as? UIViewController else { return }
        playJumpSound()
        
        UnityAdsManager.shared.showRewardedAd(
            from: vc,
            customMessage: "Simulating Rewarded Video Ad playback.\nPress 'Claim Reward' to get +\(ShopAdRewardManager.rewardCoins) Coins for the Market!",
            actionTitle: "Claim +\(ShopAdRewardManager.rewardCoins) Coins"
        ) { [weak self] in
            guard let self = self else { return }
            
            // 1. Зараховуємо нагороду
            let earned = ShopAdRewardManager.shared.claimReward()
            
            // 2. Звук та частинки золотих монет
            self.playCoinSound()
            if let btn = self.shopAdRewardBtnNode {
                let scenePos = card.convert(btn.position, to: self)
                self.playCoinPickupEffect(at: scenePos)
            }
            
            // 3. Оновлення балансу в магазині з привабливою пульсацією
            if let balance = card.childNode(withName: "shopBalanceNode")?.childNode(withName: "shopBalanceLabel") as? SKLabelNode,
               let coin = card.childNode(withName: "shopBalanceNode")?.childNode(withName: "shopCoinIcon") as? SKSpriteNode {
                balance.text = self.totalCoins.formattedWithSeparator
                let balSpacing: CGFloat = 8.0
                let totalW = coin.size.width + balSpacing + balance.frame.width
                coin.position = CGPoint(x: -totalW / 2.0 + coin.size.width / 2.0, y: 0)
                balance.position = CGPoint(x: coin.position.x + coin.size.width / 2.0 + balSpacing, y: 0)
                
                balance.run(SKAction.sequence([
                    SKAction.scale(to: 1.30, duration: 0.15),
                    SKAction.scale(to: 1.0, duration: 0.15)
                ]))
            }
            
            // 4. Оновлення поточної картки скіна (якщо монет стало достатньо для купівлі)
            self.renderCurrentShopCard()
            
            // 5. Оновлення лічильника монет у головному меню
            self.updateMenuCoinsDisplay()
            
            // 6. Перехід кнопки в режим очікування кулдауну
            self.updateShopAdRewardButtonState()
            
            // 7. Спливаюче повідомлення про успішне отримання монет
            self.showShopAdToast(on: card, text: "+\(earned) COINS RECEIVED!", isSuccess: true)
            
        } onFailed: { message in
            print("[GameScene] Shop rewarded ad failed or skipped: \(message)")
        }
    }
    
    /// Відображення акуратного спливаючого тосту над кнопкою нагороди
    func showShopAdToast(on card: SKNode, text: String, isSuccess: Bool) {
        card.childNode(withName: "shopAdToast")?.removeFromParent()
        
        let toast = SKNode()
        toast.name = "shopAdToast"
        toast.position = CGPoint(x: 0, y: (shopAdRewardBtnNode?.position.y ?? -200.0) + 36.0)
        toast.zPosition = 20
        
        let label = SKLabelNode(fontNamed: AppFont.name)
        label.text = text
        label.fontSize = 13.5
        label.fontColor = isSuccess ? SKColor(red: 1.0, green: 0.90, blue: 0.30, alpha: 1.0) : SKColor(red: 1.0, green: 0.45, blue: 0.40, alpha: 1.0)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 2
        toast.addChild(label)
        
        let bgW = label.frame.width + 20.0
        let bgH: CGFloat = 26.0
        let bg = SKShapeNode(rectOf: CGSize(width: bgW, height: bgH), cornerRadius: 6.0)
        bg.fillColor = SKColor.black.withAlphaComponent(0.85)
        bg.strokeColor = isSuccess ? SKColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 0.9) : SKColor.white.withAlphaComponent(0.3)
        bg.lineWidth = 1.0
        bg.zPosition = 1
        toast.addChild(bg)
        
        card.addChild(toast)
        
        toast.alpha = 0.0
        toast.setScale(0.85)
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        let wait = SKAction.wait(forDuration: 1.6)
        let disappear = SKAction.group([
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.moveBy(x: 0, y: 10, duration: 0.25)
        ])
        toast.run(SKAction.sequence([appear, wait, disappear, SKAction.removeFromParent()]))
    }
    
    /// Миттєве застосування поточної теми до сцени (персонаж, стіни, фон)
    func applyCurrentThemeToScene() {
        let theme = ThemeManager.shared.currentTheme
        updateCachedThemeTextures()
        
        // 1. Оновлення образу персонажа
        player.applyTheme(prefix: theme.heroRunPrefix, frameCount: theme.heroRunCount)
        if gameState == .menu {
            player.setReadyStance()
        }
        
        // 2. Оновлення атмосферного оверлею фону та текстури фону
        let newBgTex = backgroundTexture
        newBgTex.filteringMode = .linear
        if newBgTex.size().width > 0 {
            backgroundNode?.texture = newBgTex
            let textureSize = newBgTex.size()
            let baseScale = max(size.width / textureSize.width, size.height / textureSize.height)
            let scale = baseScale * backgroundScaleMultiplier
            let bgSize = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
            backgroundNode?.size = bgSize
            
            let topH: CGFloat = 120.0
            backgroundTopExtensionNode?.size = CGSize(width: max(size.width, bgSize.width) + 40.0, height: topH)
            backgroundTopExtensionNode?.position = CGPoint(x: 0, y: (bgSize.height / 2.0) + (topH / 2.0) - 2.0)
            
            let botH: CGFloat = 120.0
            backgroundBottomExtensionNode?.size = CGSize(width: max(size.width, bgSize.width) + 40.0, height: botH)
            backgroundBottomExtensionNode?.position = CGPoint(x: 0, y: -(bgSize.height / 2.0) - (botH / 2.0) + 2.0)
        }
        backgroundTopExtensionNode?.run(SKAction.colorize(with: theme.backgroundTopColor, colorBlendFactor: 1.0, duration: 0.35))
        backgroundBottomExtensionNode?.run(SKAction.colorize(with: theme.backgroundBottomColor, colorBlendFactor: 1.0, duration: 0.35))
        backgroundOverlayNode?.run(SKAction.colorize(with: theme.backgroundOverlayColor, colorBlendFactor: 1.0, duration: 0.35))
        backgroundOverlayNode?.run(SKAction.fadeAlpha(to: theme.backgroundOverlayAlpha, duration: 0.35))
        
        // Оновлення текстури сердець у HUD
        let heartTex = cachedHeartTexture
        for heart in heartHUDNodes {
            heart.texture = heartTex
        }
        hudCoinIcon?.texture = SKTexture(imageNamed: theme.guiCoinIconName)
        
        // 3. Повне перезавантаження траси, стін, прірв та декорацій під нову тему (у режимі меню)
        if gameState == .menu {
            leftTrackNodes.forEach { $0.removeFromParent() }
            leftTrackNodes.removeAll()
            rightTrackNodes.forEach { $0.removeFromParent() }
            rightTrackNodes.removeAll()
            leftAbyssNodes.removeAll()
            rightAbyssNodes.removeAll()
            decorationNodes.forEach { $0.removeFromParent() }
            decorationNodes.removeAll()
            trackHeartNodes.forEach { $0.removeFromParent() }
            trackHeartNodes.removeAll()
            trackMobNodes.forEach { $0.removeFromParent() }
            trackMobNodes.removeAll()
            trackCoinNodes.forEach { $0.removeFromParent() }
            trackCoinNodes.removeAll()
            
            setupProceduralTrack()
            player.setReadyStance()
        }
        
        // 4. Оновлення елементів інтерфейсу головного меню під активну тему
        if let menu = menuNode {
            if let titleContainer = menu.childNode(withName: "menuTitle") {
                (titleContainer.childNode(withName: "menuBanner") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiBannerName)
                (titleContainer.childNode(withName: "menuBannerShadow") as? SKLabelNode)?.fontColor = theme.guiBannerShadowColor
            }
            if let card = menu.childNode(withName: "menuCard") as? SKSpriteNode {
                card.texture = SKTexture(imageNamed: theme.guiStatsBarName)
                (card.childNode(withName: "menuBestScoreText") as? SKLabelNode)?.fontColor = theme.guiStatsTextColor
                (card.childNode(withName: "menuCoinsText") as? SKLabelNode)?.fontColor = theme.guiStatsTextColor
                (card.childNode(withName: "menuCoinsIcon") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCoinIconName)
                (card.childNode(withName: "menuStarIcon") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiStarIconName)
            }
            (menu.childNode(withName: "menuPlayButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiPrimaryBtnName)
            (menu.childNode(withName: "menuShopButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiSecondaryBtnName)
            (menu.childNode(withName: "menuSoundButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            if let achBtn = menu.childNode(withName: "menuAchievementsButton") as? SKSpriteNode {
                achBtn.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
                (achBtn.childNode(withName: "menuAchievementsStarIcon") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiStarIconName)
            }
        }
        
        // 5. Оновлення елементів інтерфейсу магазину (якщо відкритий)
        if let card = shopNode?.childNode(withName: "shopCard") {
            (card.childNode(withName: "shopBanner") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiBannerName)
            (card.childNode(withName: "shopCloseButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            (card.childNode(withName: "shopPrevButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            (card.childNode(withName: "shopNextButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            if let balanceNode = card.childNode(withName: "shopBalanceNode") {
                (balanceNode.childNode(withName: "shopCoinIcon") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCoinIconName)
            }
            updateShopAdRewardButtonState()
        }
        
        // 5b. Оновлення елементів інтерфейсу досягнень (якщо відкритий)
        if let achCard = achievementsNode?.childNode(withName: "achievementsCard") {
            (achCard.childNode(withName: "achievementsBanner") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiBannerName)
            (achCard.childNode(withName: "achievementsCloseButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            (achCard.childNode(withName: "achievementsPrevButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            (achCard.childNode(withName: "achievementsNextButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
        }
        
        // 5c. Оновлення елементів інтерфейсу налаштувань (якщо відкритий)
        if let settingsCard = settingsNode?.childNode(withName: "settingsCard") {
            (settingsCard.childNode(withName: "settingsBanner") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiBannerName)
            (settingsCard.childNode(withName: "settingsCloseButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            refreshSettingsUI()
        }
        
        // 6. Оновлення лічильника меню
        updateMenuCoinsDisplay()
    }
    

}
