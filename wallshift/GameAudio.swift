//
//  GameAudio.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 20.10.2026.
//

import AVFoundation
import UIKit

// MARK: - GameAudio
/// Високопродуктивний звуковий рушій на базі AVAudioEngine, пре-декодованих PCM-буферів
/// та асинхронної обробки у виділеній черзі.
/// Забезпечує:
/// 1. Стабільні 60/120 FPS без мікролагів та нульове блокування головного потоку рендерингу.
/// 2. Повну підтримку системних апаратних клавіш гучності (Media Volume).
/// 3. Ідеальний баланс гучності: соковита фонова музика та збалансовані звукові ефекти.
final class GameAudio {
    static let shared = GameAudio()
    
    // MARK: - Рівні гучності (баланс музики та ефектів)
    static let bgmTargetVolume: Float = 0.82
    static let bgmLowVolume: Float = 0.42
    static let coinVolume: Float = 0.32
    static let jumpVolume: Float = 0.28
    static let gameOverVolume: Float = 0.45
    
    // MARK: - Виділена аудіо-черга (повне усунення затримок головного потоку)
    private let audioQueue = DispatchQueue(label: "com.wallshift.gameaudio", qos: .userInteractive)
    
    // MARK: - AVAudioEngine (Низьколатентне мікшування SFX)
    private let engine = AVAudioEngine()
    
    // Пре-декодовані в пам'ять PCM-буфери (нуль звернень до диска під час гри)
    private var jumpBuffer: AVAudioPCMBuffer?
    private var coinBuffer: AVAudioPCMBuffer?
    private var gameOverBuffer: AVAudioPCMBuffer?
    
    // Ноди відтворення звукових ефектів
    private let jumpNode = AVAudioPlayerNode()
    private let gameOverNode = AVAudioPlayerNode()
    
    // Пул із 4 нод для монет (швидкий збір кількох монет поспіль без обриву)
    private let coinNodes: [AVAudioPlayerNode] = [
        AVAudioPlayerNode(),
        AVAudioPlayerNode(),
        AVAudioPlayerNode(),
        AVAudioPlayerNode()
    ]
    private var currentCoinNodeIndex: Int = 0
    
    // MARK: - Фонова музика (AVAudioPlayer hardware stream)
    private var bgmPlayer: AVAudioPlayer?
    
    private var isSetup = false
    
    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: "WallShiftMuted") }
        set { UserDefaults.standard.set(newValue, forKey: "WallShiftMuted") }
    }
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        engine.stop()
    }
    
    // MARK: - Ініціалізація
    
    func setupIfNeeded() {
        guard !isSetup else { return }
        isSetup = true
        
        // 1. Налаштовуємо спільну аудіосесію (реагує на фізичні кнопки гучності)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        // Використовуємо системний нативний буфер для стабільного VSYNC без навантаження на CPU
        try? session.setActive(true)
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        
        // 2. Пре-декодування коротких SFX у PCM-буфери в пам'яті
        self.jumpBuffer = loadPCMBuffer(named: "player_jump", tempDir: tempDir)
        self.coinBuffer = loadPCMBuffer(named: "coin_pickup", tempDir: tempDir)
        self.gameOverBuffer = loadPCMBuffer(named: "game_over", tempDir: tempDir)
        
        // 3. Підключення нод до мікшера двигуна
        setupAudioEngine()
        
        // 4. Підготовка фонової музики через локальний файл
        setupBGMPlayer(tempDir: tempDir)
    }
    
    private func setupAudioEngine() {
        // Підключаємо ноду стрибка
        engine.attach(jumpNode)
        connectNode(jumpNode, format: jumpBuffer?.format)
        jumpNode.volume = GameAudio.jumpVolume
        
        // Підключаємо пул нод монет
        for node in coinNodes {
            engine.attach(node)
            connectNode(node, format: coinBuffer?.format)
            node.volume = GameAudio.coinVolume
        }
        
        // Підключаємо ноду Game Over
        engine.attach(gameOverNode)
        connectNode(gameOverNode, format: gameOverBuffer?.format)
        gameOverNode.volume = GameAudio.gameOverVolume
        
        // Готуємо та запускаємо двигун
        engine.prepare()
        do {
            try engine.start()
        } catch {
            print("[GameAudio] Engine start error: \(error)")
        }
    }
    
    private func connectNode(_ node: AVAudioNode, format: AVAudioFormat?) {
        if #available(iOS 27.0, *) {
            try? engine.connectNode(node, to: engine.mainMixerNode, format: format)
        } else {
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }
    
    private func playNode(_ node: AVAudioPlayerNode) {
        if #available(iOS 27.0, *) {
            try? node.playAudio()
        } else {
            node.play()
        }
    }
    
    private func ensureEngineRunning() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("[GameAudio] Engine restart error: \(error)")
        }
    }
    
    private func loadPCMBuffer(named name: String, tempDir: URL) -> AVAudioPCMBuffer? {
        guard let data = NSDataAsset(name: name)?.data else { return nil }
        let url = tempDir.appendingPathComponent("\(name).mp3")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let frameCount = UInt32(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        try? file.read(into: buffer)
        return buffer
    }
    
    private func setupBGMPlayer(tempDir: URL) {
        if let data = NSDataAsset(name: "background_music")?.data {
            let url = tempDir.appendingPathComponent("background_music.mp3")
            if !FileManager.default.fileExists(atPath: url.path) {
                try? data.write(to: url)
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.volume = GameAudio.bgmTargetVolume
                player.prepareToPlay()
                self.bgmPlayer = player
            } catch {
                print("[GameAudio] Failed to initialize BGM player: \(error)")
            }
        }
    }
    
    // MARK: - Сповіщення життєвого циклу
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            pauseBGM()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) && !isMuted {
                audioQueue.async { [weak self] in
                    self?.ensureEngineRunning()
                }
                resumeBGM()
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleWillEnterForeground() {
        guard !isMuted else { return }
        audioQueue.async { [weak self] in
            self?.ensureEngineRunning()
        }
        resumeBGM()
    }
    
    // MARK: - Звукові ефекти (SFX)
    
    /// Відтворення звуку стрибка героя (асинхронно у виділеній черзі, 0ms затримка, нуль блокувань головного потоку)
    func playJump() {
        guard !isMuted else { return }
        audioQueue.async { [weak self] in
            guard let self = self, !self.isMuted, let buffer = self.jumpBuffer else { return }
            self.ensureEngineRunning()
            if self.jumpNode.isPlaying {
                self.jumpNode.stop()
            }
            self.jumpNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            self.playNode(self.jumpNode)
        }
    }
    
    /// Відтворення звуку підбору монети з пулу нод (асинхронно, без переривання при швидкому зборі)
    func playCoin() {
        guard !isMuted else { return }
        audioQueue.async { [weak self] in
            guard let self = self, !self.isMuted, let buffer = self.coinBuffer else { return }
            self.ensureEngineRunning()
            let node = self.coinNodes[self.currentCoinNodeIndex]
            self.currentCoinNodeIndex = (self.currentCoinNodeIndex + 1) % self.coinNodes.count
            if node.isPlaying {
                node.stop()
            }
            node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            self.playNode(node)
        }
    }
    
    /// Відтворення звуку Game Over
    func playGameOver() {
        guard !isMuted else { return }
        audioQueue.async { [weak self] in
            guard let self = self, !self.isMuted, let buffer = self.gameOverBuffer else { return }
            self.ensureEngineRunning()
            if self.gameOverNode.isPlaying {
                self.gameOverNode.stop()
            }
            self.gameOverNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            self.playNode(self.gameOverNode)
        }
    }
    
    // MARK: - Фонова музика (BGM)
    
    /// Запуск або відновлення фонової музики
    func startBGM(lowVolume: Bool = false) {
        guard !isMuted, let player = bgmPlayer else { return }
        let targetVol: Float = lowVolume ? GameAudio.bgmLowVolume : GameAudio.bgmTargetVolume
        player.volume = targetVol
        if !player.isPlaying {
            player.play()
        }
    }
    
    /// Плавна зміна гучності фонової музики
    func setBGMVolume(_ volume: Float, fadeDuration: TimeInterval = 0) {
        guard let player = bgmPlayer else { return }
        if fadeDuration > 0 {
            player.setVolume(volume, fadeDuration: fadeDuration)
        } else {
            player.volume = volume
        }
    }
    
    /// Призупинення фонової музики
    func pauseBGM() {
        bgmPlayer?.pause()
    }
    
    /// Відновлення фонової музики
    func resumeBGM() {
        guard !isMuted, let player = bgmPlayer, !player.isPlaying else { return }
        player.play()
    }
    
    /// Зупинка фонової музики з плавним згасанням
    func stopBGM(fadeDuration: TimeInterval = 0) {
        guard let player = bgmPlayer, player.isPlaying else { return }
        if fadeDuration > 0 {
            player.setVolume(0.0, fadeDuration: fadeDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) { [weak player] in
                if player?.volume == 0.0 {
                    player?.pause()
                }
            }
        } else {
            player.pause()
        }
    }
    
    /// Перемикання звуку (Mute / Unmute)
    @discardableResult
    func toggleMute() -> Bool {
        let newMuted = !isMuted
        isMuted = newMuted
        if newMuted {
            pauseBGM()
            audioQueue.async { [weak self] in
                guard let self = self else { return }
                self.jumpNode.stop()
                self.coinNodes.forEach { $0.stop() }
                self.gameOverNode.stop()
            }
        } else {
            audioQueue.async { [weak self] in
                self?.ensureEngineRunning()
            }
            resumeBGM()
        }
        return newMuted
    }
}
