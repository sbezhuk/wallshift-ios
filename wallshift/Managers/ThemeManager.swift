//
//  ThemeManager.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 20.10.2026.
//

import SpriteKit

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
            backgroundTopColor: SKColor(red: 0.69, green: 0.56, blue: 0.44, alpha: 1.0),
            backgroundBottomColor: SKColor(red: 0.73, green: 0.51, blue: 0.35, alpha: 1.0),
            backgroundOverlayColor: .clear,
            backgroundOverlayAlpha: 0.0,
            treeTextureNames: ["deco_tree_01", "deco_tree_02"],
            decorTextureNames: ["deco_bush_01", "deco_stump", "deco_stone_01", "deco_stone_02"],
            signpostTextureNames: ["deco_sign_warning", "deco_sign_arrow", "deco_sign_question"],
            patrollerPrefix: "seer_walk_",
            patrollerFrameCount: 24,
            shooterPrefix: "shooter_walk_",
            shooterFrameCount: 24,
            projectileType: .fire,
            heartTextureName: "life_hearth",
            coinTexturePrefix: "autumn_coin_",
            coinFrameCount: 6,
            guiCoinIconName: "autumn_coin_0",
            guiStarIconName: "autumn_star",
            guiBannerName: "gui_banner_orange",
            guiBannerShadowColor: SKColor(red: 0.12, green: 0.05, blue: 0.02, alpha: 0.95),
            guiStatsBarName: "gui_bar_orange",
            guiStatsTextColor: SKColor(red: 0.22, green: 0.09, blue: 0.03, alpha: 1.0),
            guiPrimaryBtnName: "gui_btn_large_orange",
            guiSecondaryBtnName: "gui_btn_small_blue",
            guiCircleBtnName: "gui_btn_circle_orange",
            guiCardFrameName: "gui_card_orange",
            guiAccentColor: SKColor(red: 1.0, green: 0.65, blue: 0.18, alpha: 1.0)
        ),
        
        // 2. Forest Ranger (Unlockable in market with coins)
        ThemeData(
            id: "forest_ranger",
            name: "FOREST RANGER",
            subtitle: "World Tree Roots • Ranger • Water Arrows",
            price: 25000,
            previewImageName: "ranger_preview",
            heroRunPrefix: "forest_run_",
            heroRunCount: 12,
            wallTileName: "forest_wall_ground",
            wallDirtTileName: "forest_wall_face_09",
            wallRockTileName: "forest_wall_face_13",
            cliffLowerTileName: "forest_cliff_lower",
            cliffUpperTileName: "forest_cliff_upper",
            backgroundTextureName: "forest_bg",
            backgroundTopColor: SKColor(red: 0.18, green: 0.45, blue: 0.32, alpha: 1.0),
            backgroundBottomColor: SKColor(red: 0.18, green: 0.45, blue: 0.32, alpha: 1.0),
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
            projectileType: .water,
            heartTextureName: "forest_heart",
            coinTexturePrefix: "forest_coin_",
            coinFrameCount: 6,
            guiCoinIconName: "forest_coin_0",
            guiStarIconName: "forest_star",
            guiBannerName: "gui_banner_green",
            guiBannerShadowColor: SKColor(red: 0.02, green: 0.12, blue: 0.04, alpha: 0.95),
            guiStatsBarName: "gui_bar_green",
            guiStatsTextColor: SKColor(red: 0.90, green: 0.96, blue: 0.91, alpha: 1.0),
            guiPrimaryBtnName: "gui_btn_large_green",
            guiSecondaryBtnName: "gui_btn_small_blue",
            guiCircleBtnName: "gui_btn_circle_green",
            guiCardFrameName: "gui_card_green",
            guiAccentColor: SKColor(red: 0.35, green: 0.88, blue: 0.40, alpha: 1.0)
        ),
        
        // 3. Crystal Golem (Unlockable in market with coins)
        ThemeData(
            id: "crystal_golem",
            name: "CRYSTAL GOLEM",
            subtitle: "Crystal Caves • Golem & Necromancer • Water Arrows",
            price: 50000,
            previewImageName: "golem_preview",
            heroRunPrefix: "golem_run_",
            heroRunCount: 12,
            wallTileName: "crystal_wall_ground",
            wallDirtTileName: "crystal_wall_ground",
            wallRockTileName: "crystal_wall_ground",
            cliffLowerTileName: "crystal_cliff_lower",
            cliffUpperTileName: "crystal_cliff_upper",
            backgroundTextureName: "crystal_bg",
            backgroundTopColor: SKColor(red: 0.14, green: 0.15, blue: 0.29, alpha: 1.0),
            backgroundBottomColor: SKColor(red: 0.11, green: 0.11, blue: 0.21, alpha: 1.0),
            backgroundOverlayColor: SKColor(red: 0.06, green: 0.10, blue: 0.28, alpha: 1.0),
            backgroundOverlayAlpha: 0.18,
            treeTextureNames: [
                "deco_crystal_tree",
                "deco_crystal_pillar",
                "deco_crystal_pile_01",
                "deco_crystal_pile_02"
            ],
            decorTextureNames: [
                "deco_crystal_01",
                "deco_crystal_02",
                "deco_crystal_03",
                "deco_crystal_candlestick",
                "deco_crystal_rune_stone",
                "deco_crystal_stone_01",
                "deco_crystal_stone_02",
                "deco_crystal_pile_stones_01",
                "deco_crystal_pile_stones_02",
                "deco_crystal_rock_01",
                "deco_crystal_rock_02",
                "deco_crystal_rock_03",
                "deco_crystal_rock_04",
                "deco_crystal_rock_05",
                "deco_crystal_rock_06",
                "deco_crystal_fence_01",
                "deco_crystal_fence_02"
            ],
            signpostTextureNames: [
                "deco_crystal_sign_01",
                "deco_crystal_sign_02",
                "deco_crystal_sign_03",
                "deco_crystal_sign_04",
                "deco_crystal_sign_05",
                "deco_crystal_sign_06"
            ],
            patrollerPrefix: "golem_patroller_walk_",
            patrollerFrameCount: 24,
            shooterPrefix: "necromancer_shooter_walk_",
            shooterFrameCount: 24,
            projectileType: .water,
            heartTextureName: "crystal_heart",
            coinTexturePrefix: "crystal_coin_",
            coinFrameCount: 6,
            guiCoinIconName: "crystal_coin_0",
            guiStarIconName: "crystal_star",
            guiBannerName: "gui_banner_blue",
            guiBannerShadowColor: SKColor(red: 0.02, green: 0.06, blue: 0.18, alpha: 0.95),
            guiStatsBarName: "gui_bar_blue",
            guiStatsTextColor: SKColor(red: 0.90, green: 0.96, blue: 1.0, alpha: 1.0),
            guiPrimaryBtnName: "gui_btn_large_blue",
            guiSecondaryBtnName: "gui_btn_small_orange",
            guiCircleBtnName: "gui_btn_circle_blue",
            guiCardFrameName: "gui_card_blue",
            guiAccentColor: SKColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 1.0)
        ),
        
        // 4. Shadow Wraith (Unlockable in market for 100 000 coins)
        ThemeData(
            id: "shadow_wraith",
            name: "SHADOW WRAITH",
            subtitle: "Forbidden Graveyard • Wraith & Phantoms • Fire Arrows",
            price: 100000,
            previewImageName: "wraith_preview",
            heroRunPrefix: "wraith_run_",
            heroRunCount: 12,
            wallTileName: "graveyard_wall_ground",
            wallDirtTileName: "graveyard_wall_dirt",
            wallRockTileName: "graveyard_wall_rock",
            cliffLowerTileName: "graveyard_cliff_lower",
            cliffUpperTileName: "graveyard_cliff_upper",
            backgroundTextureName: "graveyard_bg",
            backgroundTopColor: SKColor(red: 0.20, green: 0.16, blue: 0.24, alpha: 1.0),
            backgroundBottomColor: SKColor(red: 0.21, green: 0.19, blue: 0.26, alpha: 1.0),
            backgroundOverlayColor: SKColor(red: 0.14, green: 0.08, blue: 0.20, alpha: 1.0),
            backgroundOverlayAlpha: 0.15,
            treeTextureNames: [
                "deco_graveyard_tree_01",
                "deco_graveyard_tree_02",
                "deco_graveyard_crypt",
                "deco_graveyard_coffin"
            ],
            decorTextureNames: [
                "deco_graveyard_bush_01",
                "deco_graveyard_bush_02",
                "deco_graveyard_bone",
                "deco_graveyard_skull",
                "deco_graveyard_headstone_01",
                "deco_graveyard_headstone_02",
                "deco_graveyard_headstone_03",
                "deco_graveyard_lantern",
                "deco_graveyard_fire",
                "deco_graveyard_fence_01",
                "deco_graveyard_fence_02",
                "deco_graveyard_rock_01",
                "deco_graveyard_rock_02",
                "deco_graveyard_rock_03",
                "deco_graveyard_rock_04",
                "deco_graveyard_rock_05",
                "deco_graveyard_rock_06"
            ],
            signpostTextureNames: [
                "deco_graveyard_sign_01",
                "deco_graveyard_sign_02",
                "deco_graveyard_sign_03",
                "deco_graveyard_sign_04",
                "deco_graveyard_sign_05",
                "deco_graveyard_sign_06"
            ],
            patrollerPrefix: "wraith_patroller_walk_",
            patrollerFrameCount: 12,
            shooterPrefix: "wraith_shooter_walk_",
            shooterFrameCount: 12,
            projectileType: .fire,
            heartTextureName: "graveyard_heart",
            coinTexturePrefix: "graveyard_coin_",
            coinFrameCount: 6,
            guiCoinIconName: "graveyard_coin_0",
            guiStarIconName: "graveyard_star",
            guiBannerName: "gui_banner_blue",
            guiBannerShadowColor: SKColor(red: 0.04, green: 0.02, blue: 0.08, alpha: 0.95),
            guiStatsBarName: "gui_bar_blue",
            guiStatsTextColor: SKColor(red: 0.92, green: 0.90, blue: 0.98, alpha: 1.0),
            guiPrimaryBtnName: "gui_btn_large_blue",
            guiSecondaryBtnName: "gui_btn_small_orange",
            guiCircleBtnName: "gui_btn_circle_blue",
            guiCardFrameName: "gui_card_blue",
            guiAccentColor: SKColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 1.0)
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
