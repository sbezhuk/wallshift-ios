//
//  GameScene+Physics.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import SpriteKit

// MARK: - GameScene + Physics Contact Delegate
extension GameScene: SKPhysicsContactDelegate {
    // MARK: - Physics Contact Delegate
    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing, !isGameOver, !isPlayerFalling else { return }
        
        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        // 1. Потрапляння у прірву
        if mask == (PhysicsCategory.player | PhysicsCategory.abyss) {
            // Гравець у стрибку/польоті летить над прірвою і не може в неї впасти.
            // Також прірва на протилежній стіні не повинна вражати героя, поки він біжить або приземляється.
            guard !player.isJumping else { return }
            let abyssNode = (contact.bodyA.categoryBitMask == PhysicsCategory.abyss ? contact.bodyA.node : contact.bodyB.node) as? AbyssObstacleNode
            guard let abyss = abyssNode, abyss.isOnLeftWall == player.isOnLeftWall else { return }
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
                // При прямому зіткненні або падінні на голову моба це зараховується як удар гравця (-1 життя)
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
    func handleAbyssHit(abyss: AbyssObstacleNode?) {
        guard !isGameOver, !isPlayerFalling else { return }
        
        let now = CACurrentMediaTime()
        guard now - lastAbyssHitTime > 0.45 else { return }
        lastAbyssHitTime = now
        
        currentLives -= 1
        tookDamageThisRun = true
        fellIntoAbyssThisRun = true
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
    func recoverFromAbyss(abyss: AbyssObstacleNode?) {
        hasBufferedJump = false
        // Визначаємо стіну з прірвою та безпечну протилежну стіну
        let wallWithAbyssIsLeft = abyss?.isOnLeftWall ?? player.isOnLeftWall
        let safeWallIsLeft = !wallWithAbyssIsLeft
        let safeTargetX = safeWallIsLeft ? playerLeftX : playerRightX
        
        // Плавний акробатичний стрибок-відскок на протилежну гарантовано суцільну стіну
        player.rebound(to: safeTargetX, onLeftWall: safeWallIsLeft, duration: 0.22) { [weak self] in
            self?.hasBufferedJump = false
        }
        
        // Вмикаємо 3 секунди невразливості з морганням
        player.startInvulnerability(duration: 3.0)
    }
    
    /// Обробка підбору додаткового життя
    func handleHeartCollect(heart: HeartItemNode) {
        if currentLives < GameScene.maxLives {
            heart.collect()
            currentLives += 1
            AchievementManager.shared.trackHeartCollected()
            updateHUD()
            playHeartPickupEffect(at: heart.position)
        } else {
            // У гравця вже є всі 3 життя — 4-е життя додати не можна, серце залишається на карті
            heart.pulseMaxLivesHint()
        }
    }
    
    /// Миттєвий запуск рубінового цілющого спрею з попередньо виділеного пулу (нуль алокацій)
    func playHeartPickupEffect(at position: CGPoint) {
        if let node = heartSprayPool.first(where: { !$0.inUse }) {
            node.trigger(at: position)
        } else if let oldest = heartSprayPool.first {
            oldest.trigger(at: position)
        }
    }
    
    // MARK: - Lives & Mob Interaction
    
    /// Обробка потрапляння снаряду моба-стрільця в героя (як на стіні, так і в повітрі під час стрибка)
    func handleArrowHit(arrow: FireArrowNode) {
        guard !player.isInvulnerable, !isGameOver, !isPlayerFalling else { return }
        
        arrow.explodeAndRemove()
        currentLives -= 1
        tookDamageThisRun = true
        updateHUD()
        
        if currentLives > 0 {
            player.startInvulnerability(duration: 3.0)
        } else {
            triggerMobDefeat(reason: "Hit by projectile")
        }
    }
    
    /// Обробка зіткнення героя з ворожим мобом
    func handleMobHit(mob: MobNode?) {
        guard !player.isInvulnerable, !isGameOver, !isPlayerFalling else { return }
        
        currentLives -= 1
        tookDamageThisRun = true
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
    func triggerMobDefeat(reason: String) {
        guard !isPlayerFalling, !isGameOver else { return }
        hasBufferedJump = false
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
    func handleCoinCollect(coin: CoinNode) {
        coin.collect()
        coinsCollected += 1
        totalCoins += 1
        
        // Звуковий ефект підбору монети
        playCoinSound()
        
        // Оновлюємо лічильник монет у HUD
        coinsLabel.text = coinsCollected.formattedWithSeparator
        
        // Пружний сплеск іконки монети в HUD (використовуємо кешований SKAction)
        hudCoinIcon?.removeAction(forKey: "coinPulse")
        hudCoinIcon?.run(GameScene.coinIconPulseAction, withKey: "coinPulse")
        
        // Спливаючий золотистий індикатор +1 над монетою
        playCoinPickupEffect(at: coin.position)
        
        // Оновлення досягнень зі збору монет
        AchievementManager.shared.trackRunProgress(
            score: score,
            runJumps: runJumpsCount,
            runCoins: coinsCollected,
            tookDamageThisRun: tookDamageThisRun,
            fellIntoAbyssThisRun: fellIntoAbyssThisRun,
            usedReviveThisRun: hasUsedAdRevive
        )
    }
    
    /// Миттєвий запуск золотистого спрею мікро-частинок з попередньо виділеного пулу (нуль алокацій)
    func playCoinPickupEffect(at position: CGPoint) {
        if let node = coinSprayPool.first(where: { !$0.inUse }) {
            node.trigger(at: position)
        } else if let oldest = coinSprayPool.first {
            oldest.trigger(at: position)
        }
    }
    

}
