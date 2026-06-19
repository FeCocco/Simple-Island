//
//  AppDelegation.swift
//  MyApp
//
//  Created by Felipe Giacomini Cocco on 18/06/26.
//

import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        NSApp.setActivationPolicy(.accessory)
        
        if let window = NSApplication.shared.windows.first {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.styleMask = .borderless
            window.level = .statusBar
            window.hasShadow = false
            
            if let screen = NSScreen.main {
                let screenWidth = screen.frame.width
                let screenHeight = screen.frame.height
                
                let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY

                let islandWidth: CGFloat = 400
                let islandHeight = menuBarHeight

                let x = (screenWidth - islandWidth) / 2
                let y = screenHeight - islandHeight
                
                let novaPosicao = NSRect(x: x, y: y, width: islandWidth, height: islandHeight)
                window.setFrame(novaPosicao, display: true)
            }
        }
    }
}

class IslandState: ObservableObject {
    @Published var hasNotch: Bool = false
}
