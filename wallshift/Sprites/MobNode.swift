//
//  MobNode.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit

// MARK: - MobNode
/// Процедурний ворожий моб, що патрулює стіну каньйону від точки А до точки Б.
/// Підтримує два типи:
/// - `patroller`: початковий моб із базовим спрайтом (seer_walk_X), що патрулює стіну;
/// - `shooter`: новий моб із власним спрайтом ходьби (shooter_walk_X з каталогу mob_walk),
///   який при появі гравця на своїй стіні випускає вогняну стрілу (FireArrowNode).
final class MobNode: SKSpriteNode {
    
    // MARK: - Mob Type
    enum MobType {
        case patroller
        case shooter
    }
    
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
        
        // Префікси текстур для кожного моба
        static let patrollerPrefix: String = "seer_walk_"
        static let shooterPrefix: String = "shooter_walk_"
        
        // Параметри стрільби
        static let shotCooldown: TimeInterval = 2.4
        static let detectionRangeY: CGFloat = 360.0
        static let telegraphDuration: TimeInterval = 0.55
    }
    
    // MARK: - Properties
    let mobType: MobType
    let isOnLeftWall: Bool
    let pointAY: CGFloat
    let pointBY: CGFloat
    let patrolSpeed: CGFloat
    
    private(set) var isMovingUp: Bool = true
    private(set) var isAttacking: Bool = false
    private var lastShotTime: TimeInterval = 0
    
    /// Колбек для створення та додавання вогняної стріли у сцену
    var onShootArrow: ((_ startPosition: CGPoint, _ targetPosition: CGPoint) -> Void)?
    
    // Кешовані текстури ходьби старого моба (патрульного)
    private static let patrollerWalkTextures: [SKTexture] = {
        var textures: [SKTexture] = []
        for i in 0..<Constants.frameCount {
            let name = "\(Constants.patrollerPrefix)\(i)"
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            textures.append(texture)
        }
        return textures
    }()
    
    // Кешовані текстури ходьби нового моба (стрільця з mob_walk)
    private static let shooterWalkTextures: [SKTexture] = {
        var textures: [SKTexture] = []
        for i in 0..<Constants.frameCount {
            let name = "\(Constants.shooterPrefix)\(i)"
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            textures.append(texture)
        }
        return textures
    }()
    
    /// Текстури ходьби конкретного екземпляра моба відповідно до його типу
    private let activeWalkTextures: [SKTexture]
    
    // MARK: - Initialization
    init(
        mobType: MobType = .patroller,
        isOnLeftWall: Bool,
        wallX: CGFloat,
        pointAY: CGFloat,
        pointBY: CGFloat,
        patrolSpeed: CGFloat,
        customTextures: [SKTexture]? = nil
    ) {
        self.mobType = mobType
        self.isOnLeftWall = isOnLeftWall
        self.pointAY = min(pointAY, pointBY)
        self.pointBY = max(pointAY, pointBY)
        self.patrolSpeed = patrolSpeed
        
        // Вибираємо відповідний набір спрайтів: кастомний за темою або стандартний
        let textures: [SKTexture]
        if let custom = customTextures, !custom.isEmpty {
            textures = custom
        } else {
            textures = (mobType == .shooter) ? MobNode.shooterWalkTextures : MobNode.patrollerWalkTextures
        }
        self.activeWalkTextures = textures
        
        let initialTexture = textures.first ?? SKTexture()
        super.init(texture: initialTexture, color: .clear, size: Constants.visualSize)
        
        name = mobType == .shooter ? "ShooterMobNode" : "MobNode"
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
        // 1. Анімація циклічної ходьби власного набору спрайтів моба
        guard !activeWalkTextures.isEmpty else { return }
        let walkAction = SKAction.repeatForever(
            SKAction.animate(with: activeWalkTextures, timePerFrame: Constants.timePerFrame, resize: false, restore: true)
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
    
    // MARK: - Shooting Logic
    /// Оновлення перевірки присутності гравця на тій самій стіні та ініціація пострілу
    func updateShooting(
        playerPosition: CGPoint,
        playerIsOnLeftWall: Bool,
        playerIsJumping: Bool,
        currentTime: TimeInterval,
        isDodgeSafe: Bool = true
    ) {
        guard mobType == .shooter, !isAttacking else { return }
        
        // 1. Гравець повинен бігти по тій самій стіні, де ходить моб
        guard playerIsOnLeftWall == self.isOnLeftWall else { return }
        
        // 2. Гравець не в польоті під час стрибка
        guard !playerIsJumping else { return }
        
        // 3. Чесність ухилення: протилежна стіна ОБОВ'ЯЗКОВО безпечна для стрибка (без прірв)
        guard isDodgeSafe else { return }
        
        // 4. Гравець знаходиться нижче моба (наближається) у зоні видимості/досяжності
        let verticalDistance = position.y - playerPosition.y
        guard verticalDistance > 35.0 && verticalDistance <= Constants.detectionRangeY else { return }
        
        // 5. Перевірка кулдауну між пострілами
        guard currentTime - lastShotTime >= Constants.shotCooldown else { return }
        
        // Запуск підготовки та пострілу стріли
        triggerAttack(towards: playerPosition, currentTime: currentTime)
    }
    
    /// Підготовка та здійснення пострілу з виразним візуальним телеграфом для комфортного ухилення
    private func triggerAttack(towards targetPosition: CGPoint, currentTime: TimeInterval) {
        guard !isAttacking else { return }
        isAttacking = true
        lastShotTime = currentTime
        
        // Сповільнюємо рух патрулювання на час прицілювання
        action(forKey: "patrolMovement")?.speed = 0.2
        
        // Візуальний телеграф: пульсуючий спалах прицілювання
        let chargeGlow = SKShapeNode(circleOfRadius: 20.0)
        chargeGlow.fillColor = SKColor(red: 1.0, green: 0.35, blue: 0.05, alpha: 0.8)
        chargeGlow.strokeColor = SKColor(red: 1.0, green: 0.90, blue: 0.2, alpha: 1.0)
        chargeGlow.lineWidth = 2.5
        chargeGlow.blendMode = .add
        chargeGlow.zPosition = 6.0
        addChild(chargeGlow)
        
        let pulse1 = SKAction.scale(to: 1.45, duration: 0.22)
        let pulse2 = SKAction.scale(to: 1.0, duration: 0.15)
        let pulse3 = SKAction.scale(to: 1.6, duration: 0.18)
        let fadeOut = SKAction.fadeOut(withDuration: 0.06)
        let remove = SKAction.removeFromParent()
        chargeGlow.run(SKAction.sequence([pulse1, pulse2, pulse3, fadeOut, remove]))
        
        // Достатній час затримки (~0.55 с), щоб гравець встиг спокійно оцінити ситуацію та стрибнути
        let waitToShoot = SKAction.wait(forDuration: Constants.telegraphDuration)
        let shootAction = SKAction.run { [weak self] in
            guard let self = self else { return }
            
            // Випускаємо стрілу вниз вздовж стіни у бік гравця
            let shootOffsetY: CGFloat = -26.0
            let spawnPoint = CGPoint(x: self.position.x, y: self.position.y + shootOffsetY)
            let aimTarget = CGPoint(x: self.position.x, y: self.position.y - 400.0)
            
            self.onShootArrow?(spawnPoint, aimTarget)
            
            // Відновлюємо нормальний темп ходьби
            self.action(forKey: "patrolMovement")?.speed = 1.0
            self.isAttacking = false
        }
        
        run(SKAction.sequence([waitToShoot, shootAction]), withKey: "shootingSequence")
    }
}
