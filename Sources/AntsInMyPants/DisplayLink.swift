import SwiftUI

#if os(macOS)
public class DisplayLink: ObservableObject {
    private var displayLink: CVDisplayLink?
    private var tickHandler: (_ framesPerSecond: CFTimeInterval) -> Void = {_ in}
    private var previousTimestamp: CFTimeInterval?
    
    deinit {
        stop()
    }
    
    public func start(tickHandler: @escaping (_ framesPerSecond: CFTimeInterval) -> Void) {
        self.tickHandler = tickHandler
        previousTimestamp = nil
        
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        guard let displayLink = displayLink else {
            return
        }
        
        let opaqueself = Unmanaged.passUnretained(self).toOpaque()
        
        CVDisplayLinkSetOutputCallback(displayLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, opaque) -> CVReturn in
            let myself = Unmanaged<DisplayLink>.fromOpaque(opaque!).takeUnretainedValue()
            myself.tick(timestamp: inNow.pointee.timeInterval)
            return kCVReturnSuccess
        }, opaqueself)
        
        self.displayLink = displayLink
        CVDisplayLinkStart(displayLink)
    }
    
    public func stop() {
        guard let displayLink = displayLink else { return }
        CVDisplayLinkStop(displayLink)
        self.displayLink = nil
        previousTimestamp = nil
    }
    
    private func tick(timestamp: CFTimeInterval) {
        if let previousTimestamp = previousTimestamp {
            let deltaTime = timestamp - previousTimestamp
            let actualFramesPerSecond = deltaTime > 0 ? 1 / deltaTime : 60
            
            DispatchQueue.main.async {
                self.tickHandler(actualFramesPerSecond)
            }
        }
        
        previousTimestamp = timestamp
    }
}

extension CVTimeStamp {
    var timeInterval: CFTimeInterval {
        Double(videoTime) / Double(videoTimeScale)
    }
}

#else
public class DisplayLink: ObservableObject {
    private var tickHandler: (_ framesPerSecond: CFTimeInterval) -> Void = {_ in}
    private lazy var link = CADisplayLink(target: self, selector: #selector(tick))

    deinit {
        stop()
    }

    public func start(tickHandler: @escaping (_ framesPerSecond: CFTimeInterval) -> Void) {
        self.tickHandler = tickHandler
        link.add(to: .main, forMode: .common)
    }

    public func stop() {
        link.invalidate()
    }

    @objc private func tick() {
        let actualFramesPerSecond = 1 / (link.targetTimestamp - link.timestamp)
        tickHandler(actualFramesPerSecond)
    }
}
#endif
