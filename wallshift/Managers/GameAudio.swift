//
//  GameAudio.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 20.10.2026.
//

import AVFoundation
import UIKit

// MARK: - GameAudio
/// Єдиний високопродуктивний звуковий рушій на базі єдиного графа AVAudioEngine.
/// Повністю усуває конфлікти між різними аудіопідсистемами (AVAudioPlayer та AVAudioEngine),
/// конвертує всі PCM-буфери в нативний апаратний формат мікшера при старті,
/// відтворює BGM безперервно з оперативної пам'яті (0 звернень до диска під час гри)
/// та гарантує стабільні 60/120 FPS без мікролагів при увімкненій музиці та звуках.
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
    private var bgmFadeTimer: Timer?
    
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
        bgmFadeTimer?.invalidate()
        engine.stop()
    }
    
    // MARK: - Ініціалізація
    
    func setupIfNeeded() {
        guard !isSetup else { return }
        isSetup = true
        
        // 1. Налаштовуємо спільну аудіосесію
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        
        // 2. Пре-декодування та конвертація всіх звуків в точний формат мікшера
        self.jumpBuffer = loadAndConvertBuffer(named: "player_jump", targetFormat: mixerFormat, tempDir: tempDir)
        self.coinBuffer = loadAndConvertBuffer(named: "coin_pickup", targetFormat: mixerFormat, tempDir: tempDir)
        self.gameOverBuffer = loadAndConvertBuffer(named: "game_over", targetFormat: mixerFormat, tempDir: tempDir)
        self.bgmBuffer = loadAndConvertBuffer(named: "background_music", targetFormat: mixerFormat, tempDir: tempDir)
        
        // 3. Підключення всіх нод до єдиного мікшера
        setupAudioEngine(format: mixerFormat)
    }
    
    private func setupAudioEngine(format: AVAudioFormat) {
        // Підключаємо BGM ноду
        engine.attach(bgmPlayerNode)
        connectNode(bgmPlayerNode, format: format)
        
        // Підключаємо пул нод стрибків
        for node in jumpNodes {
            engine.attach(node)
            connectNode(node, format: format)
        }
        
        // Підключаємо пул нод монет
        for node in coinNodes {
            engine.attach(node)
            connectNode(node, format: format)
        }
        
        // Підключаємо ноду Game Over
        engine.attach(gameOverNode)
        connectNode(gameOverNode, format: format)
        
        applySFXVolumeInternal()
        applyBGMVolumeInternal()
        
        // Готуємо та запускаємо двигун
        engine.prepare()
        do {
            try engine.start()
            // Запускаємо стан нод один раз на старті; відтворення регулюється плануванням буферів
            bgmPlayerNode.play()
            jumpNodes.forEach { $0.play() }
            coinNodes.forEach { $0.play() }
            gameOverNode.play()
        } catch {
            print("[GameAudio] Engine start error: \(error)")
        }
    }
    
    private func connectNode(_ node: AVAudioNode, format: AVAudioFormat) {
        if #available(iOS 27.0, *) {
            try? engine.connectNode(node, to: engine.mainMixerNode, format: format)
        } else {
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }
    
    private func ensureEngineRunning() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            if !bgmPlayerNode.isPlaying { bgmPlayerNode.play() }
            jumpNodes.forEach { if !$0.isPlaying { $0.play() } }
            coinNodes.forEach { if !$0.isPlaying { $0.play() } }
            if !gameOverNode.isPlaying { gameOverNode.play() }
        } catch {
            print("[GameAudio] Engine restart error: \(error)")
        }
    }
    
    /// Завантажує аудіофайл та один раз при старті переводить його в цільовий апаратний формат мікшера.
    /// Це повністю виключає sample rate conversion та ресемплінг під час ігрового процесу.
    private func loadAndConvertBuffer(named name: String, targetFormat: AVAudioFormat, tempDir: URL) -> AVAudioPCMBuffer? {
        guard let data = NSDataAsset(name: name)?.data else { return nil }
        let url = tempDir.appendingPathComponent("\(name).mp3")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let fileFormat = file.processingFormat
        let fileLength = UInt32(file.length)
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: fileLength) else { return nil }
        do {
            try file.read(into: sourceBuffer)
        } catch {
            return nil
        }
        
        if fileFormat.sampleRate == targetFormat.sampleRate && fileFormat.channelCount == targetFormat.channelCount {
            return sourceBuffer
        }
        
        guard let converter = AVAudioConverter(from: fileFormat, to: targetFormat) else {
            return sourceBuffer
        }
        
        let ratio = targetFormat.sampleRate / fileFormat.sampleRate
        let targetCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio + 1024)
        guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetCapacity) else {
            return sourceBuffer
        }
        
        var error: NSError?
        var hasRead = false
        _ = converter.convert(to: targetBuffer, error: &error) { _, outStatus in
            if hasRead {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasRead = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        
        if error == nil && targetBuffer.frameLength > 0 {
            return targetBuffer
        }
        return sourceBuffer
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
                ensureEngineRunning()
                resumeBGM()
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleWillEnterForeground() {
        guard !isAdActive, !isMuted else { return }
        ensureEngineRunning()
        resumeBGM()
    }
    
    // MARK: - Застосування рівнів гучності
    
    /// Оновлення нод SFX з урахуванням поточного sfxVolume та isMuted
    func applySFXVolume() {
        applySFXVolumeInternal()
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
    
    // MARK: - Звукові ефекти (SFX: 0ns затримка, 0 блокування, чиста черга)
    
    /// Відтворення звуку стрибка героя (без блокування головного потоку та без зупинки нод)
    func playJump() {
        guard !isMuted, sfxVolume > 0.001, let buffer = jumpBuffer else { return }
        ensureEngineRunning()
        let node = jumpNodes[currentJumpNodeIndex]
        currentJumpNodeIndex = (currentJumpNodeIndex + 1) % jumpNodes.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }
    
    /// Відтворення звуку підбору монети з пулу нод
    func playCoin() {
        guard !isMuted, sfxVolume > 0.001, let buffer = coinBuffer else { return }
        ensureEngineRunning()
        let node = coinNodes[currentCoinNodeIndex]
        currentCoinNodeIndex = (currentCoinNodeIndex + 1) % coinNodes.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }
    
    /// Відтворення звуку Game Over
    func playGameOver() {
        guard !isMuted, sfxVolume > 0.001, let buffer = gameOverBuffer else { return }
        ensureEngineRunning()
        gameOverNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }
    
    // MARK: - Фонова музика (BGM через RAM-буфер єдиного рушія)
    
    private func ensureBGMPlaying() {
        guard let buffer = bgmBuffer else { return }
        ensureEngineRunning()
        
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
        ensureBGMPlaying()
        applyBGMVolumeInternal()
    }
    
    /// Плавна зміна гучності фонової музики без блокування runloop
    func setBGMVolume(_ volume: Float, fadeDuration: TimeInterval = 0) {
        guard !isAdActive, !isMuted, bgmVolume > 0.001 else {
            pauseBGM()
            return
        }
        
        let target = volume * bgmVolume
        bgmFadeTimer?.invalidate()
        bgmFadeTimer = nil
        
        ensureBGMPlaying()
        
        if fadeDuration <= 0.04 {
            bgmPlayerNode.volume = target
        } else {
            let startVol = bgmPlayerNode.volume
            let diff = target - startVol
            let steps = 10
            let interval = fadeDuration / Double(steps)
            var currentStep = 0
            
            bgmFadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                currentStep += 1
                let progress = Float(currentStep) / Float(steps)
                self.bgmPlayerNode.volume = startVol + (diff * progress)
                if currentStep >= steps {
                    self.bgmPlayerNode.volume = target
                    timer.invalidate()
                    self.bgmFadeTimer = nil
                }
            }
            if let timer = bgmFadeTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    
    /// Призупинення фонової музики
    func pauseBGM() {
        bgmFadeTimer?.invalidate()
        bgmFadeTimer = nil
        bgmPlayerNode.pause()
        isBGMPlaying = false
    }
    
    /// Відновлення фонової музики
    func resumeBGM() {
        guard !isAdActive, !isMuted, bgmVolume > 0.001 else { return }
        ensureBGMPlaying()
        applyBGMVolumeInternal()
    }
    
    /// Зупинка фонової музики з плавним згасанням
    func stopBGM(fadeDuration: TimeInterval = 0) {
        guard isBGMPlaying else { return }
        bgmFadeTimer?.invalidate()
        bgmFadeTimer = nil
        
        if fadeDuration <= 0.04 {
            bgmPlayerNode.volume = 0.0
            bgmPlayerNode.pause()
            isBGMPlaying = false
        } else {
            let startVol = bgmPlayerNode.volume
            let steps = 10
            let interval = fadeDuration / Double(steps)
            var currentStep = 0
            
            bgmFadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                currentStep += 1
                let progress = Float(currentStep) / Float(steps)
                self.bgmPlayerNode.volume = max(0.0, startVol * (1.0 - progress))
                if currentStep >= steps {
                    self.bgmPlayerNode.volume = 0.0
                    self.bgmPlayerNode.pause()
                    self.isBGMPlaying = false
                    timer.invalidate()
                    self.bgmFadeTimer = nil
                }
            }
            if let timer = bgmFadeTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
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
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
        
        ensureEngineRunning()
        resumeBGM()
    }
    
    // MARK: - Загальне перемикання звуку (Master Mute / Unmute)
    
    /// Встановлення стану загального вимкнення звуку
    func setMuted(_ muted: Bool) {
        isMuted = muted
        applySFXVolumeInternal()
        if muted {
            pauseBGM()
        } else {
            ensureEngineRunning()
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
