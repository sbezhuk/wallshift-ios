//
//  ThemeData.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 20.10.2026.
//

import SpriteKit

// MARK: - Projectile Type
enum ProjectileType {
    case fire
    case water
}

// MARK: - Theme Model
struct ThemeData {
    let id: String
    let name: String
    let subtitle: String
    let price: Int
    let previewImageName: String
    
    // Hero
    let heroRunPrefix: String
    let heroRunCount: Int
    
    // Walls
    let wallTileName: String
    let wallDirtTileName: String
    let wallRockTileName: String
    let cliffLowerTileName: String
    let cliffUpperTileName: String
    
    // Background & Environment Tint
    let backgroundTextureName: String
    let backgroundTopColor: SKColor
    let backgroundBottomColor: SKColor
    let backgroundOverlayColor: SKColor
    let backgroundOverlayAlpha: CGFloat
    
    // Decorations
    let treeTextureNames: [String]
    let decorTextureNames: [String]
    let signpostTextureNames: [String]
    
    // Mobs
    let patrollerPrefix: String
    let patrollerFrameCount: Int
    let shooterPrefix: String
    let shooterFrameCount: Int
    let projectileType: ProjectileType
    
    // Items
    let heartTextureName: String
    
    // Coins
    let coinTexturePrefix: String
    let coinFrameCount: Int
    let guiCoinIconName: String
    
    // Star Icon
    let guiStarIconName: String
    
    // GUI Styling
    let guiBannerName: String
    let guiBannerShadowColor: SKColor
    let guiStatsBarName: String
    let guiStatsTextColor: SKColor
    let guiPrimaryBtnName: String
    let guiSecondaryBtnName: String
    let guiCircleBtnName: String
    let guiCardFrameName: String
    let guiAccentColor: SKColor
}
