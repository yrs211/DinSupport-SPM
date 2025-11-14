//
//  Double+DSExtension.swift
//  HelioSDK
//
//  Created by Jin on 2020/5/11.
//  Copyright © 2020 Dinsafer. All rights reserved.
//

import Foundation

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
