//
//  UserDefaultsProvider.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 9.02.26.
//

import Foundation

final class UserDefaultsProvider {
    
    private struct Key {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let prefferedReloadTimerInterval = "prefferedReloadTimerInterval"
    }

    private struct DefaultValue {
        static let prefferedReloadTimerInterval: TimeInterval = 300
    }
    
    private let defaults = UserDefaults.standard
    
    func getHasLaunchedBefore() -> Bool {
        defaults.bool(forKey: Key.hasLaunchedBefore)
    }
    
    func set(hasLaunchedBefore: Bool) {
        defaults.set(hasLaunchedBefore, forKey: Key.hasLaunchedBefore)
    }
    
    func getPrefferedReloadTimerInterval() -> TimeInterval {
        let value = defaults.double(forKey: Key.prefferedReloadTimerInterval)
        return value > 0 ? value : DefaultValue.prefferedReloadTimerInterval
    }
    
    func set(prefferedReloadTimerInterval: TimeInterval) {
        defaults.set(prefferedReloadTimerInterval, forKey: Key.prefferedReloadTimerInterval)
    }
}
