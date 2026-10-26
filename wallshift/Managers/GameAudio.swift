//
//  GameAudio.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 20.10.2026.
//

import AVFoundation
import UIKit

// MARK: - GameAudio
/// Високопродуктивний звуковий рушій, оптимізований для стабільних 60-120 FPS без мікролагів:
/// 1. BGM: апаратне потокове відтворення через `AVAudioPlayer` (0 МБ зайвої RAM, без перевантаження буферів, вбудований DSP fade).
/// 2. SFX: низьколатентний пул нод у `AVAudioEngine` з попереднім прогрівом (0 викликів блокуючих API на Main Thread).
final class GameAudio {
    static let shared = GameAudio()
    
    // MARK: - Рівні гучності (баланс музики та ефектів)
    static let bgmTargetVolume: Float = 0.82
    static let bgmLowVolume: Float = 0.50
    static let coinVolume: Float = 0.32
    static let jumpVolume: Float = 0.28
    static let gameOverVolume: Float = 0.45
    
    // MARK: - Стан гучності та Mute
    private var isLowVolumeActive: Bool = false
    
    /// Прапорець, що сигналізує про активний показ реклами
    private(set) var isAdActive: Bool = false
    
    // In-memory кеш налаштувань звуку (0 звернень до UserDefaults під час гри)
    private var cachedIsMuted: Bool = UserDefaults.standard.bool(forKey: "WallShiftMuted")
    private var cachedBGMVolume: Float = UserDefaults.standard.object(forKey: "WallShiftBGMVolume") == nil ? 1.0 : UserDefaults.standard.float(forKey: "WallShiftBGMVolume")
    private var cachedSFXVolume: Float = UserDefaults.standard.object(forKey: "WallShiftSFXVolume") == nil ? 1.0 : UserDefaults.standard.float(forKey: "WallShiftSFXVolume")
    
    var isMuted: Bool {
        get { cachedIsMuted }
        set {
            cachedIsMuted = newValue
            DispatchQueue.global(qos: .utility).async {
                UserDefaults.standard.set(newValue, forKey: "WallShiftMuted")
            }
        }
    }
    
    /// Гучність фонової музики: 0.0 ... 1.0 (за замовчуванням 1.0)
    var bgmVolume: Float {
        get { cachedBGMVolume }
        set {
            let clamped = max(0.0, min(1.0, newValue))
            cachedBGMVolume = clamped
            DispatchQueue.global(qos: .utility).async {
                UserDefaults.standard.set(clamped, forKey: "WallShiftBGMVolume")
            }
            applyBGMVolume()
        }
    }
    
    /// Гучність звукових ефектів (стрибок, монетки, game over): 0.0 ... 1.0 (за замовчуванням 1.0)
    var sfxVolume: Float {
        get { cachedSFXVolume }
        set {
            let clamped = max(0.0, min(1.0, newValue))
            cachedSFXVolume = clamped
            DispatchQueue.global(qos: .utility).async {
                UserDefaults.standard.set(clamped, forKey: "WallShiftSFXVolume")
            }
            applySFXVolume()
        }
    }
    
    // MARK: - Виділена аудіо-черга для SFX (100% ізоляція від головного потоку)
    private let audioQueue = DispatchQueue(label: "com.wallshift.audio", qos: .userInitiated)
    
    // MARK: - AVAudioEngine (Низьколатентне апаратне мікшування SFX)
    private let engine = AVAudioEngine()
    
    // Пре-декодовані легкі PCM-буфери звукових ефектів у RAM (<200 КБ)
    private var jumpBuffer: AVAudioPCMBuffer?
    private var coinBuffer: AVAudioPCMBuffer?
    private var gameOverBuffer: AVAudioPCMBuffer?
    
    // Пул нод для стрибків (усуває збої при швидких послідовних тапах/буферизації)
    private let jumpNodes: [AVAudioPlayerNode] = [
        AVAudioPlayerNode(),
        AVAudioPlayerNode()
    ]
    private var currentJumpNodeIndex: Int = 0
    
    // Нода для Game Over
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
    private var isBGMPlayingRequested: Bool = false
    
    private var isSetup = false
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        engine.stop()
        bgmPlayer?.stop()
    }
    
    // MARK: - Ініціалізація та попереднє завантаження
    
    func setupIfNeeded() {
        guard !isSetup else { return }
        isSetup = true
        
        // 1. Налаштовуємо спільну аудіосесію
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        
        // 2. Ініціалізуємо потоковий BGM плеєр (апаратне читання MP3 з диску, 0 МБ витрат RAM)
        setupBGMPlayer(tempDir: tempDir)
        
        // 3. Пре-декодування коротких звуків SFX у пам'ять (<200 КБ)
        let jBuf = loadPCMBuffer(named: "player_jump", tempDir: tempDir)
        let cBuf = loadPCMBuffer(named: "coin_pickup", tempDir: tempDir)
        let gBuf = loadPCMBuffer(named: "game_over", tempDir: tempDir)
        
        self.jumpBuffer = jBuf
        self.coinBuffer = cBuf
        self.gameOverBuffer = gBuf
        
        // 4. Підключаємо ноди SFX до головного мікшера з їхнім точним нативним форматом каналів
        for node in jumpNodes {
            engine.attach(node)
            connectNode(node, format: jBuf?.format)
        }
        for node in coinNodes {
            engine.attach(node)
            connectNode(node, format: cBuf?.format)
        }
        engine.attach(gameOverNode)
        connectNode(gameOverNode, format: gBuf?.format)
        
        // 5. Підготовка та старт рушія SFX у виділеній фоновій черзі
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            self.applySFXVolumeInternal()
            self.ensureEngineRunningInternal()
            self.prewarmAudioNodesInternal()
        }
    }
    
    private func setupBGMPlayer(tempDir: URL) {
        guard let data = NSDataAsset(name: "background_music")?.data else { return }
        let url = tempDir.appendingPathComponent("background_music.mp3")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            self.bgmPlayer = player
            player.prepareToPlay()
        } catch {
            print("[GameAudio] Failed to initialize BGM player: \(error)")
        }
    }
    
    private func connectNode(_ node: AVAudioNode, format: AVAudioFormat?) {
        if #available(iOS 27.0, *) {
            try? engine.connectNode(node, to: engine.mainMixerNode, format: format)
        } else {
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }
    
    private func ensureEngineRunningInternal() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            prewarmAudioNodesInternal()
        } catch {
            print("[GameAudio] Engine restart error: \(error)")
        }
    }
    
    /// Попередній запуск нод відтворення звукових ефектів (усуває затримки та IPC блокування на перших стрибках)
    private func prewarmAudioNodesInternal() {
        for node in jumpNodes {
            if !node.isPlaying {
                node.play()
            }
        }
        for node in coinNodes {
            if !node.isPlaying {
                node.play()
            }
        }
        if !gameOverNode.isPlaying {
            gameOverNode.play()
        }
    }
    
    /// Завантажує аудіофайл напряму в PCM-буфер у пам'яті (тільки для коротких SFX)
    private func loadPCMBuffer(named name: String, tempDir: URL) -> AVAudioPCMBuffer? {
        guard let data = NSDataAsset(name: name)?.data else { return nil }
        let url = tempDir.appendingPathComponent("\(name).mp3")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let fileFormat = file.processingFormat
        let fileLength = UInt32(file.length)
        guard fileLength > 0, let buffer = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: fileLength) else { return nil }
        do {
            try file.read(into: buffer)
            return buffer
        } catch {
            return nil
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
            if options.contains(.shouldResume) && !isMuted && !isAdActive {
                audioQueue.async { [weak self] in
                    self?.ensureEngineRunningInternal()
                }
                resumeBGM()
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleWillEnterForeground() {
        guard !isAdActive, !isMuted else { return }
        audioQueue.async { [weak self] in
            self?.ensureEngineRunningInternal()
        }
        resumeBGM()
    }
    
    // MARK: - Застосування рівнів гучності SFX
    
    /// Оновлення нод SFX з урахуванням поточного sfxVolume та isMuted (асинхронно в аудіо-черзі)
    func applySFXVolume() {
        audioQueue.async { [weak self] in
            self?.applySFXVolumeInternal()
        }
    }
    
    private func applySFXVolumeInternal() {
        let eff = isMuted ? 0.0 : sfxVolume
        for node in jumpNodes {
            node.volume = GameAudio.jumpVolume * eff
        }
        for node in coinNodes {
            node.volume = GameAudio.coinVolume * eff
        }
        gameOverNode.volume = GameAudio.gameOverVolume * eff
    }
    
    // MARK: - Звукові ефекти (SFX: 0 блокування головного потоку)
    
    /// Відтворення звуку стрибка героя (виклик на MainThread триває ~1 мкс: лише надсилання задачі в audioQueue)
    func playJump() {
        guard !isMuted, sfxVolume > 0.001 else { return }
        audioQueue.async { [weak self] in
            self?.playJumpInternal()
        }
    }
    
    private func playJumpInternal() {
        guard !isMuted, sfxVolume > 0.001, let buffer = jumpBuffer else { return }
        let node = jumpNodes[currentJumpNodeIndex]
        guard node.engine != nil else { return }
        ensureEngineRunningInternal()
        currentJumpNodeIndex = (currentJumpNodeIndex + 1) % jumpNodes.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying {
            node.play()
        }
    }
    
    /// Відтворення звуку підбору монети з пулу нод
    func playCoin() {
        guard !isMuted, sfxVolume > 0.001 else { return }
        audioQueue.async { [weak self] in
            self?.playCoinInternal()
        }
    }
    
    private func playCoinInternal() {
        guard !isMuted, sfxVolume > 0.001, let buffer = coinBuffer else { return }
        let node = coinNodes[currentCoinNodeIndex]
        guard node.engine != nil else { return }
        ensureEngineRunningInternal()
        currentCoinNodeIndex = (currentCoinNodeIndex + 1) % coinNodes.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying {
            node.play()
        }
    }
    
    /// Відтворення звуку Game Over
    func playGameOver() {
        guard !isMuted, sfxVolume > 0.001 else { return }
        audioQueue.async { [weak self] in
            self?.playGameOverInternal()
        }
    }
    
    private func playGameOverInternal() {
        guard !isMuted, sfxVolume > 0.001, let buffer = gameOverBuffer, gameOverNode.engine != nil else { return }
        ensureEngineRunningInternal()
        gameOverNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !gameOverNode.isPlaying {
            gameOverNode.play()
        }
    }
    
    // MARK: - Фонова музика (BGM через потоковий AVAudioPlayer)
    
    /// Запуск або відновлення фонової музики
    func startBGM(lowVolume: Bool = false) {
        self.isLowVolumeActive = lowVolume
        self.isBGMPlayingRequested = true
        guard let player = bgmPlayer, !isAdActive, !isMuted, bgmVolume > 0.001 else { return }
        let base = lowVolume ? GameAudio.bgmLowVolume : GameAudio.bgmTargetVolume
        let target = base * bgmVolume
        player.volume = target
        if !player.isPlaying {
            player.play()
        }
    }
    
    /// Плавна зміна гучності фонової музики (апаратний DSP fade без софтверних таймерів)
    func setBGMVolume(_ volume: Float, fadeDuration: TimeInterval = 0) {
        guard let player = bgmPlayer, !isAdActive, !isMuted, bgmVolume > 0.001 else {
            bgmPlayer?.pause()
            return
        }
        let target = volume * bgmVolume
        if fadeDuration > 0.05 {
            player.setVolume(target, fadeDuration: fadeDuration)
        } else {
            player.volume = target
        }
        if !player.isPlaying && isBGMPlayingRequested {
            player.play()
        }
    }
    
    /// Призупинення фонової музики
    func pauseBGM() {
        self.isBGMPlayingRequested = false
        bgmPlayer?.pause()
    }
    
    /// Відновлення фонової музики
    func resumeBGM() {
        guard !isAdActive, !isMuted, bgmVolume > 0.001 else { return }
        self.isBGMPlayingRequested = true
        applyBGMVolume()
    }
    
    /// Оновлення гучності BGM плеєра з урахуванням поточного bgmVolume, isMuted та показу реклами
    func applyBGMVolume(fadeDuration: TimeInterval = 0) {
        guard let player = bgmPlayer else { return }
        if isAdActive || isMuted || bgmVolume <= 0.001 {
            if fadeDuration > 0.05 && player.isPlaying {
                player.setVolume(0.0, fadeDuration: fadeDuration)
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + fadeDuration) { [weak self] in
                    guard let self = self, let player = self.bgmPlayer else { return }
                    if !self.isBGMPlayingRequested {
                        player.pause()
                    }
                }
            } else {
                player.pause()
            }
        } else {
            let base = isLowVolumeActive ? GameAudio.bgmLowVolume : GameAudio.bgmTargetVolume
            let target = base * bgmVolume
            if fadeDuration > 0.05 {
                player.setVolume(target, fadeDuration: fadeDuration)
            } else {
                player.volume = target
            }
            if !player.isPlaying && isBGMPlayingRequested {
                player.play()
            }
        }
    }
    
    /// Зупинка фонової музики з плавним згасанням
    func stopBGM(fadeDuration: TimeInterval = 0) {
        self.isBGMPlayingRequested = false
        guard let player = bgmPlayer, player.isPlaying else { return }
        if fadeDuration > 0.05 {
            player.setVolume(0.0, fadeDuration: fadeDuration)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + fadeDuration) { [weak self] in
                guard let self = self, let player = self.bgmPlayer else { return }
                if !self.isBGMPlayingRequested {
                    player.pause()
                }
            }
        } else {
            player.volume = 0.0
            player.pause()
        }
    }
    
    // MARK: - Керування звуком під час реклами (Ads Lifecycle)
    
    /// Викликається безпосередньо перед відкриттям будь-якої реклами (Rewarded / Interstitial)
    func notifyAdWillPresent() {
        guard !isAdActive else { return }
        isAdActive = true
        pauseBGM()
    }
    
    /// Викликається після закриття реклами (успішно, з помилкою чи скасовано)
    func notifyAdDidDismiss() {
        guard isAdActive else { return }
        isAdActive = false
        
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        
        audioQueue.async { [weak self] in
            self?.ensureEngineRunningInternal()
        }
        resumeBGM()
    }
    
    // MARK: - Загальне перемикання звуку (Master Mute / Unmute)
    
    /// Встановлення стану загального вимкнення звуку
    func setMuted(_ muted: Bool) {
        isMuted = muted
        applySFXVolume()
        if muted {
            pauseBGM()
        } else {
            resumeBGM()
        }
    }
    
    /// Перемикання звуку (Mute / Unmute)
    @discardableResult
    func toggleMute() -> Bool {
        let newMuted = !isMuted
        setMuted(newMuted)
        return newMuted
    }
}
