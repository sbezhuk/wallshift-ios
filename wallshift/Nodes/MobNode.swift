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
        static let detectionRangeY: CGFloat = 460.0
        static let telegraphDuration: TimeInterval = 0.35
        static let volleyDelay: TimeInterval = 0.80
        static let leadAheadY: CGFloat = 80.0
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
    private var currentLeadAheadY: CGFloat = Constants.leadAheadY
    
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
    
    // Кеш екшенів ходьби для виключення виділення пам'яті під час спавну мобів
    private static var walkActionCache: [ObjectIdentifier: SKAction] = [:]
    
    static func cachedWalkAction(for textures: [SKTexture]) -> SKAction? {
        guard let first = textures.first else { return nil }
        let key = ObjectIdentifier(first)
        if let cached = walkActionCache[key] {
            return cached
        }
        let action = SKAction.repeatForever(
            SKAction.animate(with: textures, timePerFrame: Constants.timePerFrame, resize: false, restore: true)
        )
        walkActionCache[key] = action
        return action
    }
    
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
        // 1. Анімація циклічної ходьби власного набору спрайтів моба (використовуємо кешований екшен)
        guard !activeWalkTextures.isEmpty,
              let walkAction = MobNode.cachedWalkAction(for: activeWalkTextures) else { return }
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
    /// Оновлення перевірки присутності гравця та ініціація серії пострілів.
    /// Усі параметри (радіус реакції, кулдаун, затримка перед пострілом, упередження)
    /// динамічно адаптуються під поточну швидкість гри, щоб моб залишався небезпечним суперником.
    func updateShooting(
        playerPosition: CGPoint,
        playerIsOnLeftWall: Bool,
        playerIsJumping: Bool,
        currentTime: TimeInterval,
        isDodgeSafe: Bool = true,
        canDoubleShot: Bool = false,
        gameSpeed: CGFloat = 290.0
    ) {
        // Оновлюємо найсвіжіші координати цілі щокадру
        self.lastPlayerPosition = playerPosition
        self.lastPlayerIsOnLeftWall = playerIsOnLeftWall
        
        guard mobType == .shooter, !isAttacking else { return }
        
        // Гравець повинен бігти по тій самій стіні, захищаючи яку моб здійснює постріл,
        // щоб гравець мав змогу ухилитися стрибком на протилежну чисту стіну
        guard playerIsOnLeftWall == self.isOnLeftWall else { return }
        
        // Якщо навпроти гравця прірва чи інший моб і йому нікуди стрибнути для ухилення — утримуємо вогонь
        guard isDodgeSafe else { return }
        
        // Динамічний радіус виявлення: на високій швидкості моб реагує раніше, не даючи гравцю пролетіти повз
        let speedFactor = max(0, gameSpeed - 290.0)
        let dynamicDetectionRange = min(760.0, Constants.detectionRangeY + (speedFactor * 0.50))
        
        // 1. Гравець повинен знаходитися в зоні досяжності каньйону (наближається знизу)
        let verticalDistance = position.y - playerPosition.y
        guard verticalDistance > 80.0 && verticalDistance <= dynamicDetectionRange else { return }
        
        // Якщо гравець на тій самій стіні, але вже занадто близько — не стріляємо, щоб дати шанс оббігти/перестрибнути
        if verticalDistance < 140.0 {
            return
        }
        
        // Динамічний кулдаун: на надвисокій швидкості гри плавно скорочується до 1.2 с
        let dynamicCooldown = max(1.20, Constants.shotCooldown - Double(speedFactor / 350.0))
        guard currentTime - lastShotTime >= dynamicCooldown else { return }
        
        // Динамічні часові інтервали атаки під поточну швидкість гри
        let dynamicTelegraph = max(0.14, Constants.telegraphDuration - Double(speedFactor / 1100.0))
        let dynamicVolleyDelay = max(0.38, Constants.volleyDelay - Double(speedFactor / 700.0))
        let dynamicLead = min(170.0, Constants.leadAheadY + (speedFactor * 0.18))
        
        // 3. Запуск серії пострілів (1 постріл на початкових рівнях, максимум 2 на високих)
        triggerAttackVolley(
            currentTime: currentTime,
            totalShots: canDoubleShot ? 2 : 1,
            telegraph: dynamicTelegraph,
            volleyDelay: dynamicVolleyDelay,
            leadAheadY: dynamicLead
        )
    }
    
    /// Підготовка та здійснення серії пострілів з динамічно збалансованими інтервалами
    private func triggerAttackVolley(
        currentTime: TimeInterval,
        totalShots: Int,
        telegraph: TimeInterval,
        volleyDelay: TimeInterval,
        leadAheadY: CGFloat
    ) {
        guard !isAttacking else { return }
        isAttacking = true
        lastShotTime = currentTime
        self.currentLeadAheadY = leadAheadY
        
        // Сповільнюємо рух патрулювання на час атаки
        action(forKey: "patrolMovement")?.speed = 0.35
        
        var actions: [SKAction] = []
        
        for shotIndex in 0..<totalShots {
            // Затримка реакції перед першим пострілом або інтервал перед другим
            if shotIndex == 0 {
                actions.append(SKAction.wait(forDuration: telegraph))
            } else {
                actions.append(SKAction.wait(forDuration: volleyDelay))
            }
            
            // Випуск снаряду зі свіжими координатами цілі
            let fireAction = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.fireSingleProjectile()
            }
            actions.append(fireAction)
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
            // На протилежній стіні: стріляємо з адаптивним упередженням по швидкості
            let targetY = min(self.lastPlayerPosition.y + currentLeadAheadY, self.position.y - 30.0)
            aimTarget = CGPoint(x: self.lastPlayerPosition.x, y: targetY)
        }
        
        self.onShootArrow?(spawnPoint, aimTarget)
    }
}
