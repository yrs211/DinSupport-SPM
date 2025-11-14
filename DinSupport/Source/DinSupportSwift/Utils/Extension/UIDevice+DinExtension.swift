//
//  UIDevice+DinExtension.swift
//  DinSupport
//
//  Created by 郑少玲 on 2021/5/6.
//

import Foundation
import UIKit

public extension UIDevice {
    
    func isEarlyIphone5s() -> Bool {
        if UIScreen.main.bounds.width == 320 {
            return true
        }
        return false
    }

    func isLargeScreen() -> Bool {
        if UIScreen.main.bounds.width >= 414 {
            return true
        }
        return false
    }
    
    func isX() -> Bool {
        if UIScreen.main.bounds.height >= 812 {
            return true
        }
        return false
    }
    
    func statusBarHeight() -> CGFloat {
        return isX() ? 44.0 : 20.0
    }
    
    func tabbarHeight() -> CGFloat {
        return isX() ? (49.0+34.0) : 49.0
    }
    
    func homeIndicator() -> CGFloat {
        return isX() ? 34.0 : 0.0
    }
    
    func statusBarAndNavigationBarHeight() -> CGFloat {
        return isX() ? 88.0 : 64.0
    }

    func bottomSaveBtnHeight() -> CGFloat {
        return isX() ? 88 : 54
    }
    
    func viewSafeAreInsets(view: UIView) -> UIEdgeInsets {
        var insets: UIEdgeInsets
        if #available(iOS 11.0, *) {
            insets = view.safeAreaInsets;
        }
        else {
            insets = .zero;
        }
        return insets;
    }
    
    var deviceModel: String {
        get {
            var systemInfo = utsname()
            uname(&systemInfo)
            
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            let identifier = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
            
            return identifier
        }
    }
    
}
