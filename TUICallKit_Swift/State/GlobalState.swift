//
//  GlobalState.swift
//  Pods
//
//  Created by vincepzhang on 2025/2/6.
//

import UIKit

class GlobalState: NSObject {
    var enableMuteMode: Bool = UserDefaults.standard.value(forKey: ENABLE_MUTEMODE_USERDEFAULT) as? Bool == true ? true : false
    var enableFloatWindow: Bool = false
    var enableIncomingBanner: Bool = false
    var enableVirtualBackground: Bool = false
    var enableForceUseV2API: Bool = false
    var enableMultiDeviceAbility: Bool = false
    var enablePictureInPicture: Bool = false
    var orientation: Orientation = .portrait
    
    // 视频通话等待/无视频流时的背景颜色，默认为绿色
    private var _waitingBackgroundColor: UIColor = UIColor.green
    
    /// 获取等待/无视频流时的背景颜色
    var waitingBackgroundColor: UIColor {
        return _waitingBackgroundColor
    }
    
    /// 设置等待/无视频流时的背景颜色
    /// - Parameter hexString: 十六进制颜色字符串，例如 "#00FF00" 或 "00FF00"
    func setWaitingBackgroundColor(hexString: String) {
        if let color = UIColor(hex: hexString) {
            _waitingBackgroundColor = color
        } else {
            // 如果解析失败，使用默认的绿色
            _waitingBackgroundColor = UIColor.green
        }
    }
}

// MARK: - UIColor Hex Extension
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0
        let length = hexSanitized.count
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
            
        } else {
            return nil
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

enum Orientation: Int{
    case portrait = 0
    case landscape = 1
    case auto = 2
}
