//
//  AppDelegate.swift
//  MyApp
//
//  Created by Felipe Giacomini Cocco on 18/06/26.
//

import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var janelas: [NSWindow] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        NSApp.setActivationPolicy(.accessory)
        
        criarJanelasParaTodasAsTelas()
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.criarJanelasParaTodasAsTelas()
        }
    }
    
    private func criarJanelasParaTodasAsTelas() {
        janelas.forEach { $0.close() }
        janelas.removeAll()
        
        janelas = NSScreen.screens.map { criarJanela(para: $0) }
    }
    
    private func criarJanela(para screen: NSScreen) -> NSWindow {
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        
        let islandWidth: CGFloat = 400
        let islandHeight = menuBarHeight
        
        // screen.frame.origin é essencial aqui: cada tela tem sua própria origem
        // no espaço de coordenadas global do macOS (só a tela principal do
        // sistema começa em x=0, y=0).
        let x = screen.frame.origin.x + (screen.frame.width - islandWidth) / 2
        let y = screen.frame.origin.y + screen.frame.height - islandHeight
        
        let frame = NSRect(x: x, y: y, width: islandWidth, height: islandHeight)
        
        let janela = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        janela.isOpaque = false
        janela.backgroundColor = .clear
        janela.level = .statusBar
        janela.hasShadow = false
        janela.collectionBehavior = [.transient, .canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        
       
        let conteudo = ContentView(islandState: IslandState(), screen: screen)
        janela.contentView = NSHostingView(rootView: conteudo)
        
        janela.setFrame(frame, display: true)
        janela.orderFrontRegardless()
        
        return janela
    }
}

class IslandState: ObservableObject {
    @Published var hasNotch: Bool = false
}
