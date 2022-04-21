//
//  SRTLogSupport.swift
//  VideoCast
//
//  Created by Tomohiro Matsuzawa on 2018/03/09.
//  Copyright © 2018年 CyberAgent, Inc. All rights reserved.
//

import Foundation

public enum SRTLogLevel: Int {
    case alert
    case crit
    case debug
    case emerg
    case err
    case info
    case notice
    case warning

    func setLogLevel() {
        let logLevel: Int32
        switch self {
        case .alert:
            logLevel = LOG_ALERT
        case .crit:
            logLevel = LOG_CRIT
        case .debug:
            logLevel = LOG_DEBUG
        case .emerg:
            logLevel = LOG_EMERG
        case .err:
            logLevel = LOG_ERR
        case .info:
            logLevel = LOG_INFO
        case .notice:
            logLevel = LOG_NOTICE
        case .warning:
            logLevel = LOG_WARNING
        }
        srt_setloglevel(logLevel)
    }
}

public enum SRTLogFA: Int32 {
    case general = 0        // gglog: General uncategorized log, for serious issues only
    case sockmgmt = 1       // smlog: Socket create/open/close/configure activities
    case conn = 2           // cnlog: Connection establishment and handshake
    case xtimer = 3         // xtlog: The checkTimer and around activities
    case tsbpd = 4          // tslog: The TsBPD thread
    case rsrc = 5           // rslog: System resource allocation and management
            
    case congest = 7        // cclog: Congestion control module
    case pfilter = 8        // pflog: Packet filter module
            
    case apiCtrl = 11       // aclog: API part for socket and library managmenet
            
    case queCtrl = 13       // qclog: Queue control activities
            
    case epollUpd = 16      // eilog: EPoll, internal update activities
            
    case apiRecv = 21       // arlog: API part for receiving
    case bufRecv = 22       // brlog: Buffer, receiving side
    case queRecv = 23       // qrlog: Queue, receiving side
    case chnRecv = 24       // krlog: CChannel, receiving side
    case grpRecv = 25       // grlog: Group, receiving side
            
    case apiSend = 31       // aslog: API part for sending
    case bufSend = 32       // bslog: Buffer, sending side
    case queSend = 33       // qslog: Queue, sending side
    case chnSend = 34       // kslog: CChannel, sending side
    case grpSend = 35       // gslog: Group, sending side
            
    case `internal` = 41    // inlog: Internal activities not connected directly to a socket
            
    case queMgmt = 43       // qmlog: Queue, management part
    case chnMgmt = 44       // kmlog: CChannel, management part
    case grpMgmt = 45       // gmlog: Group, management part
    case epollApi = 46      // ealog: EPoll, API part
            
    case haicrypt = 6       // hclog: Haicrypt module area
    case applog = 10        // aplog: Applications
}

public struct SRTLogFAs {
    
    private let options: Set<SRTLogFA>

    public init(_ options: [SRTLogFA]) {
        self.options = Set(options)
    }
    
    public init(_ option: SRTLogFA) {
        self.options = [option]
    }
    
    public func setLogFA() {
        options.forEach {
            srt_addlogfa($0.rawValue)
        }
    }
}
