//
//  KBVideoEngine.swift
//  Kitsunebi
//
//  Created by Tomoya Hirano on 2018/04/13.
//

import AVFoundation
import CoreImage

internal protocol KBVideoEngineUpdateDelegate: class {
  @discardableResult
  func didOutputFrame(_ basePixelBuffer: CVPixelBuffer, alphaPixelBuffer: CVPixelBuffer) -> Bool
  func didReceiveError(_ error: Error?)
  func didCompleted()
}

internal protocol KBVideoEngineDelegate: class {
  func didUpdateFrame(_ index: Int, engine: KBVideoEngine)
  func engineDidFinishPlaying(_ engine: KBVideoEngine)
}

protocol DisplayLinkDelegate: class {
  func didUpdated(_ link: CADisplayLink)
}

class DisplayLink: NSObject {
  private lazy var displayLink: CADisplayLink = .init(target: self, selector: #selector(DisplayLink.update))
  private lazy var renderThread: Thread = .init(target: self, selector: #selector(DisplayLink.threadLoop), object: nil)
  private var isRunningTheread = true
  weak var delegate: DisplayLinkDelegate? = nil
  
  static let shared: DisplayLink = .init()
  var isPaused: Bool {
    get { return displayLink.isPaused }
    set { displayLink.isPaused = newValue }
  }
  
  override init() {
    super.init()
    renderThread.start()
  }
  
  deinit {
    displayLink.remove(from: .current, forMode: .common)
    displayLink.invalidate()
  }
  
  @objc private func threadLoop() -> Void {
    displayLink.add(to: .current, forMode: .common)
    if #available(iOS 10.0, *) {
      displayLink.preferredFramesPerSecond = 0
    } else {
      displayLink.frameInterval = 1
    }
    while isRunningTheread {
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 1/60))
    }
  }
  
  @objc private func update(_ link: CADisplayLink) {
    delegate?.didUpdated(link)
  }
}

internal class KBVideoEngine: NSObject {
  private let mainAsset: KBAsset
  private let alphaAsset: KBAsset
  private let fpsKeeper: FPSKeeper
  internal weak var delegate: KBVideoEngineDelegate? = nil
  internal weak var updateDelegate: KBVideoEngineUpdateDelegate? = nil
  private lazy var currentFrameIndex: Int = 0
  private let displayLink = DisplayLink.shared
  public init(mainVideoUrl: URL, alphaVideoUrl: URL, fps: Int) {
    mainAsset = KBAsset(url: mainVideoUrl)
    alphaAsset = KBAsset(url: alphaVideoUrl)
    fpsKeeper = FPSKeeper(fps: fps)
    super.init()
  }
  
  private func reset() throws {
    try mainAsset.reset()
    try alphaAsset.reset()
  }
  
  private func cancelReading() {
    mainAsset.cancelReading()
    alphaAsset.cancelReading()
  }
  
  public func play() throws {
    try reset()
    displayLink.delegate = self
  }
  
  public func pause() {
    guard !isCompleted else { return }
    displayLink.delegate = nil
  }
  
  public func resume() {
    guard !isCompleted else { return }
    displayLink.delegate = self
  }
  
  private func finish() {
    displayLink.delegate = nil
    fpsKeeper.clear()
    updateDelegate?.didCompleted()
    delegate?.engineDidFinishPlaying(self)
//    purge()
  }
  
  @objc private func update(_ link: CADisplayLink) {
    guard fpsKeeper.checkPast1Frame(link) else { return }
    
    #if DEBUG
      FPSDebugger.shared.update(link)
    #endif
    
    autoreleasepool(invoking: { [weak self] in
      self?.updateFrame()
    })
  }
  
  private var isCompleted: Bool {
    return mainAsset.status == .completed || alphaAsset.status == .completed
  }
  
  private func updateFrame() {
    guard !displayLink.isPaused else { return }
    if isCompleted {
      finish()
      return
    }
    do {
      let (basePixelBuffer, alphaPixelBuffer) = try copyNextSampleBuffer()
      updateDelegate?.didOutputFrame(basePixelBuffer, alphaPixelBuffer: alphaPixelBuffer)
      
      currentFrameIndex += 1
      delegate?.didUpdateFrame(currentFrameIndex, engine: self)
    } catch (let error) {
      updateDelegate?.didReceiveError(error)
      finish()
    }
  }
  
  private func copyNextSampleBuffer() throws -> (CVImageBuffer, CVImageBuffer) {
    let main = try mainAsset.copyNextImageBuffer()
    let alpha = try alphaAsset.copyNextImageBuffer()
    return (main, alpha)
  }
}

extension KBVideoEngine: DisplayLinkDelegate {
  func didUpdated(_ link: CADisplayLink) {
    update(link)
  }
}


