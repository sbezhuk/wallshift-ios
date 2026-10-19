//
//  HeartItemNode.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit

// MARK: - HeartItemNode
/// Вузол додаткового життя (серця), яке можна зібрати на карті для відновлення втраченого життя
final class HeartItemNode: SKSpriteNode {
    
    // MARK: - Constants
    enum Constants {
        static let visualSize = CGSize(width: 32.0, height: 32.0)
        static let collisionRadius: CGFloat = 20.0
    }
    
    // MARK: - Properties
    private(set) var isCollected: Bool = false
    
    // MARK: - Initialization
    init() {
        let texture = SKTexture(imageNamed: "life_hearth")
        super.init(texture: texture, color: .clear, size: Constants.visualSize)
        
        name = "HeartItemNode"
        zPosition = 4
        setupPhysics()
        startIdleAnimation()
    }
    
    required init?(coder aDecoder: NSCoder) {
        let texture = SKTexture(imageNamed: "life_hearth")
        super.init(texture: texture, color: .clear, size: Constants.visualSize)
        name = "HeartItemNode"
        zPosition = 4
        setupPhysics()
        startIdleAnimation()
    }
    
    // MARK: - Physics
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: Constants.collisionRadius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.heart
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        self.physicsBody = body
    }
    
    // MARK: - Animations
    
    /// Плавна анімація ширяння та легкого пульсування серця в повітрі
    private func startIdleAnimation() {
        let floatUp = SKAction.moveBy(x: 0, y: 6.0, duration: 0.6)
        floatUp.timingMode = .easeInEaseOut
        let floatDown = SKAction.moveBy(x: 0, y: -6.0, duration: 0.6)
        floatDown.timingMode = .easeInEaseOut
        let floatSequence = SKAction.sequence([floatUp, floatDown])
        
        let pulseUp = SKAction.scale(to: 1.15, duration: 0.6)
        pulseUp.timingMode = .easeInEaseOut
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.6)
        pulseDown.timingMode = .easeInEaseOut
        let pulseSequence = SKAction.sequence([pulseUp, pulseDown])
        
        let idleGroup = SKAction.group([floatSequence, pulseSequence])
        run(SKAction.repeatForever(idleGroup), withKey: "idleAnimation")
    }
    
    /// Анімація підбору серця: збільшення, підйом вгору, зникнення
    func collect(completion: (() -> Void)? = nil) {
        guard !isCollected else { return }
        isCollected = true
        
        // Вимикаємо фізичне тіло, щоб уникнути повторного контакту
        physicsBody = nil
        removeAction(forKey: "idleAnimation")
        
        let moveUp = SKAction.moveBy(x: 0, y: 32.0, duration: 0.35)
        moveUp.timingMode = .easeOut
        let scaleUp = SKAction.scale(to: 1.6, duration: 0.35)
        scaleUp.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.35)
        
        let collectGroup = SKAction.group([moveUp, scaleUp, fade])
        let remove = SKAction.removeFromParent()
        
        run(SKAction.sequence([collectGroup, remove])) {
            completion?()
        }
    }
    
    /// Підказка, коли у гравця вже 3 з 3 життів: серце легенько колихається, але не збирається
    func pulseMaxLivesHint() {
        guard action(forKey: "maxHint") == nil else { return }
        let wobbleRight = SKAction.rotate(toAngle: 0.20, duration: 0.08)
        let wobbleLeft = SKAction.rotate(toAngle: -0.20, duration: 0.08)
        let reset = SKAction.rotate(toAngle: 0.0, duration: 0.08)
        run(SKAction.sequence([wobbleRight, wobbleLeft, reset]), withKey: "maxHint")
    }
}
