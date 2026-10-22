//
//  CoinNode.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit

// MARK: - CoinNode
/// Вузол золотистої монети з плавною 6-кадровою анімацією обертання
final class CoinNode: SKSpriteNode {
    
    // MARK: - Constants
    enum Constants {
        static let visualSize = CGSize(width: 26.0, height: 26.0)
        static let collisionRadius: CGFloat = 16.0
        static let timePerFrame: TimeInterval = 0.08
    }
    
    // MARK: - Properties
    private(set) var isCollected: Bool = false
    
    // Кешовані текстури анімації обертання монети під кожну тему
    private static var themeTexturesCache: [String: [SKTexture]] = [:]
    private static var themeActionCache: [String: SKAction] = [:]
    
    static func textures(for theme: ThemeData) -> [SKTexture] {
        if let cached = themeTexturesCache[theme.id] {
            return cached
        }
        var textures: [SKTexture] = []
        for i in 0..<theme.coinFrameCount {
            let name = "\(theme.coinTexturePrefix)\(i)"
            let tex = SKTexture(imageNamed: name)
            tex.filteringMode = .linear
            textures.append(tex)
        }
        // Безпечний фолбек на класичні монети у разі потреби
        if textures.isEmpty {
            for i in 0..<6 {
                textures.append(SKTexture(imageNamed: "coin_\(i)"))
            }
        }
        themeTexturesCache[theme.id] = textures
        return textures
    }
    
    static func spinAction(for theme: ThemeData) -> SKAction {
        if let cached = themeActionCache[theme.id] {
            return cached
        }
        let textures = textures(for: theme)
        let action = SKAction.repeatForever(
            SKAction.animate(with: textures, timePerFrame: Constants.timePerFrame, resize: false, restore: true)
        )
        themeActionCache[theme.id] = action
        return action
    }
    
    // MARK: - Initialization
    init(theme: ThemeData = ThemeManager.shared.currentTheme) {
        let textures = CoinNode.textures(for: theme)
        let initialTexture = textures.first ?? SKTexture()
        super.init(texture: initialTexture, color: .clear, size: Constants.visualSize)
        
        name = "CoinNode"
        zPosition = 4.2
        setupPhysics()
        startSpinAnimation(theme: theme)
    }
    
    required init?(coder aDecoder: NSCoder) {
        let theme = ThemeManager.shared.currentTheme
        let textures = CoinNode.textures(for: theme)
        let initialTexture = textures.first ?? SKTexture()
        super.init(texture: initialTexture, color: .clear, size: Constants.visualSize)
        name = "CoinNode"
        zPosition = 4.2
        setupPhysics()
        startSpinAnimation(theme: theme)
    }
    
    // MARK: - Physics Setup
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: Constants.collisionRadius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.coin
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        self.physicsBody = body
    }
    
    // MARK: - Animations
    private func startSpinAnimation(theme: ThemeData) {
        let action = CoinNode.spinAction(for: theme)
        run(action, withKey: "coinSpin")
    }
    
    /// Анімація підбору монети з ефектом сплеску та розчинення
    func collect(completion: (() -> Void)? = nil) {
        guard !isCollected else { return }
        isCollected = true
        physicsBody = nil
        removeAction(forKey: "coinSpin")
        
        let scaleUp = SKAction.scale(to: 1.45, duration: 0.10)
        let moveUp = SKAction.moveBy(x: 0, y: 18.0, duration: 0.22)
        let fadeOut = SKAction.fadeOut(withDuration: 0.16)
        let remove = SKAction.removeFromParent()
        
        run(SKAction.sequence([
            SKAction.group([scaleUp, moveUp, fadeOut]),
            remove,
            SKAction.run { completion?() }
        ]))
    }
}
