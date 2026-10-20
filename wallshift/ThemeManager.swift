//
//  ThemeManager.swift
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
}

// MARK: - ThemeManager
final class ThemeManager {
    static let shared = ThemeManager()
    
    // MARK: - Keys
    private let unlockedThemesKey = "WallShiftUnlockedThemes"
    private let selectedThemeKey = "WallShiftSelectedTheme"
    private let totalCoinsKey = "TotalWallShiftCoins"
    
    // MARK: - Available Themes
    let themes: [ThemeData] = [
        // 1. Autumn Mage (Default free theme)
        ThemeData(
            id: "autumn_mage",
            name: "AUTUMN MAGE",
            subtitle: "Autumn Forest • Seer • Fire Arrows",
            price: 0,
            previewImageName: "seer_preview",
            heroRunPrefix: "run_",
            heroRunCount: 12,
            wallTileName: "wall_tile",
            wallDirtTileName: "wall_dirt",
            wallRockTileName: "wall_rock",
            cliffLowerTileName: "abyss_cliff_right",
            cliffUpperTileName: "abyss_cliff_left",
            backgroundTextureName: "backround",
            backgroundOverlayColor: .clear,
            backgroundOverlayAlpha: 0.0,
            treeTextureNames: ["deco_tree_01", "deco_tree_02"],
            decorTextureNames: ["deco_bush_01", "deco_stump", "deco_stone_01", "deco_stone_02"],
            signpostTextureNames: ["deco_sign_warning", "deco_sign_arrow", "deco_sign_question"],
            patrollerPrefix: "seer_walk_",
            patrollerFrameCount: 24,
            shooterPrefix: "shooter_walk_",
            shooterFrameCount: 24,
            projectileType: .fire
        ),
        
        // 2. Forest Ranger (Unlockable in market with coins)
        ThemeData(
            id: "forest_ranger",
            name: "FOREST RANGER",
            subtitle: "World Tree Roots • Ranger • Water Arrows",
            price: 35,
            previewImageName: "ranger_preview",
            heroRunPrefix: "forest_run_",
            heroRunCount: 12,
            wallTileName: "forest_wall_ground",
            wallDirtTileName: "forest_wall_face_09",
            wallRockTileName: "forest_wall_face_13",
            cliffLowerTileName: "forest_cliff_lower",
            cliffUpperTileName: "forest_cliff_upper",
            backgroundTextureName: "forest_bg",
            backgroundOverlayColor: SKColor(red: 0.02, green: 0.15, blue: 0.08, alpha: 1.0),
            backgroundOverlayAlpha: 0.15,
            treeTextureNames: [
                "deco_forest_root",
                "deco_forest_statue",
                "deco_forest_portal"
            ],
            decorTextureNames: [
                "deco_forest_plant_01",
                "deco_forest_plant_02",
                "deco_forest_bush_01",
                "deco_forest_bush_02",
                "deco_forest_ivy_01",
                "deco_forest_ivy_02",
                "deco_forest_leaves",
                "deco_forest_stone_01",
                "deco_forest_stone_02",
                "deco_forest_rock_01",
                "deco_forest_rock_02",
                "deco_forest_rock_03",
                "deco_forest_rock_04",
                "deco_forest_rock_05",
                "deco_forest_rock_06",
                "deco_forest_fence_01",
                "deco_forest_fence_02",
                "deco_forest_torch"
            ],
            signpostTextureNames: [
                "deco_forest_sign_01",
                "deco_forest_sign_02",
                "deco_forest_sign_03",
                "deco_forest_sign_04",
                "deco_forest_sign_05",
                "deco_forest_sign_06"
            ],
            patrollerPrefix: "ranger_patroller_walk_",
            patrollerFrameCount: 24,
            shooterPrefix: "ranger_shooter_walk_",
            shooterFrameCount: 24,
            projectileType: .water
        )
    ]
    
    // MARK: - Properties
    private(set) var unlockedThemeIDs: Set<String>
    private(set) var selectedThemeID: String
    
    var currentTheme: ThemeData {
        return theme(for: selectedThemeID) ?? themes[0]
    }
    
    var totalCoins: Int {
        get { UserDefaults.standard.integer(forKey: totalCoinsKey) }
        set { UserDefaults.standard.set(newValue, forKey: totalCoinsKey) }
    }
    
    // MARK: - Initialization
    private init() {
        let savedUnlocked = UserDefaults.standard.stringArray(forKey: unlockedThemesKey) ?? ["autumn_mage"]
        self.unlockedThemeIDs = Set(savedUnlocked)
        let savedSelected = UserDefaults.standard.string(forKey: selectedThemeKey) ?? "autumn_mage"
        if themes.contains(where: { $0.id == savedSelected }) {
            self.selectedThemeID = savedSelected
        } else {
            self.selectedThemeID = "autumn_mage"
        }
    }
    
    func theme(for id: String) -> ThemeData? {
        return themes.first { $0.id == id }
    }
    
    func isUnlocked(_ theme: ThemeData) -> Bool {
        if theme.price == 0 { return true }
        return unlockedThemeIDs.contains(theme.id)
    }
    
    func canAfford(_ theme: ThemeData) -> Bool {
        return totalCoins >= theme.price
    }
    
    /// Придбання персонажа/теми за зібрані монети
    @discardableResult
    func buyTheme(_ theme: ThemeData) -> Bool {
        guard !isUnlocked(theme) else {
            selectTheme(theme)
            return true
        }
        guard canAfford(theme) else { return false }
        
        totalCoins -= theme.price
        unlockedThemeIDs.insert(theme.id)
        UserDefaults.standard.set(Array(unlockedThemeIDs), forKey: unlockedThemesKey)
        selectTheme(theme)
        return true
    }
    
    /// Вибір активного персонажа/теми
    func selectTheme(_ theme: ThemeData) {
        selectedThemeID = theme.id
        UserDefaults.standard.set(selectedThemeID, forKey: selectedThemeKey)
    }
}
