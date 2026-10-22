//
//  PlayerNode.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit

// MARK: - PlayerNode
/// Окремий вузол для головного героя з інкапсуляцією анімацій, текстур та фізики бігу по стіні
final class PlayerNode: SKSpriteNode {
    
    // MARK: - Constants
    enum Constants {
        static let visualSize = CGSize(width: 84.0, height: 84.0)
        
        // Відстань від центру ноди до підошви ніг персонажа (84 * 1/3 = 28.0)
        static let footOffset: CGFloat = 28.0
        
        // Хітбокс для зіткнень з перешкодами
        static let hitboxSize = CGSize(width: 38.0, height: 50.0)
        static let timePerFrame: TimeInterval = 0.05
        
        // Параметри анімації: легко змінити кількість кадрів або префікс
        static let runningFrameCount: Int = 12
        static let runningFramePrefix: String = "run_"
    }
    
    // MARK: - Properties
    private(set) var currentState: PlayerState = .running
    
    /// Стан положення героя: true - ліва стіна, false - права стіна
    private(set) var isOnLeftWall: Bool = true
    
    /// Стан невразливості героя (під час якого він моргає та ігнорує пошкодження від прірви)
    private(set) var isInvulnerable: Bool = false
    
    var isJumping: Bool {
        return currentState == .jumping
    }
    
    var isDead: Bool {
        return currentState == .dead
    }
    
    // Кешовані текстури анімації бігу поточного персонажа
    private var activeRunningTextures: [SKTexture] = []
    
    // MARK: - Initialization
    init(prefix: String = "run_", frameCount: Int = 12) {
        var textures: [SKTexture] = []
        for i in 0..<frameCount {
            let frameName = "\(prefix)\(i)"
            let texture = SKTexture(imageNamed: frameName)
            texture.filteringMode = .linear
            textures.append(texture)
        }
        self.activeRunningTextures = textures
        let defaultTexture = textures.first ?? SKTexture()
        super.init(texture: defaultTexture, color: .clear, size: Constants.visualSize)
        
        name = "PlayerNode"
        zPosition = 5
        setupPhysicsBody()
        updateOrientation(forLeftWall: true)
        startRunningAnimation()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        name = "PlayerNode"
        zPosition = 5
        applyTheme(prefix: "run_", frameCount: 12)
        setupPhysicsBody()
        updateOrientation(forLeftWall: true)
        startRunningAnimation()
    }
    
    /// Оновлення образу персонажа (зміна скіна/теми)
    func applyTheme(prefix: String, frameCount: Int = 12) {
        var textures: [SKTexture] = []
        for i in 0..<frameCount {
            let frameName = "\(prefix)\(i)"
            let texture = SKTexture(imageNamed: frameName)
            texture.filteringMode = .linear
            textures.append(texture)
        }
        self.activeRunningTextures = textures
        if let first = textures.first {
            self.texture = first
        }
        if currentState == .running {
            startRunningAnimation()
        }
    }
    
    // MARK: - Physics Setup
    private func setupPhysicsBody() {
        let body = SKPhysicsBody(rectangleOf: Constants.hitboxSize)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.abyss | PhysicsCategory.heart | PhysicsCategory.coin
        self.physicsBody = body
    }
    
    // MARK: - Wall Running Orientation
    /// Орієнтація спрайта для бігу по вертикальній стіні:
    /// - Ліва стіна: ноги впираються в ліву стіну (-90°), напрямок бігу вгору.
    /// - Права стіна: ноги впираються в праву стіну (+90°), напрямок бігу вгору.
    func updateOrientation(forLeftWall isLeft: Bool) {
        isOnLeftWall = isLeft
        if isLeft {
            xScale = -1.0
            yScale = 1.0
            zRotation = -.pi / 2.0
        } else {
            xScale = 1.0
            yScale = 1.0
            zRotation = .pi / 2.0
        }
    }
    
    // MARK: - Animations
    
    /// Запуск циклічної анімації бігу по стіні
    func startRunningAnimation() {
        guard !activeRunningTextures.isEmpty else { return }
        
        currentState = .running
        let runAction = SKAction.repeatForever(
            SKAction.animate(with: activeRunningTextures, timePerFrame: Constants.timePerFrame, resize: false, restore: false)
        )
        run(runAction, withKey: "runAnimation")
    }
    
    /// Стійка очікування / готовності героя на стіні (без анімації кроків)
    func setReadyStance() {
        removeAction(forKey: "runAnimation")
        currentState = .idle
        if let first = activeRunningTextures.first {
            texture = first
        }
    }
    
    /// Стрибок на протилежну стіну з переворотом у повітрі
    func jump(to targetX: CGFloat, duration: TimeInterval, completion: @escaping () -> Void) {
        guard currentState != .dead else { return }
        removeAction(forKey: "landingCushion")
        self.yScale = 1.0
        currentState = .jumping
        
        // Гарантуємо чистий візуальний стан персонажа (без залишкових бліків чи напівпрозорості)
        if !isInvulnerable {
            self.alpha = 1.0
            self.color = .clear
            self.colorBlendFactor = 0.0
        }
        
        // 1. Горизонтальний рух із вибуховим стартом (.easeOut замість повільного розгону .easeInEaseOut)
        let moveX = SKAction.moveTo(x: targetX, duration: duration)
        moveX.timingMode = .easeOut
        
        // 2. Акробатичний переворот у повітрі:
        // Герой відштовхується ногами від поточної стіни, розвертається в польоті
        // та готує ноги для приземлення на протилежну стіну
        let nextIsOnLeftWall = !isOnLeftWall
        let targetRotation: CGFloat = nextIsOnLeftWall ? -.pi / 2.0 : .pi / 2.0
        let halfDuration = duration * 0.5
        
        let midAirFlip = SKAction.sequence([
            SKAction.rotate(toAngle: 0.0, duration: halfDuration),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.xScale = nextIsOnLeftWall ? -1.0 : 1.0
            },
            SKAction.rotate(toAngle: targetRotation, duration: halfDuration)
        ])
        midAirFlip.timingMode = .easeOut
        
        let flightGroup = SKAction.group([moveX, midAirFlip])
        
        // 3. Приземлення на протилежну стіну
        let landAction = SKAction.run { [weak self] in
            guard let self = self, self.currentState != .dead else { return }
            
            self.isOnLeftWall = nextIsOnLeftWall
            self.position.x = targetX
            self.updateOrientation(forLeftWall: self.isOnLeftWall)
            self.currentState = .running
            
            // Чистий рендеринг без бліків при приземленні
            if !self.isInvulnerable {
                self.alpha = 1.0
                self.color = .clear
                self.colorBlendFactor = 0.0
            }
            
            // Амортизація ногами (squash & stretch) при ударі об стіну
            let landingCushion = SKAction.sequence([
                SKAction.scaleY(to: 0.82, duration: 0.03),
                SKAction.scaleY(to: 1.0, duration: 0.06)
            ])
            self.run(landingCushion, withKey: "landingCushion")
            
            completion()
        }
        
        let fullJumpSequence = SKAction.sequence([flightGroup, landAction])
        run(fullJumpSequence, withKey: "jumpAction")
    }
    
    /// Акробатичний плавний відскок на безпечну стіну без телепортації
    func rebound(to targetX: CGFloat, onLeftWall targetIsLeft: Bool, duration: TimeInterval = 0.22, completion: (() -> Void)? = nil) {
        guard currentState != .dead else { return }
        removeAction(forKey: "landingCushion")
        self.yScale = 1.0
        removeAction(forKey: "jumpAction")
        currentState = .jumping
        self.color = .clear
        self.colorBlendFactor = 0.0
        
        let targetRotation: CGFloat = targetIsLeft ? -.pi / 2.0 : .pi / 2.0
        let halfDuration = duration * 0.5
        
        let moveX = SKAction.moveTo(x: targetX, duration: duration)
        moveX.timingMode = .easeOut
        
        let midAirFlip = SKAction.sequence([
            SKAction.rotate(toAngle: 0.0, duration: halfDuration),
            SKAction.run { [weak self] in
                self?.xScale = targetIsLeft ? -1.0 : 1.0
            },
            SKAction.rotate(toAngle: targetRotation, duration: halfDuration)
        ])
        midAirFlip.timingMode = .easeOut
        
        let flightGroup = SKAction.group([moveX, midAirFlip])
        
        let landAction = SKAction.run { [weak self] in
            guard let self = self, self.currentState != .dead else { return }
            self.isOnLeftWall = targetIsLeft
            self.position.x = targetX
            self.updateOrientation(forLeftWall: targetIsLeft)
            self.currentState = .running
            self.color = .clear
            self.colorBlendFactor = 0.0
            
            let landingCushion = SKAction.sequence([
                SKAction.scaleY(to: 0.82, duration: 0.03),
                SKAction.scaleY(to: 1.0, duration: 0.06)
            ])
            self.run(landingCushion, withKey: "landingCushion")
            
            completion?()
        }
        
        run(SKAction.sequence([flightGroup, landAction]), withKey: "jumpAction")
    }
    
    /// Падіння героя безпосередньо всередину прірви (у точку розриву між уступами скелі)
    func fallIntoAbyss(targetPoint: CGPoint, completion: @escaping () -> Void) {
        guard currentState != .dead else { return }
        currentState = .dead
        
        removeAction(forKey: "landingCushion")
        self.yScale = 1.0
        removeAction(forKey: "jumpAction")
        removeAction(forKey: "runAnimation")
        
        // Знижуємо zPosition до 2 (нижче ніж тайли скелі zPosition = 3, але вище за темний фон ями zPosition = 1)
        self.zPosition = 2
        self.color = .clear
        self.colorBlendFactor = 0.0
        
        // Політ безпосередньо в отвір прірви (туди, куди вказує розрив між уступами)
        let moveToHole = SKAction.move(to: targetPoint, duration: 0.45)
        moveToHole.timingMode = .easeIn
        
        // Обертання/перекидання під час затягування у прірву
        let spinAngle: CGFloat = isOnLeftWall ? -.pi * 2.5 : .pi * 2.5
        let rotateAction = SKAction.rotate(byAngle: spinAngle, duration: 0.45)
        rotateAction.timingMode = .easeIn
        
        // Перспективне зменшення (занурення у глибину чорної ями)
        let targetXScale: CGFloat = isOnLeftWall ? -0.05 : 0.05
        let scaleX = SKAction.scaleX(to: targetXScale, duration: 0.45)
        let scaleY = SKAction.scaleY(to: 0.05, duration: 0.45)
        scaleX.timingMode = .easeIn
        scaleY.timingMode = .easeIn
        let scaleDown = SKAction.group([scaleX, scaleY])
        
        // Занурення та розчинення на тлі темної глибини
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 0.15),
            SKAction.fadeOut(withDuration: 0.30)
        ])
        
        let fallGroup = SKAction.group([moveToHole, rotateAction, scaleDown, fadeOut])
        run(fallGroup) {
            completion()
        }
    }
    
    // MARK: - Invulnerability & Respawn
    
    /// Запуск 3 секунд невразливості з ефектом моргання
    func startInvulnerability(duration: TimeInterval = 3.0) {
        isInvulnerable = true
        removeAction(forKey: "invulnerabilityAction")
        self.color = .clear
        self.colorBlendFactor = 0.0
        
        let blinkInterval: TimeInterval = 0.12
        let blinkCount = Int(duration / (blinkInterval * 2.0))
        
        let blinkStep = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.25, duration: blinkInterval),
            SKAction.fadeAlpha(to: 1.0, duration: blinkInterval)
        ])
        
        let blinkSequence = SKAction.repeat(blinkStep, count: blinkCount)
        let finish = SKAction.run { [weak self] in
            self?.alpha = 1.0
            self?.color = .clear
            self?.colorBlendFactor = 0.0
            self?.isInvulnerable = false
        }
        
        run(SKAction.sequence([blinkSequence, finish]), withKey: "invulnerabilityAction")
    }
    
    /// Скидання стану невразливості
    func cancelInvulnerability() {
        removeAction(forKey: "invulnerabilityAction")
        alpha = 1.0
        color = .clear
        colorBlendFactor = 0.0
        isInvulnerable = false
    }
    
    /// Відновлення персонажа поза прірвою на безпечній стіні з 3-секундною невразливістю
    func respawn(onLeftWall isLeft: Bool, at newPosition: CGPoint) {
        removeAction(forKey: "jumpAction")
        removeAction(forKey: "runAnimation")
        removeAllActions()
        
        currentState = .running
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        
        self.position = newPosition
        self.zPosition = 5
        self.color = .clear
        self.colorBlendFactor = 0.0
        self.alpha = 1.0
        
        updateOrientation(forLeftWall: isLeft)
        startRunningAnimation()
        startInvulnerability(duration: 3.0)
    }
}
