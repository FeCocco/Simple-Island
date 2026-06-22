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
    private var telasConhecidas: [CGDirectDisplayID] = []
    private var debounceWorkItem: DispatchWorkItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        NSApp.setActivationPolicy(.accessory)
        
        criarJanelasParaTodasAsTelas()
        
    NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        
            self?.janelas.forEach { $0.orderOut(nil) }
        
            // Espera meio segundo para o macOS estabilizar o hardware de vídeo
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.criarJanelasParaTodasAsTelas()
            }
        }
    }
    
    private func agendarRecriacaoComDebounce() {
        debounceWorkItem?.cancel()
        
        let item = DispatchWorkItem { [weak self] in
            self?.atualizarSeNecessario()
        }
        debounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }
    
    private func atualizarSeNecessario() {
        let telasAtuais = idsDasTelas(NSScreen.screens)
        
        guard telasAtuais != telasConhecidas else {
            return
        }
        
        criarJanelasParaTodasAsTelas()
    }
    
    private func idsDasTelas(_ screens: [NSScreen]) -> [CGDirectDisplayID] {
        screens.compactMap { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        }
    }
    
    private func criarJanelasParaTodasAsTelas() {
        janelas.forEach { $0.close() }
        janelas.removeAll()
        
        let telas = NSScreen.screens
        janelas = telas.map { criarJanela(para: $0) }
        telasConhecidas = idsDasTelas(telas)
    }
    
    private func criarJanela(para screen: NSScreen) -> NSWindow {
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        
        let islandWidth: CGFloat = 400
        let islandHeight = menuBarHeight
        
        // screen.frame.origin é essencial aqui: cada tela tem sua própria origem
        // no espaço de coordenadas global do macOS (só a tela principal do
        // sistema começa em x=0, y=0).
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
        janela.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        janela.hasShadow = false
        janela.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        janela.isReleasedWhenClosed = false
        
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
