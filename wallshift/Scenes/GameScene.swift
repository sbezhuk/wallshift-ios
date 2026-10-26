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

// MARK: - GameScene
final class GameScene: SKScene {
    // MARK: - Configuration Constants
    enum Config {
        static let wallWidth: CGFloat = 48.0
        static let tileSize: CGFloat = 48.0
        
        // Швидкість постійного руху вгору (точок за секунду)
        static let baseUpwardSpeed: CGFloat = 290.0
        static let maxUpwardSpeed: CGFloat = 580.0
        
        // Кількість точок вертикального підйому на 1 очко
        static let distancePerScorePoint: CGFloat = 25.0
        
        // Базова та мінімальна тривалість стрибка між стінами (в секундах)
        static let baseJumpDuration: TimeInterval = 0.28
        static let minJumpDuration: TimeInterval = 0.175
        
        // Колірна гамма підкладки фону (теплий осінній тон)
        static let backgroundColor = SKColor(red: 0.18, green: 0.12, blue: 0.09, alpha: 1.0)
    }
    
    // MARK: - Active Theme & Cached Textures
    var currentTheme: ThemeData {
        return ThemeManager.shared.currentTheme
    }
    
    var cachedBackgroundTexture: SKTexture = SKTexture()
    var cachedWallTexture: SKTexture = SKTexture()
    var cachedCliffLowerTexture: SKTexture = SKTexture()
    var cachedCliffUpperTexture: SKTexture = SKTexture()
    var cachedWallDirtTexture: SKTexture = SKTexture()
    var cachedWallRockTexture: SKTexture = SKTexture()
    var cachedTreeTextures: [SKTexture] = []
    var cachedBushTexture: SKTexture = SKTexture(imageNamed: "deco_bush_01")
    var cachedStumpTexture: SKTexture = SKTexture(imageNamed: "deco_stump")
    var cachedStoneTextures: [SKTexture] = [
        SKTexture(imageNamed: "deco_stone_01"),
        SKTexture(imageNamed: "deco_stone_02")
    ]
    var cachedDecorTextures: [SKTexture] = []
    var cachedSignpostTextures: [SKTexture] = []
    var cachedPatrollerTextures: [SKTexture] = []
    var cachedShooterTextures: [SKTexture] = []
    var cachedHeartTexture: SKTexture = SKTexture()
    
    // Fast texture accessors
    var backgroundTexture: SKTexture { return cachedBackgroundTexture }
    var wallTexture: SKTexture { return cachedWallTexture }
    var cliffLowerTexture: SKTexture { return cachedCliffLowerTexture }
    var cliffUpperTexture: SKTexture { return cachedCliffUpperTexture }
    var wallDirtTexture: SKTexture { return cachedWallDirtTexture }
    var wallRockTexture: SKTexture { return cachedWallRockTexture }
    var treeTextures: [SKTexture] { return cachedTreeTextures }
    var bushTexture: SKTexture { return cachedBushTexture }
    var stumpTexture: SKTexture { return cachedStumpTexture }
    var stoneTextures: [SKTexture] { return cachedStoneTextures }
    var decorTextures: [SKTexture] { return cachedDecorTextures }
    var signpostTextures: [SKTexture] { return cachedSignpostTextures }
    
    // MARK: - Particle Textures & Spray Templates
    static let sparkTexture: SKTexture = {
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
    static let sprayParticleTexture: SKTexture = {
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
    var coinSprayPool: [PooledSprayNode] = []
    var heartSprayPool: [PooledSprayNode] = []
    
    static let coinIconPulseAction: SKAction = {
        let scaleUp = SKAction.scale(to: 1.30, duration: 0.06)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.10)
        return SKAction.sequence([scaleUp, scaleDown])
    }()
    
    /// Завантаження та прогрів усіх текстур активної теми у пам'ять GPU для усунення мікрофризів
    func updateCachedThemeTextures() {
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
        texturesToPreload.append(contentsOf: CoinNode.textures(for: theme))
        texturesToPreload.append(contentsOf: FireArrowNode.allTextures)
        let playerFrames = (0..<PlayerNode.Constants.runningFrameCount).map {
            SKTexture(imageNamed: "\(PlayerNode.Constants.runningFramePrefix)\($0)")
        }
        texturesToPreload.append(contentsOf: playerFrames)
        texturesToPreload.append(SKTexture(imageNamed: "coin"))
        
        SKTexture.preload(texturesToPreload) {}
    }
    
    // MARK: - Audio
    static let bgmTargetVolume: Float = GameAudio.bgmTargetVolume
    
    // MARK: - Nodes & State
    let cameraNode = SKCameraNode()
    
    /// Окремий вузол героя з власною ієрархією спрайтів та анімацій
    var player: PlayerNode!
    
    /// Фіксоване вертикальне зміщення героя відносно центру камери
    var playerCameraOffsetY: CGFloat = 0
    
    /// Прапорець падіння героя в прірву (відв'язує Y-координату від камери)
    var isPlayerFalling: Bool = false
    
    /// Запобіжник повторного відтворення аудіо закінчення гри
    var hasPlayedGameOverSound: Bool = false
    
    /// Делеговані стани героя
    var isOnLeftWall: Bool {
        return player.isOnLeftWall
    }
    
    var isJumping: Bool {
        return player.isJumping
    }
    
    // MARK: - Input Buffering (Буферизація тапу для чуйного стрибка)
    var hasBufferedJump: Bool = false
    var bufferedJumpTimestamp: TimeInterval = 0
    let jumpBufferWindow: TimeInterval = 0.16
    
    // MARK: - Game State
    var gameState: GameState = .menu
    let initialMode: GameState
    
    // Ноди та елементи головного меню
    var menuNode: SKNode?
    var soundIconSprite: SKSpriteNode?
    var menuCoinsText: SKLabelNode?
    
    // Ноди та елементи налаштувань (Settings)
    var settingsNode: SKNode?
    var isDraggingMusicSlider: Bool = false
    var isDraggingSFXSlider: Bool = false
    
    // Ноди та елементи системи досягнень
    var achievementsNode: SKNode?
    var currentAchievementsPage: Int = 0
    var toastQueue: [Achievement] = []
    var isShowingToast: Bool = false
    
    // Статистика поточного забігу для трекінгу досягнень
    var runJumpsCount: Int = 0
    var tookDamageThisRun: Bool = false
    var fellIntoAbyssThisRun: Bool = false
    var clutchScoreStart: Int? = nil
    var clutchScoreThisRun: Int = 0
    
    // Ноди та елементи маркету/магазину
    var shopNode: SKNode?
    var currentShopIndex: Int = 0
    var shopAdRewardBtnNode: SKNode?
    var shopAdRewardBgSprite: SKSpriteNode?
    var shopAdRewardLabel: SKLabelNode?
    var shopAdRewardPlayIcon: SKSpriteNode?
    var shopAdRewardCoinIcon: SKSpriteNode?
    var backgroundNode: SKSpriteNode?
    var backgroundOverlayNode: SKSpriteNode?
    var backgroundTopExtensionNode: SKSpriteNode?
    var backgroundBottomExtensionNode: SKSpriteNode?
    
    /// Масштаб фонового зображення: повне покриття екрана (Aspect Fill із запасом 1.05 для гарантованого покриття всієї площі без розривів)
    let backgroundScaleMultiplier: CGFloat = 1.05
    
    /// Прапорець закінчення гри
    var isGameOver: Bool = false
    var gameOverOverlayNode: SKNode?
    
    // MARK: - Ad Rewards (Revive 1x, Double Coins 1x)
    var hasUsedAdRevive: Bool = false
    var hasUsedAdDoubleCoins: Bool = false
    var gameOverCoinsSummaryLabel: SKLabelNode?
    var gameOverDoubleCoinsBtn: SKSpriteNode?
    var gameOverDoubleCoinsLabel: SKLabelNode?
    
    // MARK: - Lives, Score & Difficulty
    static let maxLives: Int = 3
    var currentLives: Int = GameScene.maxLives
    var heartHUDNodes: [SKSpriteNode] = []
    let hudNode = SKNode()
    
    var score: Int = 0
    private static var cachedBestScore: Int = UserDefaults.standard.integer(forKey: "BestWallShiftScore")
    var bestScore: Int {
        get { GameScene.cachedBestScore }
        set {
            GameScene.cachedBestScore = newValue
            DispatchQueue.global(qos: .utility).async {
                UserDefaults.standard.set(newValue, forKey: "BestWallShiftScore")
            }
        }
    }
    
    // MARK: - Dynamic Ad Tracking
    var runStartTime: TimeInterval = 0
    var isNewHighScoreThisRun: Bool = false
    var isTransitioningScene: Bool = false
    
    var startCameraY: CGFloat = 0
    var scoreLabel = SKLabelNode()
    var lastLevelCelebrated: Int = 0
    
    // MARK: - Coins System
    var coinsCollected: Int = 0
    var totalCoins: Int {
        get { ThemeManager.shared.totalCoins }
        set { ThemeManager.shared.totalCoins = newValue }
    }
    var coinsLabel = SKLabelNode()
    var hudCoinIcon: SKSpriteNode?
    
    /// Поточний розрахунковий рівень складності (кожні 50 очок)
    var difficultyLevel: Int {
        return score / 50
    }
    
    /// Поточна швидкість підйому камери: неперервне наростання темпу гри в стилі Subway Surfers.
    /// Починається з бадьорого комфортного бігу (300 pt/s) і плавно прискорюється
    /// до ~650 pt/s до 1000-2000 очок.
    /// Після 2000 очок темп продовжує безупинно наростати:
    /// 3000 очок (~725 pt/s), 4000 очок (~780 pt/s), 5000 очок (~825 pt/s) і далі без обмежень,
    /// забезпечуючи нескінченний приплив адреналіну для справжніх майстрів.
    var currentUpwardSpeed: CGFloat {
        let s = CGFloat(max(0, score))
        let acceleration = 345.0 * (1.0 - exp(-s / 300.0)) + (s * 0.05)
        let cappedBase = min(650.0, 300.0 + acceleration)
        
        // Нескінченне плавне наростання швидкості після 2000 очок (кожна 1000 очок додає відчутний спортивний драйв):
        let post2000 = max(0.0, s - 2000.0)
        let endlessBoost = (180.0 * (1.0 - exp(-post2000 / 2500.0))) + (post2000 * 0.016)
        return cappedBase + endlessBoost
    }
    
    /// Динамічна тривалість стрибка: безперервно адаптується до зростаючого темпу гри.
    /// На старті комфортний (0.28с), на 1000 очок (650 pt/s) — 0.19с, а при подальшому розгоні на 3000-5000+ очок
    /// плавно скорочується до 0.145с, зберігаючи миттєвий відгук і чіткість приземлення на екстремальних швидкостях.
    var currentJumpDuration: TimeInterval {
        guard gameState == .playing else { return Config.baseJumpDuration }
        let speedProgress = (currentUpwardSpeed - 300.0) / 350.0 // 1.0 на 650 pt/s
        let duration = Config.baseJumpDuration - (Double(speedProgress) * 0.09) // 0.19с на 650 pt/s
        return max(0.145, duration)
    }
    
    /// Розміри розриву прірв: плавний і природний розподіл без сходинкових стрибків.
    /// Після 1000 очок переходить на високий рівень паркуру (4-6 тайлів),
    /// після 2500 очок розширюється до 5-6 тайлів з першими гігантськими 7-тайловими прірвами,
    /// а після 4000-5000+ очок складні 6-7 тайлові розриви стають основою траси.

    // Відстеження часу для обчислення deltaTime
    var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Procedural Track, Abyss, Hearts & Mobs Generation
    var leftTrackNodes: [SKNode] = []
    var rightTrackNodes: [SKNode] = []
    var leftAbyssNodes: [AbyssObstacleNode] = []
    var rightAbyssNodes: [AbyssObstacleNode] = []
    var lastCleanupCameraY: CGFloat = 0
    var trackHeartNodes: [SKNode] = []
    var trackMobNodes: [MobNode] = []
    var activeFireArrows: [FireArrowNode] = []
    var trackCoinNodes: [CoinNode] = []
    var currentLeftY: CGFloat = 0
    var currentRightY: CGFloat = 0
    
    var nextAbyssY: CGFloat = 0
    var nextAbyssIsOnLeft: Bool = false
    var consecutiveAbyssesOnSameWall: Int = 1
    let maxConsecutiveAbyssesOnSameWall: Int = 2
    var consecutivePatrollers: Int = 0
    var nextHeartY: CGFloat = 0
    var nextCoinPatternY: CGFloat = 0
    var lastAbyssHitTime: TimeInterval = 0
    
    // Процедурний спавн ворожих мобів (патрульні на розминці, стрільці пізніше)
    var firstMobScoreThreshold: Int = 0
    var firstShooterScoreThreshold: Int = 0
    var nextMobY: CGFloat = 0
    
    var decorationNodes: [SKNode] = []
    var nextTreeBackgroundY: CGFloat = 0
    var lastLeftDecoY: CGFloat = 0
    var lastRightDecoY: CGFloat = 0
    
    // MARK: - Computed Properties for Wall Positions
    var leftWallInnerX: CGFloat {
        return Config.wallWidth
    }
    
    var rightWallInnerX: CGFloat {
        return size.width - Config.wallWidth
    }
    
    var playerLeftX: CGFloat {
        return leftWallInnerX + PlayerNode.Constants.footOffset
    }
    
    var playerRightX: CGFloat {
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
        hasPlayedGameOverSound = false
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
        prewarmMetalRenderPipelines()
        
        // Підписка на події розблокування досягнень (оновлення бейджика в меню)
        AchievementManager.shared.checkAndPerformWeeklyResetIfNeeded()
        AchievementManager.shared.onAchievementUnlocked = { [weak self] _ in
            self?.updateAchievementsBadge()
        }
        
        if initialMode == .menu {
            gameState = .menu
            isGameOver = false
            player.setReadyStance()
            hudNode.alpha = 1.0
            hudNode.isHidden = true
            showMainMenu(animated: false)
            startBGM(lowVolume: true)
        } else {
            gameState = .playing
            isGameOver = false
            runStartTime = CACurrentMediaTime()
            DynamicAdManager.shared.notifyRunStarted()
            AchievementManager.shared.startNewRun()
            runJumpsCount = 0
            tookDamageThisRun = false
            fellIntoAbyssThisRun = false
            player.startRunningAnimation()
            hudNode.alpha = 1.0
            hudNode.isHidden = false
            startBGM(lowVolume: false)
        }
    }
    
    // MARK: - Setup Methods
    
    func setupPhysicsWorld() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }
    
    func setupCamera() {
        cameraNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        camera = cameraNode
        addChild(cameraNode)
    }
    
    /// Створення фіксованого пулу систем частинок для збору предметів (0 алокацій під час гри, стабільні 60-120 FPS)
    func setupParticlePools() {
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
    
    /// Попередній прогрів конвеєра рендерингу Metal (PSO), атласу шрифтів та текстур мобів/снарядів (0 мікрофризів)
    func prewarmMetalRenderPipelines() {
        let warmContainer = SKNode()
        warmContainer.name = "metalWarmContainer"
        warmContainer.position = .zero
        warmContainer.zPosition = -100 // Позаду фону (-10), гарантовано всередині огляду камери (SpriteKit не скидає через culling)
        
        // 1. Прогрів шейдерів Metal для звичайного та адитивного блендингу
        let spriteAdd = SKSpriteNode(texture: GameScene.sprayParticleTexture)
        spriteAdd.blendMode = .add
        warmContainer.addChild(spriteAdd)
        
        // 2. Повний прогрів обох типів частинок (монети та серця)
        let dummyCoinSpray = PooledSprayNode(texture: GameScene.sprayParticleTexture, isHeart: false)
        dummyCoinSpray.position = .zero
        dummyCoinSpray.trigger(at: .zero)
        warmContainer.addChild(dummyCoinSpray)
        
        let dummyHeartSpray = PooledSprayNode(texture: GameScene.sprayParticleTexture, isHeart: true)
        dummyHeartSpray.position = .zero
        dummyHeartSpray.trigger(at: .zero)
        warmContainer.addChild(dummyHeartSpray)
        
        // 3. Прогрів текстур мобів (патрульний 24 кадри, стрілець 24 кадри) — усуває мікролаг на 25-80 очках
        if !cachedPatrollerTextures.isEmpty {
            let patrollerSprite = SKSpriteNode(texture: cachedPatrollerTextures.first)
            patrollerSprite.run(SKAction.animate(with: cachedPatrollerTextures, timePerFrame: 0.01))
            warmContainer.addChild(patrollerSprite)
        }
        if !cachedShooterTextures.isEmpty {
            let shooterSprite = SKSpriteNode(texture: cachedShooterTextures.first)
            shooterSprite.run(SKAction.animate(with: cachedShooterTextures, timePerFrame: 0.01))
            warmContainer.addChild(shooterSprite)
        }
        
        // 4. Прогрів текстур снарядів (вогняні/водяні стріли + світіння glow) — усуває лаг при першому пострілі
        let arrowTextures = FireArrowNode.allTextures
        if !arrowTextures.isEmpty {
            let arrowSprite = SKSpriteNode(texture: arrowTextures.first)
            arrowSprite.blendMode = .add
            arrowSprite.colorBlendFactor = 1.0
            arrowSprite.run(SKAction.animate(with: arrowTextures, timePerFrame: 0.01))
            warmContainer.addChild(arrowSprite)
        }
        
        // 5. Прогрів обертання монет (6 кадрів), сердець та тайлів скель/прірв
        let coinTextures = CoinNode.textures(for: currentTheme)
        if !coinTextures.isEmpty {
            let coinSprite = SKSpriteNode(texture: coinTextures.first)
            coinSprite.run(SKAction.animate(with: coinTextures, timePerFrame: 0.01))
            warmContainer.addChild(coinSprite)
        }
        let heartSprite = SKSpriteNode(texture: cachedHeartTexture)
        let cliffLow = SKSpriteNode(texture: cachedCliffLowerTexture)
        let cliffUp = SKSpriteNode(texture: cachedCliffUpperTexture)
        let wallDirt = SKSpriteNode(texture: cachedWallDirtTexture)
        let wallRock = SKSpriteNode(texture: cachedWallRockTexture)
        warmContainer.addChild(heartSprite)
        warmContainer.addChild(cliffLow)
        warmContainer.addChild(cliffUp)
        warmContainer.addChild(wallDirt)
        warmContainer.addChild(wallRock)
        
        // 6. Прогрів атласу гліфів шрифту AppFont для ВСІХ розмірів шрифтів HUD та гри + анімація пульсації очок
        let fontSizes: [CGFloat] = [25.0, 18.0, 17.0, 20.0, 16.0, 23.0, 30.0, 46.0]
        for fSize in fontSizes {
            let fontLabel = SKLabelNode(fontNamed: AppFont.name)
            fontLabel.text = "0123456789+., -–xX:!?SCORECOINS BEST"
            fontLabel.fontSize = fSize
            if fSize == 25.0 {
                fontLabel.run(SKAction.sequence([
                    SKAction.scale(to: 1.45, duration: 0.05),
                    SKAction.scale(to: 1.0, duration: 0.05)
                ]))
            }
            warmContainer.addChild(fontLabel)
        }
        
        cameraNode.addChild(warmContainer)
        
        // Контейнер рендериться 1.2 с для гарантованої компіляції Metal PSO та VRAM-кешування, потім самовидаляється
        warmContainer.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.2),
            SKAction.removeFromParent()
        ]))
    }
    
    func setupAudio() {
        GameAudio.shared.setupIfNeeded()
    }
    
    var isMuted: Bool {
        return GameAudio.shared.isMuted
    }
    
    /// Динамічний запуск зацикленої фонової музики (з пониженою гучністю для меню або повною для гри)
    func startBGM(lowVolume: Bool = false) {
        GameAudio.shared.startBGM(lowVolume: lowVolume)
    }
    
    func updateSoundMenuIcon() {
        let isMuted = GameAudio.shared.isMuted
        let iconName = isMuted ? "gui_icon_audio_off" : "gui_icon_audio_on"
        soundIconSprite?.texture = SKTexture(imageNamed: iconName)
    }
    
    func toggleMute() {
        _ = GameAudio.shared.toggleMute()
        updateSoundMenuIcon()
    }
    
    /// Плавне спадання тону/гучності фонової музики (fade-out 2.0 с) при завершенні гри
    func stopBGM(fadeDuration: TimeInterval = 2.0) {
        GameAudio.shared.stopBGM(fadeDuration: fadeDuration)
    }
    
    /// Відтворення звуку стрибка героя при тапі на екран
    func playJumpSound() {
        GameAudio.shared.playJump()
    }
    
    /// Відтворення звуку закінчення гри при програші (гарантовано один раз за забіг)
    func playGameOverSound() {
        guard !hasPlayedGameOverSound else { return }
        hasPlayedGameOverSound = true
        GameAudio.shared.playGameOver()
    }
    
    /// Відтворення звуку підбору монети (coin_pickup)
    func playCoinSound() {
        GameAudio.shared.playCoin()
    }
    
    func setupBackground() {
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
    
    func setupPlayer() {
        player = PlayerNode(prefix: currentTheme.heroRunPrefix, frameCount: currentTheme.heroRunCount)
        
        // Фіксуємо зміщення гравця по вертикалі відносно камери (нижня третина огляду)
        playerCameraOffsetY = -(size.height * 0.15)
        
        let startY = cameraNode.position.y + playerCameraOffsetY
        player.position = CGPoint(x: playerLeftX, y: startY)
        
        addChild(player)
    }
    

    /// Запуск бігу героя та підйому камери з тієї стіни, на якій він стоїть
    func startClimb() {
        // Видаляємо залишки меню та warmup-контейнер до першого ігрового фрейму
        menuNode?.removeFromParent()
        menuNode = nil
        removeAction(forKey: "menuAutoJump")
        cameraNode.childNode(withName: "metalWarmContainer")?.removeFromParent()
        
        // Відображення ігрового HUD (життя, рахунок, монети)
        hudNode.alpha = 1.0
        hudNode.isHidden = false
        hudNode.removeAllActions()
        
        // Головний герой починає бігти з тієї стіни, на якій він стоїть!
        if !player.isJumping {
            player.startRunningAnimation()
        }
        
        // Починається підйом камери та ігровий процес
        gameState = .playing
        hasPlayedGameOverSound = false
        runStartTime = CACurrentMediaTime()
        lastUpdateTime = 0
        
        // Скидання статистики поточного забігу для досягнень
        runJumpsCount = 0
        tookDamageThisRun = false
        fellIntoAbyssThisRun = false
        clutchScoreStart = nil
        clutchScoreThisRun = 0
        
        // Піднімаємо гучність фонової музики до повного ігрового рівня
        if !isMuted {
            GameAudio.shared.startBGM(lowVolume: false)
        }
    }
    


    // MARK: - Input Forwarding
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchesMoved(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchesCancelled(touches, with: event)
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
        if deltaTime > 1.0 / 60.0 {
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
                
                // Трекінг виживання з 1 життям (Clutch Survival)
                if currentLives == 1 {
                    if clutchScoreStart == nil {
                        clutchScoreStart = score
                    }
                    clutchScoreThisRun = max(clutchScoreThisRun, score - (clutchScoreStart ?? score))
                }
                
                // Оновлення прогресу досягнень у реальному часі кожні 25 очок (усуває надлишкове навантаження на головний потік)
                if score % 25 == 0 {
                    AchievementManager.shared.trackRunProgress(
                        score: score,
                        runJumps: runJumpsCount,
                        runCoins: coinsCollected,
                        tookDamageThisRun: tookDamageThisRun,
                        fellIntoAbyssThisRun: fellIntoAbyssThisRun,
                        usedReviveThisRun: hasUsedAdRevive,
                        clutchScore: clutchScoreThisRun
                    )
                }
                
                // Сповіщення про проходження ювілейних відміток (кожні 100 очок)
                let milestone = score / 100
                if milestone > lastLevelCelebrated && milestone > 0 {
                    lastLevelCelebrated = milestone
                    celebrateLevelUp(level: milestone)
                }
            }
            
            // Оновлення та активація стрільби ворожих мобів-стрільців при наближенні гравця.
            // Перевіряємо, чи має гравець безпечну стіну для стрибка-ухилення (без прірви та інших мобів навпроти).
            let jumpTravelY = currentUpwardSpeed * CGFloat(currentJumpDuration)
            let landingMinY = player.position.y - 20.0
            let landingMaxY = player.position.y + jumpTravelY + 180.0
            let oppositeWallHasAbyss = hasAbyssOnWall(isLeft: !player.isOnLeftWall, minY: landingMinY, maxY: landingMaxY)
            let oppositeWallHasMob = hasMobOnWall(isLeft: !player.isOnLeftWall, minY: landingMinY, maxY: landingMaxY)
            let isDodgeSafe = !oppositeWallHasAbyss && !oppositeWallHasMob
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
            
            // Якщо гравець безпосередньо падає на голову мобу або стикається з ним — зараховується удар гравця
            if let mob = checkMobUnderPlayer() {
                handleMobHit(mob: mob)
            }
        }
        
        // Безперервне поповнення доріжки наперед та очищення старих тайлів позаду
        buildTrack(upTo: cameraNode.position.y + (size.height * 2.0))
        cleanupPassedTrack()
    }
    
    /// Перевіряє, чи є розрив стіни (прірва) у вказаному діапазоні висоти (швидка перевірка O(1))
    func hasAbyssOnWall(isLeft: Bool, minY: CGFloat, maxY: CGFloat, safetyMargin: CGFloat = 0.0) -> Bool {
        let bottom = min(minY, maxY) - safetyMargin
        let top = max(minY, maxY) + safetyMargin
        let abyssNodes = isLeft ? leftAbyssNodes : rightAbyssNodes
        for abyss in abyssNodes {
            let halfH = (abyss.gapHeight / 2.0) + Config.tileSize
            let abyssMinY = abyss.position.y - halfH
            let abyssMaxY = abyss.position.y + halfH
            if max(bottom, abyssMinY) <= min(top, abyssMaxY) {
                return true
            }
        }
        return false
    }
    
    /// Перевіряє, чи є інший моб на стіні у вказаному вертикальному діапазоні
    func hasMobOnWall(isLeft: Bool, minY: CGFloat, maxY: CGFloat, safetyMargin: CGFloat = 0.0) -> Bool {
        let bottom = min(minY, maxY) - safetyMargin
        let top = max(minY, maxY) + safetyMargin
        for mob in trackMobNodes where mob.isOnLeftWall == isLeft {
            let mobMin = mob.pointAY
            let mobMax = mob.pointBY
            if max(bottom, mobMin) <= min(top, mobMax) {
                return true
            }
        }
        return false
    }
    
    /// Перевіряє, чи знаходиться гравець безпосередньо над прірвою (в розриві стіни) (швидка перевірка O(1))
    func checkAbyssUnderPlayer() -> AbyssObstacleNode? {
        let abyssNodes = player.isOnLeftWall ? leftAbyssNodes : rightAbyssNodes
        let playerY = player.position.y
        for abyss in abyssNodes {
            let halfH = abyss.gapHeight / 2.0
            let minY = abyss.position.y - halfH
            let maxY = abyss.position.y + halfH
            if playerY >= minY && playerY <= maxY {
                return abyss
            }
        }
        return nil
    }
    
    /// Перевіряє, чи знаходиться гравець у зоні прямого зіткнення / безпосереднього падіння на голову моба
    func checkMobUnderPlayer() -> MobNode? {
        guard !player.isInvulnerable, !isGameOver, !isPlayerFalling else { return nil }
        
        let pPos = player.position
        let pHalfW: CGFloat = max(PlayerNode.Constants.hitboxSize.width, PlayerNode.Constants.hitboxSize.height) * 0.5
        let pHalfH: CGFloat = max(PlayerNode.Constants.hitboxSize.width, PlayerNode.Constants.hitboxSize.height) * 0.5
        let playerRect = CGRect(x: pPos.x - pHalfW, y: pPos.y - pHalfH, width: pHalfW * 2.0, height: pHalfH * 2.0)
        
        for mob in trackMobNodes {
            guard mob.parent != nil else { continue }
            let mPos = mob.position
            let mHalfW: CGFloat = max(MobNode.Constants.hitboxSize.width, MobNode.Constants.hitboxSize.height) * 0.5
            let mHalfH: CGFloat = max(MobNode.Constants.hitboxSize.width, MobNode.Constants.hitboxSize.height) * 0.5
            let mobRect = CGRect(x: mPos.x - mHalfW, y: mPos.y - mHalfH, width: mHalfW * 2.0, height: mHalfH * 2.0)
            
            if playerRect.intersects(mobRect) {
                return mob
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
    

}
