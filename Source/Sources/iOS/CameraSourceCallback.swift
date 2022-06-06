//
//  CameraSourceCallback.swift
//  VideoCast
//
//  Created by Tomohiro Matsuzawa on 7/29/18.
//  Copyright © 2018 CyberAgent, Inc. All rights reserved.
//

import Foundation
import AVFoundation

final class SbCallback: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: - Internal vars
    
    weak var source: CameraSource?
    
    // MARK: - Internal methods
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            Logger.debug("unexpected return")
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        
        source?.cameraSnapshot = context?.makeImage()
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        source?.bufferCaptured(pixelBuffer: pixelBuffer)
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
    }

    @objc func orientationChanged(notification: Notification) {
        guard let source = source, !source.orientationLocked else { return }
        DispatchQueue.global().async { [weak self] in
            self?.source?.reorientCamera()
        }
    }
}
