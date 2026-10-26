//
//  GameScene+Track.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import SpriteKit

// MARK: - GameScene + Procedural Track Generation
extension GameScene {
    func randomAbyssGapTileCount() -> Int {
        let s = CGFloat(max(0, score))
        let roll = Double.random(in: 0...1)
        if s < 180.0 {
            // 0...180 очок: переважно 2 тайли (96 pt), іноді 3 тайли
            return (roll < 0.80) ? 2 : 3
        } else if s < 450.0 {
            // 180...450 очок: плавний перехід між 2, 3 та 4 тайлами
            return (roll < 0.40) ? 2 : ((roll < 0.85) ? 3 : 4)
        } else if s < 750.0 {
            // 450...750 очок: 3, 4 або 5 тайлів
            return (roll < 0.25) ? 3 : ((roll < 0.75) ? 4 : 5)
        } else if s < 1000.0 {
            // 750...1000 очок: 4-5 тайлів, рідко 6
            return (roll < 0.35) ? 4 : ((roll < 0.85) ? 5 : 6)
        } else if s < 2500.0 {
            // 1000...2500 очок: переважно 5 та 6 тайлів
            return (roll < 0.15) ? 4 : ((roll < 0.65) ? 5 : 6)
        } else if s < 4000.0 {
            // 2500...4000 очок: 5 та 6 тайлів, з'являються екстремальні 7-тайлові розриви (10%)
            return (roll < 0.45) ? 5 : ((roll < 0.90) ? 6 : 7)
        } else {
            // 4000+ очок (нескінченне наростання): максимальний паркур — 6 та 7 тайлів займають понад 70%
            let highRoll = min(0.35, 0.15 + Double(s - 4000.0) / 10000.0)
            return (roll < 0.30) ? 5 : ((roll < 1.0 - highRoll) ? 6 : 7)
        }
    }
    
    /// Нескінченне скорочення дистанції між прірвами (довжини твердих платформ):
    /// Платформи поступово стискаються: ~115 pt (1000-2000), ~103 pt (3000), ~94 pt (4000), ~86 pt (5000), ~80 pt (6000+),
    /// створюючи дедалі щільніший ритм стрибків без втрати фізичної прохідності.
    func randomAbyssDistance() -> CGFloat {
        let s = CGFloat(max(0, score))
        let baseMean = 115.0 + 445.0 * exp(-s / 260.0)
        let post2000 = max(0.0, s - 2000.0)
        // Плавне нескінченне стиснення до мінімально можливої безпечної довжини опори (~76 pt)
        let endlessReduction = (22.0 * (1.0 - exp(-post2000 / 2200.0))) + (post2000 * 0.004)
        let meanDistance = max(76.0, baseMean - endlessReduction)
        let spread = meanDistance * 0.13
        return CGFloat.random(in: (meanDistance - spread)...(meanDistance + spread))
    }
    
    /// Динамічний розрахунок дистанції до появи наступного серця (додаткового життя).
    /// Баланс складності:
    /// - При 1 житті (критичний стан): ~3,400...5,000 pt (~135...200 очок), дає гравцю чесний шанс вижити при майстерній грі.
    /// - При 2 життях: ~4,600...6,600 pt (~185...265 очок).
    /// - При 3 життях (повне здоров'я): ~7,200...10,000 pt (~290...400 очок), щоб не перевантажувати екран зайвими серцями.
    /// - При високому рахунку (score >= 1000): дистанція адаптується під темп 1500-2000 очок.
    /// - Після 2000 очок: плавне нескінченне розрідження сердець на 3000, 4000, 5000+ очок.
    func randomHeartDistance() -> CGFloat {
        let s = CGFloat(max(0, score))
        
        let minBase: CGFloat
        let maxBase: CGFloat
        
        if currentLives <= 1 {
            minBase = 3400.0
            maxBase = 5000.0
        } else if currentLives == 2 {
            minBase = 4600.0
            maxBase = 6600.0
        } else {
            minBase = 7200.0
            maxBase = 10000.0
        }
        
        // Коригуючий множник для високих очок (досягає піку вже на 1000 очках):
        let highProgress = max(0.0, min(1.0, (s - 450.0) / 550.0))
        var difficultyFactor = 1.0 - (highProgress * 0.25)
        
        // Нескінченне поступове розрідження сердець після 2000 очок (3000, 4000, 5000+):
        if s > 2000.0 {
            let post2000 = (s - 2000.0) / 1000.0
            let endlessHeartRarity = min(0.55, 0.12 + (post2000 * 0.08))
            difficultyFactor += endlessHeartRarity
        }
        
        return CGFloat.random(in: minBase...maxBase) * difficultyFactor
    }
    


    // MARK: - Procedural Track with Seamless Abysses, Hearts & Decorations
    
    func setupProceduralTrack() {
        // Стартуємо генерацію від Y = 0
        currentLeftY = Config.tileSize / 2.0
        currentRightY = Config.tileSize / 2.0
        startCameraY = cameraNode.position.y
        lastCleanupCameraY = startCameraY
        leftAbyssNodes.removeAll()
        rightAbyssNodes.removeAll()
        
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
        
        // Ворожі моби: простий моб (патрульний) з'являється плавно на 60-90 очках,
        // а стрільці розблоковуються помітно пізніше (210-260 очок)
        trackMobNodes.removeAll()
        activeFireArrows.forEach { $0.removeFromParent() }
        activeFireArrows.removeAll()
        consecutivePatrollers = 0
        firstMobScoreThreshold = Int.random(in: 25...40)
        firstShooterScoreThreshold = Int.random(in: 60...80)
        nextMobY = startCameraY + (CGFloat(firstMobScoreThreshold) * Config.distancePerScorePoint)
        
        // Золотисті монети: перша група монет з'являється вже на початку підйому (~250 pt)
        trackCoinNodes.removeAll()
        nextCoinPatternY = player.position.y + 250.0
        
        // Початкові декорації біля стартової позиції гравця (природний антураж)
        setupInitialDecorations()
        
        // Будуємо стіни наперед (глибокий буфер у 2.5 висоти екрана для усунення спавн-навантаження на старті)
        buildTrack(upTo: cameraNode.position.y + (size.height * 2.5))
    }
    
    /// Початкові декорації біля стартової позиції гравця (природний антураж без табличок)
    func setupInitialDecorations() {
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
    
    /// Перевіряє, чи є заданий вертикальний діапазон стіни повністю суцільним (без прірв по всій висоті)
    func isWallRangeSolid(onLeftWall: Bool, minY: CGFloat, maxY: CGFloat, safetyMargin: CGFloat = 60.0, checkPlanned: Bool = true) -> Bool {
        let bottom = min(minY, maxY)
        let top = max(minY, maxY)
        let abyssNodes = onLeftWall ? leftAbyssNodes : rightAbyssNodes
        
        for abyss in abyssNodes {
            let abyssHalfHeight = (abyss.gapHeight / 2.0) + Config.tileSize
            let abyssMinY = abyss.position.y - abyssHalfHeight - safetyMargin
            let abyssMaxY = abyss.position.y + abyssHalfHeight + safetyMargin
            // Швидка O(1) перевірка перетину двох відрізків [bottom, top] та [abyssMinY, abyssMaxY]
            if max(bottom, abyssMinY) <= min(top, abyssMaxY) {
                return false
            }
        }
        
        // Також перевіряємо заплановану наступну прірву, якщо увімкнено та вона на цій стіні
        if checkPlanned && nextAbyssIsOnLeft == onLeftWall {
            let plannedMinY = nextAbyssY - safetyMargin
            let plannedMaxY = nextAbyssY + (Config.tileSize * 6.0) + safetyMargin
            if max(bottom, plannedMinY) <= min(top, plannedMaxY) {
                return false
            }
        }
        
        return true
    }
    
    /// Перевіряє, чи є на стіні безпечна суцільна ділянка скелі без прірв
    func isWallSolid(onLeftWall: Bool, atY yPos: CGFloat, safetyMargin: CGFloat = 80.0) -> Bool {
        return isWallRangeSolid(onLeftWall: onLeftWall, minY: yPos, maxY: yPos, safetyMargin: safetyMargin)
    }
    
    /// Спроба посадити фонове дерево тільки на суцільну скелю (гарантовано не над прірвою)
    func trySpawnBackgroundTree(candidateY: CGFloat) {
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
    func spawnBackgroundTree(onLeftWall: Bool, atY: CGFloat, textureIndex: Int? = nil, scale: CGFloat? = nil) {
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
            
            let offset = (rootHeight / 2.0) - 14.0
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
        
        // 2. Прадавня статуя, портал або кришталева колона / розсип / склеп — горизонтально закріплені на скелі (основа в скелі, вершина в бік каньйону)
        if texName.contains("statue") || texName.contains("portal") || texName.contains("pillar") || texName.contains("pile") || texName.contains("crypt") || texName.contains("coffin") {
            let landmarkHeight: CGFloat = (texName.contains("statue") || texName.contains("pillar") || texName.contains("crypt")) ? CGFloat.random(in: 74...86) : CGFloat.random(in: 70...80)
            let landmarkWidth = landmarkHeight * aspect
            let landmark = SKSpriteNode(texture: tex, size: CGSize(width: landmarkWidth, height: landmarkHeight))
            landmark.zPosition = -5
            landmark.alpha = CGFloat.random(in: 0.88...0.96)
            
            let offset = (landmarkHeight / 2.0) - 12.0
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
        
        let rootOffset = (treeSize.height / 2.0) - 16.0
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
    
    /// Спавнить попереджувальну табличку на безпечній відстані перед прірвою (на суцільній стіні нижче уступу)
    func spawnAbyssWarningSign(onLeftWall: Bool, atY: CGFloat) {
        let texture = signpostTextures.randomElement() ?? signpostTextures[0]
        let sign = SKSpriteNode(texture: texture, size: CGSize(width: 28, height: 32))
        sign.zPosition = 3.2
        let signOffset: CGFloat = (32.0 / 2.0) - 3.0
        
        // Розміщуємо табличку завчасно перед прірвою (на 1.25 тайла нижче обриву, на суцільній стіні)
        let warningY = atY - (Config.tileSize * 1.25)
        
        if onLeftWall {
            sign.zRotation = -.pi / 2.0
            sign.xScale = -1.0
            sign.position = CGPoint(x: Config.wallWidth + signOffset, y: warningY)
            lastLeftDecoY = warningY
        } else {
            sign.zRotation = .pi / 2.0
            sign.xScale = 1.0
            sign.position = CGPoint(x: size.width - Config.wallWidth - signOffset, y: warningY)
            lastRightDecoY = warningY
        }
        
        addChild(sign)
        decorationNodes.append(sign)
    }
    
    /// Процедурний спавн природних декорацій на стіні (кущики, каміння, пеньки, факели, ліани, паркани — у горизонтальній орієнтації перпендикулярно до скелі)
    func maybeSpawnWallDecoration(onLeftWall: Bool, yPos: CGFloat) {
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
            protrusionOffset = (h / 2.0) - 2.5
        } else if roll < 48 {
            // Осінній кущик (Bush 01): горизонтальний ріст зі скелі в коридор
            let s = CGFloat.random(in: 24...28)
            sprite = SKSpriteNode(texture: bushTexture, size: CGSize(width: s, height: s))
            protrusionOffset = (s / 2.0) - 2.5
        } else if roll < 82 {
            // Скельний виступ / камінь (Stone 01 / Stone 02)
            let tex = stoneTextures[Int.random(in: 0..<stoneTextures.count)]
            let s = CGFloat.random(in: 22...26)
            sprite = SKSpriteNode(texture: tex, size: CGSize(width: s, height: s))
            protrusionOffset = (s / 2.0) - 2.5
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
    func scheduleNextAbyss(justSpawnedOnLeft: Bool) {
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
        var plannedY = max(currentLeftY, currentRightY) + randomAbyssDistance()
        
        // Баланс та візуальна безпека: забороняємо планувати прірву в зоні патрулювання будь-яких мобів
        // (щоб вони ніколи не ходили по краю чи в повітрі) та навпроти мобів-стрільців (для безпечного ухилення).
        for mob in trackMobNodes {
            if mob.isOnLeftWall == pickLeft {
                // На тій самій стіні, де планується прірва:
                // суворо заборонено прірву в зоні патрулювання моба та з надійним відступом 70 pt
                let forbiddenMin = mob.pointAY - 70.0
                let forbiddenMax = mob.pointBY + 70.0
                if plannedY >= forbiddenMin && plannedY <= forbiddenMax {
                    plannedY = forbiddenMax + 20.0
                }
            } else if mob.mobType == .shooter {
                // На протилежній стіні від стрільця: не повинно бути прірви навпроти зони ухилення
                let forbiddenMin = mob.pointAY - 200.0
                let forbiddenMax = mob.pointBY + 260.0
                if plannedY >= forbiddenMin && plannedY <= forbiddenMax {
                    plannedY = forbiddenMax + 10.0
                }
            }
        }
        
        nextAbyssY = plannedY
    }
    
    /// Перевіряє, чи дозволено будувати прірву на вказаній висоті,
    /// щоб не створити прірву під ногами будь-якого моба (виключає ходіння по повітрю чи краю обриву)
    /// та не створити прірву навпроти активного моба-стрільця
    func canBuildAbyss(onLeftWall: Bool, atY: CGFloat) -> Bool {
        let maxAbyssTop = atY + (Config.tileSize * 10.0) // розрив до 7 тайлів + 2 тайли уступів + запас
        let edgeBuffer: CGFloat = 65.0 // надійний відступ від краю розриву до моба
        
        for mob in trackMobNodes {
            if mob.isOnLeftWall == onLeftWall {
                // Власна стіна моба: прірва та її уступи не повинні перетинатися з патрулем моба
                let mobMin = mob.pointAY - edgeBuffer
                let mobMax = mob.pointBY + edgeBuffer
                if max(atY - edgeBuffer, mobMin) <= min(maxAbyssTop, mobMax) {
                    return false
                }
            } else if mob.mobType == .shooter {
                // Протилежна стіна від моба-стрільця: суворо заборонено прірву в усій зоні ухилення та приземлення
                let forbiddenMin = mob.pointAY - 200.0
                let forbiddenMax = mob.pointBY + 260.0
                if max(atY, forbiddenMin) <= min(maxAbyssTop, forbiddenMax) {
                    return false
                }
            }
        }
        return true
    }
    
    /// Відкладає наступну прірву вище зони активних мобів (щоб прірва не спавнилася на їхній дорозі)
    func deferNextAbyssPastMobs(onLeftWall: Bool) {
        var minSafeY = nextAbyssY
        for mob in trackMobNodes {
            if mob.isOnLeftWall == onLeftWall {
                let safeY = mob.pointBY + 85.0
                if safeY > minSafeY {
                    minSafeY = safeY
                }
            } else if mob.mobType == .shooter {
                let safeY = mob.pointBY + 270.0
                if safeY > minSafeY {
                    minSafeY = safeY
                }
            }
        }
        nextAbyssY = max(nextAbyssY, minSafeY)
    }
    
    /// Покроково будує обидві стіни у сітці без швів, інтегруючи прірви, серця та декорації
    func buildTrack(upTo targetY: CGFloat) {
        let tileSize = Config.tileSize
        
        // Будуємо обидві стіни синхронно вгору
        while currentLeftY < targetY || currentRightY < targetY {
            
            // 1. Генерація ЛІВОЇ стіни
            if currentLeftY < targetY {
                if nextAbyssIsOnLeft && currentLeftY >= nextAbyssY {
                    if canBuildAbyss(onLeftWall: true, atY: currentLeftY) {
                        // Спавнимо прірву різного розміру (залежно від рівня складності / очок)
                        let gapTiles = randomAbyssGapTileCount()
                        buildAbyssGap(onLeftWall: true, gapTileCount: gapTiles)
                        
                        // Плануємо наступну прірву процедурно (випадкова стіна з чергуванням/повторенням)
                        scheduleNextAbyss(justSpawnedOnLeft: true)
                    } else {
                        // Якщо поруч моб або навпроти стрілець, будуємо суцільний тайл і відкладаємо прірву вище
                        let tile = createWallTile(texture: wallTexture, yPos: currentLeftY, isLeft: true)
                        addChild(tile)
                        leftTrackNodes.append(tile)
                        maybeSpawnWallDecoration(onLeftWall: true, yPos: currentLeftY)
                        currentLeftY += tileSize
                        deferNextAbyssPastMobs(onLeftWall: true)
                    }
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
                    if canBuildAbyss(onLeftWall: false, atY: currentRightY) {
                        // Спавнимо прірву різного розміру на ПРАВІЙ стіні
                        let gapTiles = randomAbyssGapTileCount()
                        buildAbyssGap(onLeftWall: false, gapTileCount: gapTiles)
                        
                        // Плануємо наступну прірву процедурно (випадкова стіна з чергуванням/повторенням)
                        scheduleNextAbyss(justSpawnedOnLeft: false)
                    } else {
                        // Якщо поруч моб або навпроти стрілець, будуємо суцільний тайл і відкладаємо прірву вище
                        let tile = createWallTile(texture: wallTexture, yPos: currentRightY, isLeft: false)
                        addChild(tile)
                        rightTrackNodes.append(tile)
                        maybeSpawnWallDecoration(onLeftWall: false, yPos: currentRightY)
                        currentRightY += tileSize
                        deferNextAbyssPastMobs(onLeftWall: false)
                    }
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
    func buildAbyssGap(onLeftWall: Bool, gapTileCount: Int) {
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
            leftAbyssNodes.append(gapObstacle)
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
            rightAbyssNodes.append(gapObstacle)
            currentRightY += gapHeight
            
            // Крок В: Верхній уступ обриву стіни (Ground 04) на правій стіні
            let upperCliff = createWallTile(texture: cliffUpperTexture, yPos: currentRightY, isLeft: false)
            addChild(upperCliff)
            rightTrackNodes.append(upperCliff)
            currentRightY += tileSize
        }
    }
    
    /// Створює тайл стіни із точною орієнтацією та позицією
    func createWallTile(texture: SKTexture, yPos: CGFloat, isLeft: Bool) -> SKSpriteNode {
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
        
        return tile
    }
    
    /// Створює додаткове життя на карті тільки в безпечному місці (гарантовано не над прірвою)
    func spawnHeartItem(atY: CGFloat) {
        let isLeftSafe = isWallRangeSolid(onLeftWall: true, minY: atY - 20.0, maxY: atY + 20.0, safetyMargin: 28.0)
        let isRightSafe = isWallRangeSolid(onLeftWall: false, minY: atY - 20.0, maxY: atY + 20.0, safetyMargin: 28.0)
        
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
            // На обох стінах у цій точці прірва — відкладаємо появу серця вище на 100 pt
            nextHeartY = atY + 100.0
            return
        }
        
        let heart = HeartItemNode(textureName: currentTheme.heartTextureName)
        heart.position = CGPoint(x: heartX, y: atY)
        addChild(heart)
        trackHeartNodes.append(heart)
    }
    
    /// Інтервал між спавнами ворожих мобів:
    /// Неперервне наростання щільності ворогів після 2000 очок (3000, 4000, 5000+):
    /// Дистанція поступово скорочується: ~160 pt (2000), ~145 pt (3000), ~133 pt (4000), ~124 pt (5000) тощо.
    func randomMobDistance() -> CGFloat {
        let s = CGFloat(max(0, score))
        let baseMean = 160.0 + 640.0 * exp(-s / 240.0)
        let post2000 = max(0.0, s - 2000.0)
        let endlessReduction = (30.0 * (1.0 - exp(-post2000 / 2500.0))) + (post2000 * 0.005)
        let meanDistance = max(112.0, baseMean - endlessReduction)
        let spread = meanDistance * 0.14
        return CGFloat.random(in: (meanDistance - spread)...(meanDistance + spread))
    }
    
    /// Перевірка умов безпеки та чесності спавну моба:
    /// 1. Стіна, де рухається моб, суцільна на ділянці патруля з надійним буфером від країв прірв (щоб моб не ходив по повітрю).
    /// 2. Для мобів-стрільців: на протилежній стіні ГАРАНТОВАНО відсутня збудована прірва в зоні зустрічі.
    ///    При спавні стрільця наступна запланована прірва на протилежній стіні автоматично
    ///    відсувається далеко вперед, гарантуючи вільну стіну для безпечного ухилення.
    /// 3. Відсутність накладання на інших активних мобів.
    func canSpawnMob(onLeftWall: Bool, startY: CGFloat, endY: CGFloat, mobType: MobNode.MobType = .patroller) -> Bool {
        let wallEdgeBuffer: CGFloat = 60.0 // Надійний відступ від обривів, щоб моб завжди твердо стояв на скелі
        
        if mobType == .shooter {
            // 1. Власна стіна моба-стрільця суцільна на ділянці патруля з надійним відступом від прірв
            guard isWallRangeSolid(onLeftWall: onLeftWall, minY: startY - 20.0, maxY: endY + 20.0, safetyMargin: wallEdgeBuffer, checkPlanned: false) else {
                return false
            }
            
            // 2. На протилежній стіні навпроти стрільця та в зоні наближення не повинно бути вже збудованої прірви
            guard isWallRangeSolid(onLeftWall: !onLeftWall, minY: startY - 100.0, maxY: endY + 40.0, safetyMargin: 35.0, checkPlanned: false) else {
                return false
            }
            
            // 3. Дистанція до інших мобів:
            for mob in trackMobNodes {
                if mob.isOnLeftWall == onLeftWall {
                    let sameWallBuffer: CGFloat = 100.0
                    if startY <= (mob.pointBY + sameWallBuffer) && endY >= (mob.pointAY - sameWallBuffer) {
                        return false
                    }
                } else {
                    // На протилежній стіні не повинно бути мобів навпроти або надто близько спереду
                    let oppMin = mob.pointAY - 240.0
                    let oppMax = mob.pointBY + 140.0
                    if startY <= oppMax && endY >= oppMin {
                        return false
                    }
                }
            }
            return true
        } else {
            // 1. Власна стіна звичайного патрульного повністю суцільна з гарантованим відступом від краю прірви
            guard isWallRangeSolid(onLeftWall: onLeftWall, minY: startY, maxY: endY, safetyMargin: wallEdgeBuffer, checkPlanned: false) else {
                return false
            }
            
            // 2. Протилежна стіна має тверду поверхню навпроти зони контакту
            guard isWallRangeSolid(onLeftWall: !onLeftWall, minY: startY - 20.0, maxY: endY + 30.0, safetyMargin: 30.0, checkPlanned: false) else {
                return false
            }
            
            // 3. Дистанція до інших мобів
            for mob in trackMobNodes {
                if mob.isOnLeftWall == onLeftWall {
                    let sameWallBuffer: CGFloat = 90.0
                    if startY <= (mob.pointBY + sameWallBuffer) && endY >= (mob.pointAY - sameWallBuffer) {
                        return false
                    }
                } else {
                    if mob.mobType == .shooter {
                        let oppMin = mob.pointAY - 240.0
                        let oppMax = mob.pointBY + 140.0
                        if startY <= oppMax && endY >= oppMin {
                            return false
                        }
                    } else {
                        let buffer: CGFloat = 50.0
                        let mobMin = mob.pointAY - buffer
                        let mobMax = mob.pointBY + buffer
                        if startY <= mobMax && endY >= mobMin {
                            return false
                        }
                    }
                }
            }
            return true
        }
    }
    
    /// Спроба процедурного спавну моба на основі поточної висоти каньйону
    func trySpawnMob(candidateY: CGFloat) {
        // Плавна адаптація патрулювання без дискретних сходинок у стилі Subway Surfers:
        // довжина і швидкість мобів змінюються плавно, досягаючи спортивного максимуму вже до 1000 очок,
        // а після 2000 очок патрульні отримують додатковий елітний бонус швидкості
        let patrolProgress = min(1.0, CGFloat(max(0, score)) / 500.0)
        let maxPatrol: CGFloat = 120.0 - (patrolProgress * 55.0) // 120 -> 65 pt
        let minPatrol: CGFloat = 50.0 - (patrolProgress * 15.0)  // 50 -> 35 pt
        let patrolDistance = CGFloat.random(in: minPatrol...maxPatrol)
        let basePatrolSpeed = CGFloat.random(in: 60.0...85.0) + (patrolProgress * 65.0)
        // Нескінченне наростання швидкості патрульних після 2000 очок (кожна 1000 очок робить мобів швидшими):
        let post2000Score = max(0.0, CGFloat(score - 2000))
        let endlessSpeedBonus = (60.0 * (1.0 - exp(-post2000Score / 3000.0))) + (post2000Score * 0.015)
        let patrolSpeed = basePatrolSpeed + endlessSpeedBonus
        let endY = candidateY + patrolDistance
        
        // Випадковий вибір стіни для патрулювання
        let preferredLeft = Bool.random()
        var targetSide: Bool?
        var finalEndY = endY
        
        // Збалансована поява мобів-стрільців:
        // 1. Прості моби з'являються першими (на розминці).
        // 2. Моби-стрільці з'являються після початкової розминки (score >= firstShooterScoreThreshold ~60-80).
        // 3. Шанс стрільця плавно зростає від 25% до 50%, після 1000 очок сягає 55-60%,
        //    а після 2000 очок неперервно зростає: 70% на 3000, 76% на 4000, до 82% на 5000+.
        let shooterChance: Double
        if score < firstShooterScoreThreshold {
            shooterChance = 0.0
        } else if consecutivePatrollers < 1 && score < 250 {
            shooterChance = 0.0
        } else if score >= 2000 {
            let post2000 = Double(score - 2000)
            let endlessRatio = (0.16 * (1.0 - exp(-post2000 / 2500.0))) + (post2000 * 0.000015)
            shooterChance = min(0.82, 0.60 + endlessRatio)
        } else if score >= 1000 {
            let highProgress = min(1.0, Double(score - 1000) / 400.0)
            shooterChance = 0.50 + (highProgress * 0.10)
        } else {
            let progress = min(1.0, Double(score - firstShooterScoreThreshold) / 300.0)
            shooterChance = 0.25 + (progress * 0.25)
        }
        
        let wantsShooter = (Double.random(in: 0...1) < shooterChance)
        var actualMobType: MobNode.MobType = wantsShooter ? .shooter : .patroller
        
        if wantsShooter {
            // Спочатку намагаємося розмістити моба-стрільця з дотриманням усіх гарантій безпечного ухилення
            if canSpawnMob(onLeftWall: preferredLeft, startY: candidateY, endY: endY, mobType: .shooter) {
                targetSide = preferredLeft
                finalEndY = endY
                actualMobType = .shooter
            } else if canSpawnMob(onLeftWall: !preferredLeft, startY: candidateY, endY: endY, mobType: .shooter) {
                targetSide = !preferredLeft
                finalEndY = endY
                actualMobType = .shooter
            } else {
                let compactEndY = candidateY + 40.0
                if canSpawnMob(onLeftWall: preferredLeft, startY: candidateY, endY: compactEndY, mobType: .shooter) {
                    targetSide = preferredLeft
                    finalEndY = compactEndY
                    actualMobType = .shooter
                } else if canSpawnMob(onLeftWall: !preferredLeft, startY: candidateY, endY: compactEndY, mobType: .shooter) {
                    targetSide = !preferredLeft
                    finalEndY = compactEndY
                    actualMobType = .shooter
                }
            }
        }
        
        // Якщо стрілець не планувався або не вміщується через прірви/мобів на протилежній стіні,
        // перевіряємо розміщення звичайного патрульного, щоб не переривати динаміку гри
        if targetSide == nil {
            actualMobType = .patroller
            if canSpawnMob(onLeftWall: preferredLeft, startY: candidateY, endY: endY, mobType: .patroller) {
                targetSide = preferredLeft
                finalEndY = endY
            } else if canSpawnMob(onLeftWall: !preferredLeft, startY: candidateY, endY: endY, mobType: .patroller) {
                targetSide = !preferredLeft
                finalEndY = endY
            } else {
                let compactEndY = candidateY + 40.0
                if canSpawnMob(onLeftWall: preferredLeft, startY: candidateY, endY: compactEndY, mobType: .patroller) {
                    targetSide = preferredLeft
                    finalEndY = compactEndY
                } else if canSpawnMob(onLeftWall: !preferredLeft, startY: candidateY, endY: compactEndY, mobType: .patroller) {
                    targetSide = !preferredLeft
                    finalEndY = compactEndY
                } else {
                    targetSide = nil
                }
            }
        }
        
        if let onLeft = targetSide {
            if actualMobType == .shooter {
                consecutivePatrollers = 0
                // Баланс: гарантуємо, що прірва на протилежній стіні відсунута далеко вперед
                if nextAbyssIsOnLeft == !onLeft {
                    nextAbyssY = max(nextAbyssY, finalEndY + 250.0)
                } else {
                    nextAbyssY = max(nextAbyssY, finalEndY + 130.0)
                }
            } else {
                consecutivePatrollers += 1
                // Гарантуємо, що наступна запланована прірва на стіні патрульного не з'явиться під його ногами
                if nextAbyssIsOnLeft == onLeft {
                    nextAbyssY = max(nextAbyssY, finalEndY + 85.0)
                }
            }
            
            let wallX = onLeft ? (leftWallInnerX + MobNode.Constants.footOffset) : (rightWallInnerX - MobNode.Constants.footOffset)
            let mobType = actualMobType
            let activeTextures = (mobType == .shooter) ? cachedShooterTextures : cachedPatrollerTextures
            
            let mob = MobNode(
                mobType: mobType,
                isOnLeftWall: onLeft,
                wallX: wallX,
                pointAY: candidateY,
                pointBY: finalEndY,
                patrolSpeed: patrolSpeed,
                customTextures: activeTextures,
                projectileType: currentTheme.projectileType
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
            nextMobY = max(candidateY + 50.0, currentLeftY + 30.0)
        }
    }
    
    /// Створення та додавання у сцену снаряду (вогняна або водяна стріла), випущеного мобом-стрільцем
    func spawnFireArrow(from startPos: CGPoint, towards targetPos: CGPoint, projectileType: ProjectileType = .fire) {
        guard !isGameOver, !isPlayerFalling else { return }
        // Швидкість польоту снаряду динамічно адаптується під швидкість руху гри,
        // щоб на високих швидкостях стріли залишалися блискавичними та спортивними
        let arrowSpeed = max(250.0, currentUpwardSpeed * 0.90)
        let arrow = FireArrowNode(from: startPos, towards: targetPos, projectileType: projectileType, speed: arrowSpeed)
        addChild(arrow)
        activeFireArrows.append(arrow)
    }
    
    /// Процедурна генерація патернів золотистих монет на карті з суворою перевіркою безпеки (гарантовано не над прірвою):
    /// - 60% шанс: вертикальна доріжка з 3-4 монет уздовж однієї зі стін (тільки на повністю суцільній ділянці)
    /// - 40% шанс: дуга з 5 монет між стінами каньйону для збору в стрибку (ОБИДВІ стіни мають бути суцільними)
    func spawnCoinPattern(atY: CGFloat) {
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
    func spawnWallCoinLine(onLeft: Bool, startY: CGFloat, count: Int) {
        let coinX = onLeft ? playerLeftX : playerRightX
        for i in 0..<count {
            let coin = CoinNode()
            coin.position = CGPoint(x: coinX, y: startY + CGFloat(i) * 36.0)
            addChild(coin)
            trackCoinNodes.append(coin)
        }
    }
    
    /// Видаляє тайли та розриви, які залишилися далеко внизу за екраном (з розумним тротлінгом для стабільних 60-120 FPS)
    func cleanupPassedTrack(force: Bool = false) {
        let currentCamY = cameraNode.position.y
        if !force && (currentCamY - lastCleanupCameraY) < 40.0 {
            return
        }
        lastCleanupCameraY = currentCamY
        
        let screenBottom = currentCamY - (size.height / 2.0) - 150.0
        
        // Видалення зі стін (масиви впорядковані по Y за зростанням, швидке пакетне видалення O(1))
        let removeLeftCount = leftTrackNodes.prefix(while: { $0.position.y < screenBottom }).count
        if removeLeftCount > 0 {
            for i in 0..<removeLeftCount {
                leftTrackNodes[i].removeFromParent()
            }
            leftTrackNodes.removeFirst(removeLeftCount)
        }
        
        let removeRightCount = rightTrackNodes.prefix(while: { $0.position.y < screenBottom }).count
        if removeRightCount > 0 {
            for i in 0..<removeRightCount {
                rightTrackNodes[i].removeFromParent()
            }
            rightTrackNodes.removeFirst(removeRightCount)
        }
        
        let removeDecoCount = decorationNodes.prefix(while: { $0.position.y < screenBottom }).count
        if removeDecoCount > 0 {
            for i in 0..<removeDecoCount {
                decorationNodes[i].removeFromParent()
            }
            decorationNodes.removeFirst(removeDecoCount)
        }
        
        leftAbyssNodes.removeAll { node in
            if node.position.y < screenBottom || node.parent == nil {
                node.removeFromParent()
                return true
            }
            return false
        }
        rightAbyssNodes.removeAll { node in
            if node.position.y < screenBottom || node.parent == nil {
                node.removeFromParent()
                return true
            }
            return false
        }
        
        trackHeartNodes.removeAll { node in
            if node.position.y < screenBottom || node.parent == nil {
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
                if arrow.parent != nil {
                    AchievementManager.shared.trackArrowDodged()
                }
                arrow.removeFromParent()
                return true
            }
            return false
        }
        
        trackCoinNodes.removeAll { coin in
            if coin.position.y < screenBottom || coin.parent == nil {
                coin.removeFromParent()
                return true
            }
            return false
        }
    }
    

}
