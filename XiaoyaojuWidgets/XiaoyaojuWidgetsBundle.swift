//
//  XiaoyaojuWidgetsBundle.swift
//  XiaoyaojuWidgets
//
//  Created by xhy on 2026/6/20.
//

import WidgetKit
import SwiftUI

@main
struct XiaoyaojuWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyGuaWidget()
        DailyQuoteWidget()
        QuickCastWidget()
    }
}
