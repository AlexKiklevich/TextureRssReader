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
    
    private let defaults = UserDefaults.standard
    
    func getHasLaunchedBefore() -> Bool {
        defaults.bool(forKey: Key.hasLaunchedBefore)
    }
    
    func set(hasLaunchedBefore: Bool) {
        defaults.set(hasLaunchedBefore, forKey: Key.hasLaunchedBefore)
    }
    
    func getPrefferedReloadTimerInterval() -> TimeInterval {
        defaults.double(forKey: Key.prefferedReloadTimerInterval)
    }
    
    func set(prefferedReloadTimerInterval: Bool) {
        defaults.set(prefferedReloadTimerInterval, forKey: Key.prefferedReloadTimerInterval)
    }
}
