//
//  AbyssObstacleNode.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit

// MARK: - AbyssObstacleNode
/// Вузол прірви (розриву стіни), що розміщується безпосередньо в розриві доріжки
final class AbyssObstacleNode: SKNode {
    
    let isOnLeftWall: Bool
    let gapHeight: CGFloat
    
    init(isOnLeftWall: Bool, wallWidth: CGFloat, gapHeight: CGFloat) {
        self.isOnLeftWall = isOnLeftWall
        self.gapHeight = gapHeight
        super.init()
        
        name = "AbyssObstacleNode"
        zPosition = 1
        
        setupVisuals(wallWidth: wallWidth)
        setupPhysics(wallWidth: wallWidth)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupVisuals(wallWidth: CGFloat) {
        // Розрив стіни повністю відкритий: крізь нього безперервно видно мальовничий фоновий ліс (Layer 00).
    }
    
    private func setupPhysics(wallWidth: CGFloat) {
        // Хітбокс для реєстрації падіння гравця в прірву.
        // Зміщення по висоті вгору усуває передчасне спрацьовування, поки герой ще біжить по твердій скелі.
        // Зіткнення фіксується точно тоді, коли персонаж перетинає край уступу і сходить у порожнечу.
        let triggerWidth = wallWidth + 30.0
        let triggerHeight = max(gapHeight - 32.0, 20.0)
        let triggerCenter = CGPoint(x: 0, y: 6.0)
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: triggerWidth, height: triggerHeight), center: triggerCenter)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.abyss
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        self.physicsBody = body
    }
}
