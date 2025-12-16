//
//  TUIVoIPExtensionManager.swift
//  TUICallKit_Swift
//
//  Created by liushuoyu on 2025/12/16.
//

import Foundation
import TUIVoIPExtension
@available(iOS 17.4, *)
@objc public class TUIVoIPExtensionManager: NSObject {
    
    @objc public static func setCertificateID(_ certificateID: Int) {
        TUIVoIPExtension.setCertificateID(certificateID)
    }
}
