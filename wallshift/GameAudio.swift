//
//  GameAudio.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 20.10.2026.
//

import AVFoundation
import AudioToolbox
import UIKit

// MARK: - GameAudio
/// Централізований менеджер звуків та музики з нульовою затримкою (0ms latency).
/// Використовує апаратні AudioServices для SFX, що повністю усуває блокування
/// головного потоку рендерингу (VSYNC) та забезпечує стабільні 60-120 FPS.
final class GameAudio {
    static let shared = GameAudio()
    
    static let bgmTargetVolume: Float = 0.72
    
    private var bgmPlayer: AVAudioPlayer?
    private var jumpSoundID: SystemSoundID = 0
    private var coinSoundID: SystemSoundID = 0
    private var gameOverSoundID: SystemSoundID = 0
    private var isSetup = false
    
    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: "WallShiftMuted") }
        set { UserDefaults.standard.set(newValue, forKey: "WallShiftMuted") }
    }
    
    private init() {}
    
    deinit {
        if jumpSoundID != 0 { AudioServicesDisposeSystemSoundID(jumpSoundID) }
        if coinSoundID != 0 { AudioServicesDisposeSystemSoundID(coinSoundID) }
        if gameOverSoundID != 0 { AudioServicesDisposeSystemSoundID(gameOverSoundID) }
    }
    
    /// Одноразова ініціалізація аудіосистеми: низьколатентна сесія та апаратні звуки
    func setupIfNeeded() {
        guard !isSetup else { return }
        isSetup = true
        
        // 1. Налаштовуємо низьколатентну аудіосесію з підтримкою мікшування
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setPreferredIOBufferDuration(0.005)
        try? session.setActive(true)
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        
        // 2. Підготовка апаратних звукових ефектів (AudioServices)
        // Звук стрибка
        if let data = NSDataAsset(name: "player_jump")?.data {
            let url = tempDir.appendingPathComponent("player_jump.mp3")
            if !FileManager.default.fileExists(atPath: url.path) {
                try? data.write(to: url)
            }
            AudioServicesCreateSystemSoundID(url as CFURL, &jumpSoundID)
        }
        
        // Звук підбору монети
        if let data = NSDataAsset(name: "coin_pickup")?.data {
            let url = tempDir.appendingPathComponent("coin_pickup.mp3")
            if !FileManager.default.fileExists(atPath: url.path) {
                try? data.write(to: url)
            }
            AudioServicesCreateSystemSoundID(url as CFURL, &coinSoundID)
        }
        
        // Звук Game Over
        if let data = NSDataAsset(name: "game_over")?.data {
            let url = tempDir.appendingPathComponent("game_over.mp3")
            if !FileManager.default.fileExists(atPath: url.path) {
                try? data.write(to: url)
            }
            AudioServicesCreateSystemSoundID(url as CFURL, &gameOverSoundID)
        }
        
        // 3. Завантаження фонової музики через локальний файл для апаратного стрімінгу
        if let data = NSDataAsset(name: "background_music")?.data {
            let url = tempDir.appendingPathComponent("background_music.mp3")
            if !FileManager.default.fileExists(atPath: url.path) {
                try? data.write(to: url)
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.prepareToPlay()
                self.bgmPlayer = player
            } catch {
                print("[GameAudio] Failed to initialize BGM player: \(error)")
            }
        }
    }
    
    // MARK: - Sound Effects (Zero-Latency Non-Blocking)
    
    /// Відтворення звуку стрибка героя (апаратний виклик CoreAudio без блокування потоку)
    func playJump() {
        guard !isMuted, jumpSoundID != 0 else { return }
        AudioServicesPlaySystemSound(jumpSoundID)
    }
    
    /// Відтворення звуку збору монети (апаратний виклик CoreAudio без блокування потоку)
    func playCoin() {
        guard !isMuted, coinSoundID != 0 else { return }
        AudioServicesPlaySystemSound(coinSoundID)
    }
    
    /// Відтворення звуку програшу
    func playGameOver() {
        guard !isMuted, gameOverSoundID != 0 else { return }
        AudioServicesPlaySystemSound(gameOverSoundID)
    }
    
    // MARK: - Background Music (Hardware Streamed)
    
    /// Запуск або відновлення фонової музики
    func startBGM(lowVolume: Bool = false) {
        guard !isMuted, let player = bgmPlayer else { return }
        let targetVol: Float = lowVolume ? 0.35 : GameAudio.bgmTargetVolume
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
        } else {
            resumeBGM()
        }
        return newMuted
    }
}
