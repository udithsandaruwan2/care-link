//
//  care_link_Watch_App.swift
//  care link Watch App
//
//  Created by NEON on 2026-04-27.
//

import AppIntents

struct care_link_Watch_App: AppIntent {
    static var title: LocalizedStringResource { "care link Watch App" }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
