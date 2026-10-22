//
//  GameScene.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit
import AVFoundation
import AudioToolbox
import UIKit

// MARK: - Physics Categories
/// Бітові маски категорій фізики для визначення взаємодії об'єктів
struct PhysicsCategory {
    static let none: UInt32     = 0
    static let player: UInt32   = 1 << 0 // 1
    static let wall: UInt32     = 1 << 1 // 2
    static let obstacle: UInt32 = 1 << 2 // 4
    static let abyss: UInt32    = 1 << 3 // 8
    static let heart: UInt32    = 1 << 4 // 16
    static let coin: UInt32     = 1 << 5 // 32
}

// MARK: - App Font
enum AppFont {
    /// Головний шрифт гри (Jungle Adventurer)
    static let name: String = "JungleAdventurerRegular"
}



// MARK: - Reusable Pooled Particle Spray Node (Zero Allocations, 120 FPS Buttery Smooth)
final class PooledSprayNode: SKNode {
    let emitter: SKEmitterNode
    let shimmerEmitter: SKEmitterNode
    private(set) var inUse: Bool = false
    
    init(texture: SKTexture, isHeart: Bool = false) {
        self.emitter = SKEmitterNode()
        self.shimmerEmitter = SKEmitterNode()
        super.init()
        self.zPosition = 4.8
        
        emitter.particleTexture = texture
        emitter.particleBirthRate = 0
        
        shimmerEmitter.particleTexture = texture
        shimmerEmitter.particleBirthRate = 0
        
        if isHeart {
            // Рубіновий цілющий спрей
            emitter.particleLifetime = 0.40
            emitter.particleLifetimeRange = 0.08
            emitter.particleSpeed = 95.0
            emitter.particleSpeedRange = 35.0
            emitter.emissionAngle = .pi / 2.0
            emitter.emissionAngleRange = .pi * 1.4
            emitter.yAcceleration = 35.0
            emitter.particleAlpha = 0.95
            emitter.particleAlphaSpeed = -2.2
            emitter.particleScale = 0.22
            emitter.particleScaleRange = 0.08
            emitter.particleScaleSpeed = -0.40
            emitter.particleColor = SKColor(red: 1.0, green: 0.20, blue: 0.38, alpha: 1.0)
            emitter.particleColorBlendFactor = 1.0
            emitter.particleBlendMode = .add
            
            // Ніжно-рожеві іскри
            shimmerEmitter.particleLifetime = 0.28
            shimmerEmitter.particleLifetimeRange = 0.06
            shimmerEmitter.particleSpeed = 55.0
            shimmerEmitter.particleSpeedRange = 25.0
            shimmerEmitter.emissionAngle = .pi / 2.0
            shimmerEmitter.emissionAngleRange = .pi * 2.0
            shimmerEmitter.yAcceleration = 25.0
            shimmerEmitter.particleAlpha = 0.90
            shimmerEmitter.particleAlphaSpeed = -2.8
            shimmerEmitter.particleScale = 0.13
            shimmerEmitter.particleScaleRange = 0.05
            shimmerEmitter.particleScaleSpeed = -0.35
            shimmerEmitter.particleColor = SKColor(red: 1.0, green: 0.65, blue: 0.78, alpha: 1.0)
            shimmerEmitter.particleColorBlendFactor = 1.0
            shimmerEmitter.particleBlendMode = .add
        } else {
            // Золотистий спрей монет
            emitter.particleLifetime = 0.32
            emitter.particleLifetimeRange = 0.06
            emitter.particleSpeed = 110.0
            emitter.particleSpeedRange = 40.0
            emitter.emissionAngle = .pi / 2.0
            emitter.emissionAngleRange = .pi * 1.5
            emitter.yAcceleration = -70.0
            emitter.particleAlpha = 0.95
            emitter.particleAlphaSpeed = -2.7
            emitter.particleScale = 0.20
            emitter.particleScaleRange = 0.08
            emitter.particleScaleSpeed = -0.45
            emitter.particleColor = SKColor(red: 1.0, green: 0.84, blue: 0.20, alpha: 1.0)
            emitter.particleColorBlendFactor = 1.0
            emitter.particleBlendMode = .add
            
            // Яскраві золотаво-білі мікро-іскри
            shimmerEmitter.particleLifetime = 0.22
            shimmerEmitter.particleLifetimeRange = 0.05
            shimmerEmitter.particleSpeed = 65.0
            shimmerEmitter.particleSpeedRange = 30.0
            shimmerEmitter.emissionAngle = .pi / 2.0
            shimmerEmitter.emissionAngleRange = .pi * 2.0
            shimmerEmitter.yAcceleration = -35.0
            shimmerEmitter.particleAlpha = 0.90
            shimmerEmitter.particleAlphaSpeed = -3.5
            shimmerEmitter.particleScale = 0.12
            shimmerEmitter.particleScaleRange = 0.04
            shimmerEmitter.particleScaleSpeed = -0.40
            shimmerEmitter.particleColor = SKColor(red: 1.0, green: 0.98, blue: 0.70, alpha: 1.0)
            shimmerEmitter.particleColorBlendFactor = 1.0
            shimmerEmitter.particleBlendMode = .add
        }
        
        addChild(emitter)
        addChild(shimmerEmitter)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var burstAction: SKAction = {
        SKAction.sequence([
            SKAction.wait(forDuration: 0.04),
            SKAction.run { [weak self] in
                self?.emitter.particleBirthRate = 0
                self?.shimmerEmitter.particleBirthRate = 0
            },
            SKAction.wait(forDuration: 0.32),
            SKAction.run { [weak self] in
                self?.inUse = false
            }
        ])
    }()
    
    func trigger(at pos: CGPoint) {
        self.position = pos
        self.inUse = true
        
        emitter.resetSimulation()
        shimmerEmitter.resetSimulation()
        
        emitter.particleBirthRate = 420
        shimmerEmitter.particleBirthRate = 280
        
        removeAction(forKey: "sprayBurst")
        run(burstAction, withKey: "sprayBurst")
    }
}

// MARK: - GameScene
final class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Configuration Constants
    private enum Config {
        static let wallWidth: CGFloat = 48.0
        static let tileSize: CGFloat = 48.0
        
        // Швидкість постійного руху вгору (точок за секунду)
        static let baseUpwardSpeed: CGFloat = 290.0
        static let maxUpwardSpeed: CGFloat = 580.0
        
        // Кількість точок вертикального підйому на 1 очко
        static let distancePerScorePoint: CGFloat = 25.0
        
        // Базова та мінімальна тривалість стрибка між стінами (в секундах)
        static let baseJumpDuration: TimeInterval = 0.28
        static let minJumpDuration: TimeInterval = 0.19
        
        // Колірна гамма підкладки фону (теплий осінній тон)
        static let backgroundColor = SKColor(red: 0.18, green: 0.12, blue: 0.09, alpha: 1.0)
    }
    
    // MARK: - Active Theme & Cached Textures
    private var currentTheme: ThemeData {
        return ThemeManager.shared.currentTheme
    }
    
    private var cachedBackgroundTexture: SKTexture = SKTexture()
    private var cachedWallTexture: SKTexture = SKTexture()
    private var cachedCliffLowerTexture: SKTexture = SKTexture()
    private var cachedCliffUpperTexture: SKTexture = SKTexture()
    private var cachedWallDirtTexture: SKTexture = SKTexture()
    private var cachedWallRockTexture: SKTexture = SKTexture()
    private var cachedTreeTextures: [SKTexture] = []
    private var cachedBushTexture: SKTexture = SKTexture(imageNamed: "deco_bush_01")
    private var cachedStumpTexture: SKTexture = SKTexture(imageNamed: "deco_stump")
    private var cachedStoneTextures: [SKTexture] = [
        SKTexture(imageNamed: "deco_stone_01"),
        SKTexture(imageNamed: "deco_stone_02")
    ]
    private var cachedDecorTextures: [SKTexture] = []
    private var cachedSignpostTextures: [SKTexture] = []
    private var cachedPatrollerTextures: [SKTexture] = []
    private var cachedShooterTextures: [SKTexture] = []
    private var cachedHeartTexture: SKTexture = SKTexture()
    
    // Fast texture accessors
    private var backgroundTexture: SKTexture { return cachedBackgroundTexture }
    private var wallTexture: SKTexture { return cachedWallTexture }
    private var cliffLowerTexture: SKTexture { return cachedCliffLowerTexture }
    private var cliffUpperTexture: SKTexture { return cachedCliffUpperTexture }
    private var wallDirtTexture: SKTexture { return cachedWallDirtTexture }
    private var wallRockTexture: SKTexture { return cachedWallRockTexture }
    private var treeTextures: [SKTexture] { return cachedTreeTextures }
    private var bushTexture: SKTexture { return cachedBushTexture }
    private var stumpTexture: SKTexture { return cachedStumpTexture }
    private var stoneTextures: [SKTexture] { return cachedStoneTextures }
    private var decorTextures: [SKTexture] { return cachedDecorTextures }
    private var signpostTextures: [SKTexture] { return cachedSignpostTextures }
    
    // MARK: - Particle Textures & Spray Templates
    private static let sparkTexture: SKTexture = {
        let dim: CGFloat = 24.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: dim, height: dim))
        let image = renderer.image { ctx in
            let rect = CGRect(x: 2, y: 2, width: dim - 4, height: dim - 4)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: rect).fill()
        }
        return SKTexture(image: image)
    }()
    
    /// Текстура м'якої мікро-частинки з радіальним градієнтом для ефекту сяючого спрею
    private static let sprayParticleTexture: SKTexture = {
        let dim: CGFloat = 20.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: dim, height: dim))
        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let center = CGPoint(x: dim / 2.0, y: dim / 2.0)
            let radius = (dim / 2.0) - 1.0
            
            let colors = [
                UIColor(white: 1.0, alpha: 1.0).cgColor,
                UIColor(white: 1.0, alpha: 0.85).cgColor,
                UIColor(white: 1.0, alpha: 0.0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.45, 1.0]
            
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                cgCtx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
            }
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }()
    
    // MARK: - Reusable Pools for Sprays (Zero Allocations during Gameplay)
    private var coinSprayPool: [PooledSprayNode] = []
    private var heartSprayPool: [PooledSprayNode] = []
    
    private static let coinIconPulseAction: SKAction = {
        let scaleUp = SKAction.scale(to: 1.30, duration: 0.06)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.10)
        return SKAction.sequence([scaleUp, scaleDown])
    }()
    
    /// Завантаження та прогрів усіх текстур активної теми у пам'ять GPU для усунення мікрофризів
    private func updateCachedThemeTextures() {
        let theme = currentTheme
        
        let bgTex = SKTexture(imageNamed: theme.backgroundTextureName)
        bgTex.filteringMode = .linear
        if bgTex.size().width > 0 {
            cachedBackgroundTexture = bgTex
        } else {
            let fallback = SKTexture(imageNamed: "backround")
            fallback.filteringMode = .linear
            cachedBackgroundTexture = fallback
        }
        
        cachedWallTexture = SKTexture(imageNamed: theme.wallTileName)
        cachedWallTexture.filteringMode = .linear
        
        cachedCliffLowerTexture = SKTexture(imageNamed: theme.cliffLowerTileName)
        cachedCliffLowerTexture.filteringMode = .linear
        
        cachedCliffUpperTexture = SKTexture(imageNamed: theme.cliffUpperTileName)
        cachedCliffUpperTexture.filteringMode = .linear
        
        cachedWallDirtTexture = SKTexture(imageNamed: theme.wallDirtTileName)
        cachedWallDirtTexture.filteringMode = .linear
        
        cachedWallRockTexture = SKTexture(imageNamed: theme.wallRockTileName)
        cachedWallRockTexture.filteringMode = .linear
        
        cachedTreeTextures = theme.treeTextureNames.map { name in
            let tex = SKTexture(imageNamed: name)
            tex.filteringMode = .linear
            return tex
        }
        
        cachedDecorTextures = theme.decorTextureNames.map { name in
            let tex = SKTexture(imageNamed: name)
            tex.filteringMode = .linear
            return tex
        }
        
        if !theme.signpostTextureNames.isEmpty {
            cachedSignpostTextures = theme.signpostTextureNames.map { name in
                let tex = SKTexture(imageNamed: name)
                tex.filteringMode = .linear
                return tex
            }
        } else {
            cachedSignpostTextures = ["deco_sign_warning", "deco_sign_arrow", "deco_sign_question"].map { name in
                let tex = SKTexture(imageNamed: name)
                tex.filteringMode = .linear
                return tex
            }
        }
        
        cachedPatrollerTextures = (0..<theme.patrollerFrameCount).map { i in
            let tex = SKTexture(imageNamed: "\(theme.patrollerPrefix)\(i)")
            tex.filteringMode = .linear
            return tex
        }
        
        cachedShooterTextures = (0..<theme.shooterFrameCount).map { i in
            let tex = SKTexture(imageNamed: "\(theme.shooterPrefix)\(i)")
            tex.filteringMode = .linear
            return tex
        }
        
        cachedHeartTexture = SKTexture(imageNamed: theme.heartTextureName)
        cachedHeartTexture.filteringMode = .linear
        
        // Попереднє завантаження у VRAM для гарантування 60-120 FPS без просадок під час гри
        var texturesToPreload: [SKTexture] = [
            cachedBackgroundTexture,
            cachedWallTexture,
            cachedCliffLowerTexture,
            cachedCliffUpperTexture,
            cachedWallDirtTexture,
            cachedWallRockTexture,
            cachedHeartTexture,
            cachedBushTexture,
            cachedStumpTexture,
            GameScene.sparkTexture,
            GameScene.sprayParticleTexture
        ]
        texturesToPreload.append(contentsOf: cachedTreeTextures)
        texturesToPreload.append(contentsOf: cachedStoneTextures)
        texturesToPreload.append(contentsOf: cachedDecorTextures)
        texturesToPreload.append(contentsOf: cachedSignpostTextures)
        texturesToPreload.append(contentsOf: cachedPatrollerTextures)
        texturesToPreload.append(contentsOf: cachedShooterTextures)
        
        SKTexture.preload(texturesToPreload) {}
    }
    
    // MARK: - Audio
    private static let bgmTargetVolume: Float = GameAudio.bgmTargetVolume
    
    // MARK: - Nodes & State
    private let cameraNode = SKCameraNode()
    
    /// Окремий вузол героя з власною ієрархією спрайтів та анімацій
    private var player: PlayerNode!
    
    /// Фіксоване вертикальне зміщення героя відносно центру камери
    private var playerCameraOffsetY: CGFloat = 0
    
    /// Прапорець падіння героя в прірву (відв'язує Y-координату від камери)
    private var isPlayerFalling: Bool = false
    
    /// Делеговані стани героя
    var isOnLeftWall: Bool {
        return player.isOnLeftWall
    }
    
    var isJumping: Bool {
        return player.isJumping
    }
    
    // MARK: - Input Buffering (Буферизація тапу для чуйного стрибка)
    private var hasBufferedJump: Bool = false
    private var bufferedJumpTimestamp: TimeInterval = 0
    private let jumpBufferWindow: TimeInterval = 0.16
    
    // MARK: - Game State
    enum GameState {
        case menu
        case starting
        case playing
        case gameOver
    }
    private(set) var gameState: GameState = .menu
    private let initialMode: GameState
    
    // Ноди та елементи головного меню
    private var menuNode: SKNode?
    private var soundIconSprite: SKSpriteNode?
    private var menuCoinsText: SKLabelNode?
    
    // Ноди та елементи маркету/магазину
    private var shopNode: SKNode?
    private var currentShopIndex: Int = 0
    private var shopAdRewardBtnNode: SKNode?
    private var shopAdRewardBgSprite: SKSpriteNode?
    private var shopAdRewardLabel: SKLabelNode?
    private var shopAdRewardPlayIcon: SKSpriteNode?
    private var shopAdRewardCoinIcon: SKSpriteNode?
    private var backgroundNode: SKSpriteNode?
    private var backgroundOverlayNode: SKSpriteNode?
    private var backgroundTopExtensionNode: SKSpriteNode?
    private var backgroundBottomExtensionNode: SKSpriteNode?
    
    /// Масштаб фонового зображення: повне покриття екрана (Aspect Fill із запасом 1.05 для гарантованого покриття всієї площі без розривів)
    private let backgroundScaleMultiplier: CGFloat = 1.05
    
    /// Прапорець закінчення гри
    private(set) var isGameOver: Bool = false
    private var gameOverOverlayNode: SKNode?
    
    // MARK: - Ad Rewards (Revive 1x, Double Coins 1x)
    private var hasUsedAdRevive: Bool = false
    private var hasUsedAdDoubleCoins: Bool = false
    private var gameOverCoinsSummaryLabel: SKLabelNode?
    private var gameOverDoubleCoinsBtn: SKSpriteNode?
    private var gameOverDoubleCoinsLabel: SKLabelNode?
    
    // MARK: - Lives, Score & Difficulty
    private static let maxLives: Int = 3
    private(set) var currentLives: Int = GameScene.maxLives
    private var heartHUDNodes: [SKSpriteNode] = []
    private let hudNode = SKNode()
    
    private(set) var score: Int = 0
    private var bestScore: Int {
        get { UserDefaults.standard.integer(forKey: "BestWallShiftScore") }
        set { UserDefaults.standard.set(newValue, forKey: "BestWallShiftScore") }
    }
    private var startCameraY: CGFloat = 0
    private var scoreLabel = SKLabelNode()
    private var lastLevelCelebrated: Int = 0
    
    // MARK: - Coins System
    private(set) var coinsCollected: Int = 0
    private var totalCoins: Int {
        get { UserDefaults.standard.integer(forKey: "TotalWallShiftCoins") }
        set { UserDefaults.standard.set(newValue, forKey: "TotalWallShiftCoins") }
    }
    private var coinsLabel = SKLabelNode()
    private var hudCoinIcon: SKSpriteNode?
    
    /// Поточний розрахунковий рівень складності (кожні 50 очок)
    private var difficultyLevel: Int {
        return score / 50
    }
    
    /// Поточна швидкість підйому камери: безперервне, плавне наростання темпу гри в стилі Subway Surfers.
    /// Починається з бадьорого комфортного бігу (300 pt/s) і без жодних різких ривків
    /// чи сходинок плавно прискорюється в міру забігу до спортивного максимуму (~645 pt/s).
    private var currentUpwardSpeed: CGFloat {
        let s = CGFloat(max(0, score))
        let acceleration = 340.0 * (1.0 - exp(-s / 450.0)) + (s * 0.035)
        return min(645.0, 300.0 + acceleration)
    }
    
    /// Динамічна тривалість стрибка: плавно адаптується до темпу гри.
    /// На старті стрибок комфортний (0.28с), на максимальній швидкості — швидкий і чуйний (0.19с),
    /// що усуває відчуття заторможеності на складних ділянках та вузьких платформах.
    private var currentJumpDuration: TimeInterval {
        guard gameState == .playing else { return Config.baseJumpDuration }
        let speedProgress = (currentUpwardSpeed - 300.0) / (645.0 - 300.0)
        let clamped = max(0.0, min(1.0, speedProgress))
        return Config.baseJumpDuration - (Double(clamped) * (Config.baseJumpDuration - Config.minJumpDuration))
    }
    
    /// Розміри розриву прірв: плавний і природний розподіл без сходинкових стрибків.
    /// Від легких 2 тайлів на старті до динамічних 4-5 тайлів на високих очках.
    private func randomAbyssGapTileCount() -> Int {
        let s = CGFloat(max(0, score))
        let progress = min(1.0, s / 800.0)
        let roll = Double.random(in: 0...1)
        if progress < 0.25 {
            // 0...200 очок: переважно 2 тайли (96 pt), іноді 3 тайли
            return (roll < 0.80) ? 2 : 3
        } else if progress < 0.60 {
            // 200...480 очок: плавний перехід між 2, 3 та 4 тайлами
            return (roll < 0.40) ? 2 : ((roll < 0.85) ? 3 : 4)
        } else if progress < 0.90 {
            // 480...720 очок: 3, 4 або 5 тайлів
            return (roll < 0.30) ? 3 : ((roll < 0.80) ? 4 : 5)
        } else {
            // 720+ очок: максимальний паркур (4-5 тайлів, рідко 6)
            return (roll < 0.35) ? 4 : ((roll < 0.85) ? 5 : 6)
        }
    }
    
    /// Скорочення дистанції між прірвами (довжини твердих платформ):
    /// Плавна неперервна експоненційна функція від ~560 pt на початку до ~115 pt на високих дистанціях.
    /// Без різких «перепадів» довжини — платформи звужуються органічно, як у найкращих раннерах.
    private func randomAbyssDistance() -> CGFloat {
        let s = CGFloat(max(0, score))
        let meanDistance = 115.0 + 445.0 * exp(-s / 420.0)
        let spread = meanDistance * 0.14
        return CGFloat.random(in: (meanDistance - spread)...(meanDistance + spread))
    }
    
    /// Динамічний розрахунок дистанції до появи наступного серця (додаткового життя).
    /// Баланс складності:
    /// - При 1 житті (критичний стан): ~3,400...5,000 pt (~135...200 очок), дає гравцю чесний шанс вижити при майстерній грі.
    /// - При 2 життях: ~4,600...6,600 pt (~185...265 очок).
    /// - При 3 життях (повне здоров'я): ~7,200...10,000 pt (~290...400 очок), щоб не перевантажувати екран зайвими серцями.
    /// - При високому рахунку (score >= 500-800+): дистанція плавно адаптується (до -20%),
    ///   компенсуючи пікову щільність ворогів та високу швидкість без зламу складності.
    private func randomHeartDistance() -> CGFloat {
        let s = CGFloat(max(0, score))
        
        let minBase: CGFloat
        let maxBase: CGFloat
        
        if currentLives <= 1 {
            minBase = 3400.0
            maxBase = 5000.0
        } else if currentLives == 2 {
            minBase = 4600.0
            maxBase = 6600.0
        } else {
            minBase = 7200.0
            maxBase = 10000.0
        }
        
        // М'який коригуючий множник для високих очок (після 500 до 1200+ очок):
        // Запобігає надмірному стрибку складності на 800+ очках
        let highProgress = max(0.0, min(1.0, (s - 500.0) / 700.0))
        let difficultyFactor = 1.0 - (highProgress * 0.20)
        
        return CGFloat.random(in: minBase...maxBase) * difficultyFactor
    }
    
    // Відстеження часу для обчислення deltaTime
    private var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Procedural Track, Abyss, Hearts & Mobs Generation
    private var leftTrackNodes: [SKNode] = []
    private var rightTrackNodes: [SKNode] = []
    private var leftAbyssNodes: [AbyssObstacleNode] = []
    private var rightAbyssNodes: [AbyssObstacleNode] = []
    private var lastCleanupCameraY: CGFloat = 0
    private var trackHeartNodes: [SKNode] = []
    private var trackMobNodes: [MobNode] = []
    private var activeFireArrows: [FireArrowNode] = []
    private var trackCoinNodes: [CoinNode] = []
    private var currentLeftY: CGFloat = 0
    private var currentRightY: CGFloat = 0
    
    private var nextAbyssY: CGFloat = 0
    private var nextAbyssIsOnLeft: Bool = false
    private var consecutiveAbyssesOnSameWall: Int = 1
    private let maxConsecutiveAbyssesOnSameWall: Int = 2
    private var consecutivePatrollers: Int = 0
    private var nextHeartY: CGFloat = 0
    private var nextCoinPatternY: CGFloat = 0
    private var lastAbyssHitTime: TimeInterval = 0
    
    // Процедурний спавн ворожих мобів (патрульні на розминці, стрільці пізніше)
    private var firstMobScoreThreshold: Int = 0
    private var firstShooterScoreThreshold: Int = 0
    private var nextMobY: CGFloat = 0
    
    private var decorationNodes: [SKNode] = []
    private var nextTreeBackgroundY: CGFloat = 0
    private var lastLeftDecoY: CGFloat = 0
    private var lastRightDecoY: CGFloat = 0
    
    // MARK: - Computed Properties for Wall Positions
    private var leftWallInnerX: CGFloat {
        return Config.wallWidth
    }
    
    private var rightWallInnerX: CGFloat {
        return size.width - Config.wallWidth
    }
    
    private var playerLeftX: CGFloat {
        return leftWallInnerX + PlayerNode.Constants.footOffset
    }
    
    private var playerRightX: CGFloat {
        return rightWallInnerX - PlayerNode.Constants.footOffset
    }
    
    // MARK: - Initializers
    init(size: CGSize, initialMode: GameState = .menu) {
        self.initialMode = initialMode
        super.init(size: size)
        updateCachedThemeTextures()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.initialMode = .menu
        super.init(coder: aDecoder)
        updateCachedThemeTextures()
    }
    
    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        // Очищаємо можливі стандартні ноди з шаблону Xcode (.sks)
        removeAllChildren()
        removeAllActions()
        
        // Якщо сцена завантажена зі стандартним розміром .sks або нульовим, підлаштовуємо під розмір view
        if view.bounds.size.width > 0 && (size == .zero || size.width == 750) {
            size = view.bounds.size
            scaleMode = .resizeFill
        }
        
        anchorPoint = .zero
        backgroundColor = Config.backgroundColor
        
        isPlayerFalling = false
        isGameOver = false
        currentLives = GameScene.maxLives
        score = 0
        coinsCollected = 0
        lastLevelCelebrated = 0
        lastUpdateTime = 0
        leftTrackNodes.removeAll()
        rightTrackNodes.removeAll()
        leftAbyssNodes.removeAll()
        rightAbyssNodes.removeAll()
        lastCleanupCameraY = 0
        trackHeartNodes.removeAll()
        trackMobNodes.removeAll()
        trackCoinNodes.removeAll()
        decorationNodes.removeAll()
        
        setupPhysicsWorld()
        setupCamera()
        setupParticlePools()
        setupAudio()
        setupBackground()
        setupPlayer()
        setupHUD()
        setupProceduralTrack()
        
        if initialMode == .menu {
            gameState = .menu
            isGameOver = false
            player.setReadyStance()
            hudNode.alpha = 0.0
            showMainMenu(animated: false)
            startBGM(lowVolume: true)
        } else {
            gameState = .playing
            isGameOver = false
            player.startRunningAnimation()
            hudNode.alpha = 1.0
            startBGM(lowVolume: false)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupPhysicsWorld() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }
    
    private func setupCamera() {
        cameraNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        camera = cameraNode
        addChild(cameraNode)
    }
    
    /// Створення фіксованого пулу систем частинок для збору предметів (0 алокацій під час гри, стабільні 60-120 FPS)
    private func setupParticlePools() {
        coinSprayPool.forEach { $0.removeFromParent() }
        coinSprayPool.removeAll()
        heartSprayPool.forEach { $0.removeFromParent() }
        heartSprayPool.removeAll()
        
        let sprayTex = GameScene.sprayParticleTexture
        
        // 1. Пул золотистого спрею для монет (10 пре-ініціалізованих нод)
        for _ in 0..<10 {
            let node = PooledSprayNode(texture: sprayTex, isHeart: false)
            addChild(node)
            coinSprayPool.append(node)
        }
        
        // 2. Пул рубінового цілющого спрею для сердець (4 пре-ініціалізовані ноди)
        for _ in 0..<4 {
            let node = PooledSprayNode(texture: sprayTex, isHeart: true)
            addChild(node)
            heartSprayPool.append(node)
        }
    }
    
    private func setupAudio() {
        GameAudio.shared.setupIfNeeded()
    }
    
    private var isMuted: Bool {
        return GameAudio.shared.isMuted
    }
    
    /// Динамічний запуск зацикленої фонової музики (з пониженою гучністю для меню або повною для гри)
    private func startBGM(lowVolume: Bool = false) {
        GameAudio.shared.startBGM(lowVolume: lowVolume)
    }
    
    private func toggleMute() {
        let isMuted = GameAudio.shared.toggleMute()
        let iconName = isMuted ? "gui_icon_audio_off" : "gui_icon_audio_on"
        soundIconSprite?.texture = SKTexture(imageNamed: iconName)
    }
    
    /// Плавне спадання тону/гучності фонової музики (fade-out 2.0 с) при завершенні гри
    private func stopBGM(fadeDuration: TimeInterval = 2.0) {
        GameAudio.shared.stopBGM(fadeDuration: fadeDuration)
    }
    
    /// Відтворення звуку стрибка героя при тапі на екран
    private func playJumpSound() {
        GameAudio.shared.playJump()
    }
    
    /// Відтворення звуку закінчення гри при програші
    private func playGameOverSound() {
        GameAudio.shared.playGameOver()
    }
    
    /// Відтворення звуку підбору монети (coin_pickup)
    private func playCoinSound() {
        GameAudio.shared.playCoin()
    }
    
    private func setupBackground() {
        let textureSize = backgroundTexture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return }
        
        backgroundTexture.filteringMode = .linear
        
        // Масштабуємо фон: повний Aspect Fill із коефіцієнтом backgroundScaleMultiplier (1.05),
        // завдяки чому ілюстрований фон гарантовано покриває екран від самого верху до низу без зазорів
        let baseScale = max(size.width / textureSize.width, size.height / textureSize.height)
        let scale = baseScale * backgroundScaleMultiplier
        let bgSize = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        
        let background = SKSpriteNode(texture: backgroundTexture, size: bgSize)
        background.zPosition = -10
        background.position = .zero // Завжди центрований відносно огляду камери
        cameraNode.addChild(background)
        self.backgroundNode = background
        
        // Верхнє розширення атмосфери за межами екрана (страховка для вирізів та Dynamic Island)
        let topH: CGFloat = 120.0
        let topExt = SKSpriteNode(
            color: currentTheme.backgroundTopColor,
            size: CGSize(width: max(size.width, bgSize.width) + 40.0, height: topH)
        )
        topExt.zPosition = -10
        topExt.position = CGPoint(x: 0, y: (bgSize.height / 2.0) + (topH / 2.0) - 2.0)
        cameraNode.addChild(topExt)
        self.backgroundTopExtensionNode = topExt
        
        // Нижнє розширення атмосфери за межами екрана (страховка)
        let botH: CGFloat = 120.0
        let botExt = SKSpriteNode(
            color: currentTheme.backgroundBottomColor,
            size: CGSize(width: max(size.width, bgSize.width) + 40.0, height: botH)
        )
        botExt.zPosition = -10
        botExt.position = CGPoint(x: 0, y: -(bgSize.height / 2.0) - (botH / 2.0) + 2.0)
        cameraNode.addChild(botExt)
        self.backgroundBottomExtensionNode = botExt
        
        // Атмосферний кольоровий оверлей теми (покриває весь екран із запасом)
        let overlay = SKSpriteNode(
            color: currentTheme.backgroundOverlayColor,
            size: CGSize(width: max(size.width, bgSize.width) + 40.0, height: max(size.height, bgSize.height) + 160.0)
        )
        overlay.alpha = currentTheme.backgroundOverlayAlpha
        overlay.zPosition = -8
        overlay.position = .zero
        cameraNode.addChild(overlay)
        self.backgroundOverlayNode = overlay
    }
    
    private func setupPlayer() {
        player = PlayerNode(prefix: currentTheme.heroRunPrefix, frameCount: currentTheme.heroRunCount)
        
        // Фіксуємо зміщення гравця по вертикалі відносно камери (нижня третина огляду)
        playerCameraOffsetY = -(size.height * 0.15)
        
        let startY = cameraNode.position.y + playerCameraOffsetY
        player.position = CGPoint(x: playerLeftX, y: startY)
        
        addChild(player)
    }
    
    // MARK: - Lives & Score HUD
    private func setupHUD() {
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
    
    private func updateHUD(animated: Bool = true) {
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
    private func celebrateLevelUp(level: Int) {
        // Анімація сплеску тексту очок
        scoreLabel.removeAction(forKey: "pulseScore")
        let scaleUp = SKAction.scale(to: 1.45, duration: 0.18)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.18)
        scoreLabel.run(SKAction.sequence([scaleUp, scaleDown]), withKey: "pulseScore")
    }
    
    // MARK: - In-Scene Seamless Main Menu
    
    /// Автоматичний періодичний стрибок героя між стінами під час перебування у головному меню
    private func scheduleNextMenuAutoJump(delay: TimeInterval = 2.0) {
        removeAction(forKey: "menuAutoJump")
        guard gameState == .menu else { return }
        
        let wait = SKAction.wait(forDuration: delay)
        let jump = SKAction.run { [weak self] in
            guard let self = self, self.gameState == .menu, !self.player.isJumping else { return }
            self.performJump()
        }
        run(SKAction.sequence([wait, jump]), withKey: "menuAutoJump")
    }
    
    /// Відображення GUI головного меню безпосередньо поверх живого рівня
    private func showMainMenu(animated: Bool = false) {
        menuNode?.removeFromParent()
        removeAction(forKey: "menuAutoJump")
        
        gameState = .menu
        isGameOver = false
        hudNode.alpha = 0.0
        player.setReadyStance()
        
        // Запускаємо перший автоматичний стрибок через 1.8 с
        scheduleNextMenuAutoJump(delay: 1.8)
        
        let container = SKNode()
        container.zPosition = 150
        menuNode = container
        cameraNode.addChild(container)
        
        // 1. Логотип WALLSHIFT (на помаранчевому банері)
        let titleContainer = SKNode()
        titleContainer.name = "menuTitle"
        titleContainer.position = CGPoint(x: 0, y: size.height * 0.24)
        titleContainer.zPosition = 5
        container.addChild(titleContainer)
        
        let bannerW = min(310.0, size.width - 50.0)
        let bannerH = bannerW * (457.0 / 1139.0)
        let banner = SKSpriteNode(imageNamed: currentTheme.guiBannerName)
        banner.name = "menuBanner"
        banner.size = CGSize(width: bannerW, height: bannerH)
        banner.position = .zero
        banner.zPosition = 1
        titleContainer.addChild(banner)
        
        let shadowLabel = SKLabelNode(fontNamed: AppFont.name)
        shadowLabel.name = "menuBannerShadow"
        shadowLabel.text = "WALLSHIFT"
        shadowLabel.fontSize = min(46.0, size.width * 0.115)
        shadowLabel.fontColor = currentTheme.guiBannerShadowColor
        shadowLabel.position = CGPoint(x: 1.5, y: -bannerH * 0.08)
        shadowLabel.zPosition = 2
        titleContainer.addChild(shadowLabel)
        
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.text = "WALLSHIFT"
        titleLabel.fontSize = min(46.0, size.width * 0.115)
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.05)
        titleLabel.zPosition = 3
        titleContainer.addChild(titleLabel)
        
        let floatUp = SKAction.moveBy(x: 0, y: 4.0, duration: 1.8)
        let floatDown = SKAction.moveBy(x: 0, y: -4.0, duration: 1.8)
        floatUp.timingMode = .easeInEaseOut
        floatDown.timingMode = .easeInEaseOut
        titleContainer.run(SKAction.repeatForever(SKAction.sequence([floatUp, floatDown])))
        
        // 2. Картка статистики (Best Score & Coins) із GUI Bundle
        let cardW: CGFloat = min(280.0, size.width - 70.0)
        let cardH: CGFloat = 54.0
        let card = SKSpriteNode(imageNamed: currentTheme.guiStatsBarName)
        card.name = "menuCard"
        card.size = CGSize(width: cardW, height: cardH)
        card.position = CGPoint(x: 0, y: size.height * 0.08)
        card.zPosition = 5
        container.addChild(card)
        
        let starIcon = SKSpriteNode(imageNamed: "gui_icon_star")
        starIcon.size = CGSize(width: 22.0, height: 22.0)
        starIcon.position = CGPoint(x: -cardW * 0.36, y: 0.0)
        starIcon.zPosition = 2
        card.addChild(starIcon)
        
        let bestScoreText = SKLabelNode(fontNamed: AppFont.name)
        bestScoreText.name = "menuBestScoreText"
        bestScoreText.text = "BEST: \(bestScore.formattedWithSeparator)"
        bestScoreText.fontSize = 16.0
        bestScoreText.fontColor = currentTheme.guiStatsTextColor
        bestScoreText.horizontalAlignmentMode = .left
        bestScoreText.verticalAlignmentMode = .center
        bestScoreText.position = CGPoint(x: -cardW * 0.26, y: 0.0)
        bestScoreText.zPosition = 2
        card.addChild(bestScoreText)
        
        let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
        coinIcon.name = "menuCoinsIcon"
        coinIcon.size = CGSize(width: 22.0, height: 22.0)
        coinIcon.position = CGPoint(x: cardW * 0.12, y: 0.0)
        coinIcon.zPosition = 2
        card.addChild(coinIcon)
        
        let coinsText = SKLabelNode(fontNamed: AppFont.name)
        coinsText.name = "menuCoinsText"
        coinsText.text = totalCoins.formattedWithSeparator
        coinsText.fontSize = 16.0
        coinsText.fontColor = currentTheme.guiStatsTextColor
        coinsText.horizontalAlignmentMode = .left
        coinsText.verticalAlignmentMode = .center
        coinsText.position = CGPoint(x: cardW * 0.21, y: 0.0)
        coinsText.zPosition = 2
        card.addChild(coinsText)
        self.menuCoinsText = coinsText
        
        // 3. Кнопка START GAME із GUI Bundle
        let btnW: CGFloat = min(250.0, size.width - 80.0)
        let btnH: CGFloat = 66.0
        let playBtn = SKSpriteNode(imageNamed: currentTheme.guiPrimaryBtnName)
        playBtn.name = "menuPlayButton"
        playBtn.size = CGSize(width: btnW, height: btnH)
        playBtn.position = CGPoint(x: 0, y: -size.height * 0.045)
        playBtn.zPosition = 5
        container.addChild(playBtn)
        
        let playArrow = SKSpriteNode(imageNamed: "gui_icon_play")
        playArrow.name = "menuPlayButton"
        playArrow.size = CGSize(width: 22.0, height: 22.0)
        playArrow.position = CGPoint(x: -btnW * 0.30, y: 1.0)
        playArrow.zPosition = 2
        playBtn.addChild(playArrow)
        
        let playLabel = SKLabelNode(fontNamed: AppFont.name)
        playLabel.name = "menuPlayButton"
        playLabel.text = "START GAME"
        playLabel.fontSize = 23.0
        playLabel.fontColor = .white
        playLabel.verticalAlignmentMode = .center
        playLabel.horizontalAlignmentMode = .center
        playLabel.position = CGPoint(x: 8.0, y: 1.0)
        playLabel.zPosition = 2
        playBtn.addChild(playLabel)
        
        let pulseUp = SKAction.scale(to: 1.04, duration: 0.85)
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.85)
        pulseUp.timingMode = .easeInEaseOut
        pulseDown.timingMode = .easeInEaseOut
        playBtn.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))
        
        // 4. Кнопка МАРКЕТ із Basic_GUI_Bundle
        let shopBtnW: CGFloat = min(220.0, size.width - 90.0)
        let shopBtnH: CGFloat = 56.0
        let shopBtn = SKSpriteNode(imageNamed: currentTheme.guiSecondaryBtnName)
        shopBtn.name = "menuShopButton"
        shopBtn.size = CGSize(width: shopBtnW, height: shopBtnH)
        shopBtn.position = CGPoint(x: 0, y: -size.height * 0.165)
        shopBtn.zPosition = 5
        container.addChild(shopBtn)
        
        let shopIcon = SKSpriteNode(imageNamed: "gui_icon_shop")
        shopIcon.name = "menuShopButton"
        shopIcon.size = CGSize(width: 24.0, height: 24.0)
        shopIcon.position = CGPoint(x: -shopBtnW * 0.28, y: 1.0)
        shopIcon.zPosition = 2
        shopBtn.addChild(shopIcon)
        
        let shopLabel = SKLabelNode(fontNamed: AppFont.name)
        shopLabel.name = "menuShopButton"
        shopLabel.text = "MARKET"
        shopLabel.fontSize = 21.0
        shopLabel.fontColor = .white
        shopLabel.verticalAlignmentMode = .center
        shopLabel.horizontalAlignmentMode = .center
        shopLabel.position = CGPoint(x: 12.0, y: 1.0)
        shopLabel.zPosition = 2
        shopBtn.addChild(shopLabel)
        
        // 5. Кнопка звуку із GUI Bundle (гучність вкл/викл)
        let soundBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        soundBtn.name = "menuSoundButton"
        soundBtn.size = CGSize(width: 48.0, height: 48.0)
        soundBtn.position = CGPoint(
            x: (size.width / 2.0) - 44.0,
            y: (size.height / 2.0) - 58.0
        )
        soundBtn.zPosition = 10
        container.addChild(soundBtn)
        
        let iconName = isMuted ? "gui_icon_audio_off" : "gui_icon_audio_on"
        let soundIcon = SKSpriteNode(imageNamed: iconName)
        soundIcon.name = "menuSoundButton"
        soundIcon.size = CGSize(width: 26.0, height: 26.0)
        soundIcon.position = .zero
        soundIcon.zPosition = 2
        soundBtn.addChild(soundIcon)
        self.soundIconSprite = soundIcon
        
        // 6. Кнопка EXIT у самому низу меню із Basic_GUI_Bundle
        let exitBtnW: CGFloat = min(170.0, size.width - 120.0)
        let exitBtnH: CGFloat = exitBtnW * (304.0 / 983.0)
        let exitBtn = SKSpriteNode(imageNamed: "gui_btn_exit_red")
        exitBtn.name = "menuExitButton"
        exitBtn.size = CGSize(width: exitBtnW, height: exitBtnH)
        exitBtn.position = CGPoint(x: 0, y: -size.height * 0.285)
        exitBtn.zPosition = 5
        container.addChild(exitBtn)
        
        if animated {
            container.alpha = 0.0
            container.run(SKAction.fadeIn(withDuration: 0.30))
        }
    }
    
    /// Анімоване зникнення GUI меню та плавний старт бігу персонажа
    private func dismissMenuAndStartClimb() {
        guard gameState == .menu else { return }
        gameState = .starting
        removeAction(forKey: "menuAutoJump")
        
        playJumpSound()
        
        guard let menu = menuNode else {
            startClimb()
            return
        }
        
        // Анімація зникнення кнопки старту
        if let playBtn = menu.childNode(withName: "menuPlayButton") {
            playBtn.run(SKAction.sequence([
                SKAction.scale(to: 0.92, duration: 0.08),
                SKAction.group([
                    SKAction.scale(to: 0.65, duration: 0.22),
                    SKAction.fadeOut(withDuration: 0.22)
                ])
            ]))
        }
        
        // Анімація злітання логотипу вгору
        if let title = menu.childNode(withName: "menuTitle") {
            title.run(SKAction.group([
                SKAction.moveBy(x: 0, y: 50.0, duration: 0.32),
                SKAction.fadeOut(withDuration: 0.32)
            ]))
        }
        
        // Анімація згасання картки статистики
        if let card = menu.childNode(withName: "menuCard") {
            card.run(SKAction.group([
                SKAction.scale(to: 0.85, duration: 0.28),
                SKAction.fadeOut(withDuration: 0.28)
            ]))
        }
        
        // Анімація згасання кнопки звуку
        if let soundBtn = menu.childNode(withName: "menuSoundButton") {
            soundBtn.run(SKAction.fadeOut(withDuration: 0.25))
        }
        
        // Анімація згасання кнопки маркету
        if let shopBtn = menu.childNode(withName: "menuShopButton") {
            shopBtn.run(SKAction.group([
                SKAction.scale(to: 0.80, duration: 0.24),
                SKAction.fadeOut(withDuration: 0.24)
            ]))
        }
        
        // Анімація згасання кнопки виходу
        if let exitBtn = menu.childNode(withName: "menuExitButton") {
            exitBtn.run(SKAction.group([
                SKAction.scale(to: 0.80, duration: 0.24),
                SKAction.fadeOut(withDuration: 0.24)
            ]))
        }
        
        // Анімовано зникає GUI, і ПІСЛЯ ЦЬОГО починає бігти персонаж!
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.34),
            SKAction.run { [weak self] in
                self?.startClimb()
            }
        ]))
    }
    
    // MARK: - Market / Shop System
    
    /// Відкриття оверлею магазину персонажів та тем
    private func showShopOverlay() {
        guard shopNode == nil else { return }
        removeAction(forKey: "menuAutoJump")
        
        // Знаходимо індекс поточної обраної теми для каруселі
        let themes = ThemeManager.shared.themes
        if let idx = themes.firstIndex(where: { $0.id == ThemeManager.shared.selectedThemeID }) {
            currentShopIndex = idx
        } else {
            currentShopIndex = 0
        }
        
        let container = SKNode()
        container.name = "shopContainer"
        container.zPosition = 200
        shopNode = container
        cameraNode.addChild(container)
        
        // 1. Напівпрозоре затемнення фону
        let dimBg = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.65), size: CGSize(width: size.width * 1.5, height: size.height * 1.5))
        dimBg.name = "shopDimBg"
        dimBg.position = .zero
        dimBg.zPosition = 1
        container.addChild(dimBg)
        
        // 2. Основна плашка магазину
        let cardW: CGFloat = min(330.0, size.width - 32.0)
        let cardH: CGFloat = min(530.0, size.height * 0.78)
        let card = SKSpriteNode(imageNamed: "gui_card_box")
        card.name = "shopCard"
        card.size = CGSize(width: cardW, height: cardH)
        card.position = .zero
        card.zPosition = 2
        container.addChild(card)
        
        // 3. Заголовок "MARKET"
        let bannerW = min(230.0, cardW - 40.0)
        let bannerH = bannerW * (457.0 / 1139.0)
        let banner = SKSpriteNode(imageNamed: currentTheme.guiBannerName)
        banner.name = "shopBanner"
        banner.size = CGSize(width: bannerW, height: bannerH)
        banner.position = CGPoint(x: 0, y: cardH * 0.44)
        banner.zPosition = 5
        card.addChild(banner)
        
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.name = "shopTitleLabel"
        titleLabel.text = "MARKET"
        titleLabel.fontSize = 25.0
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.05)
        titleLabel.zPosition = 6
        banner.addChild(titleLabel)
        
        // 4. Кнопка закриття [X]
        let closeBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        closeBtn.name = "shopCloseButton"
        closeBtn.size = CGSize(width: 40.0, height: 40.0)
        closeBtn.position = CGPoint(x: (cardW / 2.0) - 26.0, y: (cardH / 2.0) - 26.0)
        closeBtn.zPosition = 10
        card.addChild(closeBtn)
        
        let closeIcon = SKSpriteNode(imageNamed: "gui_icon_close")
        closeIcon.name = "shopCloseButton"
        closeIcon.size = CGSize(width: 22.0, height: 22.0)
        closeIcon.position = .zero
        closeIcon.zPosition = 2
        closeBtn.addChild(closeIcon)
        
        // 5. Баланс монет у верхній частині картки
        let balanceNode = SKNode()
        balanceNode.name = "shopBalanceNode"
        balanceNode.position = CGPoint(x: 0, y: cardH * 0.31)
        balanceNode.zPosition = 5
        card.addChild(balanceNode)
        
        let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
        coinIcon.name = "shopCoinIcon"
        coinIcon.size = CGSize(width: 24.0, height: 24.0)
        
        let balanceLabel = SKLabelNode(fontNamed: AppFont.name)
        balanceLabel.name = "shopBalanceLabel"
        balanceLabel.text = totalCoins.formattedWithSeparator
        balanceLabel.fontSize = 21.0
        balanceLabel.fontColor = SKColor(red: 1.0, green: 0.88, blue: 0.30, alpha: 1.0)
        balanceLabel.horizontalAlignmentMode = .left
        balanceLabel.verticalAlignmentMode = .center
        
        let balSpacing: CGFloat = 8.0
        let totalBalW = coinIcon.size.width + balSpacing + balanceLabel.frame.width
        coinIcon.position = CGPoint(x: -totalBalW / 2.0 + coinIcon.size.width / 2.0, y: 0)
        balanceLabel.position = CGPoint(x: coinIcon.position.x + coinIcon.size.width / 2.0 + balSpacing, y: 0)
        
        balanceNode.addChild(coinIcon)
        balanceNode.addChild(balanceLabel)
        
        // 6. Стрілки перемикання ліворуч / праворуч
        let arrowLeft = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        arrowLeft.name = "shopPrevButton"
        arrowLeft.size = CGSize(width: 44.0, height: 44.0)
        arrowLeft.position = CGPoint(x: -cardW * 0.40, y: cardH * 0.08)
        arrowLeft.zPosition = 8
        card.addChild(arrowLeft)
        
        let arrowLeftIcon = SKSpriteNode(imageNamed: "gui_icon_arrow_left")
        arrowLeftIcon.name = "shopPrevButton"
        arrowLeftIcon.size = CGSize(width: 20.0, height: 20.0)
        arrowLeftIcon.position = .zero
        arrowLeftIcon.zPosition = 2
        arrowLeft.addChild(arrowLeftIcon)
        
        let arrowRight = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        arrowRight.name = "shopNextButton"
        arrowRight.name = "shopNextButton"
        arrowRight.size = CGSize(width: 44.0, height: 44.0)
        arrowRight.position = CGPoint(x: cardW * 0.40, y: cardH * 0.08)
        arrowRight.zPosition = 8
        card.addChild(arrowRight)
        
        let arrowRightIcon = SKSpriteNode(imageNamed: "gui_icon_arrow_right")
        arrowRightIcon.name = "shopNextButton"
        arrowRightIcon.size = CGSize(width: 20.0, height: 20.0)
        arrowRightIcon.position = .zero
        arrowRightIcon.zPosition = 2
        arrowRight.addChild(arrowRightIcon)
        
        // 7. Контейнер динамічного вмісту теми
        let contentContainer = SKNode()
        contentContainer.name = "shopDynamicContent"
        contentContainer.zPosition = 5
        card.addChild(contentContainer)
        
        // 8. Кнопка перегляду реклами для отримання безкоштовних монет
        setupShopAdRewardButton(on: card, cardW: cardW, cardH: cardH)
        
        // Рендеримо картку ДО застосування початкового масштабу появи,
        // щоб розміри та позиції не спотворювалися масштабуванням картки
        renderCurrentShopCard()
        
        // Анімація появи
        container.alpha = 0.0
        card.setScale(0.85)
        container.run(SKAction.fadeIn(withDuration: 0.20))
        card.run(SKAction.scale(to: 1.0, duration: 0.20))
    }
    
    /// Рендеринг поточного персонажа/теми у вікні магазину
    private func renderCurrentShopCard() {
        guard let shop = shopNode,
              let card = shop.childNode(withName: "shopCard"),
              let content = card.childNode(withName: "shopDynamicContent") else { return }
        
        content.removeAllChildren()
        
        // Оновлюємо лічильник балансу
        if let balance = card.childNode(withName: "shopBalanceNode")?.childNode(withName: "shopBalanceLabel") as? SKLabelNode,
           let coin = card.childNode(withName: "shopBalanceNode")?.childNode(withName: "shopCoinIcon") as? SKSpriteNode {
            coin.texture = SKTexture(imageNamed: ThemeManager.shared.currentTheme.guiCoinIconName)
            balance.text = totalCoins.formattedWithSeparator
            let balSpacing: CGFloat = 8.0
            let totalW = coin.size.width + balSpacing + balance.frame.width
            coin.position = CGPoint(x: -totalW / 2.0 + coin.size.width / 2.0, y: 0)
            balance.position = CGPoint(x: coin.position.x + coin.size.width / 2.0 + balSpacing, y: 0)
        }
        
        let themes = ThemeManager.shared.themes
        guard currentShopIndex >= 0, currentShopIndex < themes.count else { return }
        let theme = themes[currentShopIndex]
        let isUnlocked = ThemeManager.shared.isUnlocked(theme)
        let isSelected = (theme.id == ThemeManager.shared.selectedThemeID)
        let canAfford = ThemeManager.shared.canAfford(theme)
        
        let cardSprite = card as? SKSpriteNode
        let scaleY = abs(cardSprite?.yScale ?? 1.0)
        let currentScaleY = scaleY > 0.001 ? scaleY : 1.0
        let cardH = (cardSprite?.size.height ?? 530.0) / currentScaleY
        let cardW = (cardSprite?.size.width ?? 330.0)
        
        // А. П'єдестал та аватар персонажа
        let avatarBg = SKSpriteNode(imageNamed: theme.guiCardFrameName)
        avatarBg.size = CGSize(width: 122.0, height: 122.0)
        avatarBg.position = CGPoint(x: 0, y: cardH * 0.08)
        avatarBg.zPosition = 1
        content.addChild(avatarBg)
        
        let heroAvatar = SKSpriteNode(imageNamed: theme.previewImageName)
        heroAvatar.size = CGSize(width: 86.0, height: 86.0)
        heroAvatar.position = CGPoint(x: 0, y: -4.0)
        heroAvatar.zPosition = 2
        avatarBg.addChild(heroAvatar)
        
        // Пульсація аватара
        let breatheUp = SKAction.scale(to: 1.05, duration: 1.1)
        let breatheDown = SKAction.scale(to: 0.98, duration: 1.1)
        breatheUp.timingMode = .easeInEaseOut
        breatheDown.timingMode = .easeInEaseOut
        heroAvatar.run(SKAction.repeatForever(SKAction.sequence([breatheUp, breatheDown])))
        
        // Статусний бейдж на кутку аватара
        if isSelected {
            let badge = SKSpriteNode(imageNamed: "gui_icon_check")
            badge.size = CGSize(width: 24.0, height: 24.0)
            badge.position = CGPoint(x: 46.0, y: 46.0)
            badge.zPosition = 5
            avatarBg.addChild(badge)
        } else if !isUnlocked {
            let lock = SKSpriteNode(imageNamed: "gui_icon_lock")
            let lockH: CGFloat = 24.0
            let lockW: CGFloat = lockH * (130.0 / 164.0)
            lock.size = CGSize(width: lockW, height: lockH)
            lock.position = CGPoint(x: 46.0, y: 46.0)
            lock.zPosition = 5
            avatarBg.addChild(lock)
        }
        
        // Б. Назва теми (позиціонується з безпечним відступом під п'єдесталом аватара)
        let avatarBottomY = avatarBg.position.y - (avatarBg.size.height / 2.0)
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.text = theme.name
        titleLabel.fontSize = 17.0
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: avatarBottomY - 18.0)
        titleLabel.zPosition = 2
        content.addChild(titleLabel)
        
        // В. Опис характеристик
        let subtitleLabel = SKLabelNode(fontNamed: AppFont.name)
        subtitleLabel.text = theme.subtitle
        subtitleLabel.fontSize = 12.0
        subtitleLabel.fontColor = SKColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 0.90)
        subtitleLabel.position = CGPoint(x: 0, y: titleLabel.position.y - 17.0)
        subtitleLabel.zPosition = 2
        content.addChild(subtitleLabel)
        
        // Г. Індикатор пагінації (точки 1 2 3)
        let dotsContainer = SKNode()
        dotsContainer.position = CGPoint(x: 0, y: subtitleLabel.position.y - 17.0)
        dotsContainer.zPosition = 2
        content.addChild(dotsContainer)
        
        let dotSpacing: CGFloat = 16.0
        let totalDotsW = CGFloat(themes.count - 1) * dotSpacing
        for i in 0..<themes.count {
            let dot = SKShapeNode(circleOfRadius: (i == currentShopIndex) ? 4.5 : 3.0)
            dot.fillColor = (i == currentShopIndex) ? theme.guiAccentColor : SKColor.white.withAlphaComponent(0.35)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: -totalDotsW / 2.0 + CGFloat(i) * dotSpacing, y: 0)
            dotsContainer.addChild(dot)
        }
        
        // Д. Кнопка дії (ОБРАНО / ОБРАТИ / КУПИТИ)
        let btnW: CGFloat = min(220.0, cardW - 60.0)
        let btnH: CGFloat = 46.0
        let actionBtnNode = SKNode()
        actionBtnNode.name = isSelected ? "shopAlreadySelected" : "shopActionButton"
        actionBtnNode.position = CGPoint(x: 0, y: -cardH * 0.24)
        actionBtnNode.zPosition = 3
        content.addChild(actionBtnNode)
        
        if isSelected {
            let btnBg = SKSpriteNode(imageNamed: theme.guiSecondaryBtnName)
            btnBg.name = "shopAlreadySelected"
            btnBg.size = CGSize(width: btnW, height: btnH)
            btnBg.zPosition = 1
            actionBtnNode.addChild(btnBg)
            
            let checkIcon = SKSpriteNode(imageNamed: "gui_icon_check")
            checkIcon.name = "shopAlreadySelected"
            checkIcon.size = CGSize(width: 18.0, height: 18.0)
            checkIcon.position = CGPoint(x: -42.0, y: 1.0)
            checkIcon.zPosition = 3
            btnBg.addChild(checkIcon)
            
            let label = SKLabelNode(fontNamed: AppFont.name)
            label.name = "shopAlreadySelected"
            label.text = "SELECTED"
            label.fontSize = 18.0
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 10.0, y: 1.0)
            label.zPosition = 3
            btnBg.addChild(label)
        } else if isUnlocked {
            let btnBg = SKSpriteNode(imageNamed: theme.guiPrimaryBtnName)
            btnBg.name = "shopActionButton"
            btnBg.size = CGSize(width: btnW, height: btnH)
            btnBg.zPosition = 1
            actionBtnNode.addChild(btnBg)
            
            let label = SKLabelNode(fontNamed: AppFont.name)
            label.name = "shopActionButton"
            label.text = "SELECT"
            label.fontSize = 18.0
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 1.0)
            label.zPosition = 3
            btnBg.addChild(label)
        } else {
            // Заблокована тема — покупка
            let btnBg = SKSpriteNode(imageNamed: theme.guiPrimaryBtnName)
            btnBg.name = "shopActionButton"
            btnBg.size = CGSize(width: btnW, height: btnH)
            btnBg.alpha = canAfford ? 1.0 : 0.65
            if !canAfford {
                btnBg.color = .darkGray
                btnBg.colorBlendFactor = 0.35
            }
            btnBg.zPosition = 1
            actionBtnNode.addChild(btnBg)
            
            let coin = SKSpriteNode(imageNamed: theme.guiCoinIconName)
            coin.name = "shopActionButton"
            coin.size = CGSize(width: 19.0, height: 19.0)
            coin.zPosition = 3
            
            let label = SKLabelNode(fontNamed: AppFont.name)
            label.name = "shopActionButton"
            let formattedPrice = theme.price.formattedWithSeparator
            label.text = canAfford ? "BUY (\(formattedPrice))" : "\(formattedPrice) (NOT ENOUGH)"
            label.fontSize = canAfford ? 17.0 : 13.5
            label.fontColor = canAfford ? .white : SKColor(white: 0.95, alpha: 1.0)
            label.verticalAlignmentMode = .center
            label.zPosition = 3
            
            // Динамічне центроване розміщення: монетка + гарантований відступ + текст (наїзд неможливий)
            let spacing: CGFloat = 8.0
            let totalContentW = coin.size.width + spacing + label.frame.width
            let startX = -totalContentW / 2.0
            
            coin.position = CGPoint(x: startX + (coin.size.width / 2.0), y: 1.0)
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: startX + coin.size.width + spacing, y: 1.0)
            
            btnBg.addChild(coin)
            btnBg.addChild(label)
        }
    }
    
    /// Закриття оверлею магазину та повернення до головного меню
    private func dismissShopOverlay() {
        guard let shop = shopNode else { return }
        shop.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.18),
            SKAction.removeFromParent()
        ]))
        self.shopNode = nil
        self.shopAdRewardBtnNode = nil
        self.shopAdRewardBgSprite = nil
        self.shopAdRewardLabel = nil
        self.shopAdRewardPlayIcon = nil
        self.shopAdRewardCoinIcon = nil
        
        // Оновлюємо лічильник монет у меню
        updateMenuCoinsDisplay()
        
        // Відновлюємо інтервал автострибка в меню
        if gameState == .menu {
            scheduleNextMenuAutoJump(delay: 2.0)
        }
    }
    
    /// Оновлення лічильника монет у меню після покупок
    private func updateMenuCoinsDisplay() {
        menuCoinsText?.text = totalCoins.formattedWithSeparator
    }
    
    // MARK: - Shop Ad Reward Feature
    
    /// Налаштування кнопки перегляду реклами для отримання безкоштовних монет
    private func setupShopAdRewardButton(on card: SKNode, cardW: CGFloat, cardH: CGFloat) {
        let btnW: CGFloat = min(220.0, cardW - 60.0)
        let btnH: CGFloat = 44.0
        
        let container = SKNode()
        container.name = "shopAdRewardButton"
        container.position = CGPoint(x: 0, y: -cardH * 0.385)
        container.zPosition = 8
        card.addChild(container)
        self.shopAdRewardBtnNode = container
        
        let bgSprite = SKSpriteNode(imageNamed: "gui_btn_large_green")
        bgSprite.name = "shopAdRewardButton"
        bgSprite.size = CGSize(width: btnW, height: btnH)
        bgSprite.zPosition = 1
        container.addChild(bgSprite)
        self.shopAdRewardBgSprite = bgSprite
        
        let playIcon = SKSpriteNode(imageNamed: "gui_icon_play")
        playIcon.name = "shopAdRewardButton"
        playIcon.size = CGSize(width: 16.0, height: 16.0)
        playIcon.zPosition = 3
        bgSprite.addChild(playIcon)
        self.shopAdRewardPlayIcon = playIcon
        
        let label = SKLabelNode(fontNamed: AppFont.name)
        label.name = "shopAdRewardButton"
        label.fontSize = 16.0
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 3
        bgSprite.addChild(label)
        self.shopAdRewardLabel = label
        
        let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
        coinIcon.name = "shopAdRewardButton"
        coinIcon.size = CGSize(width: 20.0, height: 20.0)
        coinIcon.zPosition = 3
        bgSprite.addChild(coinIcon)
        self.shopAdRewardCoinIcon = coinIcon
        
        // Початкове налаштування стану (доступно чи кулдаун)
        updateShopAdRewardButtonState()
        
        // Таймер для щосекундного оновлення кулдауну
        container.removeAction(forKey: "shopAdTimer")
        let timerAction = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                self?.updateShopAdRewardTimerTick()
            }
        ]))
        container.run(timerAction, withKey: "shopAdTimer")
    }
    
    /// Оновлення візуального стану кнопки реклами в магазині
    private func updateShopAdRewardButtonState() {
        guard let container = shopAdRewardBtnNode,
              let bg = shopAdRewardBgSprite,
              let label = shopAdRewardLabel,
              let coin = shopAdRewardCoinIcon,
              let play = shopAdRewardPlayIcon else { return }
        
        // 1. Якщо відсутнє інтернет-підключення — кнопка вимкнена
        guard NetworkMonitor.shared.isConnected else {
            container.removeAction(forKey: "adPulse")
            container.setScale(1.0)
            
            bg.texture = SKTexture(imageNamed: currentTheme.guiSecondaryBtnName)
            bg.color = .black
            bg.colorBlendFactor = 0.35
            bg.alpha = 0.60
            
            play.isHidden = true
            coin.isHidden = true
            label.text = "NO INTERNET"
            label.fontColor = SKColor(white: 0.82, alpha: 0.85)
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 1.0)
            return
        }
        
        let isAvailable = ShopAdRewardManager.shared.isRewardAvailable
        coin.texture = SKTexture(imageNamed: currentTheme.guiCoinIconName)
        coin.isHidden = false
        
        if isAvailable {
            bg.texture = SKTexture(imageNamed: "gui_btn_large_green")
            bg.color = .clear
            bg.colorBlendFactor = 0.0
            bg.alpha = 1.0
            
            play.isHidden = false
            label.text = "FREE +\(ShopAdRewardManager.rewardCoins)"
            label.fontColor = .white
            
            // Центроване розташування [Play] [Text] [Coin]
            let spacing: CGFloat = 6.0
            let totalW = play.size.width + spacing + label.frame.width + spacing + coin.size.width
            let startX = -totalW / 2.0
            
            play.position = CGPoint(x: startX + (play.size.width / 2.0), y: 1.0)
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: play.position.x + (play.size.width / 2.0) + spacing, y: 1.0)
            coin.position = CGPoint(x: label.position.x + label.frame.width + spacing + (coin.size.width / 2.0), y: 1.0)
            
            // М'яка пульсація для привернення уваги, що нагорода доступна
            container.removeAction(forKey: "adPulse")
            let pulseUp = SKAction.scale(to: 1.035, duration: 0.85)
            let pulseDown = SKAction.scale(to: 0.975, duration: 0.85)
            pulseUp.timingMode = .easeInEaseOut
            pulseDown.timingMode = .easeInEaseOut
            container.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])), withKey: "adPulse")
        } else {
            container.removeAction(forKey: "adPulse")
            container.setScale(1.0)
            
            bg.texture = SKTexture(imageNamed: currentTheme.guiSecondaryBtnName)
            bg.color = .black
            bg.colorBlendFactor = 0.25
            bg.alpha = 0.85
            
            play.isHidden = true
            label.text = ShopAdRewardManager.shared.formattedCooldownString()
            label.fontColor = SKColor(white: 0.92, alpha: 1.0)
            
            // Центроване розташування [Coin] [Cooldown Text]
            let spacing: CGFloat = 8.0
            let totalW = coin.size.width + spacing + label.frame.width
            let startX = -totalW / 2.0
            
            coin.position = CGPoint(x: startX + (coin.size.width / 2.0), y: 1.0)
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: startX + coin.size.width + spacing, y: 1.0)
        }
    }
    
    /// Щосекундний тік таймера кулдауну
    private func updateShopAdRewardTimerTick() {
        guard let label = shopAdRewardLabel,
              let coin = shopAdRewardCoinIcon,
              let container = shopAdRewardBtnNode else { return }
        
        let isConnected = NetworkMonitor.shared.isConnected
        let wasOffline = (coin.isHidden == true)
        
        if !isConnected {
            if !wasOffline {
                updateShopAdRewardButtonState()
            }
            return
        }
        
        if wasOffline {
            // Мережа щойно відновилась
            updateShopAdRewardButtonState()
            return
        }
        
        let isAvailable = ShopAdRewardManager.shared.isRewardAvailable
        let wasAvailable = (shopAdRewardPlayIcon?.isHidden == false)
        
        if isAvailable {
            if !wasAvailable {
                // Завершення кулдауну: оновлюємо вигляд та запускаємо анімацію появи готовності
                updateShopAdRewardButtonState()
                container.run(SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.15),
                    SKAction.scale(to: 1.0, duration: 0.15)
                ]))
            }
        } else {
            label.text = ShopAdRewardManager.shared.formattedCooldownString()
            let spacing: CGFloat = 8.0
            let totalW = coin.size.width + spacing + label.frame.width
            let startX = -totalW / 2.0
            coin.position = CGPoint(x: startX + (coin.size.width / 2.0), y: 1.0)
            label.position = CGPoint(x: startX + coin.size.width + spacing, y: 1.0)
        }
    }
    
    /// Обробка натискання кнопки реклами в магазині
    private func handleShopAdRewardTapped() {
        guard let shop = shopNode,
              let card = shop.childNode(withName: "shopCard") else { return }
        
        // 1. Перевірка наявності інтернет-з'єднання
        guard NetworkMonitor.shared.isConnected else {
            playJumpSound()
            if let btn = shopAdRewardBtnNode {
                let left = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
                let right = SKAction.moveBy(x: 12, y: 0, duration: 0.08)
                let back = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
                btn.run(SKAction.sequence([left, right, back]))
            }
            showShopAdToast(on: card, text: "NO INTERNET CONNECTION", isSuccess: false)
            return
        }
        
        // 2. Перевірка кулдауну
        if !ShopAdRewardManager.shared.isRewardAvailable {
            // Кулдаун ще активний: похитування кнопки та підказка з часом до наступної нагороди
            playJumpSound()
            if let btn = shopAdRewardBtnNode {
                let left = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
                let right = SKAction.moveBy(x: 12, y: 0, duration: 0.08)
                let back = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
                btn.run(SKAction.sequence([left, right, back]))
            }
            showShopAdToast(on: card, text: "READY IN \(ShopAdRewardManager.shared.cooldownDescriptionString())", isSuccess: false)
            return
        }
        
        guard let vc = view?.window?.rootViewController ?? view?.next as? UIViewController else { return }
        playJumpSound()
        
        UnityAdsManager.shared.showRewardedAd(
            from: vc,
            customMessage: "Simulating Rewarded Video Ad playback.\nPress 'Claim Reward' to get +\(ShopAdRewardManager.rewardCoins) Coins for the Market!",
            actionTitle: "Claim +\(ShopAdRewardManager.rewardCoins) Coins"
        ) { [weak self] in
            guard let self = self else { return }
            
            // 1. Зараховуємо нагороду
            let earned = ShopAdRewardManager.shared.claimReward()
            
            // 2. Звук та частинки золотих монет
            self.playCoinSound()
            if let btn = self.shopAdRewardBtnNode {
                let scenePos = card.convert(btn.position, to: self)
                self.playCoinPickupEffect(at: scenePos)
            }
            
            // 3. Оновлення балансу в магазині з привабливою пульсацією
            if let balance = card.childNode(withName: "shopBalanceNode")?.childNode(withName: "shopBalanceLabel") as? SKLabelNode,
               let coin = card.childNode(withName: "shopBalanceNode")?.childNode(withName: "shopCoinIcon") as? SKSpriteNode {
                balance.text = self.totalCoins.formattedWithSeparator
                let balSpacing: CGFloat = 8.0
                let totalW = coin.size.width + balSpacing + balance.frame.width
                coin.position = CGPoint(x: -totalW / 2.0 + coin.size.width / 2.0, y: 0)
                balance.position = CGPoint(x: coin.position.x + coin.size.width / 2.0 + balSpacing, y: 0)
                
                balance.run(SKAction.sequence([
                    SKAction.scale(to: 1.30, duration: 0.15),
                    SKAction.scale(to: 1.0, duration: 0.15)
                ]))
            }
            
            // 4. Оновлення поточної картки скіна (якщо монет стало достатньо для купівлі)
            self.renderCurrentShopCard()
            
            // 5. Оновлення лічильника монет у головному меню
            self.updateMenuCoinsDisplay()
            
            // 6. Перехід кнопки в режим очікування кулдауну
            self.updateShopAdRewardButtonState()
            
            // 7. Спливаюче повідомлення про успішне отримання монет
            self.showShopAdToast(on: card, text: "+\(earned) COINS RECEIVED!", isSuccess: true)
            
        } onFailed: { message in
            print("[GameScene] Shop rewarded ad failed or skipped: \(message)")
        }
    }
    
    /// Відображення акуратного спливаючого тосту над кнопкою нагороди
    private func showShopAdToast(on card: SKNode, text: String, isSuccess: Bool) {
        card.childNode(withName: "shopAdToast")?.removeFromParent()
        
        let toast = SKNode()
        toast.name = "shopAdToast"
        toast.position = CGPoint(x: 0, y: (shopAdRewardBtnNode?.position.y ?? -200.0) + 36.0)
        toast.zPosition = 20
        
        let label = SKLabelNode(fontNamed: AppFont.name)
        label.text = text
        label.fontSize = 13.5
        label.fontColor = isSuccess ? SKColor(red: 1.0, green: 0.90, blue: 0.30, alpha: 1.0) : SKColor(red: 1.0, green: 0.45, blue: 0.40, alpha: 1.0)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 2
        toast.addChild(label)
        
        let bgW = label.frame.width + 20.0
        let bgH: CGFloat = 26.0
        let bg = SKShapeNode(rectOf: CGSize(width: bgW, height: bgH), cornerRadius: 6.0)
        bg.fillColor = SKColor.black.withAlphaComponent(0.85)
        bg.strokeColor = isSuccess ? SKColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 0.9) : SKColor.white.withAlphaComponent(0.3)
        bg.lineWidth = 1.0
        bg.zPosition = 1
        toast.addChild(bg)
        
        card.addChild(toast)
        
        toast.alpha = 0.0
        toast.setScale(0.85)
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        let wait = SKAction.wait(forDuration: 1.6)
        let disappear = SKAction.group([
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.moveBy(x: 0, y: 10, duration: 0.25)
        ])
        toast.run(SKAction.sequence([appear, wait, disappear, SKAction.removeFromParent()]))
    }
    
    /// Миттєве застосування поточної теми до сцени (персонаж, стіни, фон)
    private func applyCurrentThemeToScene() {
        let theme = ThemeManager.shared.currentTheme
        updateCachedThemeTextures()
        
        // 1. Оновлення образу персонажа
        player.applyTheme(prefix: theme.heroRunPrefix, frameCount: theme.heroRunCount)
        if gameState == .menu {
            player.setReadyStance()
        }
        
        // 2. Оновлення атмосферного оверлею фону та текстури фону
        let newBgTex = backgroundTexture
        newBgTex.filteringMode = .linear
        if newBgTex.size().width > 0 {
            backgroundNode?.texture = newBgTex
            let textureSize = newBgTex.size()
            let baseScale = max(size.width / textureSize.width, size.height / textureSize.height)
            let scale = baseScale * backgroundScaleMultiplier
            let bgSize = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
            backgroundNode?.size = bgSize
            
            let topH: CGFloat = 120.0
            backgroundTopExtensionNode?.size = CGSize(width: max(size.width, bgSize.width) + 40.0, height: topH)
            backgroundTopExtensionNode?.position = CGPoint(x: 0, y: (bgSize.height / 2.0) + (topH / 2.0) - 2.0)
            
            let botH: CGFloat = 120.0
            backgroundBottomExtensionNode?.size = CGSize(width: max(size.width, bgSize.width) + 40.0, height: botH)
            backgroundBottomExtensionNode?.position = CGPoint(x: 0, y: -(bgSize.height / 2.0) - (botH / 2.0) + 2.0)
        }
        backgroundTopExtensionNode?.run(SKAction.colorize(with: theme.backgroundTopColor, colorBlendFactor: 1.0, duration: 0.35))
        backgroundBottomExtensionNode?.run(SKAction.colorize(with: theme.backgroundBottomColor, colorBlendFactor: 1.0, duration: 0.35))
        backgroundOverlayNode?.run(SKAction.colorize(with: theme.backgroundOverlayColor, colorBlendFactor: 1.0, duration: 0.35))
        backgroundOverlayNode?.run(SKAction.fadeAlpha(to: theme.backgroundOverlayAlpha, duration: 0.35))
        
        // Оновлення текстури сердець у HUD
        let heartTex = cachedHeartTexture
        for heart in heartHUDNodes {
            heart.texture = heartTex
        }
        hudCoinIcon?.texture = SKTexture(imageNamed: theme.guiCoinIconName)
        
        // 3. Повне перезавантаження траси, стін, прірв та декорацій під нову тему (у режимі меню)
        if gameState == .menu {
            leftTrackNodes.forEach { $0.removeFromParent() }
            leftTrackNodes.removeAll()
            rightTrackNodes.forEach { $0.removeFromParent() }
            rightTrackNodes.removeAll()
            leftAbyssNodes.removeAll()
            rightAbyssNodes.removeAll()
            decorationNodes.forEach { $0.removeFromParent() }
            decorationNodes.removeAll()
            trackHeartNodes.forEach { $0.removeFromParent() }
            trackHeartNodes.removeAll()
            trackMobNodes.forEach { $0.removeFromParent() }
            trackMobNodes.removeAll()
            trackCoinNodes.forEach { $0.removeFromParent() }
            trackCoinNodes.removeAll()
            
            setupProceduralTrack()
            player.setReadyStance()
        }
        
        // 4. Оновлення елементів інтерфейсу головного меню під активну тему
        if let menu = menuNode {
            if let titleContainer = menu.childNode(withName: "menuTitle") {
                (titleContainer.childNode(withName: "menuBanner") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiBannerName)
                (titleContainer.childNode(withName: "menuBannerShadow") as? SKLabelNode)?.fontColor = theme.guiBannerShadowColor
            }
            if let card = menu.childNode(withName: "menuCard") as? SKSpriteNode {
                card.texture = SKTexture(imageNamed: theme.guiStatsBarName)
                (card.childNode(withName: "menuBestScoreText") as? SKLabelNode)?.fontColor = theme.guiStatsTextColor
                (card.childNode(withName: "menuCoinsText") as? SKLabelNode)?.fontColor = theme.guiStatsTextColor
                (card.childNode(withName: "menuCoinsIcon") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCoinIconName)
            }
            (menu.childNode(withName: "menuPlayButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiPrimaryBtnName)
            (menu.childNode(withName: "menuShopButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiSecondaryBtnName)
            (menu.childNode(withName: "menuSoundButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
        }
        
        // 5. Оновлення елементів інтерфейсу магазину (якщо відкритий)
        if let card = shopNode?.childNode(withName: "shopCard") {
            (card.childNode(withName: "shopBanner") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiBannerName)
            (card.childNode(withName: "shopCloseButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            (card.childNode(withName: "shopPrevButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            (card.childNode(withName: "shopNextButton") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCircleBtnName)
            if let balanceNode = card.childNode(withName: "shopBalanceNode") {
                (balanceNode.childNode(withName: "shopCoinIcon") as? SKSpriteNode)?.texture = SKTexture(imageNamed: theme.guiCoinIconName)
            }
            updateShopAdRewardButtonState()
        }
        
        // 6. Оновлення лічильника меню
        updateMenuCoinsDisplay()
    }
    
    /// Обробка виходу з гри при натисканні на кнопку Exit
    private func handleExitApp() {
        playJumpSound()
        if let exitBtn = menuNode?.childNode(withName: "menuExitButton") {
            exitBtn.run(SKAction.sequence([
                SKAction.scale(to: 0.90, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.08),
                SKAction.run {
                    UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        exit(0)
                    }
                }
            ]))
        } else {
            UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                exit(0)
            }
        }
    }
    
    /// Запуск бігу героя та підйому камери з тієї стіни, на якій він стоїть
    private func startClimb() {
        menuNode?.removeFromParent()
        menuNode = nil
        removeAction(forKey: "menuAutoJump")
        
        // Плавна поява ігрового HUD (життя, рахунок, монети)
        hudNode.alpha = 0.0
        hudNode.run(SKAction.fadeIn(withDuration: 0.25))
        
        // Головний герой починає бігти з тієї стіни, на якій він стоїть!
        if !player.isJumping {
            player.startRunningAnimation()
        }
        
        // Починається підйом камери та ігровий процес
        gameState = .playing
        lastUpdateTime = 0
        
        // Піднімаємо гучність фонової музики до повного ігрового рівня
        if !isMuted {
            GameAudio.shared.setBGMVolume(GameAudio.bgmTargetVolume, fadeDuration: 0.6)
        }
    }
    
    // MARK: - Procedural Track with Seamless Abysses, Hearts & Decorations
    
    private func setupProceduralTrack() {
        // Стартуємо генерацію від Y = 0
        currentLeftY = Config.tileSize / 2.0
        currentRightY = Config.tileSize / 2.0
        startCameraY = cameraNode.position.y
        lastCleanupCameraY = startCameraY
        leftAbyssNodes.removeAll()
        rightAbyssNodes.removeAll()
        
        decorationNodes.removeAll()
        lastLeftDecoY = 0
        lastRightDecoY = 0
        // Перше фонове дерево з'явиться не раніше 800 pt вище старту
        nextTreeBackgroundY = player.position.y + 800.0
        
        // Перша прірва з'явиться вище гравця на випадковій стіні
        nextAbyssIsOnLeft = Bool.random()
        consecutiveAbyssesOnSameWall = 1
        nextAbyssY = player.position.y + 320.0
        lastAbyssHitTime = 0
        
        // Серця тепер суттєво скорочені: перше з'явиться не раніше 280 очок (~7000 pt)
        trackHeartNodes.removeAll()
        nextHeartY = player.position.y + 7000.0
        
        // Ворожі моби: простий моб (патрульний) з'являється плавно на 60-90 очках,
        // а стрільці розблоковуються помітно пізніше (210-260 очок)
        trackMobNodes.removeAll()
        activeFireArrows.forEach { $0.removeFromParent() }
        activeFireArrows.removeAll()
        consecutivePatrollers = 0
        firstMobScoreThreshold = Int.random(in: 60...90)
        firstShooterScoreThreshold = Int.random(in: 210...260)
        nextMobY = startCameraY + (CGFloat(firstMobScoreThreshold) * Config.distancePerScorePoint)
        
        // Золотисті монети: перша група монет з'являється вже на початку підйому (~250 pt)
        trackCoinNodes.removeAll()
        nextCoinPatternY = player.position.y + 250.0
        
        // Початкові декорації біля стартової позиції гравця (природний антураж)
        setupInitialDecorations()
        
        // Будуємо стіни наперед
        buildTrack(upTo: cameraNode.position.y + (size.height * 1.5))
    }
    
    /// Початкові декорації біля стартової позиції гравця (природний антураж без табличок)
    private func setupInitialDecorations() {
        let pY = player.position.y
        
        // 1. Фонова структура обраної теми на старті зліва
        if !treeTextures.isEmpty {
            spawnBackgroundTree(onLeftWall: true, atY: pY + 140.0, textureIndex: 0, scale: 0.50)
        }
        
        // 2, 3, 4. Настінні декорації обраної теми (горизонтальна орієнтація перпендикулярно до скелі)
        if !decorTextures.isEmpty {
            let tex1 = decorTextures[0]
            let s1 = tex1.size()
            let aspect1 = s1.width / max(s1.height, 1.0)
            let h1: CGFloat = 26.0
            let w1 = min(h1 * aspect1, 46.0)
            let deco1 = SKSpriteNode(texture: tex1, size: CGSize(width: w1, height: h1))
            deco1.zPosition = 3.2
            deco1.zRotation = -.pi / 2.0
            deco1.xScale = -1.0
            deco1.position = CGPoint(x: Config.wallWidth + (h1 / 2.0) - 3.0, y: pY - 30.0)
            addChild(deco1)
            decorationNodes.append(deco1)
            
            let tex2 = decorTextures.count > 1 ? decorTextures[1] : decorTextures[0]
            let s2 = tex2.size()
            let aspect2 = s2.width / max(s2.height, 1.0)
            let h2: CGFloat = 26.0
            let w2 = min(h2 * aspect2, 46.0)
            let deco2 = SKSpriteNode(texture: tex2, size: CGSize(width: w2, height: h2))
            deco2.zPosition = 3.2
            deco2.zRotation = -.pi / 2.0
            deco2.xScale = -1.0
            deco2.position = CGPoint(x: Config.wallWidth + (h2 / 2.0) - 3.0, y: pY + 40.0)
            addChild(deco2)
            decorationNodes.append(deco2)
            
            let tex3 = decorTextures.count > 2 ? decorTextures[2] : decorTextures[0]
            let s3 = tex3.size()
            let aspect3 = s3.width / max(s3.height, 1.0)
            let h3: CGFloat = 26.0
            let w3 = min(h3 * aspect3, 46.0)
            let deco3 = SKSpriteNode(texture: tex3, size: CGSize(width: w3, height: h3))
            deco3.zPosition = 3.2
            deco3.zRotation = .pi / 2.0
            deco3.xScale = 1.0
            deco3.position = CGPoint(x: size.width - Config.wallWidth - (h3 / 2.0) + 3.0, y: pY + 80.0)
            addChild(deco3)
            decorationNodes.append(deco3)
        }
    }
    
    /// Перевіряє, чи є заданий вертикальний діапазон стіни повністю суцільним (без прірв по всій висоті)
    private func isWallRangeSolid(onLeftWall: Bool, minY: CGFloat, maxY: CGFloat, safetyMargin: CGFloat = 60.0) -> Bool {
        let bottom = min(minY, maxY)
        let top = max(minY, maxY)
        let abyssNodes = onLeftWall ? leftAbyssNodes : rightAbyssNodes
        
        for abyss in abyssNodes {
            let abyssHalfHeight = (abyss.gapHeight / 2.0) + Config.tileSize
            let abyssMinY = abyss.position.y - abyssHalfHeight - safetyMargin
            let abyssMaxY = abyss.position.y + abyssHalfHeight + safetyMargin
            // Швидка O(1) перевірка перетину двох відрізків [bottom, top] та [abyssMinY, abyssMaxY]
            if max(bottom, abyssMinY) <= min(top, abyssMaxY) {
                return false
            }
        }
        
        // Також перевіряємо заплановану наступну прірву, якщо вона на цій стіні
        if nextAbyssIsOnLeft == onLeftWall {
            let plannedMinY = nextAbyssY - safetyMargin
            let plannedMaxY = nextAbyssY + (Config.tileSize * 4.0) + safetyMargin
            if max(bottom, plannedMinY) <= min(top, plannedMaxY) {
                return false
            }
        }
        
        return true
    }
    
    /// Перевіряє, чи є на стіні безпечна суцільна ділянка скелі без прірв
    private func isWallSolid(onLeftWall: Bool, atY yPos: CGFloat, safetyMargin: CGFloat = 80.0) -> Bool {
        return isWallRangeSolid(onLeftWall: onLeftWall, minY: yPos, maxY: yPos, safetyMargin: safetyMargin)
    }
    
    /// Спроба посадити фонове дерево тільки на суцільну скелю (гарантовано не над прірвою)
    private func trySpawnBackgroundTree(candidateY: CGFloat) {
        // Обираємо сторону, де стіна гарантовано суцільна
        let preferredLeft = Bool.random()
        let targetSide: Bool?
        
        if isWallSolid(onLeftWall: preferredLeft, atY: candidateY, safetyMargin: 120.0) {
            targetSide = preferredLeft
        } else if isWallSolid(onLeftWall: !preferredLeft, atY: candidateY, safetyMargin: 120.0) {
            targetSide = !preferredLeft
        } else {
            targetSide = nil
        }
        
        if let onLeft = targetSide {
            spawnBackgroundTree(onLeftWall: onLeft, atY: candidateY)
            // Рідкісний, живописний інтервал між деревами: кожні 750...1200 pt
            nextTreeBackgroundY = candidateY + CGFloat.random(in: 750.0...1200.0)
        } else {
            // Обидві стіни мають прірви або небезпечні зони — відкладаємо генерацію на 160 pt вище
            nextTreeBackgroundY = candidateY + 160.0
        }
    }
    
    /// Спавнить фонове дерево або масштабну декорацію каньйону (горизонтальна орієнтація перпендикулярно до скелі)
    private func spawnBackgroundTree(onLeftWall: Bool, atY: CGFloat, textureIndex: Int? = nil, scale: CGFloat? = nil) {
        guard !treeTextures.isEmpty else { return }
        let chosenIndex = textureIndex ?? Int.random(in: 0..<treeTextures.count)
        let tex = treeTextures[chosenIndex]
        let texName = currentTheme.treeTextureNames.indices.contains(chosenIndex) ? currentTheme.treeTextureNames[chosenIndex] : ""
        let aspect = tex.size().width / max(tex.size().height, 1.0)
        
        // 1. Дерево / Коріння Світового Дерева (deco_forest_root) — росте горизонтально зі скелі вглиб каньйону
        if texName.contains("root") {
            let rootHeight: CGFloat = CGFloat.random(in: 95...125)
            let rootWidth = rootHeight * aspect
            let rootNode = SKSpriteNode(texture: tex, size: CGSize(width: rootWidth, height: rootHeight))
            rootNode.zPosition = -6
            rootNode.alpha = CGFloat.random(in: 0.82...0.92)
            
            let offset = (rootHeight / 2.0) - 14.0
            if onLeftWall {
                rootNode.zRotation = -.pi / 2.0
                rootNode.xScale = -1.0
                rootNode.position = CGPoint(x: Config.wallWidth + offset, y: atY)
            } else {
                rootNode.zRotation = .pi / 2.0
                rootNode.xScale = 1.0
                rootNode.position = CGPoint(x: size.width - Config.wallWidth - offset, y: atY)
            }
            
            addChild(rootNode)
            decorationNodes.append(rootNode)
            return
        }
        
        // 2. Прадавня статуя, портал або кришталева колона / розсип — горизонтально закріплені на скелі (основа в скелі, вершина в бік каньйону)
        if texName.contains("statue") || texName.contains("portal") || texName.contains("pillar") || texName.contains("pile") {
            let landmarkHeight: CGFloat = (texName.contains("statue") || texName.contains("pillar")) ? CGFloat.random(in: 74...86) : CGFloat.random(in: 70...80)
            let landmarkWidth = landmarkHeight * aspect
            let landmark = SKSpriteNode(texture: tex, size: CGSize(width: landmarkWidth, height: landmarkHeight))
            landmark.zPosition = -5
            landmark.alpha = CGFloat.random(in: 0.88...0.96)
            
            let offset = (landmarkHeight / 2.0) - 12.0
            if onLeftWall {
                landmark.zRotation = -.pi / 2.0
                landmark.xScale = -1.0
                landmark.position = CGPoint(x: Config.wallWidth + offset, y: atY)
            } else {
                landmark.zRotation = .pi / 2.0
                landmark.xScale = 1.0
                landmark.position = CGPoint(x: size.width - Config.wallWidth - offset, y: atY)
            }
            
            addChild(landmark)
            decorationNodes.append(landmark)
            return
        }
        
        // 3. Стандартне дерево (Autumn Forest: deco_tree_01, deco_tree_02 — горизонтальний ріст стовбура та крони зі скелі)
        let s = scale ?? CGFloat.random(in: 0.44...0.52)
        let treeSize = CGSize(width: tex.size().width * s, height: tex.size().height * s)
        let tree = SKSpriteNode(texture: tex, size: treeSize)
        tree.zPosition = -5
        tree.alpha = CGFloat.random(in: 0.84...0.94)
        
        let rootOffset = (treeSize.height / 2.0) - 16.0
        if onLeftWall {
            // Стовбур біля лівої скелі, крона розростається праворуч углиб каньйону
            tree.zRotation = -.pi / 2.0
            tree.xScale = -1.0
            tree.position = CGPoint(x: Config.wallWidth + rootOffset, y: atY)
        } else {
            // Стовбур біля правої скелі, крона розростається ліворуч углиб каньйону
            tree.zRotation = .pi / 2.0
            tree.xScale = 1.0
            tree.position = CGPoint(x: size.width - Config.wallWidth - rootOffset, y: atY)
        }
        
        addChild(tree)
        decorationNodes.append(tree)
    }
    
    /// Спавнить попереджувальну табличку на безпечній відстані перед прірвою (на суцільній стіні нижче уступу)
    private func spawnAbyssWarningSign(onLeftWall: Bool, atY: CGFloat) {
        let texture = signpostTextures.randomElement() ?? signpostTextures[0]
        let sign = SKSpriteNode(texture: texture, size: CGSize(width: 28, height: 32))
        sign.zPosition = 3.2
        let signOffset: CGFloat = (32.0 / 2.0) - 3.0
        
        // Розміщуємо табличку завчасно перед прірвою (на 1.25 тайла нижче обриву, на суцільній стіні)
        let warningY = atY - (Config.tileSize * 1.25)
        
        if onLeftWall {
            sign.zRotation = -.pi / 2.0
            sign.xScale = -1.0
            sign.position = CGPoint(x: Config.wallWidth + signOffset, y: warningY)
            lastLeftDecoY = warningY
        } else {
            sign.zRotation = .pi / 2.0
            sign.xScale = 1.0
            sign.position = CGPoint(x: size.width - Config.wallWidth - signOffset, y: warningY)
            lastRightDecoY = warningY
        }
        
        addChild(sign)
        decorationNodes.append(sign)
    }
    
    /// Процедурний спавн природних декорацій на стіні (кущики, каміння, пеньки, факели, ліани, паркани — у горизонтальній орієнтації перпендикулярно до скелі)
    private func maybeSpawnWallDecoration(onLeftWall: Bool, yPos: CGFloat) {
        let lastY = onLeftWall ? lastLeftDecoY : lastRightDecoY
        // Мінімальна відстань між декораціями на одній стіні — 110 pt, щоб стіни залишалися охайними
        guard (yPos - lastY) >= 110.0 else { return }
        
        // Перевіряємо, чи стіна суцільна (гарантуємо, що кущ або камінь не висить над прірвою)
        guard isWallSolid(onLeftWall: onLeftWall, atY: yPos, safetyMargin: 35.0) else { return }
        
        // 20% шанс спавну декорації на поточному тайлі
        guard Int.random(in: 1...100) <= 20 else { return }
        
        let roll = Int.random(in: 0...99)
        let sprite: SKSpriteNode
        let protrusionOffset: CGFloat
        
        if !decorTextures.isEmpty {
            let tex = decorTextures[Int.random(in: 0..<decorTextures.count)]
            let texSize = tex.size()
            let aspect = texSize.width / max(texSize.height, 1.0)
            let baseH: CGFloat = CGFloat.random(in: 22...28)
            let w = min(baseH * aspect, 46.0)
            let h = baseH
            sprite = SKSpriteNode(texture: tex, size: CGSize(width: w, height: h))
            protrusionOffset = (h / 2.0) - 2.5
        } else if roll < 48 {
            // Осінній кущик (Bush 01): горизонтальний ріст зі скелі в коридор
            let s = CGFloat.random(in: 24...28)
            sprite = SKSpriteNode(texture: bushTexture, size: CGSize(width: s, height: s))
            protrusionOffset = (s / 2.0) - 2.5
        } else if roll < 82 {
            // Скельний виступ / камінь (Stone 01 / Stone 02)
            let tex = stoneTextures[Int.random(in: 0..<stoneTextures.count)]
            let s = CGFloat.random(in: 22...26)
            sprite = SKSpriteNode(texture: tex, size: CGSize(width: s, height: s))
            protrusionOffset = (s / 2.0) - 2.5
        } else {
            // Пеньок (Stump): плоска основа у скелі
            let w = CGFloat.random(in: 26...30)
            let h = w * 0.52
            sprite = SKSpriteNode(texture: stumpTexture, size: CGSize(width: w, height: h))
            protrusionOffset = (h / 2.0) - 2.0
        }
        
        sprite.zPosition = 3.2
        if onLeftWall {
            sprite.zRotation = -.pi / 2.0
            sprite.xScale = -1.0
            sprite.position = CGPoint(x: Config.wallWidth + protrusionOffset, y: yPos)
            lastLeftDecoY = yPos
        } else {
            sprite.zRotation = .pi / 2.0
            sprite.xScale = 1.0
            sprite.position = CGPoint(x: size.width - Config.wallWidth - protrusionOffset, y: yPos)
            lastRightDecoY = yPos
        }
        
        addChild(sprite)
        decorationNodes.append(sprite)
    }
    
    /// Процедурне планування наступної прірви:
    /// Стіна обирається випадково (може бути 1 або 2 поспіль на одній стіні: 2 справа, 2 зліва, 1 справа, 1 зліва тощо)
    private func scheduleNextAbyss(justSpawnedOnLeft: Bool) {
        let pickLeft: Bool
        if consecutiveAbyssesOnSameWall >= maxConsecutiveAbyssesOnSameWall {
            // Досягнуто ліміту поспіль на одній стіні — гарантовано перемикаємо на протилежну
            pickLeft = !justSpawnedOnLeft
            consecutiveAbyssesOnSameWall = 1
        } else {
            // Рандомізація вибору стіни: 50% залишитися на тій же стіні, 50% перейти на протилежну
            pickLeft = Bool.random()
            if pickLeft == justSpawnedOnLeft {
                consecutiveAbyssesOnSameWall += 1
            } else {
                consecutiveAbyssesOnSameWall = 1
            }
        }
        
        nextAbyssIsOnLeft = pickLeft
        // Нова прірва гарантовано починається безпечно вище найвищої збудованої точки обох стін
        nextAbyssY = max(currentLeftY, currentRightY) + randomAbyssDistance()
    }
    
    /// Покроково будує обидві стіни у сітці без швів, інтегруючи прірви, серця та декорації
    private func buildTrack(upTo targetY: CGFloat) {
        let tileSize = Config.tileSize
        
        // Будуємо обидві стіни синхронно вгору
        while currentLeftY < targetY || currentRightY < targetY {
            
            // 1. Генерація ЛІВОЇ стіни
            if currentLeftY < targetY {
                if nextAbyssIsOnLeft && currentLeftY >= nextAbyssY {
                    // Спавнимо прірву різного розміру (залежно від рівня складності / очок)
                    let gapTiles = randomAbyssGapTileCount()
                    buildAbyssGap(onLeftWall: true, gapTileCount: gapTiles)
                    
                    // Плануємо наступну прірву процедурно (випадкова стіна з чергуванням/повторенням)
                    scheduleNextAbyss(justSpawnedOnLeft: true)
                } else {
                    // Звичайний суцільний тайл доріжки (Ground 02)
                    let tile = createWallTile(texture: wallTexture, yPos: currentLeftY, isLeft: true)
                    addChild(tile)
                    leftTrackNodes.append(tile)
                    maybeSpawnWallDecoration(onLeftWall: true, yPos: currentLeftY)
                    currentLeftY += tileSize
                }
            }
            
            // 2. Генерація ПРАВОЇ стіни
            if currentRightY < targetY {
                if !nextAbyssIsOnLeft && currentRightY >= nextAbyssY {
                    // Спавнимо прірву різного розміру на ПРАВІЙ стіні
                    let gapTiles = randomAbyssGapTileCount()
                    buildAbyssGap(onLeftWall: false, gapTileCount: gapTiles)
                    
                    // Плануємо наступну прірву процедурно (випадкова стіна з чергуванням/повторенням)
                    scheduleNextAbyss(justSpawnedOnLeft: false)
                } else {
                    // Звичайний суцільний тайл доріжки (Ground 02)
                    let tile = createWallTile(texture: wallTexture, yPos: currentRightY, isLeft: false)
                    addChild(tile)
                    rightTrackNodes.append(tile)
                    maybeSpawnWallDecoration(onLeftWall: false, yPos: currentRightY)
                    currentRightY += tileSize
                }
            }
            
            // 3. Фонова атмосфера лісу (осінні дерева — тільки на суцільних скелях з великим інтервалом)
            if currentLeftY >= nextTreeBackgroundY {
                trySpawnBackgroundTree(candidateY: nextTreeBackgroundY)
            }
            
            // 4. Генерація додаткових життів (life_hearth) - рідкісний шанс появи
            if currentLeftY >= nextHeartY {
                spawnHeartItem(atY: nextHeartY)
                nextHeartY = currentLeftY + randomHeartDistance()
            }
            
            // 5. Процедурна генерація ворожих мобів (патрулювання від точки А до точки Б)
            if currentLeftY >= nextMobY {
                trySpawnMob(candidateY: nextMobY)
            }
            
            // 6. Процедурна генерація золотистих монет (на стінах та в повітрі під час стрибків)
            if currentLeftY >= nextCoinPatternY {
                spawnCoinPattern(atY: nextCoinPatternY)
                nextCoinPatternY = currentLeftY + CGFloat.random(in: 320.0...520.0)
            }
        }
    }
    
    /// Будує безшовну прірву у доріжці заданого розміру:
    /// [Ground 02] -> [Ground 08 (уступ кінця стіни)] -> [РОЗРИВ/ПРІРВА] -> [Ground 04 (уступ початку стіни)] -> [Ground 02]
    private func buildAbyssGap(onLeftWall: Bool, gapTileCount: Int) {
        let tileSize = Config.tileSize
        
        if onLeftWall {
            // Крок А: Нижній уступ обриву стіни (Ground 08) - ідеально стикується з доріжкою знизу
            let lowerCliff = createWallTile(texture: cliffLowerTexture, yPos: currentLeftY, isLeft: true)
            addChild(lowerCliff)
            leftTrackNodes.append(lowerCliff)
            spawnAbyssWarningSign(onLeftWall: true, atY: currentLeftY)
            currentLeftY += tileSize
            
            // Крок Б: Сам розрив різної висоти (прірва, де стіна відсутня)
            let gapHeight = CGFloat(gapTileCount) * tileSize
            let gapCenterY = currentLeftY + (gapHeight / 2.0) - (tileSize / 2.0)
            let gapObstacle = AbyssObstacleNode(isOnLeftWall: true, wallWidth: Config.wallWidth, gapHeight: gapHeight)
            gapObstacle.position = CGPoint(x: Config.wallWidth / 2.0, y: gapCenterY)
            addChild(gapObstacle)
            leftTrackNodes.append(gapObstacle)
            leftAbyssNodes.append(gapObstacle)
            currentLeftY += gapHeight
            
            // Крок В: Верхній уступ обриву стіни (Ground 04) - ідеально переходить у доріжку вгорі
            let upperCliff = createWallTile(texture: cliffUpperTexture, yPos: currentLeftY, isLeft: true)
            addChild(upperCliff)
            leftTrackNodes.append(upperCliff)
            currentLeftY += tileSize
        } else {
            // Крок А: Нижній уступ обриву стіни (Ground 08) на правій стіні
            let lowerCliff = createWallTile(texture: cliffLowerTexture, yPos: currentRightY, isLeft: false)
            addChild(lowerCliff)
            rightTrackNodes.append(lowerCliff)
            spawnAbyssWarningSign(onLeftWall: false, atY: currentRightY)
            currentRightY += tileSize
            
            // Крок Б: Розрив на правій стіні
            let gapHeight = CGFloat(gapTileCount) * tileSize
            let gapCenterY = currentRightY + (gapHeight / 2.0) - (tileSize / 2.0)
            let gapObstacle = AbyssObstacleNode(isOnLeftWall: false, wallWidth: Config.wallWidth, gapHeight: gapHeight)
            gapObstacle.position = CGPoint(x: size.width - (Config.wallWidth / 2.0), y: gapCenterY)
            addChild(gapObstacle)
            rightTrackNodes.append(gapObstacle)
            rightAbyssNodes.append(gapObstacle)
            currentRightY += gapHeight
            
            // Крок В: Верхній уступ обриву стіни (Ground 04) на правій стіні
            let upperCliff = createWallTile(texture: cliffUpperTexture, yPos: currentRightY, isLeft: false)
            addChild(upperCliff)
            rightTrackNodes.append(upperCliff)
            currentRightY += tileSize
        }
    }
    
    /// Створює тайл стіни із точною орієнтацією та позицією
    private func createWallTile(texture: SKTexture, yPos: CGFloat, isLeft: Bool) -> SKSpriteNode {
        let tileSize = Config.tileSize
        let tile = SKSpriteNode(texture: texture, size: CGSize(width: tileSize, height: tileSize))
        tile.name = "wallTile"
        tile.zPosition = 3
        
        if isLeft {
            tile.zRotation = -.pi / 2.0
            tile.xScale = 1.0
            tile.position = CGPoint(x: tileSize / 2.0, y: yPos)
        } else {
            tile.zRotation = .pi / 2.0
            tile.xScale = -1.0
            tile.position = CGPoint(x: size.width - (tileSize / 2.0), y: yPos)
        }
        
        return tile
    }
    
    /// Створює додаткове життя на карті тільки в безпечному місці (гарантовано не над прірвою)
    private func spawnHeartItem(atY: CGFloat) {
        let isLeftSafe = isWallRangeSolid(onLeftWall: true, minY: atY - 20.0, maxY: atY + 20.0, safetyMargin: 28.0)
        let isRightSafe = isWallRangeSolid(onLeftWall: false, minY: atY - 20.0, maxY: atY + 20.0, safetyMargin: 28.0)
        
        let heartX: CGFloat
        let roll = Int.random(in: 0...9)
        
        if roll < 4 && isLeftSafe {
            heartX = playerLeftX
        } else if roll < 8 && isRightSafe {
            heartX = playerRightX
        } else if isLeftSafe && isRightSafe {
            heartX = size.width / 2.0
        } else if isLeftSafe {
            heartX = playerLeftX
        } else if isRightSafe {
            heartX = playerRightX
        } else {
            // На обох стінах у цій точці прірва — відкладаємо появу серця вище на 100 pt
            nextHeartY = atY + 100.0
            return
        }
        
        let heart = HeartItemNode(textureName: currentTheme.heartTextureName)
        heart.position = CGPoint(x: heartX, y: atY)
        addChild(heart)
        trackHeartNodes.append(heart)
    }
    
    /// Інтервал між спавнами ворожих мобів у стилі Subway Surfers:
    /// Безперервна експоненційна функція, що плавно та органічно скорочує дистанцію між ворогами.
    /// Повністю відсутні дискретні стрибки густоти мобів.
    private func randomMobDistance() -> CGFloat {
        let s = CGFloat(max(0, score))
        let meanDistance = 160.0 + 640.0 * exp(-s / 380.0)
        let spread = meanDistance * 0.15
        return CGFloat.random(in: (meanDistance - spread)...(meanDistance + spread))
    }
    
    /// Перевірка умов безпеки та чесності спавну моба:
    /// 1. Стіна, де рухається моб, суцільна на ділянці патруля (з невеликим запасом).
    /// 2. Протилежна стіна має безпечну ділянку для ухилення стрибком.
    /// 3. Відсутність накладання на інших активних мобів.
    private func canSpawnMob(onLeftWall: Bool, startY: CGFloat, endY: CGFloat) -> Bool {
        // 1. Власна стіна моба суцільна на ділянці патруля
        guard isWallRangeSolid(onLeftWall: onLeftWall, minY: startY, maxY: endY, safetyMargin: 15.0) else {
            return false
        }
        
        // 2. Протилежна стіна має тверду поверхню навпроти зони контакту
        guard isWallRangeSolid(onLeftWall: !onLeftWall, minY: startY - 10.0, maxY: endY + 20.0, safetyMargin: 10.0) else {
            return false
        }
        
        // 3. Дистанція до інших мобів (щоб уникнути непрохідних скупчень)
        for mob in trackMobNodes {
            let sameWall = (mob.isOnLeftWall == onLeftWall)
            let buffer: CGFloat = sameWall ? 90.0 : 50.0
            let mobMin = mob.pointAY - buffer
            let mobMax = mob.pointBY + buffer
            if startY <= mobMax && endY >= mobMin {
                return false
            }
        }
        
        return true
    }
    
    /// Спроба процедурного спавну моба на основі поточної висоти каньйону
    private func trySpawnMob(candidateY: CGFloat) {
        // Плавна адаптація патрулювання без дискретних сходинок у стилі Subway Surfers:
        // довжина і швидкість мобів змінюються плавно в міру зростання дистанції
        let patrolProgress = min(1.0, CGFloat(max(0, score)) / 750.0)
        let maxPatrol: CGFloat = 120.0 - (patrolProgress * 55.0) // 120 -> 65 pt
        let minPatrol: CGFloat = 50.0 - (patrolProgress * 15.0)  // 50 -> 35 pt
        let patrolDistance = CGFloat.random(in: minPatrol...maxPatrol)
        let patrolSpeed = CGFloat.random(in: 60.0...85.0) + (patrolProgress * 65.0)
        let endY = candidateY + patrolDistance
        
        // Випадковий вибір стіни для патрулювання
        let preferredLeft = Bool.random()
        var targetSide: Bool?
        var finalEndY = endY
        
        // Збалансована поява мобів-стрільців:
        // 1. Прості моби з'являються першими (на розминці).
        // 2. Моби-стрільці з'являються помітно пізніше (score >= firstShooterScoreThreshold ~210-260).
        // 3. Шанс стрільця плавно зростає від 18% до 45% без різких стрибків.
        // 4. Не спавнимо стрільців поспіль (завжди чергуємо з простими мобами до високих очок).
        let shooterChance: Double
        if score < firstShooterScoreThreshold {
            shooterChance = 0.0
        } else if consecutivePatrollers < 1 && score < 600 {
            shooterChance = 0.0
        } else {
            let progress = min(1.0, Double(score - firstShooterScoreThreshold) / 500.0)
            shooterChance = 0.18 + (progress * 0.27)
        }
        
        let wantsShooter = (Double.random(in: 0...1) < shooterChance)
        let finalMobType: MobNode.MobType = wantsShooter ? .shooter : .patroller
        
        // Перевіряємо стіни: спочатку повна дистанція патруля
        if canSpawnMob(onLeftWall: preferredLeft, startY: candidateY, endY: endY) {
            targetSide = preferredLeft
            finalEndY = endY
        } else if canSpawnMob(onLeftWall: !preferredLeft, startY: candidateY, endY: endY) {
            targetSide = !preferredLeft
            finalEndY = endY
        } else {
            // Якщо повна дистанція не вмістилася між прірвами, перевіряємо компактний патруль
            let compactEndY = candidateY + 40.0
            if canSpawnMob(onLeftWall: preferredLeft, startY: candidateY, endY: compactEndY) {
                targetSide = preferredLeft
                finalEndY = compactEndY
            } else if canSpawnMob(onLeftWall: !preferredLeft, startY: candidateY, endY: compactEndY) {
                targetSide = !preferredLeft
                finalEndY = compactEndY
            } else {
                targetSide = nil
            }
        }
        
        if let onLeft = targetSide {
            if finalMobType == .shooter {
                consecutivePatrollers = 0
            } else {
                consecutivePatrollers += 1
            }
            
            let wallX = onLeft ? (leftWallInnerX + MobNode.Constants.footOffset) : (rightWallInnerX - MobNode.Constants.footOffset)
            let mobType = finalMobType
            let activeTextures = (mobType == .shooter) ? cachedShooterTextures : cachedPatrollerTextures
            
            let mob = MobNode(
                mobType: mobType,
                isOnLeftWall: onLeft,
                wallX: wallX,
                pointAY: candidateY,
                pointBY: finalEndY,
                patrolSpeed: patrolSpeed,
                customTextures: activeTextures,
                projectileType: currentTheme.projectileType
            )
            
            if mobType == .shooter {
                mob.onShootArrow = { [weak self] startPos, targetPos in
                    self?.spawnFireArrow(from: startPos, towards: targetPos, projectileType: self?.currentTheme.projectileType ?? .fire)
                }
            }
            
            addChild(mob)
            trackMobNodes.append(mob)
            
            // Наступний моб планується з інтервалом складності, гарантовано не відстаючи від поточної генерації
            nextMobY = max(candidateY, currentLeftY) + randomMobDistance()
        } else {
            // Якщо зараз на обох стінах у цій точці прірва, пробуємо трохи вище без відставання від стін
            nextMobY = max(candidateY + 50.0, currentLeftY + 30.0)
        }
    }
    
    /// Створення та додавання у сцену снаряду (вогняна або водяна стріла), випущеного мобом-стрільцем
    private func spawnFireArrow(from startPos: CGPoint, towards targetPos: CGPoint, projectileType: ProjectileType = .fire) {
        guard !isGameOver, !isPlayerFalling else { return }
        // Швидкість польоту снаряду динамічно адаптується під швидкість руху гри,
        // щоб на високих швидкостях стріли залишалися блискавичними та спортивними
        let arrowSpeed = max(250.0, currentUpwardSpeed * 0.90)
        let arrow = FireArrowNode(from: startPos, towards: targetPos, projectileType: projectileType, speed: arrowSpeed)
        addChild(arrow)
        activeFireArrows.append(arrow)
    }
    
    /// Процедурна генерація патернів золотистих монет на карті з суворою перевіркою безпеки (гарантовано не над прірвою):
    /// - 60% шанс: вертикальна доріжка з 3-4 монет уздовж однієї зі стін (тільки на повністю суцільній ділянці)
    /// - 40% шанс: дуга з 5 монет між стінами каньйону для збору в стрибку (ОБИДВІ стіни мають бути суцільними)
    private func spawnCoinPattern(atY: CGFloat) {
        let patternRoll = Int.random(in: 1...100)
        
        if patternRoll <= 60 {
            // Патерн 1: Вертикальна доріжка з 3-4 монет уздовж безпечної стіни
            let coinCount = Int.random(in: 3...4)
            let totalPatternHeight = CGFloat(coinCount - 1) * 36.0
            let startY = atY
            let endY = atY + totalPatternHeight
            
            let preferredLeft = Bool.random()
            let chosenWall: Bool?
            
            // Перевіряємо стіну по всій довжині з запасом безпеки
            if isWallRangeSolid(onLeftWall: preferredLeft, minY: startY - 35.0, maxY: endY + 35.0, safetyMargin: 50.0) {
                chosenWall = preferredLeft
            } else if isWallRangeSolid(onLeftWall: !preferredLeft, minY: startY - 35.0, maxY: endY + 35.0, safetyMargin: 50.0) {
                chosenWall = !preferredLeft
            } else {
                chosenWall = nil
            }
            
            if let wallIsLeft = chosenWall {
                spawnWallCoinLine(onLeft: wallIsLeft, startY: startY, count: coinCount)
            }
        } else {
            // Патерн 2: Параболічна дуга з 5 монет між стінами для динамічного збору під час стрибка.
            // Щоб монети не вели гравця у прірву, ОБИДВІ стіни (ліва і права) мають бути безпечними!
            let startY = atY
            let endY = atY + 40.0
            let isLeftSafe = isWallRangeSolid(onLeftWall: true, minY: startY - 40.0, maxY: endY + 50.0, safetyMargin: 60.0)
            let isRightSafe = isWallRangeSolid(onLeftWall: false, minY: startY - 40.0, maxY: endY + 50.0, safetyMargin: 60.0)
            
            if isLeftSafe && isRightSafe {
                // Обидві стіни монолітні — стрибок для збору монет 100% безпечний
                let coinCount = 5
                for i in 0..<coinCount {
                    let t = CGFloat(i) / CGFloat(coinCount - 1)
                    let x = playerLeftX + t * (playerRightX - playerLeftX)
                    let arcLift = sin(t * .pi) * 32.0
                    let y = atY + (t * 28.0) + arcLift
                    
                    let coin = CoinNode()
                    coin.position = CGPoint(x: x, y: y)
                    addChild(coin)
                    trackCoinNodes.append(coin)
                }
            } else if isLeftSafe {
                // Якщо права стіна має прірву, дугу не спавнимо, а ставимо монети безпечно на ліву стіну
                spawnWallCoinLine(onLeft: true, startY: atY, count: 3)
            } else if isRightSafe {
                // Якщо ліва стіна має прірву, ставимо монети безпечно на праву стіну
                spawnWallCoinLine(onLeft: false, startY: atY, count: 3)
            }
        }
    }
    
    /// Допоміжний метод для розміщення вертикальної лінії монет на безпечній стіні
    private func spawnWallCoinLine(onLeft: Bool, startY: CGFloat, count: Int) {
        let coinX = onLeft ? playerLeftX : playerRightX
        for i in 0..<count {
            let coin = CoinNode()
            coin.position = CGPoint(x: coinX, y: startY + CGFloat(i) * 36.0)
            addChild(coin)
            trackCoinNodes.append(coin)
        }
    }
    
    /// Видаляє тайли та розриви, які залишилися далеко внизу за екраном (з розумним тротлінгом для стабільних 60-120 FPS)
    private func cleanupPassedTrack(force: Bool = false) {
        let currentCamY = cameraNode.position.y
        if !force && (currentCamY - lastCleanupCameraY) < 40.0 {
            return
        }
        lastCleanupCameraY = currentCamY
        
        let screenBottom = currentCamY - (size.height / 2.0) - 150.0
        
        // Видалення зі стін (масиви впорядковані по Y за зростанням, швидке пакетне видалення O(1))
        let removeLeftCount = leftTrackNodes.prefix(while: { $0.position.y < screenBottom }).count
        if removeLeftCount > 0 {
            for i in 0..<removeLeftCount {
                leftTrackNodes[i].removeFromParent()
            }
            leftTrackNodes.removeFirst(removeLeftCount)
        }
        
        let removeRightCount = rightTrackNodes.prefix(while: { $0.position.y < screenBottom }).count
        if removeRightCount > 0 {
            for i in 0..<removeRightCount {
                rightTrackNodes[i].removeFromParent()
            }
            rightTrackNodes.removeFirst(removeRightCount)
        }
        
        let removeDecoCount = decorationNodes.prefix(while: { $0.position.y < screenBottom }).count
        if removeDecoCount > 0 {
            for i in 0..<removeDecoCount {
                decorationNodes[i].removeFromParent()
            }
            decorationNodes.removeFirst(removeDecoCount)
        }
        
        leftAbyssNodes.removeAll { $0.position.y < screenBottom || $0.parent == nil }
        rightAbyssNodes.removeAll { $0.position.y < screenBottom || $0.parent == nil }
        
        trackHeartNodes.removeAll { node in
            if node.position.y < screenBottom || node.parent == nil {
                node.removeFromParent()
                return true
            }
            return false
        }
        
        trackMobNodes.removeAll { mob in
            if mob.pointBY < screenBottom || mob.position.y < screenBottom || mob.parent == nil {
                mob.removeFromParent()
                return true
            }
            return false
        }
        
        activeFireArrows.removeAll { arrow in
            if arrow.position.y < screenBottom - 120.0 || arrow.parent == nil {
                arrow.removeFromParent()
                return true
            }
            return false
        }
        
        trackCoinNodes.removeAll { coin in
            if coin.position.y < screenBottom || coin.parent == nil {
                coin.removeFromParent()
                return true
            }
            return false
        }
    }
    
    // MARK: - Input Handling (Tap to Jump)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let locInCamera = touch.location(in: cameraNode)
        
        // 0. Взаємодія з відкритим вікном маркету/магазину
        if let shop = shopNode {
            let touchedNodes = cameraNode.nodes(at: locInCamera)
            for node in touchedNodes {
                let nodeName = node.name ?? node.parent?.name ?? ""
                
                if nodeName == "shopCloseButton" || nodeName == "shopDimBg" {
                    playJumpSound()
                    dismissShopOverlay()
                    return
                }
                
                if nodeName == "shopPrevButton" {
                    playJumpSound()
                    let count = ThemeManager.shared.themes.count
                    currentShopIndex = (currentShopIndex - 1 + count) % count
                    renderCurrentShopCard()
                    return
                }
                
                if nodeName == "shopNextButton" {
                    playJumpSound()
                    let count = ThemeManager.shared.themes.count
                    currentShopIndex = (currentShopIndex + 1) % count
                    renderCurrentShopCard()
                    return
                }
                
                if nodeName == "shopAdRewardButton" {
                    handleShopAdRewardTapped()
                    return
                }
                
                if nodeName == "shopActionButton" {
                    let themes = ThemeManager.shared.themes
                    guard currentShopIndex >= 0, currentShopIndex < themes.count else { return }
                    let theme = themes[currentShopIndex]
                    
                    // Якщо скін/тема вже вибрана — ігноруємо повторне натискання (не перебудовуємо карту)
                    guard theme.id != ThemeManager.shared.selectedThemeID else { return }
                    
                    if ThemeManager.shared.isUnlocked(theme) {
                        playJumpSound()
                        ThemeManager.shared.selectTheme(theme)
                        applyCurrentThemeToScene()
                        renderCurrentShopCard()
                    } else if ThemeManager.shared.canAfford(theme) {
                        playCoinSound()
                        ThemeManager.shared.buyTheme(theme)
                        playCoinPickupEffect(at: CGPoint(x: 0, y: -size.height * 0.15))
                        applyCurrentThemeToScene()
                        renderCurrentShopCard()
                        updateShopAdRewardButtonState()
                    } else {
                        // Не вистачає монет — похитування кнопки
                        if let card = shop.childNode(withName: "shopCard"),
                           let content = card.childNode(withName: "shopDynamicContent"),
                           let btn = content.childNode(withName: "shopActionButton") {
                            let wiggleLeft = SKAction.moveBy(x: -8.0, y: 0, duration: 0.05)
                            let wiggleRight = SKAction.moveBy(x: 16.0, y: 0, duration: 0.09)
                            let wiggleBack = SKAction.moveBy(x: -8.0, y: 0, duration: 0.05)
                            btn.run(SKAction.sequence([wiggleLeft, wiggleRight, wiggleBack]))
                        }
                    }
                    return
                }
            }
            return
        }
        
        // 1. Режим головного меню
        if gameState == .menu {
            let touchedNodes = cameraNode.nodes(at: locInCamera)
            for node in touchedNodes {
                let name = node.name ?? node.parent?.name ?? ""
                if name == "menuPlayButton" {
                    dismissMenuAndStartClimb()
                    return
                }
                if name == "menuShopButton" {
                    playJumpSound()
                    showShopOverlay()
                    return
                }
                if name == "menuSoundButton" {
                    toggleMute()
                    return
                }
                if name == "menuExitButton" {
                    handleExitApp()
                    return
                }
            }
            
            // У меню гравець не тапає для зміни стіни — персонаж сам стрибає з інтервалом
            return
        }
        
        // 2. Меню анімовано зникає — ігноруємо тапи
        guard gameState != .starting else { return }
        
        // 3. Якщо гра закінчена, перевіряємо натискання на кнопки оверлею
        if gameState == .gameOver || isGameOver {
            let touchedNodes = cameraNode.nodes(at: locInCamera)
            for node in touchedNodes {
                if node.name == "adReviveButton" || node.parent?.name == "adReviveButton" {
                    handleAdReviveTapped()
                    return
                }
                if node.name == "adDoubleCoinsButton" || node.parent?.name == "adDoubleCoinsButton" {
                    handleAdDoubleCoinsTapped()
                    return
                }
                if node.name == "menuButton" || node.parent?.name == "menuButton" {
                    goToMainMenu()
                    return
                }
                if node.name == "retryButton" || node.parent?.name == "retryButton" {
                    restartGame()
                    return
                }
            }
            return
        }
        
        // 4. Активний біг у грі
        guard !isPlayerFalling else { return }
        performJump()
    }
    
    private func performJump() {
        guard !isGameOver, !isPlayerFalling else {
            hasBufferedJump = false
            return
        }
        
        // Якщо герой зараз у повітрі (в процесі стрибка) — буферизуємо тап,
        // щоб миттєво відштовхнутися від наступної стіни без втрати натискання
        if player.isJumping {
            hasBufferedJump = true
            bufferedJumpTimestamp = CACurrentMediaTime()
            return
        }
        
        hasBufferedJump = false
        
        // Відтворюємо звук стрибка
        playJumpSound()
        
        // Визначаємо цільову горизонтальну позицію (на протилежну стіну)
        let targetX: CGFloat = player.isOnLeftWall ? playerRightX : playerLeftX
        
        // Делегуємо виконання стрибка у PlayerNode з адаптивною тривалістю
        player.jump(to: targetX, duration: currentJumpDuration) { [weak self] in
            guard let self = self else { return }
            if self.gameState == .menu {
                self.player.setReadyStance()
                self.scheduleNextMenuAutoJump(delay: 2.0)
            } else if self.gameState == .starting {
                self.player.setReadyStance()
            } else if self.gameState == .playing {
                self.player.startRunningAnimation()
                
                // Перевіряємо наявність тапу в буфері введення (Input Buffer)
                let now = CACurrentMediaTime()
                if self.hasBufferedJump && (now - self.bufferedJumpTimestamp <= self.jumpBufferWindow) {
                    self.hasBufferedJump = false
                    self.performJump()
                } else {
                    self.hasBufferedJump = false
                }
            }
        }
    }
    
    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing, !isGameOver else { return }
        
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        
        var deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        // Захист від різких стрибків дельти часу (при перериваннях системи чи навантаженні)
        if deltaTime > 0.1 {
            deltaTime = 1.0 / 60.0
        }
        
        // Постійне плавне переміщення камери вгору із динамічною швидкістю.
        // При падінні героя в прірву камера зупиняється, фіксуючи погляд на розриві стіни.
        if !isPlayerFalling {
            let verticalStep = currentUpwardSpeed * CGFloat(deltaTime)
            cameraNode.position.y += verticalStep
            player.position.y = cameraNode.position.y + playerCameraOffsetY
            
            // Оновлюємо лічильник очок за пройдену відстань
            let climbed = max(0, cameraNode.position.y - startCameraY)
            let newScore = Int(climbed / Config.distancePerScorePoint)
            if newScore != score {
                score = newScore
                scoreLabel.text = score.formattedWithSeparator
                
                // Сповіщення про проходження ювілейних відміток (кожні 100 очок)
                let milestone = score / 100
                if milestone > lastLevelCelebrated && milestone > 0 {
                    lastLevelCelebrated = milestone
                    celebrateLevelUp(level: milestone)
                }
            }
            
            // Оновлення та активація стрільби ворожих мобів-стрільців при наближенні гравця.
            // Перевіряємо, чи має гравець безпечну стіну для стрибка-ухилення (без прірви навпроти).
            let oppositeWallHasAbyss = hasAbyssOnWall(isLeft: !player.isOnLeftWall, nearY: player.position.y, range: 75.0)
            let isDodgeSafe = !oppositeWallHasAbyss
            let canDoubleShot = score >= 500
            
            for mob in trackMobNodes {
                mob.updateShooting(
                    playerPosition: player.position,
                    playerIsOnLeftWall: player.isOnLeftWall,
                    playerIsJumping: player.isJumping,
                    currentTime: currentTime,
                    isDodgeSafe: isDodgeSafe,
                    canDoubleShot: canDoubleShot,
                    gameSpeed: currentUpwardSpeed
                )
            }
            
            // Якщо герой біжить по стіні (не в стрибку) — перевіряємо наявність опори під ногами.
            // Навіть за наявності 3-секундного щита герой НЕ МОЖЕ бігти по повітрю над прірвою або стояти в розриві!
            if !player.isJumping {
                if let abyss = checkAbyssUnderPlayer() {
                    handleAbyssHit(abyss: abyss)
                }
            }
        }
        
        // Безперервне поповнення доріжки наперед та очищення старих тайлів позаду
        buildTrack(upTo: cameraNode.position.y + (size.height * 1.5))
        cleanupPassedTrack()
    }
    
    /// Перевіряє, чи є розрив стіни (прірва) у вказаному діапазоні висоти (швидка перевірка O(1))
    private func hasAbyssOnWall(isLeft: Bool, nearY: CGFloat, range: CGFloat = 80.0) -> Bool {
        let abyssNodes = isLeft ? leftAbyssNodes : rightAbyssNodes
        for abyss in abyssNodes {
            let halfH = abyss.gapHeight / 2.0
            let minY = abyss.position.y - halfH - range
            let maxY = abyss.position.y + halfH + range
            if nearY >= minY && nearY <= maxY {
                return true
            }
        }
        return false
    }
    
    /// Перевіряє, чи знаходиться гравець безпосередньо над прірвою (в розриві стіни) (швидка перевірка O(1))
    private func checkAbyssUnderPlayer() -> AbyssObstacleNode? {
        let abyssNodes = player.isOnLeftWall ? leftAbyssNodes : rightAbyssNodes
        let playerY = player.position.y
        for abyss in abyssNodes {
            let halfH = abyss.gapHeight / 2.0
            let minY = abyss.position.y - halfH + 4.0
            let maxY = abyss.position.y + halfH - 4.0
            if playerY >= minY && playerY <= maxY {
                return abyss
            }
        }
        return nil
    }
    
    override func didEvaluateActions() {
        // Якщо герой біжить або стрибає, фіксуємо його положення по Y
        guard !isGameOver, !isPlayerFalling else { return }
        player.position.y = cameraNode.position.y + playerCameraOffsetY
        
        // Якщо герой на стіні (не в стрибку), строго фіксуємо його X на відповідній стіні
        if !player.isJumping {
            let currentWallX = player.isOnLeftWall ? playerLeftX : playerRightX
            player.position.x = currentWallX
            player.physicsBody?.velocity = .zero
        }
    }
    
    override func didSimulatePhysics() {
        // Гарантуємо бездоганну фіксацію положення гравця після завершення кроку фізики (усуває мікросіпання)
        guard !isGameOver, !isPlayerFalling else { return }
        player.position.y = cameraNode.position.y + playerCameraOffsetY
        if !player.isJumping {
            let currentWallX = player.isOnLeftWall ? playerLeftX : playerRightX
            player.position.x = currentWallX
            player.physicsBody?.velocity = .zero
        }
    }
    
    // MARK: - Physics Contact Delegate
    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing, !isGameOver, !isPlayerFalling else { return }
        
        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        // 1. Потрапляння у прірву
        if mask == (PhysicsCategory.player | PhysicsCategory.abyss) {
            let abyssNode = (contact.bodyA.categoryBitMask == PhysicsCategory.abyss ? contact.bodyA.node : contact.bodyB.node) as? AbyssObstacleNode
            handleAbyssHit(abyss: abyssNode)
        }
        
        // 2. Збір додаткового життя (серця)
        if mask == (PhysicsCategory.player | PhysicsCategory.heart) {
            let heartNode = (contact.bodyA.categoryBitMask == PhysicsCategory.heart ? contact.bodyA.node : contact.bodyB.node) as? HeartItemNode
            guard let heart = heartNode, !heart.isCollected else { return }
            handleHeartCollect(heart: heart)
        }
        
        // 3. Зіткнення з ворожим мобом або вогняною стрілою
        if mask == (PhysicsCategory.player | PhysicsCategory.obstacle) {
            guard !player.isInvulnerable else { return }
            let otherNode = contact.bodyA.categoryBitMask == PhysicsCategory.obstacle ? contact.bodyA.node : contact.bodyB.node
            if let mobNode = otherNode as? MobNode {
                handleMobHit(mob: mobNode)
            } else if let arrowNode = otherNode as? FireArrowNode {
                handleArrowHit(arrow: arrowNode)
            }
        }
        
        // 4. Збір золотистої монети
        if mask == (PhysicsCategory.player | PhysicsCategory.coin) {
            let coinNode = (contact.bodyA.categoryBitMask == PhysicsCategory.coin ? contact.bodyA.node : contact.bodyB.node) as? CoinNode
            guard let coin = coinNode, !coin.isCollected else { return }
            handleCoinCollect(coin: coin)
        }
    }
    
    // MARK: - Lives & Abyss Interaction
    
    /// Обробка потрапляння персонажа у прірву: втрата 1 життя або Game Over.
    /// Прірва спрацьовує ЗАВЖДИ (навіть якщо у героя активний щит після удару моба,
    /// оскільки бігти чи приземлятися в повітря над прірвою неможливо).
    private func handleAbyssHit(abyss: AbyssObstacleNode?) {
        guard !isGameOver, !isPlayerFalling else { return }
        
        let now = CACurrentMediaTime()
        guard now - lastAbyssHitTime > 0.45 else { return }
        lastAbyssHitTime = now
        
        currentLives -= 1
        updateHUD()
        
        if currentLives > 0 {
            // Персонаж має ще життя: відновлюється поза прірвою та 3 секунди моргає невразливим
            recoverFromAbyss(abyss: abyss)
        } else {
            // Усі 3 життя вичерпані: гравець остаточно падає у прірву
            var targetPoint: CGPoint?
            if let abyss = abyss {
                let targetX: CGFloat = abyss.isOnLeftWall ? 10.0 : (size.width - 10.0)
                targetPoint = CGPoint(x: targetX, y: abyss.position.y)
            }
            triggerAbyssFall(targetPoint: targetPoint, reason: "Fell into the abyss (no lives left)")
        }
    }
    
    /// Відновлення героя при потраплянні у прірву: плавний відскок на протилежну безпечну стіну
    /// БЕЗ стрибків камери вперед та БЕЗ ефекту сіпання
    private func recoverFromAbyss(abyss: AbyssObstacleNode?) {
        hasBufferedJump = false
        // Визначаємо стіну з прірвою та безпечну протилежну стіну
        let wallWithAbyssIsLeft = abyss?.isOnLeftWall ?? player.isOnLeftWall
        let safeWallIsLeft = !wallWithAbyssIsLeft
        let safeTargetX = safeWallIsLeft ? playerLeftX : playerRightX
        
        // Плавний акробатичний стрибок-відскок на протилежну гарантовано суцільну стіну
        player.rebound(to: safeTargetX, onLeftWall: safeWallIsLeft, duration: 0.22)
        
        // Вмикаємо 3 секунди невразливості з морганням
        player.startInvulnerability(duration: 3.0)
    }
    
    /// Обробка підбору додаткового життя
    private func handleHeartCollect(heart: HeartItemNode) {
        if currentLives < GameScene.maxLives {
            heart.collect()
            currentLives += 1
            updateHUD()
            playHeartPickupEffect(at: heart.position)
        } else {
            // У гравця вже є всі 3 життя — 4-е життя додати не можна, серце залишається на карті
            heart.pulseMaxLivesHint()
        }
    }
    
    /// Миттєвий запуск рубінового цілющого спрею з попередньо виділеного пулу (нуль алокацій)
    private func playHeartPickupEffect(at position: CGPoint) {
        if let node = heartSprayPool.first(where: { !$0.inUse }) {
            node.trigger(at: position)
        } else if let oldest = heartSprayPool.first {
            oldest.trigger(at: position)
        }
    }
    
    // MARK: - Lives & Mob Interaction
    
    /// Обробка потрапляння снаряду моба-стрільця в героя (як на стіні, так і в повітрі під час стрибка)
    private func handleArrowHit(arrow: FireArrowNode) {
        guard !player.isInvulnerable, !isGameOver, !isPlayerFalling else { return }
        
        arrow.explodeAndRemove()
        currentLives -= 1
        updateHUD()
        
        if currentLives > 0 {
            player.startInvulnerability(duration: 3.0)
        } else {
            triggerMobDefeat(reason: "Hit by projectile")
        }
    }
    
    /// Обробка зіткнення героя з ворожим мобом
    private func handleMobHit(mob: MobNode?) {
        guard !player.isInvulnerable, !isGameOver, !isPlayerFalling else { return }
        
        currentLives -= 1
        updateHUD()
        
        if currentLives > 0 {
            // Гравець втрачає 1 життя і моргає 3 секунди невразливим (може втекти або стрибнути)
            player.startInvulnerability(duration: 3.0)
        } else {
            // Усі 3 життя вичерпані: поразка від ворога
            triggerMobDefeat(reason: "Defeated by canyon monster")
        }
    }
    
    /// Поразка персонажа від ворожого моба (коли життів не залишилося)
    private func triggerMobDefeat(reason: String) {
        guard !isPlayerFalling, !isGameOver else { return }
        hasBufferedJump = false
        isPlayerFalling = true
        
        playGameOverSound()
        stopBGM(fadeDuration: 2.0)
        print("Game Over: \(reason)")
        
        let defeatDirection: CGFloat = player.isOnLeftWall ? -30.0 : 30.0
        let targetPoint = CGPoint(x: player.position.x + defeatDirection, y: player.position.y - 120.0)
        
        player.fallIntoAbyss(targetPoint: targetPoint) { [weak self] in
            self?.completeGameOver(message: "Caught by canyon monster")
        }
    }
    
    // MARK: - Coins Collection
    
    /// Обробка збору золотистої монети гравцем
    private func handleCoinCollect(coin: CoinNode) {
        coin.collect()
        coinsCollected += 1
        totalCoins += 1
        
        // Звуковий ефект підбору монети
        playCoinSound()
        
        // Оновлюємо лічильник монет у HUD
        coinsLabel.text = coinsCollected.formattedWithSeparator
        
        // Пружний сплеск іконки монети в HUD (використовуємо кешований SKAction)
        hudCoinIcon?.removeAction(forKey: "coinPulse")
        hudCoinIcon?.run(GameScene.coinIconPulseAction, withKey: "coinPulse")
        
        // Спливаючий золотистий індикатор +1 над монетою
        playCoinPickupEffect(at: coin.position)
    }
    
    /// Миттєвий запуск золотистого спрею мікро-частинок з попередньо виділеного пулу (нуль алокацій)
    private func playCoinPickupEffect(at position: CGPoint) {
        if let node = coinSprayPool.first(where: { !$0.inUse }) {
            node.trigger(at: position)
        } else if let oldest = coinSprayPool.first {
            oldest.trigger(at: position)
        }
    }
    
    // MARK: - Game Over & Abyss Fall
    
    /// Запуск ефекту падіння персонажа безпосередньо всередину прірви (у розрив стіни)
    private func triggerAbyssFall(targetPoint: CGPoint?, reason: String) {
        guard !isPlayerFalling, !isGameOver else { return }
        hasBufferedJump = false
        isPlayerFalling = true
        
        // Відтворюємо звук закінчення гри
        playGameOverSound()
        stopBGM(fadeDuration: 2.0)
        
        print("Game Over: \(reason)")
        
        // Точка призначення — точно всередині отвору прірви між уступами скелі (куди вказує стрілка розриву)
        let destination = targetPoint ?? CGPoint(
            x: (player.position.x < size.width / 2.0) ? 10.0 : (size.width - 10.0),
            y: player.position.y
        )
        
        // Персонаж летить безпосередньо в чорний отвір між уступами скелі
        player.fallIntoAbyss(targetPoint: destination) { [weak self] in
            self?.completeGameOver(message: "Fell into the abyss")
        }
    }
    
    /// Фінальне завершення гри та показ оверлею
    private func completeGameOver(message: String) {
        guard !isGameOver else { return }
        isGameOver = true
        gameState = .gameOver
        
        // Якщо звук ще не почав грати, запускаємо його
        playGameOverSound()
        stopBGM(fadeDuration: 1.5)
        
        showGameOverOverlay(subtitle: message)
        
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                self?.isPaused = true
            }
        ]))
    }
    
    private func showGameOverOverlay(subtitle: String = "Fell into the abyss") {
        if score > bestScore {
            bestScore = score
        }
        
        let container = SKNode()
        container.zPosition = 100
        gameOverOverlayNode = container
        
        // Затемнюючий фон оверлею
        let bgDim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        bgDim.fillColor = SKColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 0.72)
        bgDim.strokeColor = .clear
        bgDim.position = .zero
        bgDim.zPosition = 1
        container.addChild(bgDim)
        
        // Головна діалогова картка (Box_Rounded)
        let dialogW = min(320.0, size.width - 40.0)
        let dialogH: CGFloat = 430.0
        let dialogCard = SKSpriteNode(imageNamed: "gui_card_box")
        dialogCard.size = CGSize(width: dialogW, height: dialogH)
        dialogCard.position = CGPoint(x: 0, y: 15.0)
        dialogCard.zPosition = 2
        container.addChild(dialogCard)
        
        // Червоний банер GAME OVER угорі картки (Banner_Red)
        let bannerW = min(260.0, dialogW - 20.0)
        let bannerH = bannerW * (457.0 / 1139.0)
        let redBanner = SKSpriteNode(imageNamed: "gui_banner_red")
        redBanner.size = CGSize(width: bannerW, height: bannerH)
        redBanner.position = CGPoint(x: 0, y: (dialogH / 2.0) - (bannerH * 0.45))
        redBanner.zPosition = 3
        dialogCard.addChild(redBanner)
        
        let titleShadow = SKLabelNode(fontNamed: AppFont.name)
        titleShadow.text = "GAME OVER"
        titleShadow.fontSize = 30.0
        titleShadow.fontColor = SKColor(red: 0.20, green: 0.04, blue: 0.04, alpha: 0.95)
        titleShadow.position = CGPoint(x: 1.5, y: -bannerH * 0.09)
        titleShadow.zPosition = 4
        redBanner.addChild(titleShadow)
        
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.text = "GAME OVER"
        titleLabel.fontSize = 30.0
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.06)
        titleLabel.zPosition = 5
        redBanner.addChild(titleLabel)
        
        let reasonLabel = SKLabelNode(fontNamed: AppFont.name)
        reasonLabel.text = subtitle
        reasonLabel.fontSize = 15.0
        reasonLabel.fontColor = SKColor(red: 0.95, green: 0.70, blue: 0.70, alpha: 1.0)
        reasonLabel.position = CGPoint(x: 0, y: 104.0)
        reasonLabel.zPosition = 3
        dialogCard.addChild(reasonLabel)
        
        // Картка результатів
        let statsW = dialogW - 40.0
        let statsH: CGFloat = 68.0
        let statsBar = SKSpriteNode(imageNamed: currentTheme.guiStatsBarName)
        statsBar.size = CGSize(width: statsW, height: statsH)
        statsBar.position = CGPoint(x: 0, y: 44.0)
        statsBar.zPosition = 3
        dialogCard.addChild(statsBar)
        
        let star = SKSpriteNode(imageNamed: "gui_icon_star")
        star.size = CGSize(width: 20.0, height: 20.0)
        star.position = CGPoint(x: -statsW * 0.38, y: 12.0)
        star.zPosition = 4
        statsBar.addChild(star)
        
        let scoreSummary = SKLabelNode(fontNamed: AppFont.name)
        scoreSummary.text = "SCORE: \(score.formattedWithSeparator)   BEST: \(bestScore.formattedWithSeparator)"
        scoreSummary.fontSize = 15.5
        scoreSummary.fontColor = currentTheme.guiStatsTextColor
        scoreSummary.horizontalAlignmentMode = .left
        scoreSummary.verticalAlignmentMode = .center
        scoreSummary.position = CGPoint(x: -statsW * 0.28, y: 12.0)
        scoreSummary.zPosition = 4
        statsBar.addChild(scoreSummary)
        
        let coin = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
        coin.size = CGSize(width: 20.0, height: 20.0)
        coin.position = CGPoint(x: -statsW * 0.38, y: -14.0)
        coin.zPosition = 4
        statsBar.addChild(coin)
        
        let coinsSummary = SKLabelNode(fontNamed: AppFont.name)
        coinsSummary.text = "COINS: +\(coinsCollected.formattedWithSeparator)   TOTAL: \(totalCoins.formattedWithSeparator)"
        coinsSummary.fontSize = 14.5
        coinsSummary.fontColor = currentTheme.guiStatsTextColor
        coinsSummary.horizontalAlignmentMode = .left
        coinsSummary.verticalAlignmentMode = .center
        coinsSummary.position = CGPoint(x: -statsW * 0.28, y: -14.0)
        coinsSummary.zPosition = 4
        statsBar.addChild(coinsSummary)
        self.gameOverCoinsSummaryLabel = coinsSummary
        self.gameOverDoubleCoinsBtn = nil
        self.gameOverDoubleCoinsLabel = nil
        
        let isOnline = NetworkMonitor.shared.isConnected
        let hasAdButton = isOnline && (!hasUsedAdRevive || (coinsCollected > 0 || hasUsedAdDoubleCoins))
        let retryBtnY: CGFloat = hasAdButton ? -86.0 : -42.0
        let menuBtnY: CGFloat = hasAdButton ? -144.0 : -104.0
        
        // Кнопка 1: Рекламна нагорода (1-й раз: REVIVE, 2-й раз: DOUBLE COINS 2X) — показується лише онлайн
        if isOnline && !hasUsedAdRevive {
            // Перший випадок: відродження з 1 життям за перегляд Unity Ads
            let reviveBtnW = dialogW - 50.0
            let reviveBtnH: CGFloat = 52.0
            let reviveBtn = SKSpriteNode(imageNamed: "gui_btn_large_green")
            reviveBtn.name = "adReviveButton"
            reviveBtn.size = CGSize(width: reviveBtnW, height: reviveBtnH)
            reviveBtn.position = CGPoint(x: 0, y: -26.0)
            reviveBtn.zPosition = 3
            dialogCard.addChild(reviveBtn)
            
            let heartIcon = SKSpriteNode(imageNamed: currentTheme.heartTextureName)
            heartIcon.name = "adReviveButton"
            heartIcon.size = CGSize(width: 22.0, height: 22.0)
            heartIcon.position = CGPoint(x: -reviveBtnW * 0.30, y: 0)
            heartIcon.zPosition = 4
            reviveBtn.addChild(heartIcon)
            
            let reviveLabel = SKLabelNode(fontNamed: AppFont.name)
            reviveLabel.name = "adReviveButton"
            reviveLabel.text = "REVIVE (+1 LIFE)"
            reviveLabel.fontSize = 17.0
            reviveLabel.fontColor = .white
            reviveLabel.verticalAlignmentMode = .center
            reviveLabel.horizontalAlignmentMode = .center
            reviveLabel.position = CGPoint(x: 12.0, y: 0)
            reviveLabel.zPosition = 4
            reviveBtn.addChild(reviveLabel)
        } else if isOnline && (coinsCollected > 0 || hasUsedAdDoubleCoins) {
            // Другий випадок: подвоєння зібраних за забіг монет (x2)
            let doubleBtnW = dialogW - 50.0
            let doubleBtnH: CGFloat = 52.0
            let doubleBtn = SKSpriteNode(imageNamed: hasUsedAdDoubleCoins ? "gui_btn_large_orange" : "gui_btn_large_green")
            doubleBtn.name = hasUsedAdDoubleCoins ? "adDoubleCoinsClaimed" : "adDoubleCoinsButton"
            doubleBtn.size = CGSize(width: doubleBtnW, height: doubleBtnH)
            doubleBtn.position = CGPoint(x: 0, y: -26.0)
            doubleBtn.zPosition = 3
            doubleBtn.alpha = hasUsedAdDoubleCoins ? 0.65 : 1.0
            dialogCard.addChild(doubleBtn)
            self.gameOverDoubleCoinsBtn = doubleBtn
            
            let coinIcon = SKSpriteNode(imageNamed: currentTheme.guiCoinIconName)
            coinIcon.name = doubleBtn.name
            coinIcon.size = CGSize(width: 22.0, height: 22.0)
            coinIcon.position = CGPoint(x: -doubleBtnW * 0.30, y: 0)
            coinIcon.zPosition = 4
            doubleBtn.addChild(coinIcon)
            
            let doubleLabel = SKLabelNode(fontNamed: AppFont.name)
            doubleLabel.name = doubleBtn.name
            doubleLabel.text = hasUsedAdDoubleCoins ? "COINS DOUBLED (2X)!" : "DOUBLE COINS (2X)"
            doubleLabel.fontSize = 17.0
            doubleLabel.fontColor = .white
            doubleLabel.verticalAlignmentMode = .center
            doubleLabel.horizontalAlignmentMode = .center
            doubleLabel.position = CGPoint(x: 12.0, y: 0)
            doubleLabel.zPosition = 4
            doubleBtn.addChild(doubleLabel)
            self.gameOverDoubleCoinsLabel = doubleLabel
        }
        
        // Кнопка 2: PLAY AGAIN
        let retryBtnW = dialogW - 50.0
        let retryBtnH: CGFloat = 50.0
        let retryBtn = SKSpriteNode(imageNamed: currentTheme.guiPrimaryBtnName)
        retryBtn.name = "retryButton"
        retryBtn.size = CGSize(width: retryBtnW, height: retryBtnH)
        retryBtn.position = CGPoint(x: 0, y: retryBtnY)
        retryBtn.zPosition = 3
        dialogCard.addChild(retryBtn)
        
        let retryIcon = SKSpriteNode(imageNamed: "gui_icon_restart")
        retryIcon.name = "retryButton"
        retryIcon.size = CGSize(width: 20.0, height: 20.0)
        retryIcon.position = CGPoint(x: -retryBtnW * 0.28, y: 0)
        retryIcon.zPosition = 4
        retryBtn.addChild(retryIcon)
        
        let retryLabel = SKLabelNode(fontNamed: AppFont.name)
        retryLabel.name = "retryButton"
        retryLabel.text = "PLAY AGAIN"
        retryLabel.fontSize = 17.0
        retryLabel.fontColor = .white
        retryLabel.verticalAlignmentMode = .center
        retryLabel.horizontalAlignmentMode = .center
        retryLabel.position = CGPoint(x: 10.0, y: 0)
        retryLabel.zPosition = 4
        retryBtn.addChild(retryLabel)
        
        // Кнопка 3: MAIN MENU
        let menuBtnW = dialogW - 64.0
        let menuBtnH: CGFloat = 46.0
        let menuBtn = SKSpriteNode(imageNamed: currentTheme.guiSecondaryBtnName)
        menuBtn.name = "menuButton"
        menuBtn.size = CGSize(width: menuBtnW, height: menuBtnH)
        menuBtn.position = CGPoint(x: 0, y: menuBtnY)
        menuBtn.zPosition = 3
        dialogCard.addChild(menuBtn)
        
        let homeIcon = SKSpriteNode(imageNamed: "gui_icon_home")
        homeIcon.name = "menuButton"
        homeIcon.size = CGSize(width: 18.0, height: 18.0)
        homeIcon.position = CGPoint(x: -menuBtnW * 0.26, y: 0)
        homeIcon.zPosition = 4
        menuBtn.addChild(homeIcon)
        
        let menuLabel = SKLabelNode(fontNamed: AppFont.name)
        menuLabel.name = "menuButton"
        menuLabel.text = "MAIN MENU"
        menuLabel.fontSize = 16.0
        menuLabel.fontColor = .white
        menuLabel.verticalAlignmentMode = .center
        menuLabel.horizontalAlignmentMode = .center
        menuLabel.position = CGPoint(x: 8.0, y: 0)
        menuLabel.zPosition = 4
        menuBtn.addChild(menuLabel)
        
        // Додаємо до cameraNode, щоб напис завжди був по центру поточного огляду камери
        cameraNode.addChild(container)
    }
    
    /// Обробка натискання кнопки перегляду реклами Unity Ads для відродження (1-й раз)
    private func handleAdReviveTapped() {
        guard isGameOver, !hasUsedAdRevive, NetworkMonitor.shared.isConnected else { return }
        guard let vc = view?.window?.rootViewController ?? view?.next as? UIViewController else { return }
        
        UnityAdsManager.shared.showRewardedAd(from: vc) { [weak self] in
            guard let self = self else { return }
            self.hasUsedAdRevive = true
            self.revivePlayerWithOneHeart()
        } onFailed: { message in
            print("[GameScene] Revive ad was not completed: \(message)")
        }
    }
    
    /// Обробка натискання кнопки перегляду реклами Unity Ads для подвоєння монет (2-й раз)
    private func handleAdDoubleCoinsTapped() {
        guard isGameOver, hasUsedAdRevive, !hasUsedAdDoubleCoins, coinsCollected > 0, NetworkMonitor.shared.isConnected else { return }
        guard let vc = view?.window?.rootViewController ?? view?.next as? UIViewController else { return }
        
        UnityAdsManager.shared.showRewardedAd(from: vc) { [weak self] in
            guard let self = self else { return }
            self.doubleCollectedCoins()
        } onFailed: { message in
            print("[GameScene] Double coins ad was not completed: \(message)")
        }
    }
    
    /// Подвоєння зібраних за забіг монет після перегляду реклами
    private func doubleCollectedCoins() {
        guard !hasUsedAdDoubleCoins, coinsCollected > 0 else { return }
        hasUsedAdDoubleCoins = true
        
        // Додаємо бонусні монети до загального балансу
        let bonus = coinsCollected
        totalCoins += bonus
        coinsCollected *= 2
        
        // Оновлюємо підсумок на оверлеї
        gameOverCoinsSummaryLabel?.text = "COINS: +\(coinsCollected.formattedWithSeparator) (2X!)   TOTAL: \(totalCoins.formattedWithSeparator)"
        
        // Переводимо кнопку у деактивований стан отриманої нагороди
        gameOverDoubleCoinsBtn?.name = "adDoubleCoinsClaimed"
        gameOverDoubleCoinsBtn?.alpha = 0.65
        gameOverDoubleCoinsLabel?.name = "adDoubleCoinsClaimed"
        gameOverDoubleCoinsLabel?.text = "COINS DOUBLED (2X)!"
        
        // Звуковий ефект нарахування монет
        playCoinSound()
    }
    
    /// Відродження персонажа з 1 серцем та повернення до гри
    private func revivePlayerWithOneHeart() {
        // 1. Прибираємо оверлей GameOver
        gameOverOverlayNode?.removeFromParent()
        gameOverOverlayNode = nil
        
        // 2. Розблоковуємо сцену та ігровий стан
        isPaused = false
        isGameOver = false
        isPlayerFalling = false
        gameState = .playing
        lastUpdateTime = 0
        
        // 3. Встановлюємо 1 життя та оновлюємо HUD
        currentLives = 1
        updateHUD(animated: true)
        
        // 4. Очищаємо ворожі стріли
        activeFireArrows.forEach { $0.removeFromParent() }
        activeFireArrows.removeAll()
        
        // 5. Очищаємо небезпечних мобів поруч із точкою відродження гравця
        let pY = cameraNode.position.y + playerCameraOffsetY
        for mob in trackMobNodes {
            if abs(mob.position.y - pY) < 240.0 {
                mob.removeFromParent()
            }
        }
        trackMobNodes.removeAll { $0.parent == nil }
        
        // 6. Знаходимо безпечну суцільну ділянку стіни на поточній висоті камери
        let isLeftSafe = isWallRangeSolid(onLeftWall: true, minY: pY - 35.0, maxY: pY + 55.0, safetyMargin: 25.0)
        let isRightSafe = isWallRangeSolid(onLeftWall: false, minY: pY - 35.0, maxY: pY + 55.0, safetyMargin: 25.0)
        
        let onLeft: Bool
        if isLeftSafe {
            onLeft = true
        } else if isRightSafe {
            onLeft = false
        } else {
            onLeft = Bool.random()
        }
        
        let safeX = onLeft ? playerLeftX : playerRightX
        let safePos = CGPoint(x: safeX, y: pY)
        
        // 7. Відроджуємо персонажа на безпечній скелі з 3 секундами повної невразливості
        player.respawn(onLeftWall: onLeft, at: safePos)
        
        // 8. Візуальний ефект відновлення серця
        playHeartPickupEffect(at: safePos)
        
        // 9. Відновлюємо фонову музику гри
        startBGM(lowVolume: false)
    }
    
    private func restartGame() {
        gameOverOverlayNode?.removeFromParent()
        gameOverOverlayNode = nil
        stopBGM(fadeDuration: 0.2)
        let newScene = GameScene(size: size, initialMode: .playing)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene)
    }
    
    private func goToMainMenu() {
        gameOverOverlayNode?.removeFromParent()
        gameOverOverlayNode = nil
        stopBGM(fadeDuration: 0.2)
        let newScene = GameScene(size: size, initialMode: .menu)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene)
    }
}

// MARK: - Unified Number Formatting
extension Int {
    /// Уніфікований формат чисел для всієї гри з розділювачем тисяч (наприклад: 25,000, 1,200)
    var formattedWithSeparator: String {
        return NumberFormatter.gameNumberFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension NumberFormatter {
    fileprivate static let gameNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter
    }()
}
