//
//  AppDelegate.swift
//  TUICallKitApp
//
//  Created by adams on 2021/5/7.
//  Copyright © 2021 Tencent. All rights reserved.
//

import UIKit
import UserNotifications
import ImSDK_Plus
import TIMPush
import PushKit
import TUIVoIPExtension

#if canImport(TUICallKit_Swift)
import TUICallKit_Swift
#elseif canImport(TUICallKit)
import TUICallKit
#endif

#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif

/// You need to register a developer certificate with Apple, download and generate the certificate (P12 file) in their developer accounts, and upload the generated P12 file to the Tencent certificate console.
/// The console will automatically generate a certificate ID and pass it to the `businessID` parameter.
#if DEBUG
let business_id: Int32 = 47290
#else
let business_id: Int32 = 47212
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var voipRegistry: PKPushRegistry?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        NotificationCenter.default.addObserver(self, selector: #selector(configIfLoggedIn(_:)),
                                               name: Notification.Name("TUILoginSuccessNotification"),
                                               object: nil)
        
        // 配置 PushKit for VoIP
        setupPushKit()
        
        // 上报证书 ID
        TUIVoIPExtension.setCertificateID(Int(business_id))
        
        // 设置推送 RegistrationID（需要在 registerPush 之前调用）
        setupRegistrationID()
        
        // 请求推送权限并注册推送
        registerForPushNotifications(application: application)
        
        return true
    }
    
    func setupRegistrationID() {
        // 生成设备唯一标识作为 RegistrationID
        // 可以使用设备的 identifierForVendor 或自定义标识符
        let registrationID: String
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString {
            registrationID = vendorID
        } else {
            // 如果没有 vendorID，使用随机 UUID
            registrationID = UUID().uuidString
        }
        
        // 设置 RegistrationID
        TIMPushManager.setRegistrationID(registrationID) {
            print("Set RegistrationID success: \(registrationID)")
        }
    }
    
    func registerForPushNotifications(application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func setupPushKit() {
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }
    
    @objc func configIfLoggedIn(_ notification: Notification) {
        DispatchQueue.main.async {
            TUICallKit.createInstance().enableFloatWindow(enable: SettingsConfig.share.floatWindow)
#if canImport(TUICallKit_Swift)
            TUICallKit.createInstance().enableVirtualBackground(enable: SettingsConfig.share.enableVirtualBackground)
            TUICallKit.createInstance().enableIncomingBanner(enable: SettingsConfig.share.enableIncomingBanner)
#endif
        }
    }
}

// MARK: - Configuration Apple Push Notification Service (APNs)

extension AppDelegate: TIMPushDelegate {
    func businessID() -> Int32 {
        return business_id;
    }
    
    //    func applicationGroupID() -> String {
    //        return "";
    //    }
    //
    //    func onRemoteNotificationReceived(_ notice: String?) -> Bool {
    //
    //    }
}

// MARK: - APNs Device Token Registration

extension AppDelegate {
    // 注册 APNs 设备令牌成功
    // 注意：TIMPushManager.registerPush 应该在登录成功后调用（在 LoginViewController 中），
    // 这里只保存 deviceToken，登录成功后会自动注册
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs device token received: \(token)")
        // TIMPushManager 会自动使用这个设备令牌，无需在此处手动注册
    }
    
    // 注册 APNs 设备令牌失败
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - PushKit VoIP Push Configuration

extension AppDelegate: PKPushRegistryDelegate {
    // VoIP Token 注册成功
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("VoIP Push Token: \(token)")
        
        // 将 VoIP token 注册到腾讯云 IM
        let data = pushCredentials.token
//        TIMPush.sharedInstance()?.updateVoIPToken(data)
    }
    
    // VoIP Token 注册失败
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("VoIP Push Token invalidated")
    }
    
    // 收到 VoIP 推送
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("Received VoIP Push: \(payload.dictionaryPayload)")
        
        // 处理 VoIP 推送，通知 TIMPush 处理
        if let payloadDict = payload.dictionaryPayload as? [String: Any] {
//            TIMPush.sharedInstance()?.handleVoIPNotification(payloadDict)
        }
        
        completion()
    }
}
