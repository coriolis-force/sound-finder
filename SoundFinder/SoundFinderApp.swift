//
//  SoundFinderApp.swift
//  SoundFinder
//
//  Created by Albert Dai on 12/25/24.
//

import SwiftUI

@main
struct SoundFinderApp: App {
  var body: some Scene {
    WindowGroup {
        ContentView().environment(SoundProcessor())
    }
  }
}
