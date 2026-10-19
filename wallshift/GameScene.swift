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
    
    // Відстеження часу для обчислення deltaTime
    private var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Procedural Track & Abyss Generation
    private var leftTrackNodes: [SKNode] = []
    private var rightTrackNodes: [SKNode] = []
    private var currentLeftY: CGFloat = 0
    private var currentRightY: CGFloat = 0
    
    private var nextAbyssY: CGFloat = 0
    private var nextAbyssIsOnLeft: Bool = false
    
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
        lastUpdateTime = 0
        leftTrackNodes.removeAll()
        rightTrackNodes.removeAll()
        
        setupPhysicsWorld()
        setupCamera()
        setupAudio()
        setupBackground()
        setupPlayer()
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
    
    // MARK: - Procedural Track with Seamless Abysses
    
    private func setupProceduralTrack() {
        // Стартуємо генерацію від Y = 0
        currentLeftY = Config.tileSize / 2.0
        currentRightY = Config.tileSize / 2.0
        
        // Перша прірва з'явиться вище гравця на правій стіні
        nextAbyssY = player.position.y + 500.0
        nextAbyssIsOnLeft = false
        
        // Будуємо стіни наперед
        buildTrack(upTo: cameraNode.position.y + (size.height * 1.5))
    }
    
    /// Покроково будує обидві стіни у сітці без швів, інтегруючи прірви як частину доріжки
    private func buildTrack(upTo targetY: CGFloat) {
        let tileSize = Config.tileSize
        
        // Будуємо обидві стіни синхронно вгору
        while currentLeftY < targetY || currentRightY < targetY {
            
            // 1. Генерація ЛІВОЇ стіни
            if currentLeftY < targetY {
                if nextAbyssIsOnLeft && currentLeftY >= nextAbyssY {
                    // Спавнимо безшовну прірву на ЛІВІЙ стіні
                    buildAbyssGap(onLeftWall: true)
                    
                    // Наступну прірву плануємо на ПРАВІЙ стіні
                    nextAbyssIsOnLeft = false
                    nextAbyssY = currentLeftY + CGFloat.random(in: 480.0...680.0)
                } else {
                    // Звичайний суцільний тайл доріжки (Ground 02)
                    let tile = createWallTile(texture: wallTexture, yPos: currentLeftY, isLeft: true)
                    addChild(tile)
                    leftTrackNodes.append(tile)
                    currentLeftY += tileSize
                }
            }
            
            // 2. Генерація ПРАВОЇ стіни
            if currentRightY < targetY {
                if !nextAbyssIsOnLeft && currentRightY >= nextAbyssY {
                    // Спавнимо безшовну прірву на ПРАВІЙ стіні
                    buildAbyssGap(onLeftWall: false)
                    
                    // Наступну прірву плануємо на ЛІВІЙ стіні
                    nextAbyssIsOnLeft = true
                    nextAbyssY = currentRightY + CGFloat.random(in: 480.0...680.0)
                } else {
                    // Звичайний суцільний тайл доріжки (Ground 02)
                    let tile = createWallTile(texture: wallTexture, yPos: currentRightY, isLeft: false)
                    addChild(tile)
                    rightTrackNodes.append(tile)
                    currentRightY += tileSize
                }
            }
        }
    }
    
    /// Будує безшовну прірву у доріжці:
    /// [Ground 02] -> [Ground 08 (уступ кінця стіни)] -> [РОЗРИВ/ПРІРВА] -> [Ground 04 (уступ початку стіни)] -> [Ground 02]
    private func buildAbyssGap(onLeftWall: Bool) {
        let tileSize = Config.tileSize
        let gapTileCount = 3 // 3 тайли = 144 точки розриву стіни
        
        if onLeftWall {
            // Крок А: Нижній уступ обриву стіни (Ground 08) - ідеально стикується з доріжкою знизу
            let lowerCliff = createWallTile(texture: cliffLowerTexture, yPos: currentLeftY, isLeft: true)
            addChild(lowerCliff)
            leftTrackNodes.append(lowerCliff)
            currentLeftY += tileSize
            
            // Крок Б: Сам розрив (прірва, де стіна відсутня)
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
        
        // Постійне плавне переміщення камери вгору.
        // При падінні героя в прірву камера зупиняється, фіксуючи погляд на розриві стіни.
        if !isPlayerFalling {
            let verticalStep = Config.baseUpwardSpeed * CGFloat(deltaTime)
            cameraNode.position.y += verticalStep
            player.position.y = cameraNode.position.y + playerCameraOffsetY
        }
        
        // Безперервне поповнення доріжки наперед та очищення старих тайлів позаду
        buildTrack(upTo: cameraNode.position.y + (size.height * 1.5))
        cleanupPassedTrack()
    }
    
    override func didEvaluateActions() {
        // Якщо герой біжить або стрибає, фіксуємо його положення по Y
        guard !isGameOver, !isPlayerFalling else { return }
        player.position.y = cameraNode.position.y + playerCameraOffsetY
    }
    
    // MARK: - Physics Contact Delegate
    func didBegin(_ contact: SKPhysicsContact) {
        guard !isGameOver, !isPlayerFalling else { return }
        
        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        // Якщо гравець перетинає край уступу і потрапляє в прірву — падіння безпосередньо всередину безодні
        if mask == (PhysicsCategory.player | PhysicsCategory.abyss) {
            var targetPoint: CGPoint?
            if let abyss = contact.bodyA.node as? AbyssObstacleNode {
                let targetX: CGFloat = abyss.isOnLeftWall ? 10.0 : (size.width - 10.0)
                targetPoint = CGPoint(x: targetX, y: abyss.position.y)
            } else if let abyss = contact.bodyB.node as? AbyssObstacleNode {
                let targetX: CGFloat = abyss.isOnLeftWall ? 10.0 : (size.width - 10.0)
                targetPoint = CGPoint(x: targetX, y: abyss.position.y)
            }
            
            triggerAbyssFall(targetPoint: targetPoint, reason: "Fell into the abyss")
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
            x: player.isOnLeftWall ? 10.0 : (size.width - 10.0),
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
        let container = SKNode()
        container.zPosition = 100
        
        let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        titleLabel.text = "GAME OVER"
        titleLabel.fontSize = 38
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 30)
        
        let reasonLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
        reasonLabel.text = subtitle
        reasonLabel.fontSize = 20
        reasonLabel.fontColor = SKColor(red: 0.98, green: 0.35, blue: 0.40, alpha: 1.0)
        reasonLabel.position = CGPoint(x: 0, y: -8)
        
        let restartHint = SKLabelNode(fontNamed: "HelveticaNeue-Light")
        restartHint.text = "Tap to restart"
        restartHint.fontSize = 16
        restartHint.fontColor = SKColor.white.withAlphaComponent(0.8)
        restartHint.position = CGPoint(x: 0, y: -38)
        
        container.addChild(titleLabel)
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
