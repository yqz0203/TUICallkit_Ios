//
//  TUIVoIPExtensionManager.swift
//  TUICallKit_Swift
//
//  Created by liushuoyu on 2025/12/16.
//

import Foundation
import PushKit
import TUIVoIPExtension

@objc public class TUIVoIPExtensionManager: NSObject {
    
    private var voipRegistry: PKPushRegistry?
    
    @objc public static let shared = TUIVoIPExtensionManager()
    
    private override init() {
        super.init()
        setupPushKit()
    }
    
    @objc public func setupPushKit() {
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
//        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }
    
    @objc public static func setCertificateID(_ certificateID: Int) {
        if #available(iOS 17.4, *) {
            TUIVoIPExtension.setCertificateID(certificateID)
//            TUIVoIPExtensionManager.shared.setupPushKit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                // 这里写要延迟执行的代码
                print("3秒后执行，主线程")
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: NSNotification.Name.TUILoginSuccess.rawValue), object: nil)

            }
        }
    }
}
//
//// MARK: - PKPushRegistryDelegate
//extension TUIVoIPExtensionManager: PKPushRegistryDelegate {
//    // VoIP Token 注册成功
//    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
//        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
//        print("VoIP Push Token: \(token)")
//        
//        // 将 VoIP token 注册到腾讯云 IM
//        let data = pushCredentials.token
//        
//        Toast.showToast("VoIP Push Token: \(token)")
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            // 这里写要延迟执行的代码
//            print("3秒后执行，主线程")
//            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NSNotification.Name.TUILoginSuccess.rawValue), object: nil)
//
//        }
//        
////        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NSNotification.Name.TUILoginSuccess.rawValue), object: nil)
//
////        NotificationCenter.default.addObserver(self, selector:  #selector(onLoginSuccess), name: NSNotification.Name.TUILoginSuccess, object: nil)
//
//
//        // TIMPush.sharedInstance()?.updateVoIPToken(data)
//    }
//    
//    // VoIP Token 注册失败
//    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
//        print("VoIP Push Token invalidated")
//        
//        Toast.showToast("VoIP Push Token invalidated")
//
//    }
//    
//    // 收到 VoIP 推送
//    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
//        print("Received VoIP Push: \(payload.dictionaryPayload)")
//        
//        // 处理 VoIP 推送，通知 TIMPush 处理
//        if let payloadDict = payload.dictionaryPayload as? [String: Any] {
//            // TIMPush.sharedInstance()?.handleVoIPNotification(payloadDict)
//        }
//        
//        completion()
//    }
//}
