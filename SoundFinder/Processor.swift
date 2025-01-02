//
//  Processor.swift
//  SoundFinder
//
//  Created by Albert Dai on 12/25/24.
//

import AVFoundation
import Accelerate

@Observable
class SoundProcessor {
  enum State {
    case locating, calibrating, description
  }
  
  public var state: State = .description {
    didSet {
      if oldValue != .description && state == .description {
        stopReceiving()
      } else if oldValue == .description && state != .description {
        startReceiving()
      }
      if state == .calibrating && oldValue != .calibrating {
        calibrationTotal1 = 0
        calibrationTotal2 = 0
        smoothedSignalEnergyBalance = 1
        smoothedSignalEnergyTotal = 0
      }
    }
  }
  public private(set) var smoothedSignalEnergyBalance: Float = 1
  public private(set) var smoothedSignalEnergyTotal: Float = 0
  public private(set) var errorString: String? = nil
  
  private static let smoothingFactor: Float = 0.8
  
  private var engine: AVAudioEngine? = nil
  private var mixerNode: AVAudioMixerNode? = nil
  private var player: AVAudioPlayer? = nil
  private var signalEnergyBalance: Float = 1
  private var signalEnergyTotal: Float = 0
  private var calibrationTotal1: Float = 0
  private var calibrationTotal2: Float = 0
  
  fileprivate func setupSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord)
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      let position = "Front"
      guard let availableInputs = session.availableInputs,
            let builtInMicInput = availableInputs.first(where: { $0.portType == .builtInMic }),
            let dataSource = builtInMicInput.dataSources?.first(where: {$0.dataSourceName == position}),
            let polarPatterns = dataSource.supportedPolarPatterns,
            polarPatterns.contains(.stereo) else {
        errorString = "The device must have a built-in stereo microphone on the \(position.lowercased())."
        return
      }
      try session.setPreferredInput(builtInMicInput)
      try builtInMicInput.setPreferredDataSource(dataSource)
      try dataSource.setPreferredPolarPattern(.stereo)
      try session.setPreferredInputOrientation(.landscapeRight)
    } catch {
      errorString = "Error setting up audio session: \(error)"
    }
  }
  
  fileprivate func setupEngine() {
    let engine = AVAudioEngine()
    self.engine = engine
    let mixerNode = AVAudioMixerNode()
    self.mixerNode = mixerNode

    mixerNode.volume = 0

    engine.attach(mixerNode)

    makeConnections()
    
    engine.prepare()
  }
  
  fileprivate func makeConnections() {
    guard let engine, let mixerNode else { return }
    let inputNode = engine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    engine.connect(inputNode, to: mixerNode, format: inputFormat)

    let mainMixerNode = engine.mainMixerNode
    let mixerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: inputFormat.sampleRate, channels: 2, interleaved: false)
    engine.connect(mixerNode, to: mainMixerNode, format: mixerFormat)
  }

  private func startReceiving() {
    setupSession()
    setupEngine()
    do {
      guard let engine, let mixerNode else { return }
      let format = mixerNode.outputFormat(forBus: 0)
      mixerNode.installTap(onBus: 0, bufferSize: 4096, format: format, block: {
        (buffer, time) in
        self.process(buffer)
      })
      
      try engine.start()
    } catch {
      errorString = "error in initializing sound reception: \(error)"
    }
  }
  
  private func process(_ buffer: AVAudioPCMBuffer) {
    guard let data = buffer.floatChannelData else { return }
    var sum1: Float = 0
    var sum2: Float = 0
    vDSP_svesq(data[0], buffer.stride, &sum1, vDSP_Length(buffer.frameLength))
    vDSP_svesq(data[1], buffer.stride, &sum2, vDSP_Length(buffer.frameLength))
    if state == .calibrating {
      calibrationTotal1 += sum1
      calibrationTotal2 += sum2
    } else {
      if calibrationTotal1 != calibrationTotal2 {
        sum1 *= calibrationTotal2 / (calibrationTotal1 + calibrationTotal2) * 2
        sum2 *= calibrationTotal1 / (calibrationTotal1 + calibrationTotal2) * 2
      }
      if sum1 == sum2 {
        signalEnergyBalance = 1
      } else {
        signalEnergyBalance = (2 * sum1) / (sum1 + sum2)
      }
    }
    signalEnergyTotal = sum1 + sum2
    let oldEnergyWeight = smoothedSignalEnergyTotal * SoundProcessor.smoothingFactor
    let newEnergyWeight = signalEnergyTotal * (1 - SoundProcessor.smoothingFactor)
    smoothedSignalEnergyTotal = oldEnergyWeight + newEnergyWeight
    if state != .calibrating {
      if oldEnergyWeight == newEnergyWeight {
        smoothedSignalEnergyBalance = 0
      } else {
        smoothedSignalEnergyBalance = (smoothedSignalEnergyBalance * oldEnergyWeight + signalEnergyBalance * newEnergyWeight) / smoothedSignalEnergyTotal
      }
    }
  }
  
  private func stopReceiving() {
    guard let engine, let mixerNode else { return }
    mixerNode.removeTap(onBus: 0)
    engine.stop()
    self.engine = nil
    self.mixerNode = nil
  }

}
