//
//  GameScene.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit
import AVFoundation
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
        
        // Тривалість стрибка між стінами (в секундах)
        static let jumpDuration: TimeInterval = 0.30
        
        // Колірна гамма підкладки фону (теплий осінній тон)
        static let backgroundColor = SKColor(red: 0.18, green: 0.12, blue: 0.09, alpha: 1.0)
    }
    
    // MARK: - Cached Textures
    private var backgroundTexture: SKTexture {
        let name = currentTheme.backgroundTextureName
        let tex = SKTexture(imageNamed: name)
        if tex.size().width > 0 {
            return tex
        }
        return SKTexture(imageNamed: "backround")
    }
    
    // MARK: - Active Theme & Textures
    private var currentTheme: ThemeData {
        return ThemeManager.shared.currentTheme
    }
    
    private var wallTexture: SKTexture {
        return SKTexture(imageNamed: currentTheme.wallTileName)
    }
    private var cliffLowerTexture: SKTexture {
        return SKTexture(imageNamed: currentTheme.cliffLowerTileName)
    }
    private var cliffUpperTexture: SKTexture {
        return SKTexture(imageNamed: currentTheme.cliffUpperTileName)
    }
    private var wallDirtTexture: SKTexture {
        return SKTexture(imageNamed: currentTheme.wallDirtTileName)
    }
    private var wallRockTexture: SKTexture {
        return SKTexture(imageNamed: currentTheme.wallRockTileName)
    }
    
    // MARK: - Particle Textures
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
    private static let starParticleTexture = SKTexture(imageNamed: "gui_icon_star")
    private static let heartParticleTexture = SKTexture(imageNamed: "life_hearth")
    
    // MARK: - Decoration Textures
    private var treeTextures: [SKTexture] {
        return currentTheme.treeTextureNames.map { SKTexture(imageNamed: $0) }
    }
    private var bushTexture: SKTexture {
        return SKTexture(imageNamed: "deco_bush_01")
    }
    private var stumpTexture: SKTexture {
        return SKTexture(imageNamed: "deco_stump")
    }
    private var stoneTextures: [SKTexture] {
        return [
            SKTexture(imageNamed: "deco_stone_01"),
            SKTexture(imageNamed: "deco_stone_02")
        ]
    }
    private var decorTextures: [SKTexture] {
        return currentTheme.decorTextureNames.map { SKTexture(imageNamed: $0) }
    }
    private var signpostTextures: [SKTexture] {
        if !currentTheme.signpostTextureNames.isEmpty {
            return currentTheme.signpostTextureNames.map { SKTexture(imageNamed: $0) }
        }
        return [
            SKTexture(imageNamed: "deco_sign_warning"),   // Варіант А: попередження (!)
            SKTexture(imageNamed: "deco_sign_arrow"),     // Варіант Б: стрілка напрямку
            SKTexture(imageNamed: "deco_sign_question")   // Варіант В: загадка (?)
        ]
    }
    
    // MARK: - Audio
    private var jumpAudioPlayer: AVAudioPlayer?
    private var gameOverAudioPlayer: AVAudioPlayer?
    private var coinAudioPlayers: [AVAudioPlayer] = []
    private var currentCoinAudioIndex: Int = 0
    private var bgmAudioPlayer: AVAudioPlayer?
    private static let bgmTargetVolume: Float = 0.72
    
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
    private var backgroundNode: SKSpriteNode?
    private var backgroundOverlayNode: SKSpriteNode?
    
    /// Прапорець закінчення гри
    private(set) var isGameOver: Bool = false
    
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
    
    /// Рівень складності, що динамічно зростає кожні 40 очок (0, 1, 2, 3...)
    private var difficultyLevel: Int {
        return score / 40
    }
    
    /// Поточна швидкість підйому камери: постійно та безперервно зростає разом із набором очок
    private var currentUpwardSpeed: CGFloat {
        let continuousIncrease = CGFloat(score) * 0.40
        return min(Config.maxUpwardSpeed, Config.baseUpwardSpeed + continuousIncrease)
    }
    
    /// Розміри розриву прірв залежно від набраних очок:
    /// - Рівень 0 (0...39): 2...3 тайли (96...144 pt)
    /// - Рівень 1 (40...79): 2...3 тайли (96...144 pt)
    /// - Рівень 2 (80...119): 2...4 тайли (96...192 pt)
    /// - Рівень 3+ (120+): 3...4 тайли (144...192 pt)
    private func randomAbyssGapTileCount() -> Int {
        switch difficultyLevel {
        case 0:
            return Int.random(in: 2...3)
        case 1:
            return Int.random(in: 2...3)
        case 2:
            return Int.random(in: 2...4)
        default:
            return Int.random(in: 3...4)
        }
    }
    
    /// Скорочення дистанції між прірвами з гарантією вільного простору для спавну мобів:
    /// - 0...39: 460...580 pt
    /// - 40...79: 380...480 pt
    /// - 80...119: 320...400 pt
    /// - 120...159: 280...350 pt
    /// - 160+: 240...320 pt
    private func randomAbyssDistance() -> CGFloat {
        switch difficultyLevel {
        case 0:
            return CGFloat.random(in: 460.0...580.0)
        case 1:
            return CGFloat.random(in: 380.0...480.0)
        case 2:
            return CGFloat.random(in: 320.0...400.0)
        case 3:
            return CGFloat.random(in: 280.0...350.0)
        default:
            return CGFloat.random(in: 240.0...320.0)
        }
    }
    
    /// Значне скорочення появи сердець (додаткових життів):
    /// Перше серце з'являється не раніше ~280 очок (~7000 pt),
    /// а наступні — кожні 9000...14000 pt (~360...560 очок).
    /// При повному здоров'ї (3 життя) додається ще +7000 pt затримки.
    private func randomHeartDistance() -> CGFloat {
        let extraDelay: CGFloat = currentLives >= GameScene.maxLives ? 7000.0 : 0.0
        return CGFloat.random(in: 9000.0...14000.0) + extraDelay
    }
    
    // Відстеження часу для обчислення deltaTime
    private var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Procedural Track, Abyss, Hearts & Mobs Generation
    private var leftTrackNodes: [SKNode] = []
    private var rightTrackNodes: [SKNode] = []
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
    
    // Процедурний спавн ворожих мобів (перший моб з'являється на відмітці 500-1000 очків)
    private var firstMobScoreThreshold: Int = 0
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
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.initialMode = .menu
        super.init(coder: aDecoder)
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
        trackHeartNodes.removeAll()
        trackMobNodes.removeAll()
        trackCoinNodes.removeAll()
        decorationNodes.removeAll()
        
        setupPhysicsWorld()
        setupCamera()
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
    
    private func setupAudio() {
        // Налаштовуємо аудіосесію для відтворення звуків навіть у беззвучному режимі
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        // Завантажуємо звук стрибка з Assets (Data Asset player_jump)
        if let dataAsset = NSDataAsset(name: "player_jump") {
            do {
                jumpAudioPlayer = try AVAudioPlayer(data: dataAsset.data)
                jumpAudioPlayer?.prepareToPlay()
            } catch {
                print("Failed to initialize AVAudioPlayer from NSDataAsset: \(error)")
            }
        } else if let fileURL = Bundle.main.url(forResource: "player_jump", withExtension: "mp3") {
            do {
                jumpAudioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                jumpAudioPlayer?.prepareToPlay()
            } catch {
                print("Failed to initialize AVAudioPlayer from bundle file: \(error)")
            }
        }
        
        // Завантажуємо звук програшу (Data Asset game_over)
        if let dataAsset = NSDataAsset(name: "game_over") {
            do {
                gameOverAudioPlayer = try AVAudioPlayer(data: dataAsset.data)
                gameOverAudioPlayer?.prepareToPlay()
            } catch {
                print("Failed to initialize AVAudioPlayer for game_over from NSDataAsset: \(error)")
            }
        } else if let fileURL = Bundle.main.url(forResource: "game_over", withExtension: "mp3") {
            do {
                gameOverAudioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                gameOverAudioPlayer?.prepareToPlay()
            } catch {
                print("Failed to initialize AVAudioPlayer for game_over from bundle file: \(error)")
            }
        }
        
        // Завантажуємо звук збору монети (Data Asset coin_pickup)
        let coinData = NSDataAsset(name: "coin_pickup")?.data
        if let data = coinData {
            coinAudioPlayers.removeAll()
            for _ in 0..<4 {
                if let player = try? AVAudioPlayer(data: data) {
                    player.prepareToPlay()
                    player.volume = 0.85
                    coinAudioPlayers.append(player)
                }
            }
        }
        
        // Завантажуємо зациклену фонову музику (Data Asset background_music)
        let bgmData = NSDataAsset(name: "background_music")?.data
        if let data = bgmData {
            do {
                bgmAudioPlayer = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
                bgmAudioPlayer?.numberOfLoops = -1
                bgmAudioPlayer?.prepareToPlay()
            } catch {
                do {
                    bgmAudioPlayer = try AVAudioPlayer(data: data)
                    bgmAudioPlayer?.numberOfLoops = -1
                    bgmAudioPlayer?.prepareToPlay()
                } catch {
                    print("Failed to initialize AVAudioPlayer for BGM from NSDataAsset: \(error)")
                }
            }
        } else if let fileURL = Bundle.main.url(forResource: "background_music", withExtension: "wav") {
            do {
                bgmAudioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                bgmAudioPlayer?.numberOfLoops = -1
                bgmAudioPlayer?.prepareToPlay()
            } catch {
                print("Failed to initialize AVAudioPlayer for BGM from bundle: \(error)")
            }
        }
    }
    
    private var isMuted: Bool {
        return UserDefaults.standard.bool(forKey: "WallShiftMuted")
    }
    
    /// Динамічний запуск зацикленої фонової музики (з пониженою гучністю для меню або повною для гри)
    private func startBGM(lowVolume: Bool = false) {
        guard !isMuted else { return }
        guard let player = bgmAudioPlayer else { return }
        player.numberOfLoops = -1
        let targetVol = lowVolume ? Float(0.35) : GameScene.bgmTargetVolume
        player.volume = lowVolume ? targetVol : 0.25
        player.currentTime = 0
        player.play()
        if !lowVolume {
            player.setVolume(GameScene.bgmTargetVolume, fadeDuration: 0.6)
        }
    }
    
    private func toggleMute() {
        let currentlyMuted = isMuted
        UserDefaults.standard.set(!currentlyMuted, forKey: "WallShiftMuted")
        let iconName = (!currentlyMuted) ? "gui_icon_audio_off" : "gui_icon_audio_on"
        soundIconSprite?.texture = SKTexture(imageNamed: iconName)
        if !currentlyMuted {
            bgmAudioPlayer?.pause()
        } else {
            bgmAudioPlayer?.play()
        }
    }
    
    /// Плавне спадання тону/гучності фонової музики (fade-out 2.0 с) при завершенні гри
    private func stopBGM(fadeDuration: TimeInterval = 2.0) {
        guard let player = bgmAudioPlayer, player.isPlaying else { return }
        player.setVolume(0.0, fadeDuration: fadeDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) { [weak player] in
            if player?.volume == 0.0 {
                player?.stop()
            }
        }
    }
    
    /// Відтворення звуку стрибка героя при тапі на екран
    private func playJumpSound() {
        guard !isMuted, let audioPlayer = jumpAudioPlayer else { return }
        audioPlayer.currentTime = 0
        audioPlayer.play()
    }
    
    /// Відтворення звуку закінчення гри при програші
    private func playGameOverSound() {
        guard !isMuted, let audioPlayer = gameOverAudioPlayer else { return }
        audioPlayer.currentTime = 0
        audioPlayer.play()
    }
    
    /// Відтворення звуку підбору монети (coin_pickup)
    private func playCoinSound() {
        guard !isMuted, !coinAudioPlayers.isEmpty else { return }
        let player = coinAudioPlayers[currentCoinAudioIndex]
        currentCoinAudioIndex = (currentCoinAudioIndex + 1) % coinAudioPlayers.count
        player.currentTime = 0
        player.play()
    }
    
    private func setupBackground() {
        let textureSize = backgroundTexture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return }
        
        // Масштабуємо фон так, щоб він гарантовано покривав увесь екран (Aspect Fill)
        let scale = max(size.width / textureSize.width, size.height / textureSize.height) * 1.05
        let bgSize = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        
        let background = SKSpriteNode(texture: backgroundTexture, size: bgSize)
        background.zPosition = -10
        background.position = .zero // Завжди центрований відносно огляду камери
        cameraNode.addChild(background)
        self.backgroundNode = background
        
        // Атмосферний кольоровий оверлей теми (змінюється відповідно до активного персонажа)
        let overlay = SKSpriteNode(
            color: currentTheme.backgroundOverlayColor,
            size: CGSize(width: bgSize.width, height: bgSize.height)
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
            let heart = SKSpriteNode(imageNamed: "life_hearth")
            heart.size = heartSize
            heart.position = CGPoint(x: startX + CGFloat(i) * spacing, y: topY)
            heart.zPosition = 100
            hudNode.addChild(heart)
            heartHUDNodes.append(heart)
        }
        updateHUD(animated: false)
        
        // 2. Лічильник очок праворуч зверху
        scoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        scoreLabel.text = "\(score)"
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: (size.width / 2.0) - 30.0, y: topY)
        scoreLabel.zPosition = 100
        hudNode.addChild(scoreLabel)
        
        // 3. Лічильник монет праворуч під очками
        let coinIcon = SKSpriteNode(imageNamed: "coin_0")
        coinIcon.size = CGSize(width: 18.0, height: 18.0)
        coinIcon.position = CGPoint(x: (size.width / 2.0) - 72.0, y: topY - 26.0)
        coinIcon.zPosition = 100
        hudNode.addChild(coinIcon)
        self.hudCoinIcon = coinIcon
        
        coinsLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        coinsLabel.text = "\(coinsCollected)"
        coinsLabel.fontSize = 17
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
        let banner = SKSpriteNode(imageNamed: "gui_banner_orange")
        banner.size = CGSize(width: bannerW, height: bannerH)
        banner.position = .zero
        banner.zPosition = 1
        titleContainer.addChild(banner)
        
        let shadowLabel = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
        shadowLabel.text = "WALLSHIFT"
        shadowLabel.fontSize = min(44.0, size.width * 0.11)
        shadowLabel.fontColor = SKColor(red: 0.12, green: 0.05, blue: 0.02, alpha: 0.95)
        shadowLabel.position = CGPoint(x: 1.5, y: -bannerH * 0.08)
        shadowLabel.zPosition = 2
        titleContainer.addChild(shadowLabel)
        
        let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
        titleLabel.text = "WALLSHIFT"
        titleLabel.fontSize = min(44.0, size.width * 0.11)
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
        let card = SKSpriteNode(imageNamed: "gui_bar_orange")
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
        
        let bestScoreText = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        bestScoreText.text = "BEST: \(bestScore)"
        bestScoreText.fontSize = 15.0
        bestScoreText.fontColor = SKColor(red: 0.22, green: 0.09, blue: 0.03, alpha: 1.0)
        bestScoreText.horizontalAlignmentMode = .left
        bestScoreText.verticalAlignmentMode = .center
        bestScoreText.position = CGPoint(x: -cardW * 0.26, y: 0.0)
        bestScoreText.zPosition = 2
        card.addChild(bestScoreText)
        
        let coinIcon = SKSpriteNode(imageNamed: "gui_icon_coin")
        coinIcon.size = CGSize(width: 22.0, height: 22.0)
        coinIcon.position = CGPoint(x: cardW * 0.12, y: 0.0)
        coinIcon.zPosition = 2
        card.addChild(coinIcon)
        
        let coinsText = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        coinsText.text = "\(totalCoins)"
        coinsText.fontSize = 15.0
        coinsText.fontColor = SKColor(red: 0.22, green: 0.09, blue: 0.03, alpha: 1.0)
        coinsText.horizontalAlignmentMode = .left
        coinsText.verticalAlignmentMode = .center
        coinsText.position = CGPoint(x: cardW * 0.21, y: 0.0)
        coinsText.zPosition = 2
        card.addChild(coinsText)
        self.menuCoinsText = coinsText
        
        // 3. Кнопка START GAME із GUI Bundle
        let btnW: CGFloat = min(250.0, size.width - 80.0)
        let btnH: CGFloat = 66.0
        let playBtn = SKSpriteNode(imageNamed: "gui_btn_large_orange")
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
        
        let playLabel = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
        playLabel.name = "menuPlayButton"
        playLabel.text = "START GAME"
        playLabel.fontSize = 22.0
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
        let shopBtn = SKSpriteNode(imageNamed: "gui_btn_small_blue")
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
        
        let shopLabel = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
        shopLabel.name = "menuShopButton"
        shopLabel.text = "MARKET"
        shopLabel.fontSize = 20.0
        shopLabel.fontColor = .white
        shopLabel.verticalAlignmentMode = .center
        shopLabel.horizontalAlignmentMode = .center
        shopLabel.position = CGPoint(x: 12.0, y: 1.0)
        shopLabel.zPosition = 2
        shopBtn.addChild(shopLabel)
        
        // 5. Кнопка звуку із GUI Bundle (гучність вкл/викл)
        let soundBtn = SKSpriteNode(imageNamed: "gui_btn_circle_orange")
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
        let cardH: CGFloat = min(490.0, size.height * 0.74)
        let card = SKSpriteNode(imageNamed: "gui_card_box")
        card.name = "shopCard"
        card.size = CGSize(width: cardW, height: cardH)
        card.position = .zero
        card.zPosition = 2
        container.addChild(card)
        
        // 3. Заголовок "MARKET"
        let bannerW = min(230.0, cardW - 40.0)
        let bannerH = bannerW * (457.0 / 1139.0)
        let banner = SKSpriteNode(imageNamed: "gui_banner_orange")
        banner.size = CGSize(width: bannerW, height: bannerH)
        banner.position = CGPoint(x: 0, y: cardH * 0.44)
        banner.zPosition = 5
        card.addChild(banner)
        
        let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
        titleLabel.text = "MARKET"
        titleLabel.fontSize = 24.0
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.05)
        titleLabel.zPosition = 6
        banner.addChild(titleLabel)
        
        // 4. Кнопка закриття [X]
        let closeBtn = SKSpriteNode(imageNamed: "gui_btn_circle_orange")
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
        balanceNode.position = CGPoint(x: 0, y: cardH * 0.30)
        balanceNode.zPosition = 5
        card.addChild(balanceNode)
        
        let coinIcon = SKSpriteNode(imageNamed: "gui_icon_coin")
        coinIcon.size = CGSize(width: 24.0, height: 24.0)
        coinIcon.position = CGPoint(x: -28.0, y: 0)
        balanceNode.addChild(coinIcon)
        
        let balanceLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        balanceLabel.name = "shopBalanceLabel"
        balanceLabel.text = "\(totalCoins)"
        balanceLabel.fontSize = 20.0
        balanceLabel.fontColor = SKColor(red: 1.0, green: 0.88, blue: 0.30, alpha: 1.0)
        balanceLabel.horizontalAlignmentMode = .left
        balanceLabel.verticalAlignmentMode = .center
        balanceLabel.position = CGPoint(x: -12.0, y: 0)
        balanceNode.addChild(balanceLabel)
        
        // 6. Стрілки перемикання ліворуч / праворуч
        let arrowLeft = SKSpriteNode(imageNamed: "gui_btn_circle_orange")
        arrowLeft.name = "shopPrevButton"
        arrowLeft.size = CGSize(width: 44.0, height: 44.0)
        arrowLeft.position = CGPoint(x: -cardW * 0.40, y: cardH * 0.05)
        arrowLeft.zPosition = 8
        card.addChild(arrowLeft)
        
        let arrowLeftIcon = SKSpriteNode(imageNamed: "gui_icon_arrow_left")
        arrowLeftIcon.name = "shopPrevButton"
        arrowLeftIcon.size = CGSize(width: 20.0, height: 20.0)
        arrowLeftIcon.position = .zero
        arrowLeftIcon.zPosition = 2
        arrowLeft.addChild(arrowLeftIcon)
        
        let arrowRight = SKSpriteNode(imageNamed: "gui_btn_circle_orange")
        arrowRight.name = "shopNextButton"
        arrowRight.size = CGSize(width: 44.0, height: 44.0)
        arrowRight.position = CGPoint(x: cardW * 0.40, y: cardH * 0.05)
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
        
        // Анімація появи
        container.alpha = 0.0
        card.setScale(0.85)
        container.run(SKAction.fadeIn(withDuration: 0.20))
        card.run(SKAction.scale(to: 1.0, duration: 0.20))
        
        renderCurrentShopCard()
    }
    
    /// Рендеринг поточного персонажа/теми у вікні магазину
    private func renderCurrentShopCard() {
        guard let shop = shopNode,
              let card = shop.childNode(withName: "shopCard"),
              let content = card.childNode(withName: "shopDynamicContent") else { return }
        
        content.removeAllChildren()
        
        // Оновлюємо лічильник балансу
        if let balance = card.childNode(withName: "shopBalanceNode")?.childNode(withName: "shopBalanceLabel") as? SKLabelNode {
            balance.text = "\(totalCoins)"
        }
        
        let themes = ThemeManager.shared.themes
        guard currentShopIndex >= 0, currentShopIndex < themes.count else { return }
        let theme = themes[currentShopIndex]
        let isUnlocked = ThemeManager.shared.isUnlocked(theme)
        let isSelected = (theme.id == ThemeManager.shared.selectedThemeID)
        let canAfford = ThemeManager.shared.canAfford(theme)
        
        let cardH = (card as? SKSpriteNode)?.size.height ?? 490.0
        
        // А. П'єдестал та аватар персонажа
        let avatarBg = SKSpriteNode(imageNamed: "gui_card_orange")
        avatarBg.size = CGSize(width: 136.0, height: 136.0)
        avatarBg.position = CGPoint(x: 0, y: cardH * 0.05)
        avatarBg.zPosition = 1
        content.addChild(avatarBg)
        
        let heroAvatar = SKSpriteNode(imageNamed: theme.previewImageName)
        heroAvatar.size = CGSize(width: 96.0, height: 96.0)
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
            badge.size = CGSize(width: 26.0, height: 26.0)
            badge.position = CGPoint(x: 52.0, y: 52.0)
            badge.zPosition = 5
            avatarBg.addChild(badge)
        } else if !isUnlocked {
            let lock = SKSpriteNode(imageNamed: "gui_icon_lock")
            lock.size = CGSize(width: 26.0, height: 26.0)
            lock.position = CGPoint(x: 52.0, y: 52.0)
            lock.zPosition = 5
            avatarBg.addChild(lock)
        }
        
        // Б. Назва теми
        let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
        titleLabel.text = theme.name
        titleLabel.fontSize = 17.0
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: -cardH * 0.14)
        titleLabel.zPosition = 2
        content.addChild(titleLabel)
        
        // В. Опис характеристик
        let subtitleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
        subtitleLabel.text = theme.subtitle
        subtitleLabel.fontSize = 12.0
        subtitleLabel.fontColor = SKColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 0.90)
        subtitleLabel.position = CGPoint(x: 0, y: -cardH * 0.20)
        subtitleLabel.zPosition = 2
        content.addChild(subtitleLabel)
        
        // Г. Індикатор пагінації (точки 1 2 3)
        let dotsContainer = SKNode()
        dotsContainer.position = CGPoint(x: 0, y: -cardH * 0.26)
        dotsContainer.zPosition = 2
        content.addChild(dotsContainer)
        
        let dotSpacing: CGFloat = 16.0
        let totalDotsW = CGFloat(themes.count - 1) * dotSpacing
        for i in 0..<themes.count {
            let dot = SKShapeNode(circleOfRadius: (i == currentShopIndex) ? 4.5 : 3.0)
            dot.fillColor = (i == currentShopIndex) ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0) : SKColor.white.withAlphaComponent(0.35)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: -totalDotsW / 2.0 + CGFloat(i) * dotSpacing, y: 0)
            dotsContainer.addChild(dot)
        }
        
        // Д. Кнопка дії (ОБРАНО / ОБРАТИ / КУПИТИ)
        let btnW: CGFloat = 220.0
        let btnH: CGFloat = 54.0
        let actionBtnNode = SKNode()
        actionBtnNode.name = "shopActionButton"
        actionBtnNode.position = CGPoint(x: 0, y: -cardH * 0.38)
        actionBtnNode.zPosition = 3
        content.addChild(actionBtnNode)
        
        if isSelected {
            let btnBg = SKSpriteNode(imageNamed: "gui_btn_small_blue")
            btnBg.name = "shopActionButton"
            btnBg.size = CGSize(width: btnW, height: btnH)
            btnBg.zPosition = 1
            actionBtnNode.addChild(btnBg)
            
            let checkIcon = SKSpriteNode(imageNamed: "gui_icon_check")
            checkIcon.name = "shopActionButton"
            checkIcon.size = CGSize(width: 20.0, height: 20.0)
            checkIcon.position = CGPoint(x: -42.0, y: 1.0)
            checkIcon.zPosition = 3
            btnBg.addChild(checkIcon)
            
            let label = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
            label.name = "shopActionButton"
            label.text = "SELECTED"
            label.fontSize = 20.0
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 10.0, y: 1.0)
            label.zPosition = 3
            btnBg.addChild(label)
        } else if isUnlocked {
            let btnBg = SKSpriteNode(imageNamed: "gui_btn_large_orange")
            btnBg.name = "shopActionButton"
            btnBg.size = CGSize(width: btnW, height: btnH)
            btnBg.zPosition = 1
            actionBtnNode.addChild(btnBg)
            
            let label = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
            label.name = "shopActionButton"
            label.text = "SELECT"
            label.fontSize = 20.0
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 1.0)
            label.zPosition = 3
            btnBg.addChild(label)
        } else {
            // Заблокована тема — покупка
            let btnBg = SKSpriteNode(imageNamed: canAfford ? "gui_btn_large_orange" : "gui_btn_exit_orange")
            btnBg.name = "shopActionButton"
            btnBg.size = CGSize(width: btnW, height: btnH)
            btnBg.alpha = canAfford ? 1.0 : 0.75
            btnBg.zPosition = 1
            actionBtnNode.addChild(btnBg)
            
            let coin = SKSpriteNode(imageNamed: "gui_icon_coin")
            coin.name = "shopActionButton"
            coin.size = CGSize(width: 22.0, height: 22.0)
            coin.position = CGPoint(x: -btnW * 0.28, y: 1.0)
            coin.zPosition = 3
            btnBg.addChild(coin)
            
            let label = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
            label.name = "shopActionButton"
            label.text = canAfford ? "BUY (\(theme.price))" : "\(theme.price) (NOT ENOUGH)"
            label.fontSize = canAfford ? 18.0 : 15.0
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 12.0, y: 1.0)
            label.zPosition = 3
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
        
        // Оновлюємо лічильник монет у меню
        updateMenuCoinsDisplay()
        
        // Відновлюємо інтервал автострибка в меню
        if gameState == .menu {
            scheduleNextMenuAutoJump(delay: 2.0)
        }
    }
    
    /// Оновлення лічильника монет у меню після покупок
    private func updateMenuCoinsDisplay() {
        menuCoinsText?.text = "\(totalCoins)"
    }
    
    /// Миттєве застосування поточної теми до сцени (персонаж, стіни, фон)
    private func applyCurrentThemeToScene() {
        let theme = ThemeManager.shared.currentTheme
        
        // 1. Оновлення образу персонажа
        player.applyTheme(prefix: theme.heroRunPrefix, frameCount: theme.heroRunCount)
        if gameState == .menu {
            player.setReadyStance()
        }
        
        // 2. Оновлення атмосферного оверлею фону та текстури фону
        let newBgTex = backgroundTexture
        if newBgTex.size().width > 0 {
            backgroundNode?.texture = newBgTex
        }
        backgroundOverlayNode?.run(SKAction.colorize(with: theme.backgroundOverlayColor, colorBlendFactor: 1.0, duration: 0.35))
        backgroundOverlayNode?.run(SKAction.fadeAlpha(to: theme.backgroundOverlayAlpha, duration: 0.35))
        
        // 3. Повне перезавантаження траси, стін, прірв та декорацій під нову тему (у режимі меню)
        if gameState == .menu {
            leftTrackNodes.forEach { $0.removeFromParent() }
            leftTrackNodes.removeAll()
            rightTrackNodes.forEach { $0.removeFromParent() }
            rightTrackNodes.removeAll()
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
        
        // 4. Оновлення лічильника меню
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
            bgmAudioPlayer?.setVolume(GameScene.bgmTargetVolume, fadeDuration: 0.6)
        }
    }
    
    // MARK: - Procedural Track with Seamless Abysses, Hearts & Decorations
    
    private func setupProceduralTrack() {
        // Стартуємо генерацію від Y = 0
        currentLeftY = Config.tileSize / 2.0
        currentRightY = Config.tileSize / 2.0
        startCameraY = cameraNode.position.y
        
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
        
        // Ворожі моби: перший моб з'являється значно раніше (на 60-120 очках)
        trackMobNodes.removeAll()
        activeFireArrows.forEach { $0.removeFromParent() }
        activeFireArrows.removeAll()
        consecutivePatrollers = 0
        firstMobScoreThreshold = Int.random(in: 60...120)
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
    
    /// Перевіряє, чи є на стіні безпечна суцільна ділянка скелі без прірв
    private func isWallSolid(onLeftWall: Bool, atY yPos: CGFloat, safetyMargin: CGFloat = 80.0) -> Bool {
        let trackNodes = onLeftWall ? leftTrackNodes : rightTrackNodes
        for node in trackNodes {
            if let abyss = node as? AbyssObstacleNode {
                let abyssHalfHeight = (abyss.gapHeight / 2.0) + Config.tileSize
                let abyssMinY = abyss.position.y - abyssHalfHeight - safetyMargin
                let abyssMaxY = abyss.position.y + abyssHalfHeight + safetyMargin
                if yPos >= abyssMinY && yPos <= abyssMaxY {
                    return false
                }
            }
        }
        
        // Також перевіряємо заплановану наступну прірву, якщо вона на цій стіні
        if nextAbyssIsOnLeft == onLeftWall {
            let plannedMinY = nextAbyssY - safetyMargin
            let plannedMaxY = nextAbyssY + (Config.tileSize * 4.0) + safetyMargin
            if yPos >= plannedMinY && yPos <= plannedMaxY {
                return false
            }
        }
        
        return true
    }
    
    /// Перевіряє, чи є заданий вертикальний діапазон стіни повністю суцільним (без прірв по всій висоті)
    private func isWallRangeSolid(onLeftWall: Bool, minY: CGFloat, maxY: CGFloat, safetyMargin: CGFloat = 60.0) -> Bool {
        let bottom = min(minY, maxY)
        let top = max(minY, maxY)
        var y = bottom
        let step: CGFloat = 24.0
        while y <= top {
            if !isWallSolid(onLeftWall: onLeftWall, atY: y, safetyMargin: safetyMargin) {
                return false
            }
            y += step
        }
        return isWallSolid(onLeftWall: onLeftWall, atY: top, safetyMargin: safetyMargin)
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
            
            let offset = (rootHeight / 2.0) - 8.0
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
        
        // 2. Прадавня статуя або портал — горизонтально закріплені на скелі (основа в скелі, вершина в бік каньйону)
        if texName.contains("statue") || texName.contains("portal") {
            let landmarkHeight: CGFloat = texName.contains("statue") ? CGFloat.random(in: 74...86) : CGFloat.random(in: 70...80)
            let landmarkWidth = landmarkHeight * aspect
            let landmark = SKSpriteNode(texture: tex, size: CGSize(width: landmarkWidth, height: landmarkHeight))
            landmark.zPosition = -5
            landmark.alpha = CGFloat.random(in: 0.88...0.96)
            
            let offset = (landmarkHeight / 2.0) - 4.0
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
        
        let rootOffset = (treeSize.height / 2.0) - 14.0
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
    
    /// Спавнить табличку біля прірви (у горизонтальній орієнтації перпендикулярно до скелі)
    private func spawnAbyssWarningSign(onLeftWall: Bool, atY: CGFloat) {
        let texture = signpostTextures.randomElement() ?? signpostTextures[0]
        let sign = SKSpriteNode(texture: texture, size: CGSize(width: 28, height: 32))
        sign.zPosition = 3.2
        let signOffset: CGFloat = (32.0 / 2.0) - 3.0
        
        if onLeftWall {
            sign.zRotation = -.pi / 2.0
            sign.xScale = -1.0
            sign.position = CGPoint(x: Config.wallWidth + signOffset, y: atY + (Config.tileSize * 0.40))
        } else {
            sign.zRotation = .pi / 2.0
            sign.xScale = 1.0
            sign.position = CGPoint(x: size.width - Config.wallWidth - signOffset, y: atY + (Config.tileSize * 0.40))
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
            protrusionOffset = (h / 2.0) - 3.0
        } else if roll < 48 {
            // Осінній кущик (Bush 01): горизонтальний ріст зі скелі в коридор
            let s = CGFloat.random(in: 24...28)
            sprite = SKSpriteNode(texture: bushTexture, size: CGSize(width: s, height: s))
            protrusionOffset = (s / 2.0) - 3.0
        } else if roll < 82 {
            // Скельний виступ / камінь (Stone 01 / Stone 02)
            let tex = stoneTextures[Int.random(in: 0..<stoneTextures.count)]
            let s = CGFloat.random(in: 22...26)
            sprite = SKSpriteNode(texture: tex, size: CGSize(width: s, height: s))
            protrusionOffset = (s / 2.0) - 3.0
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
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: tileSize, height: tileSize))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.wall
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.none
        tile.physicsBody = body
        
        return tile
    }
    
    /// Створює додаткове життя на карті тільки в безпечному місці (гарантовано не над прірвою)
    private func spawnHeartItem(atY: CGFloat) {
        let isLeftSafe = isWallRangeSolid(onLeftWall: true, minY: atY - 30.0, maxY: atY + 30.0, safetyMargin: 50.0)
        let isRightSafe = isWallRangeSolid(onLeftWall: false, minY: atY - 30.0, maxY: atY + 30.0, safetyMargin: 50.0)
        
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
            // На обох стінах у цій точці прірва — відкладаємо появу серця вище на 150 pt
            nextHeartY = atY + 150.0
            return
        }
        
        let heart = HeartItemNode()
        heart.position = CGPoint(x: heartX, y: atY)
        addChild(heart)
        trackHeartNodes.append(heart)
    }
    
    /// Інтервал між спавнами ворожих мобів, що скорочується з ускладненням гри:
    /// Чим більше очок / вищий рівень складності — тим частіше з'являються патрулюючі та стріляючі моби.
    private func randomMobDistance() -> CGFloat {
        switch difficultyLevel {
        case 0...1:
            // 0...79 очок: плавне введення перших мобів (~30...42 очки між мобами)
            return CGFloat.random(in: 750.0...1050.0)
        case 2...4:
            // 80...199 очок (~19...30 очок між мобами)
            return CGFloat.random(in: 480.0...750.0)
        case 5...8:
            // 200...359 очок (~13...20 очок між мобами)
            return CGFloat.random(in: 320.0...500.0)
        default:
            // 360+ очок: інтенсивний динамічний спавн (~8...14 очок між мобами)
            return CGFloat.random(in: 200.0...340.0)
        }
    }
    
    /// Перевірка умов безпеки та чесності спавну моба ("повністю рандомно, але так щоб реально було грати"):
    /// 1. Стіна, де рухається моб, повинна бути суцільною на всій ділянці патруля (без прірв).
    /// 2. Протилежна стіна обов'язково безпечна для ухилення гравця навпроти ділянки патруля.
    /// 3. Відсутність накладання на інших активних мобів (безпечна дистанція).
    private func canSpawnMob(onLeftWall: Bool, startY: CGFloat, endY: CGFloat) -> Bool {
        // 1. Власна стіна моба суцільна на ділянці патруля
        guard isWallRangeSolid(onLeftWall: onLeftWall, minY: startY, maxY: endY, safetyMargin: 25.0) else {
            return false
        }
        
        // 2. Протилежна стіна обов'язково безпечна для комфортного ухилення стрибком
        guard isWallRangeSolid(onLeftWall: !onLeftWall, minY: startY - 40.0, maxY: endY + 60.0, safetyMargin: 30.0) else {
            return false
        }
        
        // 3. Дистанція до інших мобів (щоб уникнути непрохідних скупчень)
        for mob in trackMobNodes {
            let sameWall = (mob.isOnLeftWall == onLeftWall)
            let buffer: CGFloat = sameWall ? 120.0 : 70.0
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
        // Довжина маршруту патрулювання від точки А до точки Б (80...130 pt)
        let patrolDistance = CGFloat.random(in: 80.0...130.0)
        let patrolSpeed = CGFloat.random(in: 60.0...85.0) + min(35.0, CGFloat(difficultyLevel) * 3.5)
        let endY = candidateY + patrolDistance
        
        // Випадковий вибір стіни для патрулювання
        let preferredLeft = Bool.random()
        var targetSide: Bool?
        var finalEndY = endY
        
        // Вибір бажаного типу моба: звичайний патрульний або моб-стрілець
        let shooterChance: Double
        switch difficultyLevel {
        case 0...2:
            shooterChance = 0.40 // Початкові рівні: 40% стрільців
        case 3...5:
            shooterChance = 0.55
        default:
            shooterChance = 0.70 // Високі рівні: 70% стрільців
        }
        
        // Якщо було 2 патрульних поспіль — гарантуємо появу стрільця для динаміки
        let forceShooter = consecutivePatrollers >= 2
        let wantsShooter = forceShooter || (Double.random(in: 0...1) < shooterChance)
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
            let compactEndY = candidateY + 75.0
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
            
            // Текстури мобів відповідно до обраної теми
            let patrollerTextures: [SKTexture] = (0..<currentTheme.patrollerFrameCount).map {
                SKTexture(imageNamed: "\(currentTheme.patrollerPrefix)\($0)")
            }
            let shooterTextures: [SKTexture] = (0..<currentTheme.shooterFrameCount).map {
                SKTexture(imageNamed: "\(currentTheme.shooterPrefix)\($0)")
            }
            let activeTextures = (mobType == .shooter) ? shooterTextures : patrollerTextures
            
            let mob = MobNode(
                mobType: mobType,
                isOnLeftWall: onLeft,
                wallX: wallX,
                pointAY: candidateY,
                pointBY: finalEndY,
                patrolSpeed: patrolSpeed,
                customTextures: activeTextures
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
            nextMobY = max(candidateY + 80.0, currentLeftY + 40.0)
        }
    }
    
    /// Створення та додавання у сцену снаряду (вогняна або водяна стріла), випущеного мобом-стрільцем
    private func spawnFireArrow(from startPos: CGPoint, towards targetPos: CGPoint, projectileType: ProjectileType = .fire) {
        guard !isGameOver, !isPlayerFalling else { return }
        let arrow = FireArrowNode(from: startPos, towards: targetPos, projectileType: projectileType)
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
    
    /// Видаляє тайли та розриви, які залишилися далеко внизу за екраном
    private func cleanupPassedTrack() {
        let screenBottom = cameraNode.position.y - (size.height / 2.0) - 150.0
        
        leftTrackNodes.removeAll { node in
            if node.position.y < screenBottom {
                node.removeFromParent()
                return true
            }
            return false
        }
        
        rightTrackNodes.removeAll { node in
            if node.position.y < screenBottom {
                node.removeFromParent()
                return true
            }
            return false
        }
        
        trackHeartNodes.removeAll { node in
            if node.position.y < screenBottom {
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
            if coin.position.y < screenBottom {
                coin.removeFromParent()
                return true
            }
            return false
        }
        
        decorationNodes.removeAll { node in
            if node.position.y < screenBottom {
                node.removeFromParent()
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
                
                if nodeName == "shopActionButton" {
                    let themes = ThemeManager.shared.themes
                    guard currentShopIndex >= 0, currentShopIndex < themes.count else { return }
                    let theme = themes[currentShopIndex]
                    
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
            gameOverAudioPlayer?.stop()
            let touchedNodes = cameraNode.nodes(at: locInCamera)
            for node in touchedNodes {
                if node.name == "menuButton" || node.parent?.name == "menuButton" {
                    goToMainMenu()
                    return
                }
                if node.name == "retryButton" || node.parent?.name == "retryButton" {
                    restartGame()
                    return
                }
            }
            restartGame()
            return
        }
        
        // 4. Активний біг у грі
        guard !isPlayerFalling else { return }
        performJump()
    }
    
    private func performJump() {
        guard !player.isJumping, !isGameOver, !isPlayerFalling else { return }
        
        // Відтворюємо звук стрибка
        playJumpSound()
        
        // Визначаємо цільову горизонтальну позицію (на протилежну стіну)
        let targetX: CGFloat = player.isOnLeftWall ? playerRightX : playerLeftX
        
        // Делегуємо виконання стрибка у PlayerNode
        player.jump(to: targetX, duration: Config.jumpDuration) { [weak self] in
            guard let self = self else { return }
            if self.gameState == .menu {
                self.player.setReadyStance()
                self.scheduleNextMenuAutoJump(delay: 2.0)
            } else if self.gameState == .starting {
                self.player.setReadyStance()
            } else if self.gameState == .playing {
                self.player.startRunningAnimation()
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
        
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
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
                scoreLabel.text = "\(score)"
                
                // Перевіряємо кожні 100 очок для сповіщення про новий рівень складності
                let currentLevel = difficultyLevel
                if currentLevel > lastLevelCelebrated && currentLevel > 0 {
                    lastLevelCelebrated = currentLevel
                    celebrateLevelUp(level: currentLevel)
                }
            }
            
            // Перевірка та активація стрільби мобів-стрільців при появі гравця на їхній стіні
            // Оцінка безпеки зони ухилення: гравець повинен мати суцільну протилежну стіну для приземлення
            let oppWallIsSafeForJump = isWallRangeSolid(
                onLeftWall: !player.isOnLeftWall,
                minY: player.position.y + 10.0,
                maxY: player.position.y + 160.0,
                safetyMargin: 20.0
            )
            let ownWallAheadIsSafe = isWallRangeSolid(
                onLeftWall: player.isOnLeftWall,
                minY: player.position.y,
                maxY: player.position.y + 70.0,
                safetyMargin: 15.0
            )
            let canSafelyDodge = oppWallIsSafeForJump && ownWallAheadIsSafe
            
            for mob in trackMobNodes {
                mob.updateShooting(
                    playerPosition: player.position,
                    playerIsOnLeftWall: player.isOnLeftWall,
                    playerIsJumping: player.isJumping,
                    currentTime: currentTime,
                    isDodgeSafe: canSafelyDodge
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
    
    /// Перевіряє, чи знаходиться гравець безпосередньо над прірвою (в розриві стіни)
    private func checkAbyssUnderPlayer() -> AbyssObstacleNode? {
        let trackNodes = player.isOnLeftWall ? leftTrackNodes : rightTrackNodes
        let playerY = player.position.y
        for node in trackNodes {
            if let abyss = node as? AbyssObstacleNode {
                let halfH = abyss.gapHeight / 2.0
                let minY = abyss.position.y - halfH + 4.0
                let maxY = abyss.position.y + halfH - 4.0
                if playerY >= minY && playerY <= maxY {
                    return abyss
                }
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
    
    /// Акуратна система мікро-частинок при підборі серця (розміщується за персонажем, без перекриття і без тексту)
    private func playHeartPickupEffect(at position: CGPoint) {
        let container = SKNode()
        container.position = position
        container.zPosition = 4.8 // Позаду персонажа (zPosition = 5.0), щоб не закривати огляд
        
        // 1. Акуратні міні-сердечка (~10 пт), що м'яко здіймаються вгору
        let heartEmitter = SKEmitterNode()
        heartEmitter.particleTexture = GameScene.heartParticleTexture
        heartEmitter.particleBirthRate = 200
        heartEmitter.numParticlesToEmit = 7
        heartEmitter.particleLifetime = 0.38
        heartEmitter.particleLifetimeRange = 0.10
        heartEmitter.particleSpeed = 65.0
        heartEmitter.particleSpeedRange = 25.0
        heartEmitter.emissionAngle = .pi / 2.0 // Вгору
        heartEmitter.emissionAngleRange = .pi * 0.65
        heartEmitter.yAcceleration = 25.0
        heartEmitter.particleAlpha = 0.95
        heartEmitter.particleAlphaSpeed = -2.2
        heartEmitter.particleScale = 0.08
        heartEmitter.particleScaleRange = 0.025
        heartEmitter.particleScaleSpeed = -0.12
        heartEmitter.particleRotation = 0
        heartEmitter.particleRotationSpeed = .pi * 1.2
        heartEmitter.particleRotationRange = .pi
        heartEmitter.particleBlendMode = .alpha
        container.addChild(heartEmitter)
        
        // 2. Дрібні смарагдові іскри відновлення здоров'я
        let healEmitter = SKEmitterNode()
        healEmitter.particleTexture = GameScene.sparkTexture
        healEmitter.particleBirthRate = 250
        healEmitter.numParticlesToEmit = 10
        healEmitter.particleLifetime = 0.35
        healEmitter.particleLifetimeRange = 0.08
        healEmitter.particleSpeed = 70.0
        healEmitter.particleSpeedRange = 25.0
        healEmitter.emissionAngle = .pi / 2.0
        healEmitter.emissionAngleRange = .pi * 0.85
        healEmitter.yAcceleration = 30.0
        healEmitter.particleAlpha = 0.9
        healEmitter.particleAlphaSpeed = -2.4
        healEmitter.particleScale = 0.16
        healEmitter.particleScaleRange = 0.05
        healEmitter.particleScaleSpeed = -0.25
        healEmitter.particleColor = SKColor(red: 0.35, green: 0.98, blue: 0.55, alpha: 1.0)
        healEmitter.particleColorBlendFactor = 1.0
        healEmitter.particleBlendMode = .add
        container.addChild(healEmitter)
        
        addChild(container)
        
        // Автоматичне видалення контейнера після завершення життя частинок
        container.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.50),
            SKAction.removeFromParent()
        ]))
    }
    
    // MARK: - Lives & Mob Interaction
    
    /// Обробка потрапляння вогняної стріли моба-стрільця в героя
    private func handleArrowHit(arrow: FireArrowNode) {
        guard !player.isInvulnerable, !isGameOver, !isPlayerFalling else { return }
        
        arrow.explodeAndRemove()
        currentLives -= 1
        updateHUD()
        
        if currentLives > 0 {
            player.startInvulnerability(duration: 3.0)
        } else {
            triggerMobDefeat(reason: "Hit by fiery arrow")
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
        coinsLabel.text = "\(coinsCollected)"
        
        // Пружний сплеск іконки монети в HUD
        hudCoinIcon?.removeAction(forKey: "coinPulse")
        let scaleUpIcon = SKAction.scale(to: 1.38, duration: 0.08)
        let scaleDownIcon = SKAction.scale(to: 1.0, duration: 0.12)
        hudCoinIcon?.run(SKAction.sequence([scaleUpIcon, scaleDownIcon]), withKey: "coinPulse")
        
        // Сплеск тексту лічильника
        coinsLabel.removeAction(forKey: "labelPulse")
        let scaleUpText = SKAction.scale(to: 1.25, duration: 0.08)
        let scaleDownText = SKAction.scale(to: 1.0, duration: 0.12)
        coinsLabel.run(SKAction.sequence([scaleUpText, scaleDownText]), withKey: "labelPulse")
        
        // Спливаючий золотистий індикатор +1 над монетою
        playCoinPickupEffect(at: coin.position)
    }
    
    /// Акуратна система мікро-частинок при підборі монети (розміщується за персонажем, без перекриття і без тексту)
    private func playCoinPickupEffect(at position: CGPoint) {
        let container = SKNode()
        container.position = position
        container.zPosition = 4.8 // Позаду персонажа (zPosition = 5.0), щоб не закривати огляд
        
        // 1. Акуратний радіальний спалах міні-зірочок (~9-10 пт)
        let starEmitter = SKEmitterNode()
        starEmitter.particleTexture = GameScene.starParticleTexture
        starEmitter.particleBirthRate = 200
        starEmitter.numParticlesToEmit = 8
        starEmitter.particleLifetime = 0.28
        starEmitter.particleLifetimeRange = 0.08
        starEmitter.particleSpeed = 65.0
        starEmitter.particleSpeedRange = 25.0
        starEmitter.emissionAngle = 0
        starEmitter.emissionAngleRange = .pi * 2.0 // Повне коло 360°
        starEmitter.particleAlpha = 0.95
        starEmitter.particleAlphaSpeed = -2.6
        starEmitter.particleScale = 0.055
        starEmitter.particleScaleRange = 0.02
        starEmitter.particleScaleSpeed = -0.09
        starEmitter.particleRotation = 0
        starEmitter.particleRotationSpeed = .pi * 3.0
        starEmitter.particleRotationRange = .pi * 2.0
        starEmitter.particleBlendMode = .alpha
        container.addChild(starEmitter)
        
        // 2. Дрібні золотисто-жовті іскри (~3-4 пт)
        let sparkEmitter = SKEmitterNode()
        sparkEmitter.particleTexture = GameScene.sparkTexture
        sparkEmitter.particleBirthRate = 250
        sparkEmitter.numParticlesToEmit = 10
        sparkEmitter.particleLifetime = 0.25
        sparkEmitter.particleLifetimeRange = 0.06
        sparkEmitter.particleSpeed = 75.0
        sparkEmitter.particleSpeedRange = 25.0
        sparkEmitter.emissionAngle = 0
        sparkEmitter.emissionAngleRange = .pi * 2.0
        sparkEmitter.particleAlpha = 0.95
        sparkEmitter.particleAlphaSpeed = -3.0
        sparkEmitter.particleScale = 0.16
        sparkEmitter.particleScaleRange = 0.05
        sparkEmitter.particleScaleSpeed = -0.25
        sparkEmitter.particleColor = SKColor(red: 1.0, green: 0.88, blue: 0.30, alpha: 1.0)
        sparkEmitter.particleColorBlendFactor = 1.0
        sparkEmitter.particleBlendMode = .add
        container.addChild(sparkEmitter)
        
        addChild(container)
        
        // Автоматичне видалення контейнера після завершення життя частинок
        container.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.45),
            SKAction.removeFromParent()
        ]))
    }
    
    // MARK: - Game Over & Abyss Fall
    
    /// Запуск ефекту падіння персонажа безпосередньо всередину прірви (у розрив стіни)
    private func triggerAbyssFall(targetPoint: CGPoint?, reason: String) {
        guard !isPlayerFalling, !isGameOver else { return }
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
        if gameOverAudioPlayer?.isPlaying != true {
            playGameOverSound()
        }
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
        
        // Затемнюючий фон оверлею
        let bgDim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        bgDim.fillColor = SKColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 0.72)
        bgDim.strokeColor = .clear
        bgDim.position = .zero
        bgDim.zPosition = 1
        container.addChild(bgDim)
        
        // Головна діалогова картка (Box_Rounded)
        let dialogW = min(320.0, size.width - 40.0)
        let dialogH: CGFloat = 370.0
        let dialogCard = SKSpriteNode(imageNamed: "gui_card_box")
        dialogCard.size = CGSize(width: dialogW, height: dialogH)
        dialogCard.position = CGPoint(x: 0, y: 10.0)
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
        
        let titleShadow = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
        titleShadow.text = "GAME OVER"
        titleShadow.fontSize = 28.0
        titleShadow.fontColor = SKColor(red: 0.20, green: 0.04, blue: 0.04, alpha: 0.95)
        titleShadow.position = CGPoint(x: 1.5, y: -bannerH * 0.09)
        titleShadow.zPosition = 4
        redBanner.addChild(titleShadow)
        
        let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
        titleLabel.text = "GAME OVER"
        titleLabel.fontSize = 28.0
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.06)
        titleLabel.zPosition = 5
        redBanner.addChild(titleLabel)
        
        let reasonLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
        reasonLabel.text = subtitle
        reasonLabel.fontSize = 14.0
        reasonLabel.fontColor = SKColor(red: 0.95, green: 0.70, blue: 0.70, alpha: 1.0)
        reasonLabel.position = CGPoint(x: 0, y: 78.0)
        reasonLabel.zPosition = 3
        dialogCard.addChild(reasonLabel)
        
        // Картка результатів (ButtonText_Orange_TextField)
        let statsW = dialogW - 40.0
        let statsH: CGFloat = 70.0
        let statsBar = SKSpriteNode(imageNamed: "gui_bar_orange")
        statsBar.size = CGSize(width: statsW, height: statsH)
        statsBar.position = CGPoint(x: 0, y: 18.0)
        statsBar.zPosition = 3
        dialogCard.addChild(statsBar)
        
        let star = SKSpriteNode(imageNamed: "gui_icon_star")
        star.size = CGSize(width: 20.0, height: 20.0)
        star.position = CGPoint(x: -statsW * 0.38, y: 12.0)
        star.zPosition = 4
        statsBar.addChild(star)
        
        let scoreSummary = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        scoreSummary.text = "SCORE: \(score)   BEST: \(bestScore)"
        scoreSummary.fontSize = 15.0
        scoreSummary.fontColor = SKColor(red: 0.22, green: 0.09, blue: 0.03, alpha: 1.0)
        scoreSummary.horizontalAlignmentMode = .left
        scoreSummary.verticalAlignmentMode = .center
        scoreSummary.position = CGPoint(x: -statsW * 0.28, y: 12.0)
        scoreSummary.zPosition = 4
        statsBar.addChild(scoreSummary)
        
        let coin = SKSpriteNode(imageNamed: "gui_icon_coin")
        coin.size = CGSize(width: 20.0, height: 20.0)
        coin.position = CGPoint(x: -statsW * 0.38, y: -14.0)
        coin.zPosition = 4
        statsBar.addChild(coin)
        
        let coinsSummary = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        coinsSummary.text = "COINS: +\(coinsCollected)   TOTAL: \(totalCoins)"
        coinsSummary.fontSize = 14.0
        coinsSummary.fontColor = SKColor(red: 0.22, green: 0.09, blue: 0.03, alpha: 1.0)
        coinsSummary.horizontalAlignmentMode = .left
        coinsSummary.verticalAlignmentMode = .center
        coinsSummary.position = CGPoint(x: -statsW * 0.28, y: -14.0)
        coinsSummary.zPosition = 4
        statsBar.addChild(coinsSummary)
        
        // Кнопка PLAY AGAIN (ButtonText_Large_Orange_Round)
        let retryBtnW = dialogW - 50.0
        let retryBtnH: CGFloat = 56.0
        let retryBtn = SKSpriteNode(imageNamed: "gui_btn_large_orange")
        retryBtn.name = "retryButton"
        retryBtn.size = CGSize(width: retryBtnW, height: retryBtnH)
        retryBtn.position = CGPoint(x: 0, y: -54.0)
        retryBtn.zPosition = 3
        dialogCard.addChild(retryBtn)
        
        let retryIcon = SKSpriteNode(imageNamed: "gui_icon_restart")
        retryIcon.name = "retryButton"
        retryIcon.size = CGSize(width: 22.0, height: 22.0)
        retryIcon.position = CGPoint(x: -retryBtnW * 0.28, y: 0)
        retryIcon.zPosition = 4
        retryBtn.addChild(retryIcon)
        
        let retryLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        retryLabel.name = "retryButton"
        retryLabel.text = "PLAY AGAIN"
        retryLabel.fontSize = 17.0
        retryLabel.fontColor = .white
        retryLabel.verticalAlignmentMode = .center
        retryLabel.horizontalAlignmentMode = .center
        retryLabel.position = CGPoint(x: 10.0, y: 0)
        retryLabel.zPosition = 4
        retryBtn.addChild(retryLabel)
        
        // Кнопка MAIN MENU (ButtonText_Small_Blue_Round)
        let menuBtnW = dialogW - 70.0
        let menuBtnH: CGFloat = 48.0
        let menuBtn = SKSpriteNode(imageNamed: "gui_btn_small_blue")
        menuBtn.name = "menuButton"
        menuBtn.size = CGSize(width: menuBtnW, height: menuBtnH)
        menuBtn.position = CGPoint(x: 0, y: -120.0)
        menuBtn.zPosition = 3
        dialogCard.addChild(menuBtn)
        
        let homeIcon = SKSpriteNode(imageNamed: "gui_icon_home")
        homeIcon.name = "menuButton"
        homeIcon.size = CGSize(width: 20.0, height: 20.0)
        homeIcon.position = CGPoint(x: -menuBtnW * 0.26, y: 0)
        homeIcon.zPosition = 4
        menuBtn.addChild(homeIcon)
        
        let menuLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        menuLabel.name = "menuButton"
        menuLabel.text = "MAIN MENU"
        menuLabel.fontSize = 15.0
        menuLabel.fontColor = .white
        menuLabel.verticalAlignmentMode = .center
        menuLabel.horizontalAlignmentMode = .center
        menuLabel.position = CGPoint(x: 8.0, y: 0)
        menuLabel.zPosition = 4
        menuBtn.addChild(menuLabel)
        
        // Додаємо до cameraNode, щоб напис завжди був по центру поточного огляду камери
        cameraNode.addChild(container)
    }
    
    private func restartGame() {
        stopBGM(fadeDuration: 0.2)
        let newScene = GameScene(size: size, initialMode: .playing)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene)
    }
    
    private func goToMainMenu() {
        stopBGM(fadeDuration: 0.2)
        let newScene = GameScene(size: size, initialMode: .menu)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene)
    }
}
