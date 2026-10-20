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
        static let shotCooldown: TimeInterval = 1.3
        static let detectionRangeY: CGFloat = 580.0
        static let telegraphDuration: TimeInterval = 0.38
        static let volleyDelay: TimeInterval = 0.44
        static let leadAheadY: CGFloat = 180.0
    }
    
    // MARK: - Properties
    let mobType: MobType
    let isOnLeftWall: Bool
    let pointAY: CGFloat
    let pointBY: CGFloat
    let patrolSpeed: CGFloat
    let projectileType: ProjectileType
    
    private(set) var isMovingUp: Bool = true
    private(set) var isAttacking: Bool = false
    private var lastShotTime: TimeInterval = 0
    private var lastPlayerPosition: CGPoint = .zero
    private var lastPlayerIsOnLeftWall: Bool = true
    
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
        customTextures: [SKTexture]? = nil,
        projectileType: ProjectileType = .fire
    ) {
        self.mobType = mobType
        self.isOnLeftWall = isOnLeftWall
        self.pointAY = min(pointAY, pointBY)
        self.pointBY = max(pointAY, pointBY)
        self.patrolSpeed = patrolSpeed
        self.projectileType = projectileType
        
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
    /// Оновлення перевірки присутності гравця та ініціація серії пострілів
    func updateShooting(
        playerPosition: CGPoint,
        playerIsOnLeftWall: Bool,
        playerIsJumping: Bool,
        currentTime: TimeInterval,
        isDodgeSafe: Bool = true
    ) {
        // Оновлюємо найсвіжіші координати цілі щокадру
        self.lastPlayerPosition = playerPosition
        self.lastPlayerIsOnLeftWall = playerIsOnLeftWall
        
        guard mobType == .shooter, !isAttacking else { return }
        
        // 1. Гравець повинен знаходитися в зоні досяжності каньйону (наближається знизу або біжить поруч)
        let verticalDistance = position.y - playerPosition.y
        guard verticalDistance > -90.0 && verticalDistance <= Constants.detectionRangeY else { return }
        
        // 2. Перевірка кулдауну між серіями пострілів
        guard currentTime - lastShotTime >= Constants.shotCooldown else { return }
        
        // 3. Запуск серії пострілів
        triggerAttackVolley(currentTime: currentTime)
    }
    
    /// Підготовка та здійснення серії пострілів (черги) з упередженням на випередження
    private func triggerAttackVolley(currentTime: TimeInterval) {
        guard !isAttacking else { return }
        isAttacking = true
        lastShotTime = currentTime
        
        // Сповільнюємо рух патрулювання на час атаки
        action(forKey: "patrolMovement")?.speed = 0.25
        
        // Кількість пострілів у черзі (2-3 постріли)
        let totalShots = Int.random(in: 2...3)
        var actions: [SKAction] = []
        
        for shotIndex in 0..<totalShots {
            let prepDuration: TimeInterval = (shotIndex == 0) ? Constants.telegraphDuration : 0.28
            
            // Візуальний телеграф: пульсуючий спалах прицілювання
            let chargeAction = SKAction.run { [weak self] in
                self?.showChargeGlow(scale: shotIndex == 0 ? 1.5 : 1.3)
            }
            actions.append(chargeAction)
            actions.append(SKAction.wait(forDuration: prepDuration))
            
            // Сам випуск снаряду зі свіжими координатами цілі
            let fireAction = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.fireSingleProjectile()
            }
            actions.append(fireAction)
            
            // Інтервал між пострілами всередині черги
            if shotIndex < totalShots - 1 {
                actions.append(SKAction.wait(forDuration: Constants.volleyDelay))
            }
        }
        
        // Завершення серії: відновлюємо нормальний темп ходьби
        let finishAction = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.action(forKey: "patrolMovement")?.speed = 1.0
            self.isAttacking = false
        }
        actions.append(finishAction)
        
        run(SKAction.sequence(actions), withKey: "shootingSequence")
    }
    
    /// Створення та випуск окремого снаряду з динамічним упередженням по гравцю
    private func fireSingleProjectile() {
        guard parent != nil else { return }
        
        let shootOffsetY: CGFloat = -20.0
        let spawnPoint = CGPoint(x: self.position.x, y: self.position.y + shootOffsetY)
        
        let isSameWall = (self.lastPlayerIsOnLeftWall == self.isOnLeftWall)
        let aimTarget: CGPoint
        
        if isSameWall {
            // На тій самій стіні: стріла летить уздовж стіни вниз назустріч гравцю
            aimTarget = CGPoint(x: self.position.x, y: self.position.y - 450.0)
        } else {
            // На протилежній стіні: стріляємо НАПЕРЕД (на випередження руху гравця вгору)
            let leadY = Constants.leadAheadY
            let targetY = max(self.lastPlayerPosition.y + leadY, self.position.y - 60.0)
            aimTarget = CGPoint(x: self.lastPlayerPosition.x, y: targetY)
        }
        
        self.onShootArrow?(spawnPoint, aimTarget)
    }
    
    /// Візуальний пульсуючий спалах прицілювання відповідно до типу магії снаряда
    private func showChargeGlow(scale: CGFloat) {
        let chargeGlow = SKShapeNode(circleOfRadius: 22.0)
        if projectileType == .water {
            chargeGlow.fillColor = SKColor(red: 0.15, green: 0.75, blue: 1.0, alpha: 0.85)
            chargeGlow.strokeColor = SKColor(red: 0.60, green: 0.90, blue: 1.0, alpha: 1.0)
        } else {
            chargeGlow.fillColor = SKColor(red: 1.0, green: 0.35, blue: 0.05, alpha: 0.85)
            chargeGlow.strokeColor = SKColor(red: 1.0, green: 0.90, blue: 0.20, alpha: 1.0)
        }
        chargeGlow.lineWidth = 2.5
        chargeGlow.blendMode = .add
        chargeGlow.zPosition = 6.0
        addChild(chargeGlow)
        
        let pulse1 = SKAction.scale(to: scale, duration: 0.14)
        let pulse2 = SKAction.scale(to: 1.0, duration: 0.10)
        let pulse3 = SKAction.scale(to: scale * 1.1, duration: 0.10)
        let fadeOut = SKAction.fadeOut(withDuration: 0.05)
        let remove = SKAction.removeFromParent()
        chargeGlow.run(SKAction.sequence([pulse1, pulse2, pulse3, fadeOut, remove]))
    }
}
