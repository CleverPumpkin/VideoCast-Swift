//
//  MicSource.swift
//  VideoCast
//
//  Created by Tomohiro Matsuzawa on 2018/01/09.
//  Copyright © 2018年 CyberAgent, Inc. All rights reserved.
//

import Foundation
import AVFoundation

/*!
 *  Capture audio from the device's microphone.
 *
 */

// MARK: - Types

public enum MicSourseError: Error {
    case cantFindAudioComponent
    case cantCreateAudioComponentInstance
    case cantEnableInput
    case cantSetAudioStreamDescrtiption
    case cantSetCallbacks
    case cantStartAudioUnit
}

// MARK: - Implementation

public class MicSource {
    
    // MARK: - Public vars
    
    public var filter: IFilter?
    
    // MARK: - Private vars
    
    private var audioUnit: AudioComponentInstance?
    private let component: AudioComponent?
    private let sampleRate: Double
    private weak var output: IOutput?
    
    private lazy var notificationsHandler: NotificationHandler = {
        let handler = NotificationHandler()
        
        handler.source = self
        
        return handler
    }()
    
    // MARK: - AudioUnit callbacks
    
    private let handleInputBuffer: AURenderCallback = {
        (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        
        let sourse = unsafeBitCast(inRefCon, to: MicSource.self)
        
        guard let audioUnit = sourse.audioUnit else {
            Logger.debug("unexpected return")
            return 0
        }

        let buffer = AudioBuffer(
            mNumberChannels: Constants.prefferedNumberOfChannels,
            mDataByteSize: 0,
            mData: nil
        )

        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: buffer
        )

        let status = AudioUnitRender(
            audioUnit,
            ioActionFlags,
            inTimeStamp,
            inBusNumber,
            inNumberFrames,
            &bufferList
        )

        guard status == noErr else {
            Logger.debug("unexpected return: \(status)")
            return status
        }

        let inputDataPtr = UnsafeMutableAudioBufferListPointer(&bufferList)

        sourse.inputCallback(
            data: inputDataPtr[0].mData,
            data_size:
            Int(inputDataPtr[0].mDataByteSize),
            inNumberFrames:
            Int(inNumberFrames)
        )

        return status
    }
    
    private let handleOutputBuffer: AURenderCallback = {
        (_, _, _, _, _, _) -> OSStatus in
        // no-op (Required only for VoiceProcessingIO to disable console error output)
        return noErr
    }
    
    // MARK: - Initialization/Deinitialization
    
    public init(
        sampleRate: Double = 48000,
        useVoiceProcessingIO: Bool = true
    ) throws {
        
        let componentSubType = useVoiceProcessingIO ? kAudioUnitSubType_VoiceProcessingIO : kAudioUnitSubType_RemoteIO
        
        var audioComponentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: componentSubType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        var inputStreamDescription = AudioStreamBasicDescription()
        
        inputStreamDescription.mSampleRate = sampleRate
        inputStreamDescription.mFormatID = kAudioFormatLinearPCM
        inputStreamDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked
        inputStreamDescription.mChannelsPerFrame = Constants.prefferedNumberOfChannels
        inputStreamDescription.mFramesPerPacket = 1
        inputStreamDescription.mBitsPerChannel = 16
        inputStreamDescription.mBytesPerFrame = inputStreamDescription.mBitsPerChannel / 8 * inputStreamDescription.mChannelsPerFrame
        inputStreamDescription.mBytesPerPacket = inputStreamDescription.mBytesPerFrame * inputStreamDescription.mFramesPerPacket
        
        guard let component = AudioComponentFindNext(nil, &audioComponentDescription) else {
            Logger.debug("Can`t find audio component")
            throw MicSourseError.cantFindAudioComponent
        }
        
        var audioComponentInstance: AudioComponentInstance?
        var latestOperationResult: OSStatus = noErr
        
        latestOperationResult = AudioComponentInstanceNew(component, &audioComponentInstance)
        
        guard
            latestOperationResult == noErr,
            let strongAudioComponentInstance = audioComponentInstance
        else {
            Logger.debug("Can`t create instance of AudioComponentInstance")
            throw MicSourseError.cantCreateAudioComponentInstance
        }
        
        var flagOne: UInt32 = 1
        
        latestOperationResult = AudioUnitSetProperty(
            strongAudioComponentInstance,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            .inputBus,
            &flagOne,
            UInt32(MemoryLayout<UInt32>.size)
        )
        
        guard latestOperationResult == noErr else {
            Logger.debug("Can`t enable input in AudioUnit")
            throw MicSourseError.cantEnableInput
        }
        
        latestOperationResult = AudioUnitSetProperty(
            strongAudioComponentInstance,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            .inputBus,
            &inputStreamDescription,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        
        guard latestOperationResult == noErr else {
            Logger.debug("Can`t set input AudioStreamDescrtiption in AudioUnit")
            throw MicSourseError.cantSetAudioStreamDescrtiption
        }
        
        self.audioUnit = audioComponentInstance
        self.component = component
        self.sampleRate = sampleRate
        
        var inputCallback = AURenderCallbackStruct(
            inputProc: handleInputBuffer,
            inputProcRefCon: UnsafeMutableRawPointer(
                Unmanaged.passUnretained(self).toOpaque()
            )
        )

        var outputCallback = AURenderCallbackStruct(
            inputProc: handleOutputBuffer,
            inputProcRefCon: UnsafeMutableRawPointer(
                Unmanaged.passUnretained(self).toOpaque()
            )
        )
        
        latestOperationResult = AudioUnitSetProperty(
            strongAudioComponentInstance,
            kAudioOutputUnitProperty_SetInputCallback,
            kAudioUnitScope_Global,
            .inputBus,
            &inputCallback,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )
        
        if useVoiceProcessingIO && latestOperationResult == noErr {
            latestOperationResult = AudioUnitSetProperty(
                strongAudioComponentInstance,
                kAudioUnitProperty_SetRenderCallback,
                kAudioUnitScope_Global,
                .outputBus,
                &outputCallback,
                UInt32(MemoryLayout<AURenderCallbackStruct>.size)
            )
        }
        
        guard latestOperationResult == noErr else {
            Logger.debug("Can`t set input callback")
            throw MicSourseError.cantSetCallbacks
        }
        
        guard initializeAndStartAudioUnit() else {
            Logger.debug("Can`t start AudioUnit")
            throw MicSourseError.cantStartAudioUnit
        }
        
        subscribeForNotifications()
    }
    
    deinit {
        dispose()
    }
    
    // MARK: - Internal methods
    
    func dispose() {
        guard let audioUnit = audioUnit else {
            return
        }
        
        notificationsHandler.source = nil
        
        NotificationCenter.default.removeObserver(notificationsHandler)
        
        AudioOutputUnitStop(audioUnit)
        AudioComponentInstanceDispose(audioUnit)
        
        self.audioUnit = nil
    }
    
    // MARK: - Private methods
    
    private func subscribeForNotifications() {
        
        NotificationCenter.default.addObserver(
            notificationsHandler,
            selector: #selector(NotificationHandler.handleInterruption(notification:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            notificationsHandler,
            selector: #selector(NotificationHandler.handleRouteChange(notification:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    private func inputCallback(data: UnsafeMutableRawPointer?, data_size: Int, inNumberFrames: Int) {
        guard
            let output = output,
            let data = data
        else {
            Logger.debug("unexpected return")
            return
        }

        let md = AudioBufferMetadata()
        let channelCount = Int(Constants.prefferedNumberOfChannels)
        
        md.data = (
            Int(sampleRate),
            16,
            channelCount,
            AudioFormatFlags(kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked),
            channelCount * 2,
            inNumberFrames,
            false,
            false,
            WeakRefISource(value: self)
        )

        output.pushBuffer(data, size: data_size, metadata: md)
    }
    
    private func interruptionBegan() {
        guard let audioUnit = audioUnit else {
            Logger.debug("unexpected return")
            return
        }
        
        Logger.debug("interruptionBegan")
        AudioOutputUnitStop(audioUnit)
    }

    private func interruptionEnded() {
        guard let audioUnit = audioUnit else {
            Logger.debug("unexpected return")
            return
        }
        
        Logger.debug("interruptionEnded")
        
        AudioOutputUnitStart(audioUnit)
    }
    
    // Not in use
    private func restart() -> Bool {
        guard stopAndUninitializeAudioUnit() else {
            Logger.debug("Can`t stop AudioUnit")
            return false
        }
        
        // You can change sample rate here
        
        return initializeAndStartAudioUnit()
    }
    
    private func stopAndUninitializeAudioUnit() -> Bool {
        guard let audioUnit = audioUnit else {
            return false
        }
        
        guard AudioOutputUnitStop(audioUnit) == noErr else {
            return false
        }
        
        return AudioUnitUninitialize(audioUnit) == noErr
    }
    
    private func initializeAndStartAudioUnit() -> Bool {
        guard let audioUnit = audioUnit else {
            return false
        }
        
        guard AudioUnitInitialize(audioUnit) == noErr else {
            return false
        }
        
        return AudioOutputUnitStart(audioUnit) == noErr
    }
}

// MARK: - ISource

extension MicSource: ISource {
    
    public func setOutput(_ output: IOutput) {
        self.output = output
        if let mixer = output as? IAudioMixer {
            mixer.registerSource(self)
        }
    }
}

// MARK: - Hashable

extension MicSource: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(
            ObjectIdentifier(self).hashValue
        )
    }
    
    public static func == (lhs: MicSource, rhs: MicSource) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

// MARK: - Constants

private extension MicSource {
    
    enum Constants {
        static let prefferedNumberOfChannels: UInt32 = 1
    }
}

// MARK: - AudioUnitScope+extension

private extension AudioUnitElement {
    
    static let inputBus: AudioUnitElement = 1
    static let outputBus: AudioUnitElement = 0
}

// MARK: - NotificationsHandler

private extension MicSource {
    
    class NotificationHandler: NSObject {
        
        // MARK: - Internal vars
        
        weak var source: MicSource?
    
        // MARK: - Internal methods
        
        @objc
        func handleInterruption(notification: Notification) {
            guard let interuptionType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] else {
                Logger.debug("unexpected return")
                return
            }
            
            let interuptionVal = AVAudioSession.InterruptionType(
                rawValue: (interuptionType as AnyObject).uintValue
            )
            
            if interuptionVal == .began {
                source?.interruptionBegan()
            } else {
                source?.interruptionEnded()
            }
        }
    
        @objc
        func handleRouteChange(notification: Notification) {
            guard let reasonType = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] else {
                Logger.debug("unexpected return")
                return
            }
    
            let reason = AVAudioSession.RouteChangeReason(
                rawValue: (reasonType as AnyObject).uintValue
            )
            
            var validRouteChange = true
    
            switch reason {
            case .unknown:
                Logger.debug("Route change: unknown")
            case .newDeviceAvailable:
                Logger.debug("Route change: newDeviceAvailable")
            case .oldDeviceUnavailable:
                Logger.debug("Route change: oldDeviceUnavailable")
            case .categoryChange:
                Logger.debug("Route change: categoryChange")
            case .override:
                Logger.debug("Route change: override")
            case .wakeFromSleep:
                Logger.debug("Route change: wakeFromSleep")
            case .noSuitableRouteForCategory:
                Logger.debug("Route change: noSuitableRouteForCategory")
            case .routeConfigurationChange:
                Logger.debug("Route change: routeConfigurationChange")
                validRouteChange = false
            default:
                Logger.debug("Route change: default case")
            }
            
            guard validRouteChange else {
                return
            }
            
            if let prevRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] {
                Logger.debug("Previous route: \(prevRoute)")
            }
        }
    }
}
