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
        static let frameCount: Int = 6
        static let framePrefix: String = "coin_"
    }
    
    // MARK: - Properties
    private(set) var isCollected: Bool = false
    
    // Кешовані текстури анімації обертання монети (Assets/Sprites/Items/Coins/coin_X)
    private static let spinTextures: [SKTexture] = {
        var textures: [SKTexture] = []
        for i in 0..<Constants.frameCount {
            let name = "\(Constants.framePrefix)\(i)"
            let tex = SKTexture(imageNamed: name)
            tex.filteringMode = .linear
            textures.append(tex)
        }
        return textures
    }()
    
    private static let spinAction: SKAction = {
        return SKAction.repeatForever(
            SKAction.animate(with: CoinNode.spinTextures, timePerFrame: Constants.timePerFrame, resize: false, restore: true)
        )
    }()
    
    // MARK: - Initialization
    init() {
        let initialTexture = CoinNode.spinTextures.first ?? SKTexture()
        super.init(texture: initialTexture, color: .clear, size: Constants.visualSize)
        
        name = "CoinNode"
        zPosition = 4.2
        setupPhysics()
        startSpinAnimation()
    }
    
    required init?(coder aDecoder: NSCoder) {
        let initialTexture = CoinNode.spinTextures.first ?? SKTexture()
        super.init(texture: initialTexture, color: .clear, size: Constants.visualSize)
        name = "CoinNode"
        zPosition = 4.2
        setupPhysics()
        startSpinAnimation()
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
    private func startSpinAnimation() {
        guard !CoinNode.spinTextures.isEmpty else { return }
        run(CoinNode.spinAction, withKey: "coinSpin")
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
