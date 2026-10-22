//
//  PhysicsCategory.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import Foundation

// MARK: - Physics Categories
/// Бітові маски категорій фізики для визначення взаємодії об'єктів
struct PhysicsCategory {
    static let none: UInt32     = 0
    static let player: UInt32   = 1 << 0 // 1
    static let wall: UInt32     = 1 << 1 // 2
    static let obstacle: UInt32 = 1 << 2 // 4
    static let abyss: UInt32    = 1 << 3 // 8
    static let heart: UInt32    = 1 << 4 // 16
    static let coin: UInt32     = 1 << 5 // 32
}
