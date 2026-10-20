//
//  FireArrowNode.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit

// MARK: - FireArrowNode
/// Вогняна стріла, яку випускає моб-стрілець при появі гравця на тій самій стіні
final class FireArrowNode: SKSpriteNode {
    
    // MARK: - Constants
    enum Constants {
        static let visualSize = CGSize(width: 54.0, height: 26.0)
        static let hitboxSize = CGSize(width: 28.0, height: 14.0)
        static let frameCount: Int = 8
        static let framePrefix: String = "fire_arrow_"
        static let timePerFrame: TimeInterval = 0.045
        static let defaultSpeed: CGFloat = 300.0
    }
    
    // MARK: - Properties
    let projectileType: ProjectileType
    private(set) var isExploded: Bool = false
    
    // Кешовані текстури вогняної стріли
    private static let fireArrowTextures: [SKTexture] = {
        var textures: [SKTexture] = []
        for i in 0..<Constants.frameCount {
            let name = "\(Constants.framePrefix)\(i)"
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            textures.append(texture)
        }
        return textures
    }()
    
    // Кешовані текстури водяної стріли
    private static let waterArrowTextures: [SKTexture] = {
        var textures: [SKTexture] = []
        for i in 0..<8 {
            let name = "water_arrow_\(i)"
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            textures.append(texture)
        }
        return textures
    }()
    
    private var activeTextures: [SKTexture] {
        return projectileType == .water ? FireArrowNode.waterArrowTextures : FireArrowNode.fireArrowTextures
    }
    
    // MARK: - Initialization
    init(from startPosition: CGPoint, towards targetPosition: CGPoint, projectileType: ProjectileType = .fire, speed: CGFloat = Constants.defaultSpeed) {
        self.projectileType = projectileType
        let textures = (projectileType == .water) ? FireArrowNode.waterArrowTextures : FireArrowNode.fireArrowTextures
        let initialTexture = textures.first ?? SKTexture()
        super.init(texture: initialTexture, color: .clear, size: Constants.visualSize)
        
        name = "FireArrowNode"
        zPosition = 7.0
        position = startPosition
        
        // Розрахунок кута польоту (вихідний спрайт стріли спрямований праворуч)
        let dx = targetPosition.x - startPosition.x
        let dy = targetPosition.y - startPosition.y
        let distance = hypot(dx, dy)
        let angle = atan2(dy, dx)
        zRotation = angle
        
        setupPhysics()
        setupFlameGlow()
        startFlight(distance: distance, dx: dx, dy: dy, speed: speed)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Physics Setup
    private func setupPhysics() {
        // Хітбокс зміщений ближче до наконечника стріли
        let body = SKPhysicsBody(rectangleOf: Constants.hitboxSize, center: CGPoint(x: 4.0, y: 0.0))
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.obstacle
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        self.physicsBody = body
    }
    
    // MARK: - Visual Glow
    private func setupFlameGlow() {
        let glowNode = SKShapeNode(ellipseOf: CGSize(width: Constants.visualSize.width * 0.9, height: Constants.visualSize.height * 0.8))
        if projectileType == .water {
            glowNode.fillColor = SKColor(red: 0.15, green: 0.70, blue: 1.0, alpha: 0.35)
        } else {
            glowNode.fillColor = SKColor(red: 1.0, green: 0.45, blue: 0.1, alpha: 0.28)
        }
        glowNode.strokeColor = .clear
        glowNode.zPosition = -1.0
        glowNode.blendMode = .add
        addChild(glowNode)
    }
    
    // MARK: - Flight & Animation
    private func startFlight(distance: CGFloat, dx: CGFloat, dy: CGFloat, speed: CGFloat) {
        // 1. Анімація мерехтіння стріли
        if !activeTextures.isEmpty {
            let animateAction = SKAction.repeatForever(
                SKAction.animate(with: activeTextures, timePerFrame: Constants.timePerFrame, resize: false, restore: true)
            )
            run(animateAction, withKey: "flameAnimation")
        }
        
        // 2. Політ стріли вздовж траєкторії на безпечну відстань поза екран (~1100 pt)
        let totalFlightDistance: CGFloat = max(1100.0, distance + 400.0)
        let flightDuration = TimeInterval(totalFlightDistance / max(speed, 100.0))
        
        let unitX = distance > 0 ? (dx / distance) : 0
        let unitY = distance > 0 ? (dy / distance) : -1.0
        
        let moveAction = SKAction.moveBy(
            x: unitX * totalFlightDistance,
            y: unitY * totalFlightDistance,
            duration: flightDuration
        )
        
        let sequence = SKAction.sequence([
            moveAction,
            SKAction.removeFromParent()
        ])
        run(sequence, withKey: "flightAction")
    }
    
    // MARK: - Explosion / Impact
    /// Візуальний вибух полум'я або водяний сплеск при попаданні в героя або перешкоду
    func explodeAndRemove() {
        guard !isExploded else { return }
        isExploded = true
        
        // Вимикаємо фізику, щоб уникнути повторного контакту
        physicsBody = nil
        removeAction(forKey: "flightAction")
        removeAction(forKey: "flameAnimation")
        
        // Спалах полум'я / води
        let burst = SKShapeNode(circleOfRadius: 18.0)
        if projectileType == .water {
            burst.fillColor = SKColor(red: 0.2, green: 0.85, blue: 1.0, alpha: 0.8)
            burst.strokeColor = SKColor(red: 0.7, green: 0.95, blue: 1.0, alpha: 1.0)
        } else {
            burst.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.8)
            burst.strokeColor = SKColor.yellow
        }
        burst.lineWidth = 2.0
        burst.zPosition = 8.0
        burst.blendMode = .add
        addChild(burst)
        
        let expand = SKAction.scale(to: 1.6, duration: 0.16)
        let fade = SKAction.fadeOut(withDuration: 0.16)
        let scaleDownSelf = SKAction.scale(to: 0.4, duration: 0.16)
        
        burst.run(SKAction.group([expand, fade]))
        run(SKAction.sequence([
            SKAction.group([scaleDownSelf, SKAction.fadeOut(withDuration: 0.16)]),
            SKAction.removeFromParent()
        ]))
    }
}
