//
//  PooledSprayNode.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import SpriteKit

// MARK: - Reusable Pooled Particle Spray Node (Zero Allocations, 120 FPS Buttery Smooth)
final class PooledSprayNode: SKNode {
    let emitter: SKEmitterNode
    let shimmerEmitter: SKEmitterNode
    private(set) var inUse: Bool = false
    
    init(texture: SKTexture, isHeart: Bool = false) {
        self.emitter = SKEmitterNode()
        self.shimmerEmitter = SKEmitterNode()
        super.init()
        self.zPosition = 4.8
        
        emitter.particleTexture = texture
        emitter.particleBirthRate = 0
        
        shimmerEmitter.particleTexture = texture
        shimmerEmitter.particleBirthRate = 0
        
        if isHeart {
            // Рубіновий цілющий спрей
            emitter.particleLifetime = 0.40
            emitter.particleLifetimeRange = 0.08
            emitter.particleSpeed = 95.0
            emitter.particleSpeedRange = 35.0
            emitter.emissionAngle = .pi / 2.0
            emitter.emissionAngleRange = .pi * 1.4
            emitter.yAcceleration = 35.0
            emitter.particleAlpha = 0.95
            emitter.particleAlphaSpeed = -2.2
            emitter.particleScale = 0.22
            emitter.particleScaleRange = 0.08
            emitter.particleScaleSpeed = -0.40
            emitter.particleColor = SKColor(red: 1.0, green: 0.20, blue: 0.38, alpha: 1.0)
            emitter.particleColorBlendFactor = 1.0
            emitter.particleBlendMode = .add
            
            // Ніжно-рожеві іскри
            shimmerEmitter.particleLifetime = 0.28
            shimmerEmitter.particleLifetimeRange = 0.06
            shimmerEmitter.particleSpeed = 55.0
            shimmerEmitter.particleSpeedRange = 25.0
            shimmerEmitter.emissionAngle = .pi / 2.0
            shimmerEmitter.emissionAngleRange = .pi * 2.0
            shimmerEmitter.yAcceleration = 25.0
            shimmerEmitter.particleAlpha = 0.90
            shimmerEmitter.particleAlphaSpeed = -2.8
            shimmerEmitter.particleScale = 0.13
            shimmerEmitter.particleScaleRange = 0.05
            shimmerEmitter.particleScaleSpeed = -0.35
            shimmerEmitter.particleColor = SKColor(red: 1.0, green: 0.65, blue: 0.78, alpha: 1.0)
            shimmerEmitter.particleColorBlendFactor = 1.0
            shimmerEmitter.particleBlendMode = .add
        } else {
            // Золотистий спрей монет
            emitter.particleLifetime = 0.32
            emitter.particleLifetimeRange = 0.06
            emitter.particleSpeed = 110.0
            emitter.particleSpeedRange = 40.0
            emitter.emissionAngle = .pi / 2.0
            emitter.emissionAngleRange = .pi * 1.5
            emitter.yAcceleration = -70.0
            emitter.particleAlpha = 0.95
            emitter.particleAlphaSpeed = -2.7
            emitter.particleScale = 0.20
            emitter.particleScaleRange = 0.08
            emitter.particleScaleSpeed = -0.45
            emitter.particleColor = SKColor(red: 1.0, green: 0.84, blue: 0.20, alpha: 1.0)
            emitter.particleColorBlendFactor = 1.0
            emitter.particleBlendMode = .add
            
            // Яскраві золотаво-білі мікро-іскри
            shimmerEmitter.particleLifetime = 0.22
            shimmerEmitter.particleLifetimeRange = 0.05
            shimmerEmitter.particleSpeed = 65.0
            shimmerEmitter.particleSpeedRange = 30.0
            shimmerEmitter.emissionAngle = .pi / 2.0
            shimmerEmitter.emissionAngleRange = .pi * 2.0
            shimmerEmitter.yAcceleration = -35.0
            shimmerEmitter.particleAlpha = 0.90
            shimmerEmitter.particleAlphaSpeed = -3.5
            shimmerEmitter.particleScale = 0.12
            shimmerEmitter.particleScaleRange = 0.04
            shimmerEmitter.particleScaleSpeed = -0.40
            shimmerEmitter.particleColor = SKColor(red: 1.0, green: 0.98, blue: 0.70, alpha: 1.0)
            shimmerEmitter.particleColorBlendFactor = 1.0
            shimmerEmitter.particleBlendMode = .add
        }
        
        addChild(emitter)
        addChild(shimmerEmitter)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var burstAction: SKAction = {
        SKAction.sequence([
            SKAction.wait(forDuration: 0.04),
            SKAction.run { [weak self] in
                self?.emitter.particleBirthRate = 0
                self?.shimmerEmitter.particleBirthRate = 0
            },
            SKAction.wait(forDuration: 0.32),
            SKAction.run { [weak self] in
                self?.inUse = false
            }
        ])
    }()
    
    func trigger(at pos: CGPoint) {
        self.position = pos
        self.inUse = true
        
        emitter.resetSimulation()
        shimmerEmitter.resetSimulation()
        
        emitter.particleBirthRate = 420
        shimmerEmitter.particleBirthRate = 280
        
        removeAction(forKey: "sprayBurst")
        run(burstAction, withKey: "sprayBurst")
    }
}
