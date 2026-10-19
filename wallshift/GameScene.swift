//
//  GameScene.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit
import GameplayKit
import AVFoundation

// MARK: - Physics Categories
/// Бітові маски категорій фізики для визначення взаємодії об'єктів
struct PhysicsCategory {
    static let none: UInt32     = 0
    static let player: UInt32   = 1 << 0 // 1
    static let wall: UInt32     = 1 << 1 // 2
    static let obstacle: UInt32 = 1 << 2 // 4
    static let abyss: UInt32    = 1 << 3 // 8
    static let heart: UInt32    = 1 << 4 // 16
}

// MARK: - GameScene
final class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // Сумісність із GKScene (шаблоном Xcode)
    var entities = [GKEntity]()
    var graphs = [String: GKGraph]()
    
    // MARK: - Configuration Constants
    private enum Config {
        static let wallWidth: CGFloat = 48.0
        static let tileSize: CGFloat = 48.0
        
        // Швидкість постійного руху вгору (точок за секунду)
        static let baseUpwardSpeed: CGFloat = 280.0
        static let maxUpwardSpeed: CGFloat = 430.0
        
        // Кількість точок вертикального підйому на 1 очко
        static let distancePerScorePoint: CGFloat = 25.0
        
        // Тривалість стрибка між стінами (в секундах)
        static let jumpDuration: TimeInterval = 0.30
        
        // Колірна гамма підкладки фону (теплий осінній тон)
        static let backgroundColor = SKColor(red: 0.18, green: 0.12, blue: 0.09, alpha: 1.0)
    }
    
    // MARK: - Cached Textures
    private let backgroundTexture: SKTexture = {
        for name in ["backround", "background", "Autumn_Forest_2D_Platformer_Tileset_Background - Layer 00"] {
            let texture = SKTexture(imageNamed: name)
            if texture.size().width > 0 {
                return texture
            }
        }
        return SKTexture(imageNamed: "backround")
    }()
    private let wallTexture = SKTexture(imageNamed: "wall_tile")            // Ground 02 - основна доріжка
    private let cliffLowerTexture = SKTexture(imageNamed: "abyss_cliff_right") // Ground 04 - нижній уступ прірви (де стіна закінчується)
    private let cliffUpperTexture = SKTexture(imageNamed: "abyss_cliff_left")  // Ground 08 - верхній уступ прірви (де стіна починається знову)
    
    // MARK: - Decoration Textures (Autumn Forest Environment)
    private let treeTextures: [SKTexture] = [
        SKTexture(imageNamed: "deco_tree_01"),
        SKTexture(imageNamed: "deco_tree_02")
    ]
    private let bushTexture = SKTexture(imageNamed: "deco_bush_01")
    private let stumpTexture = SKTexture(imageNamed: "deco_stump")
    private let stoneTextures: [SKTexture] = [
        SKTexture(imageNamed: "deco_stone_01"),
        SKTexture(imageNamed: "deco_stone_02")
    ]
    private let signpostTextures: [SKTexture] = [
        SKTexture(imageNamed: "deco_sign_warning"),   // Варіант А: попередження (!)
        SKTexture(imageNamed: "deco_sign_arrow"),     // Варіант Б: стрілка напрямку
        SKTexture(imageNamed: "deco_sign_question")   // Варіант В: загадка (?)
    ]
    
    // MARK: - Audio
    private var jumpAudioPlayer: AVAudioPlayer?
    private var gameOverAudioPlayer: AVAudioPlayer?
    
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
    
    /// Рівень складності, що зростає кожні 100 очок (0, 1, 2, 3...)
    private var difficultyLevel: Int {
        return score / 100
    }
    
    /// Поточна швидкість підйому камери, що плавно зростає кожні 100 очок
    private var currentUpwardSpeed: CGFloat {
        let speedIncrease = CGFloat(difficultyLevel) * 20.0
        return min(Config.maxUpwardSpeed, Config.baseUpwardSpeed + speedIncrease)
    }
    
    /// Різні розміри розриву прірв залежно від набраних очок:
    /// - 0...99: 2...3 тайли (96...144 pt)
    /// - 100...199: 2...4 тайли (96...192 pt)
    /// - 200...299: 2...5 тайлів (96...240 pt)
    /// - 300+: 3...6 тайлів (144...288 pt)
    private func randomAbyssGapTileCount() -> Int {
        switch difficultyLevel {
        case 0:
            return Int.random(in: 2...3)
        case 1:
            return Int.random(in: 2...4)
        case 2:
            return Int.random(in: 2...5)
        default:
            return Int.random(in: 3...6)
        }
    }
    
    /// Скорочення дистанції між прірвами кожні 100 очок (більше прірв з часом):
    /// - 0...99: 520...720 pt
    /// - 100...199: 400...560 pt
    /// - 200...299: 320...460 pt
    /// - 300...399: 260...380 pt
    /// - 400+: 220...320 pt
    private func randomAbyssDistance() -> CGFloat {
        switch difficultyLevel {
        case 0:
            return CGFloat.random(in: 520.0...720.0)
        case 1:
            return CGFloat.random(in: 400.0...560.0)
        case 2:
            return CGFloat.random(in: 320.0...460.0)
        case 3:
            return CGFloat.random(in: 260.0...380.0)
        default:
            return CGFloat.random(in: 220.0...320.0)
        }
    }
    
    /// Рідкісний інтервал появи сердець (додаткових життів):
    /// Перше серце з'являється не раніше 2200 pt (~90 очок),
    /// а наступні — кожні 3500...5500 pt (~140...220 очок)
    private func randomHeartDistance() -> CGFloat {
        let extraDelay: CGFloat = currentLives >= GameScene.maxLives ? 2000.0 : 0.0
        return CGFloat.random(in: 3500.0...5500.0) + extraDelay
    }
    
    // Відстеження часу для обчислення deltaTime
    private var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Procedural Track, Abyss, Hearts & Mobs Generation
    private var leftTrackNodes: [SKNode] = []
    private var rightTrackNodes: [SKNode] = []
    private var trackHeartNodes: [SKNode] = []
    private var trackMobNodes: [MobNode] = []
    private var currentLeftY: CGFloat = 0
    private var currentRightY: CGFloat = 0
    
    private var nextAbyssY: CGFloat = 0
    private var nextAbyssIsOnLeft: Bool = false
    private var consecutiveAbyssesOnSameWall: Int = 1
    private let maxConsecutiveAbyssesOnSameWall: Int = 2
    private var nextHeartY: CGFloat = 0
    
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
        lastLevelCelebrated = 0
        lastUpdateTime = 0
        leftTrackNodes.removeAll()
        rightTrackNodes.removeAll()
        trackHeartNodes.removeAll()
        trackMobNodes.removeAll()
        decorationNodes.removeAll()
        
        setupPhysicsWorld()
        setupCamera()
        setupAudio()
        setupBackground()
        setupPlayer()
        setupHUD()
        setupProceduralTrack()
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
    }
    
    /// Відтворення звуку стрибка героя при тапі на екран
    private func playJumpSound() {
        guard let audioPlayer = jumpAudioPlayer else { return }
        audioPlayer.currentTime = 0
        audioPlayer.play()
    }
    
    /// Відтворення звуку закінчення гри при програші
    private func playGameOverSound() {
        guard let audioPlayer = gameOverAudioPlayer else { return }
        audioPlayer.currentTime = 0
        audioPlayer.play()
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
    }
    
    private func setupPlayer() {
        player = PlayerNode()
        
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
        nextAbyssY = player.position.y + 500.0
        
        // Серця тепер є рідкістю: перше з'явиться приблизно після 90-100 очок (~2200 pt)
        trackHeartNodes.removeAll()
        nextHeartY = player.position.y + 2200.0
        
        // Ворожі моби: перший моб з'являється на рандомній відмітці 500-1000 очок (в кожному раунді різний інтервал)
        trackMobNodes.removeAll()
        firstMobScoreThreshold = Int.random(in: 500...1000)
        nextMobY = startCameraY + (CGFloat(firstMobScoreThreshold) * Config.distancePerScorePoint)
        
        // Початкові декорації біля стартової позиції гравця (природний антураж)
        setupInitialDecorations()
        
        // Будуємо стіни наперед
        buildTrack(upTo: cameraNode.position.y + (size.height * 1.5))
    }
    
    /// Початкові декорації біля стартової позиції гравця (природний антураж без табличок)
    private func setupInitialDecorations() {
        let pY = player.position.y
        
        // 1. Одне величне осіннє дерево на старті зліва (коріння у міцній початковій скелі)
        spawnBackgroundTree(onLeftWall: true, atY: pY + 140.0, textureIndex: 0, scale: 0.50)
        
        // 2. Пеньок на лівій стіні біля старту
        let stump = SKSpriteNode(texture: stumpTexture, size: CGSize(width: 28, height: 15))
        stump.zPosition = 3.2
        stump.zRotation = -.pi / 2.0
        stump.xScale = -1.0
        stump.position = CGPoint(x: Config.wallWidth + 5.0, y: pY - 30.0)
        addChild(stump)
        decorationNodes.append(stump)
        
        // 3. Осінній кущик на лівій стіні
        let bush = SKSpriteNode(texture: bushTexture, size: CGSize(width: 26, height: 26))
        bush.zPosition = 3.2
        bush.zRotation = -.pi / 2.0
        bush.xScale = -1.0
        bush.position = CGPoint(x: Config.wallWidth + 10.0, y: pY + 40.0)
        addChild(bush)
        decorationNodes.append(bush)
        
        // 4. Скельний камінь на правій стіні
        let stone = SKSpriteNode(texture: stoneTextures[0], size: CGSize(width: 26, height: 26))
        stone.zPosition = 3.2
        stone.zRotation = .pi / 2.0
        stone.xScale = 1.0
        stone.position = CGPoint(x: size.width - Config.wallWidth - 10.0, y: pY + 80.0)
        addChild(stone)
        decorationNodes.append(stone)
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
            let plannedMaxY = nextAbyssY + (Config.tileSize * 6.0) + safetyMargin
            if yPos >= plannedMinY && yPos <= plannedMaxY {
                return false
            }
        }
        
        return true
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
    
    /// Спавнить фонове дерево, що виростає зі скелі каньйону (позаду бігової доріжки)
    private func spawnBackgroundTree(onLeftWall: Bool, atY: CGFloat, textureIndex: Int? = nil, scale: CGFloat? = nil) {
        let tex = treeTextures[textureIndex ?? Int.random(in: 0..<treeTextures.count)]
        let s = scale ?? CGFloat.random(in: 0.42...0.52)
        let treeSize = CGSize(width: tex.size().width * s, height: tex.size().height * s)
        let tree = SKSpriteNode(texture: tex, size: treeSize)
        tree.zPosition = -5
        
        let rootOffset = (treeSize.height / 2.0) - 18.0
        if onLeftWall {
            // Коріння впирається у ліву стіну, крона розростається вглиб каньйону праворуч
            tree.zRotation = -.pi / 2.0
            tree.xScale = -1.0
            tree.position = CGPoint(x: Config.wallWidth + rootOffset, y: atY)
        } else {
            // Коріння впирається у праву стіну, крона розростається вглиб каньйону ліворуч
            tree.zRotation = .pi / 2.0
            tree.xScale = 1.0
            tree.position = CGPoint(x: size.width - Config.wallWidth - rootOffset, y: atY)
        }
        
        tree.alpha = CGFloat.random(in: 0.82...0.94)
        addChild(tree)
        decorationNodes.append(tree)
    }
    
    /// Спавнить табличку біля прірви (в рандомному порядку: знак оклику, стрілка або знак питання)
    private func spawnAbyssWarningSign(onLeftWall: Bool, atY: CGFloat) {
        // Обираємо випадкову табличку для кожної прірви (біля однієї - варіант А, біля іншої - варіант Б)
        let texture = signpostTextures.randomElement() ?? signpostTextures[0]
        let sign = SKSpriteNode(texture: texture, size: CGSize(width: 30, height: 30))
        sign.zPosition = 3.2
        
        let signOffset: CGFloat = 13.0
        if onLeftWall {
            sign.zRotation = -.pi / 2.0
            sign.xScale = -1.0
            sign.position = CGPoint(x: Config.wallWidth + signOffset, y: atY)
        } else {
            sign.zRotation = .pi / 2.0
            sign.xScale = 1.0
            sign.position = CGPoint(x: size.width - Config.wallWidth - signOffset, y: atY)
        }
        
        addChild(sign)
        decorationNodes.append(sign)
    }
    
    /// Процедурний спавн природних декорацій на стіні (кущики, каміння, пеньки — тільки на суцільних ділянках)
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
        
        if roll < 48 {
            // Осінній кущик (Bush 01): основа в стіні, листя виступає в коридор
            let s = CGFloat.random(in: 24...28)
            sprite = SKSpriteNode(texture: bushTexture, size: CGSize(width: s, height: s))
            protrusionOffset = (s / 2.0) - 3.0
        } else if roll < 82 {
            // Скельний виступ / камінь (Stone 01 / Stone 02)
            let tex = stoneTextures[Int.random(in: 0..<stoneTextures.count)]
            let s = CGFloat.random(in: 24...28)
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
    
    /// Створює додаткове життя на карті
    private func spawnHeartItem(atY: CGFloat) {
        let heart = HeartItemNode()
        let roll = Int.random(in: 0...9)
        let heartX: CGFloat
        if roll < 4 {
            heartX = playerLeftX
        } else if roll < 8 {
            heartX = playerRightX
        } else {
            heartX = size.width / 2.0
        }
        heart.position = CGPoint(x: heartX, y: atY)
        addChild(heart)
        trackHeartNodes.append(heart)
    }
    
    /// Інтервал між спавнами ворожих мобів, що скорочується з ускладненням гри:
    /// Чим більше очок / вищий рівень складності — тим частіше з'являються патрулюючі моби.
    private func randomMobDistance() -> CGFloat {
        switch difficultyLevel {
        case 0...9:
            // 500...999 очок: плавне введення перших мобів (~45...65 очок між мобами)
            return CGFloat.random(in: 1100.0...1600.0)
        case 10...14:
            // 1000...1499 очок (~32...48 очок між мобами)
            return CGFloat.random(in: 800.0...1200.0)
        case 15...19:
            // 1500...1999 очок (~22...34 очки між мобами)
            return CGFloat.random(in: 550.0...850.0)
        default:
            // 2000+ очок: інтенсивний спавн (~16...26 очок між мобами)
            return CGFloat.random(in: 400.0...650.0)
        }
    }
    
    /// Перевірка умов безпеки та чесності спавну моба ("повністю рандомно, але так щоб реально було грати"):
    /// 1. Стіна, де рухається моб, повинна бути суцільною на всій ділянці патруля (без прірв).
    /// 2. ПРОТИЛЕЖНА СТІНА ОБОВ'ЯЗКОВО ПОВИННА БУТИ ЦІЛОЮ на цій самій висоті,
    ///    щоб гравець завжди мав куди перестрибнути та безпечно оббігти ворога!
    /// 3. Відсутність накладання на інших активних мобів (безпечна дистанція).
    private func canSpawnMob(onLeftWall: Bool, startY: CGFloat, endY: CGFloat) -> Bool {
        let midY = (startY + endY) / 2.0
        
        // 1. Стіна для патрулювання має бути повністю суцільною
        guard isWallSolid(onLeftWall: onLeftWall, atY: startY, safetyMargin: 40.0),
              isWallSolid(onLeftWall: onLeftWall, atY: endY, safetyMargin: 40.0),
              isWallSolid(onLeftWall: onLeftWall, atY: midY, safetyMargin: 40.0) else {
            return false
        }
        
        // 2. Протилежна стіна обов'язково безпечна для гравця (головний фактор playability)
        guard isWallSolid(onLeftWall: !onLeftWall, atY: startY, safetyMargin: 60.0),
              isWallSolid(onLeftWall: !onLeftWall, atY: endY, safetyMargin: 60.0),
              isWallSolid(onLeftWall: !onLeftWall, atY: midY, safetyMargin: 60.0) else {
            return false
        }
        
        // 3. Дистанція до інших мобів (щоб уникнути непрохідних скупчень)
        for mob in trackMobNodes {
            let mobMin = mob.pointAY - 160.0
            let mobMax = mob.pointBY + 160.0
            if startY <= mobMax && endY >= mobMin {
                return false
            }
        }
        
        return true
    }
    
    /// Спроба процедурного спавну моба на основі поточної висоти каньйону
    private func trySpawnMob(candidateY: CGFloat) {
        // Довжина маршруту патрулювання від точки А до точки Б (120...200 pt)
        let patrolDistance = CGFloat.random(in: 120.0...200.0)
        let patrolSpeed = CGFloat.random(in: 55.0...80.0)
        let endY = candidateY + patrolDistance
        
        // Випадковий вибір стіни для патрулювання
        let preferredLeft = Bool.random()
        let targetSide: Bool?
        
        if canSpawnMob(onLeftWall: preferredLeft, startY: candidateY, endY: endY) {
            targetSide = preferredLeft
        } else if canSpawnMob(onLeftWall: !preferredLeft, startY: candidateY, endY: endY) {
            targetSide = !preferredLeft
        } else {
            targetSide = nil
        }
        
        if let onLeft = targetSide {
            let wallX = onLeft ? (leftWallInnerX + MobNode.Constants.footOffset) : (rightWallInnerX - MobNode.Constants.footOffset)
            let mob = MobNode(isOnLeftWall: onLeft, wallX: wallX, pointAY: candidateY, pointBY: endY, patrolSpeed: patrolSpeed)
            addChild(mob)
            trackMobNodes.append(mob)
            
            // Наступний моб планується з інтервалом, скоректованим складності
            nextMobY = candidateY + randomMobDistance()
        } else {
            // Якщо зараз обидві стіни зайняті прірвами, відкладаємо перевірку на 120 pt вище
            nextMobY = candidateY + 120.0
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
            if mob.position.y < screenBottom {
                mob.removeFromParent()
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
        // Якщо гра закінчена, тап перезапускає сцену
        if isGameOver {
            gameOverAudioPlayer?.stop()
            restartGame()
            return
        }
        
        // Виконуємо стрибок, якщо герой не знаходиться в падінні
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
        player.jump(to: targetX, duration: Config.jumpDuration) {
            // Приземлення виконано успішно
        }
    }
    
    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        
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
        }
        
        // Безперервне поповнення доріжки наперед та очищення старих тайлів позаду
        buildTrack(upTo: cameraNode.position.y + (size.height * 1.5))
        cleanupPassedTrack()
    }
    
    override func didEvaluateActions() {
        // Якщо герой біжить або стрибає, фіксуємо його положення по Y
        guard !isGameOver, !isPlayerFalling else { return }
        player.position.y = cameraNode.position.y + playerCameraOffsetY
        
        // Якщо герой біжить по стіні (не в стрибку), строго фіксуємо його X на відповідній стіні
        if !player.isJumping {
            let currentWallX = player.isOnLeftWall ? playerLeftX : playerRightX
            player.position.x = currentWallX
            player.physicsBody?.velocity = .zero
        }
    }
    
    // MARK: - Physics Contact Delegate
    func didBegin(_ contact: SKPhysicsContact) {
        guard !isGameOver, !isPlayerFalling else { return }
        
        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        // 1. Потрапляння у прірву
        if mask == (PhysicsCategory.player | PhysicsCategory.abyss) {
            // Якщо гравець зараз моргає (невразливий 3 секунди), прірва не завдає шкоди
            guard !player.isInvulnerable else { return }
            
            let abyssNode = (contact.bodyA.categoryBitMask == PhysicsCategory.abyss ? contact.bodyA.node : contact.bodyB.node) as? AbyssObstacleNode
            handleAbyssHit(abyss: abyssNode)
        }
        
        // 2. Збір додаткового життя (серця)
        if mask == (PhysicsCategory.player | PhysicsCategory.heart) {
            let heartNode = (contact.bodyA.categoryBitMask == PhysicsCategory.heart ? contact.bodyA.node : contact.bodyB.node) as? HeartItemNode
            guard let heart = heartNode, !heart.isCollected else { return }
            handleHeartCollect(heart: heart)
        }
        
        // 3. Зіткнення з ворожим мобом
        if mask == (PhysicsCategory.player | PhysicsCategory.obstacle) {
            guard !player.isInvulnerable else { return }
            let mobNode = (contact.bodyA.categoryBitMask == PhysicsCategory.obstacle ? contact.bodyA.node : contact.bodyB.node) as? MobNode
            handleMobHit(mob: mobNode)
        }
    }
    
    // MARK: - Lives & Abyss Interaction
    
    /// Обробка потрапляння персонажа у прірву: втрата 1 життя або Game Over
    private func handleAbyssHit(abyss: AbyssObstacleNode?) {
        guard !player.isInvulnerable, !isGameOver, !isPlayerFalling else { return }
        
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
    
    /// Відновлення героя на стіні вище прірви з 3 секундами моргання (невразливості)
    private func recoverFromAbyss(abyss: AbyssObstacleNode?) {
        // Базова логіка прірви: гравець відновлюється на тій стіні, де знаходиться прірва,
        // у яку він потрапив (навіть якщо зіткнення сталося під час перестрибування зі стіни на стіну).
        let wallIsLeft = abyss?.isOnLeftWall ?? (player.position.x < size.width / 2.0)
        let respawnX = wallIsLeft ? playerLeftX : playerRightX
        
        // Підтягуємо вертикальну позицію камери так, щоб уся прірва гарантовано залишилася позаду
        let abyssCenterY = abyss?.position.y ?? player.position.y
        let gapHeight = abyss?.gapHeight ?? (Config.tileSize * 3.0)
        let abyssTopY = abyssCenterY + (gapHeight / 2.0) + Config.tileSize
        
        let requiredCameraY = abyssTopY - playerCameraOffsetY
        if cameraNode.position.y < requiredCameraY {
            cameraNode.position.y = requiredCameraY
        }
        
        let safeY = cameraNode.position.y + playerCameraOffsetY
        
        // Візуальний ефект удару (струс камери та короткий червоний спалах)
        playHurtEffect()
        
        // Відновлюємо гравця на стіні вище прірви
        player.respawn(onLeftWall: wallIsLeft, at: CGPoint(x: respawnX, y: safeY))
    }
    
    /// Візуальний ефект отримання пошкодження
    private func playHurtEffect() {
        let flash = SKSpriteNode(color: SKColor.red.withAlphaComponent(0.35), size: size)
        flash.zPosition = 90
        cameraNode.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.removeFromParent()
        ]))
        
        let shakeLeft = SKAction.moveBy(x: -6.0, y: 0, duration: 0.04)
        let shakeRight = SKAction.moveBy(x: 12.0, y: 0, duration: 0.04)
        let shakeBack = SKAction.moveBy(x: -6.0, y: 0, duration: 0.04)
        cameraNode.run(SKAction.sequence([shakeLeft, shakeRight, shakeBack]))
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
    
    /// Спливаючий текст та ефект при підборі серця
    private func playHeartPickupEffect(at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = "+1 LIFE"
        label.fontSize = 17
        label.fontColor = SKColor(red: 0.45, green: 0.98, blue: 0.55, alpha: 1.0)
        label.position = position
        label.zPosition = 50
        addChild(label)
        
        let moveUp = SKAction.moveBy(x: 0, y: 36.0, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        label.run(SKAction.sequence([SKAction.group([moveUp, fadeOut]), SKAction.removeFromParent()]))
    }
    
    // MARK: - Lives & Mob Interaction
    
    /// Обробка зіткнення героя з ворожим мобом
    private func handleMobHit(mob: MobNode?) {
        guard !player.isInvulnerable, !isGameOver, !isPlayerFalling else { return }
        
        currentLives -= 1
        updateHUD()
        playHurtEffect()
        
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
        print("Game Over: \(reason)")
        
        let defeatDirection: CGFloat = player.isOnLeftWall ? -30.0 : 30.0
        let targetPoint = CGPoint(x: player.position.x + defeatDirection, y: player.position.y - 120.0)
        
        player.fallIntoAbyss(targetPoint: targetPoint) { [weak self] in
            self?.completeGameOver(message: "Caught by canyon monster")
        }
    }
    
    // MARK: - Game Over & Abyss Fall
    
    /// Запуск ефекту падіння персонажа безпосередньо всередину прірви (у розрив стіни)
    private func triggerAbyssFall(targetPoint: CGPoint?, reason: String) {
        guard !isPlayerFalling, !isGameOver else { return }
        isPlayerFalling = true
        
        // Відтворюємо звук закінчення гри
        playGameOverSound()
        
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
        
        // Якщо звук ще не почав грати, запускаємо його
        if gameOverAudioPlayer?.isPlaying != true {
            playGameOverSound()
        }
        
        showGameOverOverlay(subtitle: message)
        
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                self?.isPaused = true
            }
        ]))
    }
    
    private func showGameOverOverlay(subtitle: String = "Tap to restart") {
        if score > bestScore {
            bestScore = score
        }
        
        let container = SKNode()
        container.zPosition = 100
        
        let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        titleLabel.text = "GAME OVER"
        titleLabel.fontSize = 38
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 46)
        
        let scoreSummary = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        scoreSummary.text = "SCORE: \(score)   BEST: \(bestScore)"
        scoreSummary.fontSize = 20
        scoreSummary.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 1.0)
        scoreSummary.position = CGPoint(x: 0, y: 10)
        
        let reasonLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
        reasonLabel.text = subtitle
        reasonLabel.fontSize = 17
        reasonLabel.fontColor = SKColor(red: 0.98, green: 0.35, blue: 0.40, alpha: 1.0)
        reasonLabel.position = CGPoint(x: 0, y: -20)
        
        let restartHint = SKLabelNode(fontNamed: "HelveticaNeue-Light")
        restartHint.text = "Tap to restart"
        restartHint.fontSize = 16
        restartHint.fontColor = SKColor.white.withAlphaComponent(0.8)
        restartHint.position = CGPoint(x: 0, y: -52)
        
        container.addChild(titleLabel)
        container.addChild(scoreSummary)
        container.addChild(reasonLabel)
        container.addChild(restartHint)
        
        // Додаємо до cameraNode, щоб напис завжди був по центру поточного екрана
        cameraNode.addChild(container)
    }
    
    private func restartGame() {
        let newScene = GameScene(size: size)
        newScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.25)
        view?.presentScene(newScene, transition: transition)
    }
}
