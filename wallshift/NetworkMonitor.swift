//
//  NetworkMonitor.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 22.10.2026.
//

import Foundation
import Network

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("WallShiftNetworkStatusChanged")
}

final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.wallshift.networkMonitorQueue")
    
    #if DEBUG
    private var simulatedConnection: Bool?
    #endif
    
    private(set) var isConnected: Bool = false
    
    var onStatusChange: ((Bool) -> Void)?
    
    private init() {
        // Початкова перевірка поточного стану шляху
        self.isConnected = (monitor.currentPath.status == .satisfied)
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            #if DEBUG
            if let sim = self.simulatedConnection {
                self.updateConnectionState(sim)
                return
            }
            #endif
            
            let connected = (path.status == .satisfied)
            self.updateConnectionState(connected)
        }
        
        monitor.start(queue: queue)
    }
    
    private func updateConnectionState(_ connected: Bool) {
        let changed = (self.isConnected != connected)
        self.isConnected = connected
        
        if changed {
            print("[NetworkMonitor] Network status changed -> isConnected: \(connected)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onStatusChange?(connected)
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": connected]
                )
            }
        }
    }
    
    /// Запуск або перевірка активності монітора
    func start() {
        // Доступ до властивості гарантує ініціалізацію сінглтона
        _ = isConnected
    }
    
    #if DEBUG
    /// Симуляція зміни мережевого підключення для автоматичних тестів
    func simulateConnectionState(_ connected: Bool?) {
        self.simulatedConnection = connected
        if let sim = connected {
            updateConnectionState(sim)
        } else {
            updateConnectionState(monitor.currentPath.status == .satisfied)
        }
    }
    #endif
}
