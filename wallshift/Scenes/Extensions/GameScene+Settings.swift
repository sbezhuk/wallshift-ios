//
//  GameScene+Settings.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import SpriteKit

// MARK: - GameScene + Settings Overlay
extension GameScene {
    
    // MARK: - Constants
    private static let trackWidthOffset: CGFloat = 126.0
    private static let trackHeight: CGFloat = 14.0
    
    // MARK: - Show Settings Overlay
    
    /// Відкриття вікна налаштувань звуку
    func showSettingsOverlay() {
        guard settingsNode == nil else { return }
        removeAction(forKey: "menuAutoJump")
        
        let container = SKNode()
        container.name = "settingsContainer"
        container.zPosition = 200
        settingsNode = container
        cameraNode.addChild(container)
        
        // 1. Затемнення фону (tap для виходу)
        let dimBg = SKSpriteNode(
            color: SKColor.black.withAlphaComponent(0.72),
            size: CGSize(width: size.width * 1.5, height: size.height * 1.5)
        )
        dimBg.name = "settingsDimBg"
        dimBg.position = .zero
        dimBg.zPosition = 1
        container.addChild(dimBg)
        
        // 2. Основна плашка-картка
        let cardW: CGFloat = min(340.0, size.width - 24.0)
        let cardH: CGFloat = min(470.0, size.height * 0.76)
        let card = SKSpriteNode(imageNamed: "gui_card_box")
        card.name = "settingsCard"
        card.size = CGSize(width: cardW, height: cardH)
        card.position = .zero
        card.zPosition = 2
        container.addChild(card)
        
        // 3. Заголовок "SETTINGS"
        let bannerW = min(240.0, cardW - 40.0)
        let bannerH = bannerW * (457.0 / 1139.0)
        let banner = SKSpriteNode(imageNamed: currentTheme.guiBannerName)
        banner.name = "settingsBanner"
        banner.size = CGSize(width: bannerW, height: bannerH)
        banner.position = CGPoint(x: 0, y: cardH * 0.44)
        banner.zPosition = 5
        card.addChild(banner)
        
        let titleLabel = SKLabelNode(fontNamed: AppFont.name)
        titleLabel.name = "settingsTitleLabel"
        titleLabel.text = "SETTINGS"
        titleLabel.fontSize = 22.0
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: -bannerH * 0.05)
        titleLabel.zPosition = 6
        banner.addChild(titleLabel)
        
        // 4. Кнопка закриття [X]
        let closeBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        closeBtn.name = "settingsCloseButton"
        closeBtn.size = CGSize(width: 40.0, height: 40.0)
        closeBtn.position = CGPoint(x: (cardW / 2.0) - 26.0, y: (cardH / 2.0) - 26.0)
        closeBtn.zPosition = 10
        card.addChild(closeBtn)
        
        let closeIcon = SKSpriteNode(imageNamed: "gui_icon_close")
        closeIcon.name = "settingsCloseButton"
        closeIcon.size = CGSize(width: 22.0, height: 22.0)
        closeIcon.position = .zero
        closeIcon.zPosition = 2
        closeBtn.addChild(closeIcon)
        
        let rowW = cardW - 36.0
        
        // 5. Секція 1: ALL SOUNDS (Загальне вкл/викл)
        buildMasterSoundSection(in: card, rowW: rowW, cardH: cardH)
        
        // 6. Секція 2: BACKGROUND MUSIC (Фонова музика)
        buildMusicSection(in: card, rowW: rowW, cardH: cardH)
        
        // 7. Секція 3: SOUND EFFECTS (Звуки стрибків, програшу та монет)
        buildSFXSection(in: card, rowW: rowW, cardH: cardH)
        
        // 8. Підказка збереження
        let footerLabel = SKLabelNode(fontNamed: AppFont.name)
        footerLabel.name = "settingsFooterLabel"
        footerLabel.text = "SETTINGS SAVE AUTOMATICALLY"
        footerLabel.fontSize = 11.0
        footerLabel.fontColor = SKColor(white: 0.70, alpha: 0.85)
        footerLabel.verticalAlignmentMode = .center
        footerLabel.position = CGPoint(x: 0, y: -cardH * 0.415)
        footerLabel.zPosition = 5
        card.addChild(footerLabel)
        
        // 9. Оновлюємо стан елементів
        refreshSettingsUI()
        
        // 10. Анімація появи
        container.alpha = 0.0
        card.setScale(0.92)
        container.run(SKAction.fadeIn(withDuration: 0.18))
        card.run(SKAction.scale(to: 1.0, duration: 0.18))
    }
    
    // MARK: - Section Builders
    
    private func buildMasterSoundSection(in card: SKNode, rowW: CGFloat, cardH: CGFloat) {
        let panel = SKShapeNode(rectOf: CGSize(width: rowW, height: 56.0), cornerRadius: 12.0)
        panel.name = "settingsMasterPanel"
        panel.position = CGPoint(x: 0, y: cardH * 0.22)
        panel.fillColor = SKColor(red: 0.10, green: 0.14, blue: 0.22, alpha: 0.80)
        panel.strokeColor = SKColor.white.withAlphaComponent(0.18)
        panel.lineWidth = 1.5
        panel.zPosition = 5
        card.addChild(panel)
        
        let iconName = GameAudio.shared.isMuted ? "gui_icon_audio_off" : "gui_icon_audio_on"
        let icon = SKSpriteNode(imageNamed: iconName)
        icon.name = "settingsMasterIcon"
        icon.size = CGSize(width: 24.0, height: 24.0)
        icon.position = CGPoint(x: -rowW / 2.0 + 26.0, y: 0)
        icon.zPosition = 2
        panel.addChild(icon)
        
        let title = SKLabelNode(fontNamed: AppFont.name)
        title.name = "settingsMasterTitle"
        title.text = "ALL SOUNDS"
        title.fontSize = 17.0
        title.fontColor = .white
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -rowW / 2.0 + 46.0, y: 0)
        title.zPosition = 2
        panel.addChild(title)
        
        let toggleW: CGFloat = 74.0
        let toggleH: CGFloat = 34.0
        let toggleBtn = SKShapeNode(rectOf: CGSize(width: toggleW, height: toggleH), cornerRadius: 9.0)
        toggleBtn.name = "settingsMasterToggle"
        toggleBtn.position = CGPoint(x: rowW / 2.0 - 46.0, y: 0)
        toggleBtn.zPosition = 3
        panel.addChild(toggleBtn)
        
        let toggleLabel = SKLabelNode(fontNamed: AppFont.name)
        toggleLabel.name = "settingsMasterToggleLabel"
        toggleLabel.fontSize = 16.0
        toggleLabel.fontColor = .white
        toggleLabel.verticalAlignmentMode = .center
        toggleLabel.position = .zero
        toggleLabel.zPosition = 4
        toggleBtn.addChild(toggleLabel)
    }
    
    private func buildMusicSection(in card: SKNode, rowW: CGFloat, cardH: CGFloat) {
        let panel = SKShapeNode(rectOf: CGSize(width: rowW, height: 96.0), cornerRadius: 14.0)
        panel.name = "settingsMusicPanel"
        panel.position = CGPoint(x: 0, y: cardH * 0.01)
        panel.fillColor = SKColor(red: 0.10, green: 0.14, blue: 0.22, alpha: 0.80)
        panel.strokeColor = SKColor.white.withAlphaComponent(0.18)
        panel.lineWidth = 1.5
        panel.zPosition = 5
        card.addChild(panel)
        
        // Іконка ноти
        let icon = SKSpriteNode(imageNamed: "gui_icon_music_on")
        icon.name = "settingsMusicIcon"
        icon.size = CGSize(width: 22.0, height: 22.0)
        icon.position = CGPoint(x: -rowW / 2.0 + 26.0, y: 22.0)
        icon.zPosition = 2
        panel.addChild(icon)
        
        // Заголовок
        let title = SKLabelNode(fontNamed: AppFont.name)
        title.name = "settingsMusicTitle"
        title.text = "BACKGROUND MUSIC"
        title.fontSize = 15.0
        title.fontColor = .white
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -rowW / 2.0 + 44.0, y: 22.0)
        title.zPosition = 2
        panel.addChild(title)
        
        // Відсоток гучності
        let percentLabel = SKLabelNode(fontNamed: AppFont.name)
        percentLabel.name = "settingsMusicPercentLabel"
        percentLabel.text = "100%"
        percentLabel.fontSize = 16.0
        percentLabel.fontColor = currentTheme.guiAccentColor
        percentLabel.horizontalAlignmentMode = .right
        percentLabel.verticalAlignmentMode = .center
        percentLabel.position = CGPoint(x: rowW / 2.0 - 18.0, y: 22.0)
        percentLabel.zPosition = 2
        panel.addChild(percentLabel)
        
        // Нижній ряд: [-] ---Слайдер--- [+]
        buildSliderControls(
            in: panel,
            rowW: rowW,
            yOffset: -16.0,
            minusName: "settingsMusicMinus",
            plusName: "settingsMusicPlus",
            trackName: "settingsMusicTrack",
            fillName: "settingsMusicFill",
            knobName: "settingsMusicKnob"
        )
    }
    
    private func buildSFXSection(in card: SKNode, rowW: CGFloat, cardH: CGFloat) {
        let panel = SKShapeNode(rectOf: CGSize(width: rowW, height: 96.0), cornerRadius: 14.0)
        panel.name = "settingsSFXPanel"
        panel.position = CGPoint(x: 0, y: -cardH * 0.23)
        panel.fillColor = SKColor(red: 0.10, green: 0.14, blue: 0.22, alpha: 0.80)
        panel.strokeColor = SKColor.white.withAlphaComponent(0.18)
        panel.lineWidth = 1.5
        panel.zPosition = 5
        card.addChild(panel)
        
        // Іконка звуку
        let icon = SKSpriteNode(imageNamed: "gui_icon_audio_on")
        icon.name = "settingsSFXIcon"
        icon.size = CGSize(width: 22.0, height: 22.0)
        icon.position = CGPoint(x: -rowW / 2.0 + 26.0, y: 22.0)
        icon.zPosition = 2
        panel.addChild(icon)
        
        // Заголовок
        let title = SKLabelNode(fontNamed: AppFont.name)
        title.name = "settingsSFXTitle"
        title.text = "SFX (JUMPS & COINS)"
        title.fontSize = 15.0
        title.fontColor = .white
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -rowW / 2.0 + 44.0, y: 22.0)
        title.zPosition = 2
        panel.addChild(title)
        
        // Відсоток гучності
        let percentLabel = SKLabelNode(fontNamed: AppFont.name)
        percentLabel.name = "settingsSFXPercentLabel"
        percentLabel.text = "100%"
        percentLabel.fontSize = 16.0
        percentLabel.fontColor = currentTheme.guiAccentColor
        percentLabel.horizontalAlignmentMode = .right
        percentLabel.verticalAlignmentMode = .center
        percentLabel.position = CGPoint(x: rowW / 2.0 - 18.0, y: 22.0)
        percentLabel.zPosition = 2
        panel.addChild(percentLabel)
        
        // Нижній ряд: [-] ---Слайдер--- [+]
        buildSliderControls(
            in: panel,
            rowW: rowW,
            yOffset: -16.0,
            minusName: "settingsSFXMinus",
            plusName: "settingsSFXPlus",
            trackName: "settingsSFXTrack",
            fillName: "settingsSFXFill",
            knobName: "settingsSFXKnob"
        )
    }
    
    private func buildSliderControls(
        in parent: SKNode,
        rowW: CGFloat,
        yOffset: CGFloat,
        minusName: String,
        plusName: String,
        trackName: String,
        fillName: String,
        knobName: String
    ) {
        let btnSize: CGFloat = 34.0
        let trackWidth = rowW - GameScene.trackWidthOffset
        let trackH = GameScene.trackHeight
        
        // Кнопка [-]
        let minusBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        minusBtn.name = minusName
        minusBtn.size = CGSize(width: btnSize, height: btnSize)
        minusBtn.position = CGPoint(x: -rowW / 2.0 + 26.0, y: yOffset)
        minusBtn.zPosition = 3
        parent.addChild(minusBtn)
        
        let minusLabel = SKLabelNode(fontNamed: AppFont.name)
        minusLabel.name = minusName
        minusLabel.text = "-"
        minusLabel.fontSize = 24.0
        minusLabel.fontColor = .white
        minusLabel.verticalAlignmentMode = .center
        minusLabel.horizontalAlignmentMode = .center
        minusLabel.position = CGPoint(x: 0, y: 1.0)
        minusLabel.zPosition = 4
        minusBtn.addChild(minusLabel)
        
        // Кнопка [+]
        let plusBtn = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        plusBtn.name = plusName
        plusBtn.size = CGSize(width: btnSize, height: btnSize)
        plusBtn.position = CGPoint(x: rowW / 2.0 - 26.0, y: yOffset)
        plusBtn.zPosition = 3
        parent.addChild(plusBtn)
        
        let plusLabel = SKLabelNode(fontNamed: AppFont.name)
        plusLabel.name = plusName
        plusLabel.text = "+"
        plusLabel.fontSize = 22.0
        plusLabel.fontColor = .white
        plusLabel.verticalAlignmentMode = .center
        plusLabel.horizontalAlignmentMode = .center
        plusLabel.position = CGPoint(x: 0, y: 1.0)
        plusLabel.zPosition = 4
        plusBtn.addChild(plusLabel)
        
        // Базова лінія треку (Track)
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackH), cornerRadius: trackH / 2.0)
        track.name = trackName
        track.position = CGPoint(x: 0, y: yOffset)
        track.fillColor = SKColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 0.95)
        track.strokeColor = SKColor.white.withAlphaComponent(0.25)
        track.lineWidth = 1.2
        track.zPosition = 2
        parent.addChild(track)
        
        // Заповнений індикатор (Fill)
        let fill = SKShapeNode()
        fill.name = fillName
        fill.fillColor = currentTheme.guiAccentColor
        fill.strokeColor = .clear
        fill.zPosition = 3
        parent.addChild(fill)
        
        // Повзунок (Knob)
        let knob = SKSpriteNode(imageNamed: currentTheme.guiCircleBtnName)
        knob.name = knobName
        knob.size = CGSize(width: 26.0, height: 26.0)
        knob.zPosition = 4
        parent.addChild(knob)
        
        let knobCenter = SKShapeNode(circleOfRadius: 4.0)
        knobCenter.name = knobName
        knobCenter.fillColor = .white
        knobCenter.strokeColor = .clear
        knobCenter.zPosition = 5
        knob.addChild(knobCenter)
    }
    
    // MARK: - UI Refresh
    
    /// Оновлення всіх візуальних станів налаштувань відповідно до GameAudio
    func refreshSettingsUI() {
        guard let card = settingsNode?.childNode(withName: "settingsCard") else { return }
        
        let isMuted = GameAudio.shared.isMuted
        let bgmVol = GameAudio.shared.bgmVolume
        let sfxVol = GameAudio.shared.sfxVolume
        let cardW: CGFloat = card.frame.width
        let rowW = cardW - 36.0
        let trackWidth = rowW - GameScene.trackWidthOffset
        let trackH = GameScene.trackHeight
        
        // 1. Оновлення Master секції
        if let masterPanel = card.childNode(withName: "settingsMasterPanel") {
            if let icon = masterPanel.childNode(withName: "settingsMasterIcon") as? SKSpriteNode {
                icon.texture = SKTexture(imageNamed: isMuted ? "gui_icon_audio_off" : "gui_icon_audio_on")
            }
            if let toggleBtn = masterPanel.childNode(withName: "settingsMasterToggle") as? SKShapeNode {
                if isMuted {
                    toggleBtn.fillColor = SKColor(red: 0.72, green: 0.22, blue: 0.20, alpha: 1.0)
                    toggleBtn.strokeColor = SKColor(red: 0.90, green: 0.38, blue: 0.35, alpha: 1.0)
                } else {
                    toggleBtn.fillColor = SKColor(red: 0.16, green: 0.65, blue: 0.32, alpha: 1.0)
                    toggleBtn.strokeColor = SKColor(red: 0.30, green: 0.85, blue: 0.50, alpha: 1.0)
                }
                if let label = toggleBtn.childNode(withName: "settingsMasterToggleLabel") as? SKLabelNode {
                    label.text = isMuted ? "OFF" : "ON"
                }
            }
        }
        
        // 2. Оновлення Music секції
        if let musicPanel = card.childNode(withName: "settingsMusicPanel") {
            musicPanel.alpha = isMuted ? 0.52 : 1.0
            
            if let icon = musicPanel.childNode(withName: "settingsMusicIcon") as? SKSpriteNode {
                let musicIconName = (isMuted || bgmVol <= 0.001) ? "gui_icon_music_off" : "gui_icon_music_on"
                icon.texture = SKTexture(imageNamed: musicIconName)
            }
            
            if let label = musicPanel.childNode(withName: "settingsMusicPercentLabel") as? SKLabelNode {
                if isMuted {
                    label.text = "MUTED"
                    label.fontColor = .lightGray
                } else {
                    let percent = Int((bgmVol * 100).rounded())
                    label.text = "\(percent)%"
                    label.fontColor = currentTheme.guiAccentColor
                }
            }
            
            updateSliderVisual(
                panel: musicPanel,
                trackName: "settingsMusicTrack",
                fillName: "settingsMusicFill",
                knobName: "settingsMusicKnob",
                volume: bgmVol,
                trackWidth: trackWidth,
                trackH: trackH,
                yOffset: -16.0
            )
        }
        
        // 3. Оновлення SFX секції
        if let sfxPanel = card.childNode(withName: "settingsSFXPanel") {
            sfxPanel.alpha = isMuted ? 0.52 : 1.0
            
            if let icon = sfxPanel.childNode(withName: "settingsSFXIcon") as? SKSpriteNode {
                let sfxIconName = (isMuted || sfxVol <= 0.001) ? "gui_icon_audio_off" : "gui_icon_audio_on"
                icon.texture = SKTexture(imageNamed: sfxIconName)
            }
            
            if let label = sfxPanel.childNode(withName: "settingsSFXPercentLabel") as? SKLabelNode {
                if isMuted {
                    label.text = "MUTED"
                    label.fontColor = .lightGray
                } else {
                    let percent = Int((sfxVol * 100).rounded())
                    label.text = "\(percent)%"
                    label.fontColor = currentTheme.guiAccentColor
                }
            }
            
            updateSliderVisual(
                panel: sfxPanel,
                trackName: "settingsSFXTrack",
                fillName: "settingsSFXFill",
                knobName: "settingsSFXKnob",
                volume: sfxVol,
                trackWidth: trackWidth,
                trackH: trackH,
                yOffset: -16.0
            )
        }
        
        // Синхронізуємо іконку звуку у головному меню
        updateSoundMenuIcon()
    }
    
    private func updateSliderVisual(
        panel: SKNode,
        trackName: String,
        fillName: String,
        knobName: String,
        volume: Float,
        trackWidth: CGFloat,
        trackH: CGFloat,
        yOffset: CGFloat
    ) {
        let clampedVol = CGFloat(max(0.0, min(1.0, volume)))
        let trackLeft = -trackWidth / 2.0
        let knobX = trackLeft + trackWidth * clampedVol
        
        // Knob
        if let knob = panel.childNode(withName: knobName) {
            knob.position = CGPoint(x: knobX, y: yOffset)
        }
        
        // Fill
        if let fill = panel.childNode(withName: fillName) as? SKShapeNode {
            let fillW = max(trackH, trackWidth * clampedVol)
            let fillRect = CGRect(x: trackLeft, y: yOffset - trackH / 2.0, width: fillW, height: trackH)
            let path = CGPath(roundedRect: fillRect, cornerWidth: trackH / 2.0, cornerHeight: trackH / 2.0, transform: nil)
            fill.path = path
            fill.isHidden = clampedVol <= 0.001
        }
    }
    
    // MARK: - Dismiss Settings Overlay
    
    /// Закриття вікна налаштувань з плавною анімацією
    func dismissSettingsOverlay() {
        guard let container = settingsNode else { return }
        
        container.run(SKAction.fadeOut(withDuration: 0.15))
        if let card = container.childNode(withName: "settingsCard") {
            card.run(SKAction.scale(to: 0.90, duration: 0.15))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self = self else { return }
            container.removeFromParent()
            self.settingsNode = nil
            self.isDraggingMusicSlider = false
            self.isDraggingSFXSlider = false
            
            self.updateSoundMenuIcon()
            if self.gameState == .menu {
                self.scheduleNextMenuAutoJump(delay: 2.0)
            }
        }
    }
    
    // MARK: - Touch Interaction
    
    /// Обробка тапу у відкритому вікні Settings
    func handleSettingsTouchesBegan(touch: UITouch, locInCamera: CGPoint) {
        let touchedNodes = cameraNode.nodes(at: locInCamera)
        
        for node in touchedNodes {
            let nodeName = node.name ?? node.parent?.name ?? ""
            
            // Закриття вікна
            if nodeName == "settingsCloseButton" || nodeName == "settingsDimBg" {
                playJumpSound()
                dismissSettingsOverlay()
                return
            }
            
            // Головний перемикач звуку
            if nodeName == "settingsMasterToggle" || nodeName == "settingsMasterIcon" {
                let isMutedNow = GameAudio.shared.toggleMute()
                if !isMutedNow {
                    GameAudio.shared.playCoin()
                }
                refreshSettingsUI()
                return
            }
            
            // Музика: мінус
            if nodeName == "settingsMusicMinus" {
                let current = GameAudio.shared.bgmVolume
                let updated = max(0.0, current - 0.10)
                GameAudio.shared.bgmVolume = (updated * 10).rounded() / 10.0
                refreshSettingsUI()
                return
            }
            
            // Музика: плюс
            if nodeName == "settingsMusicPlus" {
                let current = GameAudio.shared.bgmVolume
                let updated = min(1.0, current + 0.10)
                GameAudio.shared.bgmVolume = (updated * 10).rounded() / 10.0
                refreshSettingsUI()
                return
            }
            
            // SFX: мінус
            if nodeName == "settingsSFXMinus" {
                let current = GameAudio.shared.sfxVolume
                let updated = max(0.0, current - 0.10)
                GameAudio.shared.sfxVolume = (updated * 10).rounded() / 10.0
                refreshSettingsUI()
                GameAudio.shared.playCoin()
                return
            }
            
            // SFX: плюс
            if nodeName == "settingsSFXPlus" {
                let current = GameAudio.shared.sfxVolume
                let updated = min(1.0, current + 0.10)
                GameAudio.shared.sfxVolume = (updated * 10).rounded() / 10.0
                refreshSettingsUI()
                GameAudio.shared.playCoin()
                return
            }
            
            // Початок протягування повзунка музики
            if nodeName == "settingsMusicTrack" || nodeName == "settingsMusicKnob" || nodeName == "settingsMusicFill" {
                isDraggingMusicSlider = true
                applyMusicTouch(locInCamera: locInCamera)
                return
            }
            
            // Початок протягування повзунка SFX
            if nodeName == "settingsSFXTrack" || nodeName == "settingsSFXKnob" || nodeName == "settingsSFXFill" {
                isDraggingSFXSlider = true
                applySFXTouch(locInCamera: locInCamera)
                return
            }
        }
    }
    
    /// Обробка руху пальця по слайдеру
    func handleSettingsTouchesMoved(touch: UITouch, locInCamera: CGPoint) {
        if isDraggingMusicSlider {
            applyMusicTouch(locInCamera: locInCamera)
        } else if isDraggingSFXSlider {
            applySFXTouch(locInCamera: locInCamera)
        }
    }
    
    /// Завершення взаємодії зі слайдером
    func handleSettingsTouchesEnded(touch: UITouch, locInCamera: CGPoint) {
        if isDraggingSFXSlider {
            GameAudio.shared.playCoin()
        }
        isDraggingMusicSlider = false
        isDraggingSFXSlider = false
    }
    
    // MARK: - Touch Helpers for Sliders
    
    private func applyMusicTouch(locInCamera: CGPoint) {
        guard let card = settingsNode?.childNode(withName: "settingsCard"),
              let musicPanel = card.childNode(withName: "settingsMusicPanel") else { return }
        
        let cardW: CGFloat = card.frame.width
        let rowW = cardW - 36.0
        let trackWidth = rowW - GameScene.trackWidthOffset
        let locInPanel = musicPanel.convert(locInCamera, from: cameraNode)
        
        let fraction = max(0.0, min(1.0, (locInPanel.x + trackWidth / 2.0) / trackWidth))
        let snapped = Float((fraction * 20.0).rounded() / 20.0) // крок 5%
        
        GameAudio.shared.bgmVolume = snapped
        refreshSettingsUI()
    }
    
    private func applySFXTouch(locInCamera: CGPoint) {
        guard let card = settingsNode?.childNode(withName: "settingsCard"),
              let sfxPanel = card.childNode(withName: "settingsSFXPanel") else { return }
        
        let cardW: CGFloat = card.frame.width
        let rowW = cardW - 36.0
        let trackWidth = rowW - GameScene.trackWidthOffset
        let locInPanel = sfxPanel.convert(locInCamera, from: cameraNode)
        
        let fraction = max(0.0, min(1.0, (locInPanel.x + trackWidth / 2.0) / trackWidth))
        let snapped = Float((fraction * 20.0).rounded() / 20.0) // крок 5%
        
        GameAudio.shared.sfxVolume = snapped
        refreshSettingsUI()
    }
}
