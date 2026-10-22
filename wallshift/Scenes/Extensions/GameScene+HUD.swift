//
//  GameScene+HUD.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import SpriteKit

// MARK: - GameScene + HUD
extension GameScene {
    // MARK: - Lives & Score HUD
    func setupHUD() {
        hudNode.removeFromParent()
        hudNode.removeAllChildren()
        heartHUDNodes.removeAll()
        
        hudNode.zPosition = 100
        hudNode.position = .zero
        cameraNode.addChild(hudNode)
        
        // 1. Серця (життя) ліворуч зверху
        let heartSize = CGSize(width: 28.0, height: 28.0)
        let spacing: CGFloat = 34.0
        let startX: CGFloat = -(size.width / 2.0) + 36.0
        let topY: CGFloat = (size.height / 2.0) - 58.0
        
        for i in 0..<GameScene.maxLives {
            let heart = SKSpriteNode(imageNamed: currentTheme.heartTextureName)
            heart.size = heartSize
            heart.position = CGPoint(x: startX + CGFloat(i) * spacing, y: topY)
            heart.zPosition = 100
            hudNode.addChild(heart)
            heartHUDNodes.append(heart)
        }
        updateHUD(animated: false)
        
        // 2. Лічильник очок праворуч зверху
        scoreLabel = SKLabelNode(fontNamed: AppFont.name)
        scoreLabel.text = score.formattedWithSeparator
        scoreLabel.fontSize = 25
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: (size.width / 2.0) - 30.0, y: topY)
        scoreLabel.zPosition = 100
        hudNode.addChild(scoreLabel)
        
        // 3. Лічильник монет праворуч під очками
        let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
        coinIcon.size = CGSize(width: 18.0, height: 18.0)
        coinIcon.position = CGPoint(x: (size.width / 2.0) - 72.0, y: topY - 26.0)
        coinIcon.zPosition = 100
        hudNode.addChild(coinIcon)
        self.hudCoinIcon = coinIcon
        
        coinsLabel = SKLabelNode(fontNamed: AppFont.name)
        coinsLabel.text = coinsCollected.formattedWithSeparator
        coinsLabel.fontSize = 18
        coinsLabel.fontColor = SKColor(red: 1.0, green: 0.86, blue: 0.28, alpha: 1.0)
        coinsLabel.horizontalAlignmentMode = .right
        coinsLabel.verticalAlignmentMode = .center
        coinsLabel.position = CGPoint(x: (size.width / 2.0) - 30.0, y: topY - 26.0)
        coinsLabel.zPosition = 100
        hudNode.addChild(coinsLabel)
    }
    
    func updateHUD(animated: Bool = true) {
        for (index, heart) in heartHUDNodes.enumerated() {
            let hasLife = index < currentLives
            if animated {
                if hasLife && heart.alpha < 1.0 {
                    // Відновлення життя: підсвічування та плавний сплеск розміру
                    heart.removeAction(forKey: "hudAnim")
                    let scaleUp = SKAction.scale(to: 1.35, duration: 0.15)
                    let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
                    let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.2)
                    heart.run(SKAction.group([SKAction.sequence([scaleUp, scaleDown]), fadeIn]), withKey: "hudAnim")
                } else if !hasLife && heart.alpha > 0.3 {
                    // Втрата життя: тремтіння та згасання
                    heart.removeAction(forKey: "hudAnim")
                    let shakeLeft = SKAction.moveBy(x: -3.0, y: 0, duration: 0.05)
                    let shakeRight = SKAction.moveBy(x: 6.0, y: 0, duration: 0.05)
                    let shakeBack = SKAction.moveBy(x: -3.0, y: 0, duration: 0.05)
                    let fadeOut = SKAction.fadeAlpha(to: 0.25, duration: 0.25)
                    heart.run(SKAction.group([SKAction.sequence([shakeLeft, shakeRight, shakeBack]), fadeOut]), withKey: "hudAnim")
                }
            } else {
                heart.alpha = hasLife ? 1.0 : 0.25
                heart.xScale = 1.0
                heart.yScale = 1.0
            }
        }
    }
    
    /// Візуальний сплеск очок при збільшенні складності кожні 100 очок (без текстового банера)
    func celebrateLevelUp(level: Int) {
        // Анімація сплеску тексту очок
        scoreLabel.removeAction(forKey: "pulseScore")
        let scaleUp = SKAction.scale(to: 1.45, duration: 0.18)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.18)
        scoreLabel.run(SKAction.sequence([scaleUp, scaleDown]), withKey: "pulseScore")
    }
    

}
