//
//  Int+Formatting.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import Foundation

// MARK: - Unified Number Formatting
extension Int {
    /// Уніфікований формат чисел для всієї гри з розділювачем тисяч (наприклад: 25,000, 1,200)
    var formattedWithSeparator: String {
        return NumberFormatter.gameNumberFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension NumberFormatter {
    fileprivate static let gameNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter
    }()
}
