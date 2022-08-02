//
//  SRTStats.swift
//  VideoCast
//
//  Created by Tomohiro Matsuzawa on 2018/08/15.
//  Copyright © 2018年 CyberAgent, Inc. All rights reserved.
//

import Foundation

public class SrtStats: Codable {
    public let sid: Int32
    public let time: Int64
    public let window: SrtStatsWindow
    public let link: SrtStatsLink
    public let send: SrtStatsSend
    public let recv: SrtStatsRecv

    init(_ sid: Int32, mon: inout CBytePerfMon) {
        self.sid = sid
        self.time = mon.msTimeStamp
        self.window = SrtStatsWindow(&mon)
        self.link = SrtStatsLink(&mon)
        self.send = SrtStatsSend(&mon)
        self.recv = SrtStatsRecv(&mon)
    }
}

public struct SrtStatsWindow: Codable {
    public let flow: Int32
    public let congestion: Int32
    public let flight: Int32

    init(_ mon: inout CBytePerfMon) {
        flow = mon.pktFlowWindow
        congestion = mon.pktCongestionWindow
        flight = mon.pktFlightSize
    }
}

public struct SrtStatsLink: Codable {
    public let rtt: Double
    public let bandwidth: Double
    public let maxBandwidth: Double

    init(_ mon: inout CBytePerfMon) {
        rtt = mon.msRTT
        bandwidth = mon.mbpsBandwidth
        maxBandwidth = mon.mbpsMaxBW
    }
}

public struct SrtStatsSend: Codable {
    public let packets: Int64
    public let packetsLost: Int32
    public let packetsDropped: Int32
    public let packetsRetransmitted: Int32
    public let bytes: UInt64
    public let bytesDropped: UInt64
    public let mbitRate: Double
    
    public let packetsTotal: Int64
    public let packetsLostTotal: Int32
    public let packetsDroppedTotal: Int32
    public let packetsRetransmittedTotal: Int32
    public let bytesTotal: UInt64
    public let bytesDroppedTotal: UInt64

    init(_ mon: inout CBytePerfMon) {
        packets = mon.pktSent
        packetsLost = mon.pktSndLoss
        packetsDropped = mon.pktSndDrop
        packetsRetransmitted = mon.pktRetrans
        bytes = mon.byteSent
        bytesDropped = mon.byteSndDrop
        mbitRate = mon.mbpsSendRate
        packetsTotal = mon.pktSentTotal
        packetsLostTotal = mon.pktSndLossTotal
        packetsDroppedTotal = mon.pktSndDropTotal
        packetsRetransmittedTotal  = mon.pktRetransTotal
        bytesTotal = mon.byteSentTotal
        bytesDroppedTotal = mon.byteSndDropTotal
    }
}

public struct SrtStatsRecv: Codable {
    public let packets: Int64
    public let packetsLost: Int32
    public let packetsDropped: Int32
    public let packetsRetransmitted: Int32
    public let packetsBelated: Int64
    public let bytes: UInt64
    public let bytesLost: UInt64
    public let bytesDropped: UInt64
    public let mbitRate: Double

    init(_ mon: inout CBytePerfMon) {
        packets = mon.pktRecv
        packetsLost = mon.pktRcvLoss
        packetsDropped = mon.pktRcvDrop
        packetsRetransmitted = mon.pktRcvRetrans
        packetsBelated = mon.pktRcvBelated
        bytes = mon.byteRecv
        bytesLost = mon.byteRcvLoss
        bytesDropped = mon.byteRcvDrop
        mbitRate = mon.mbpsRecvRate
    }
}
