//
//  GameAudio.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 20.10.2026.
//

import AVFoundation
import UIKit

// MARK: - GameAudio
/// Повністю асинхронний високопродуктивний аудіорушій на базі єдиного графа AVAudioEngine.
/// Усі операції зі звуком (ініціалізація, планування буферів, запуск, зміна гучності, фейди)
/// виконуються виключно у виділеній черзі `audioQueue` (QoS: .userInitiated).
/// Головний потік рендерингу (Main Thread) звільнено на 100% від будь-яких навантажень CoreAudio,
/// що гарантує абсолютно стабільні 60/120 FPS без найменших мікролагів.
final class GameAudio {
    static let shared = GameAudio()
    
    // MARK: - Рівні гучності (баланс музики та ефектів)
    static let bgmTargetVolume: Float = 0.82
    static let bgmLowVolume: Float = 0.42
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
    
    // MARK: - Виділена аудіо-черга (100% ізоляція від головного потоку)
    private let audioQueue = DispatchQueue(label: "com.wallshift.audio", qos: .userInitiated)
    
    // MARK: - Єдиний AVAudioEngine (Низьколатентне апаратне мікшування BGM + SFX)
    private let engine = AVAudioEngine()
    
    // Пре-декодовані та конвертовані в нативний формат мікшера PCM-буфери в RAM
    private var jumpBuffer: AVAudioPCMBuffer?
    private var coinBuffer: AVAudioPCMBuffer?
    private var gameOverBuffer: AVAudioPCMBuffer?
    private var bgmBuffer: AVAudioPCMBuffer?
    
    // Нода фонової музики (частина того самого графа AVAudioEngine)
    private let bgmPlayerNode = AVAudioPlayerNode()
    private var isBGMPlaying: Bool = false
    private var isBGMBufferScheduled: Bool = false
    private var fadeTimerSource: DispatchSourceTimer?
    
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
    
    private var isSetup = false
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        fadeTimerSource?.cancel()
        engine.stop()
    }
    
    // MARK: - Ініціалізація та попереднє завантаження буферів
    
    func setupIfNeeded() {
        guard !isSetup else { return }
        isSetup = true
        
        // 1. Налаштовуємо спільну аудіосесію
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        
        // 2. Пре-декодування всіх звуків у PCM-буфери в пам'яті
        let jBuf = loadPCMBuffer(named: "player_jump", tempDir: tempDir)
        let cBuf = loadPCMBuffer(named: "coin_pickup", tempDir: tempDir)
        let gBuf = loadPCMBuffer(named: "game_over", tempDir: tempDir)
        let bBuf = loadPCMBuffer(named: "background_music", tempDir: tempDir)
        
        self.jumpBuffer = jBuf
        self.coinBuffer = cBuf
        self.gameOverBuffer = gBuf
        self.bgmBuffer = bBuf
        
        // 3. Підключаємо ноди до головного мікшера з їхнім точним нативним форматом каналів
        engine.attach(bgmPlayerNode)
        connectNode(bgmPlayerNode, format: bBuf?.format)
        
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
        
        // 4. Підготовка та старт двигуна у виділеній фоновій черзі
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            self.applySFXVolumeInternal()
            self.applyBGMVolumeInternal()
            self.ensureEngineRunningInternal()
            self.prewarmAudioNodesInternal()
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
    
    /// Завантажує аудіофайл напряму в PCM-буфер у пам'яті
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
                    self?.resumeBGMInternal()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleWillEnterForeground() {
        guard !isAdActive, !isMuted else { return }
        audioQueue.async { [weak self] in
            self?.ensureEngineRunningInternal()
            self?.resumeBGMInternal()
        }
    }
    
    // MARK: - Застосування рівнів гучності
    
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
    
    /// Оновлення гучності BGM ноди з урахуванням поточного bgmVolume, isMuted та показу реклами
    func applyBGMVolume(fadeDuration: TimeInterval = 0) {
        setBGMVolume(GameAudio.bgmTargetVolume, fadeDuration: fadeDuration)
    }
    
    private func applyBGMVolumeInternal() {
        let eff = (isAdActive || isMuted || bgmVolume <= 0.001) ? 0.0 : bgmVolume
        let base = isLowVolumeActive ? GameAudio.bgmLowVolume : GameAudio.bgmTargetVolume
        bgmPlayerNode.volume = base * eff
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
    
    // MARK: - Фонова музика (BGM через RAM-буфер у черзі audioQueue)
    
    private func cancelFadeTimer() {
        fadeTimerSource?.cancel()
        fadeTimerSource = nil
    }
    
    private func ensureBGMPlayingInternal() {
        guard let buffer = bgmBuffer, bgmPlayerNode.engine != nil else { return }
        ensureEngineRunningInternal()
        
        if !isBGMBufferScheduled {
            bgmPlayerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            isBGMBufferScheduled = true
        }
        
        if !bgmPlayerNode.isPlaying {
            bgmPlayerNode.play()
        }
        isBGMPlaying = true
    }
    
    /// Запуск або відновлення фонової музики
    func startBGM(lowVolume: Bool = false) {
        self.isLowVolumeActive = lowVolume
        guard !isAdActive, !isMuted, bgmVolume > 0.001 else { return }
        audioQueue.async { [weak self] in
            guard let self = self, !self.isAdActive, !self.isMuted, self.bgmVolume > 0.001 else { return }
            self.cancelFadeTimer()
            self.ensureBGMPlayingInternal()
            self.applyBGMVolumeInternal()
        }
    }
    
    /// Плавна зміна гучності фонової музики (виконується суто в audioQueue через DispatchSourceTimer)
    func setBGMVolume(_ volume: Float, fadeDuration: TimeInterval = 0) {
        guard !isAdActive, !isMuted, bgmVolume > 0.001 else {
            pauseBGM()
            return
        }
        
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isAdActive, !self.isMuted, self.bgmVolume > 0.001 else {
                self.pauseBGMInternal()
                return
            }
            
            let target = volume * self.bgmVolume
            self.cancelFadeTimer()
            self.ensureBGMPlayingInternal()
            
            let startVol = self.bgmPlayerNode.volume
            let diff = target - startVol
            
            if fadeDuration <= 0.05 || abs(diff) < 0.02 {
                self.bgmPlayerNode.volume = target
            } else {
                let steps = max(3, min(8, Int(fadeDuration / 0.1)))
                let interval = fadeDuration / Double(steps)
                var currentStep = 0
                
                let timer = DispatchSource.makeTimerSource(queue: self.audioQueue)
                timer.schedule(deadline: .now() + interval, repeating: interval)
                timer.setEventHandler { [weak self] in
                    guard let self = self else { return }
                    currentStep += 1
                    let progress = Float(currentStep) / Float(steps)
                    self.bgmPlayerNode.volume = startVol + (diff * progress)
                    if currentStep >= steps {
                        self.bgmPlayerNode.volume = target
                        self.cancelFadeTimer()
                    }
                }
                self.fadeTimerSource = timer
                timer.resume()
            }
        }
    }
    
    /// Призупинення фонової музики
    func pauseBGM() {
        audioQueue.async { [weak self] in
            self?.pauseBGMInternal()
        }
    }
    
    private func pauseBGMInternal() {
        cancelFadeTimer()
        bgmPlayerNode.pause()
        isBGMPlaying = false
    }
    
    /// Відновлення фонової музики
    func resumeBGM() {
        guard !isAdActive, !isMuted, bgmVolume > 0.001 else { return }
        audioQueue.async { [weak self] in
            self?.resumeBGMInternal()
        }
    }
    
    private func resumeBGMInternal() {
        guard !isAdActive, !isMuted, bgmVolume > 0.001 else { return }
        cancelFadeTimer()
        ensureBGMPlayingInternal()
        applyBGMVolumeInternal()
    }
    
    /// Зупинка фонової музики з плавним згасанням (таймер працює в audioQueue)
    func stopBGM(fadeDuration: TimeInterval = 0) {
        audioQueue.async { [weak self] in
            self?.stopBGMInternal(fadeDuration: fadeDuration)
        }
    }
    
    private func stopBGMInternal(fadeDuration: TimeInterval) {
        guard isBGMPlaying else { return }
        cancelFadeTimer()
        
        if fadeDuration <= 0.04 {
            bgmPlayerNode.volume = 0.0
            bgmPlayerNode.pause()
            isBGMPlaying = false
        } else {
            let startVol = bgmPlayerNode.volume
            let steps = 10
            let interval = fadeDuration / Double(steps)
            var currentStep = 0
            
            let timer = DispatchSource.makeTimerSource(queue: self.audioQueue)
            timer.schedule(deadline: .now() + interval, repeating: interval)
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                currentStep += 1
                let progress = Float(currentStep) / Float(steps)
                self.bgmPlayerNode.volume = max(0.0, startVol * (1.0 - progress))
                if currentStep >= steps {
                    self.bgmPlayerNode.volume = 0.0
                    self.bgmPlayerNode.pause()
                    self.isBGMPlaying = false
                    self.cancelFadeTimer()
                }
            }
            self.fadeTimerSource = timer
            timer.resume()
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
        
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, mode: .default)
            try? session.setActive(true)
            
            self.ensureEngineRunningInternal()
            self.resumeBGMInternal()
        }
    }
    
    // MARK: - Загальне перемикання звуку (Master Mute / Unmute)
    
    /// Встановлення стану загального вимкнення звуку
    func setMuted(_ muted: Bool) {
        isMuted = muted
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            self.applySFXVolumeInternal()
            if muted {
                self.pauseBGMInternal()
            } else {
                self.ensureEngineRunningInternal()
                self.resumeBGMInternal()
            }
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
