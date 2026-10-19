//
//  MobNode.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit

// MARK: - MobNode
/// Процедурний ворожий моб (Seer), що патрулює стіну каньйону від точки А до точки Б
final class MobNode: SKSpriteNode {
    
    // MARK: - Constants
    enum Constants {
        static let visualSize = CGSize(width: 78.0, height: 78.0)
        
        // Відстань від центру ноди до підошви ніг персонажа на стіні
        static let footOffset: CGFloat = 26.0
        
        // Хітбокс для зіткнення з гравцем (комфортний та чесний)
        static let hitboxSize = CGSize(width: 36.0, height: 46.0)
        
        // Швидкість зміни кадрів анімації ходьби (24 кадри за ~1.08 с)
        static let timePerFrame: TimeInterval = 0.045
        static let frameCount: Int = 24
        static let framePrefix: String = "seer_walk_"
    }
    
    // MARK: - Properties
    let isOnLeftWall: Bool
    let pointAY: CGFloat
    let pointBY: CGFloat
    let patrolSpeed: CGFloat
    
    private(set) var isMovingUp: Bool = true
    
    // Кешовані текстури анімації ходьби моба (завантажуються з Assets/Sprites/Enemies/seer_walk_X)
    private static let walkTextures: [SKTexture] = {
        var textures: [SKTexture] = []
        for i in 0..<Constants.frameCount {
            let name = "\(Constants.framePrefix)\(i)"
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            textures.append(texture)
        }
        return textures
    }()
    
    // MARK: - Initialization
    init(isOnLeftWall: Bool, wallX: CGFloat, pointAY: CGFloat, pointBY: CGFloat, patrolSpeed: CGFloat) {
        self.isOnLeftWall = isOnLeftWall
        self.pointAY = min(pointAY, pointBY)
        self.pointBY = max(pointAY, pointBY)
        self.patrolSpeed = patrolSpeed
        
        let initialTexture = MobNode.walkTextures.first ?? SKTexture()
        super.init(texture: initialTexture, color: .clear, size: Constants.visualSize)
        
        name = "MobNode"
        zPosition = 4.5
        
        // Початкова позиція в точці А на відповідній стіні
        position = CGPoint(x: wallX, y: self.pointAY)
        
        setupPhysics()
        updateOrientation(movingUp: true)
        startPatrol()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Physics Setup
    private func setupPhysics() {
        let body = SKPhysicsBody(rectangleOf: Constants.hitboxSize)
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.obstacle
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        self.physicsBody = body
    }
    
    // MARK: - Orientation Logic
    /// Орієнтація моба на вертикальній стіні:
    /// Ноги впираються у скелю, голова спрямована в глибину каньйону.
    /// - Рух вгору (до точки Б): обличчя повернуто вгору по стіні.
    /// - Рух вниз (до точки А): обличчя розвертається вниз по стіні.
    func updateOrientation(movingUp: Bool) {
        self.isMovingUp = movingUp
        if isOnLeftWall {
            zRotation = -.pi / 2.0
            xScale = movingUp ? -1.0 : 1.0
            yScale = 1.0
        } else {
            zRotation = .pi / 2.0
            xScale = movingUp ? 1.0 : -1.0
            yScale = 1.0
        }
    }
    
    // MARK: - Patrol & Walk Animation
    /// Запуск циклу безперервного патрулювання між точкою А та точкою Б
    private func startPatrol() {
        // 1. Анімація циклічної ходьби Seer
        guard !MobNode.walkTextures.isEmpty else { return }
        let walkAction = SKAction.repeatForever(
            SKAction.animate(with: MobNode.walkTextures, timePerFrame: Constants.timePerFrame, resize: false, restore: true)
        )
        run(walkAction, withKey: "walkAnimation")
        
        // 2. Механіка руху між точками А та Б
        let distance = pointBY - pointAY
        guard distance > 0, patrolSpeed > 0 else { return }
        let travelDuration = TimeInterval(distance / patrolSpeed)
        
        let moveToB = SKAction.sequence([
            SKAction.run { [weak self] in self?.updateOrientation(movingUp: true) },
            SKAction.moveTo(y: pointBY, duration: travelDuration)
        ])
        moveToB.timingMode = .easeInEaseOut
        
        let pauseAtB = SKAction.wait(forDuration: 0.15)
        
        let moveToA = SKAction.sequence([
            SKAction.run { [weak self] in self?.updateOrientation(movingUp: false) },
            SKAction.moveTo(y: pointAY, duration: travelDuration)
        ])
        moveToA.timingMode = .easeInEaseOut
        
        let pauseAtA = SKAction.wait(forDuration: 0.15)
        
        let patrolSequence = SKAction.sequence([moveToB, pauseAtB, moveToA, pauseAtA])
        run(SKAction.repeatForever(patrolSequence), withKey: "patrolMovement")
    }
}
