//
//  ContentView.swift
//  SoundFinder
//
//  Created by Albert Dai on 12/25/24.
//

import SwiftUI

struct ContentView: View {
  @Environment(SoundProcessor.self) var processor
  @Environment(\.scenePhase) var scenePhase

  var body: some View {
    if let errorString = processor.errorString {
      Text(errorString)
        .padding()
    } else {
      ZStack {
        switch processor.state {
        case .description:
          VStack {
            Spacer()
            Spacer()
            Text("The app approximates the direction and amplitude of sounds near your device").multilineTextAlignment(.center)
            Spacer()
            Text("The offset of the circle from the center roughly indicates the direction of the sound (i.e. how much left or right it is), while the size of the circle represents the amplitude").multilineTextAlignment(.center)
            Spacer()
            Text("Calibrating the app will allow it to adjust to microphone placement in your device, in order to more accurately locate sounds").multilineTextAlignment(.center)
            Spacer()
            Button("Start Calibrating") { processor.state = .calibrating }
            Button("Continue to app") { processor.state = .locating }
            Spacer()
          }
        case .calibrating:
          VStack {
            Spacer()
            Spacer()
            Text("Calibrating...")
            Text("Please make sounds while your device is directly facing you, and avoid environmental noises").multilineTextAlignment(.center)
            Spacer()
            Button("Finish") { processor.state = .locating }
            Spacer()
            GeometryReader { geometry in
              Path { path in
                path.addArc(
                  center: CGPoint(x:geometry.size.width/2,y: geometry.size.height/2),
                  radius: CGFloat(35*log(processor.smoothedSignalEnergyTotal+1)),
                  startAngle: Angle(degrees: 0),
                  endAngle: Angle(degrees: 360),
                  clockwise: true)
              }
            }
            Spacer()
            Spacer()
          }
        case .locating:
          VStack {
            Button("Start Calibrating") { processor.state = .calibrating }
            GeometryReader { geometry in
              Path { path in
                let orientation = UIDevice.current.orientation
                let balance = orientation == .landscapeLeft ? processor.smoothedSignalEnergyBalance : 2-processor.smoothedSignalEnergyBalance
                path.addArc(
                  center: CGPoint(x:geometry.size.width/2*(CGFloat(balance)),y: geometry.size.height/2),
                  radius: CGFloat(35*log(processor.smoothedSignalEnergyTotal+1)),
                  startAngle: Angle(degrees: 0),
                  endAngle: Angle(degrees: 360),
                  clockwise: true)
              }
            }
          }
        }
      }.onChange(of: scenePhase, {
        oldValue, newValue in
        if newValue != .active {
          processor.state = .description
        }
      })
    }
  }
}

#Preview {
  ContentView().environment(SoundProcessor())
}
