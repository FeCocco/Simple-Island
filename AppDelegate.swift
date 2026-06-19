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
            
            posicionarJanela(window)
        }
        
        // Se um monitor externo for conectado/desconectado com o app aberto,
        // reposiciona a janela automaticamente.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let window = NSApplication.shared.windows.first else { return }
            self?.posicionarJanela(window)
        }
    }
    
    private func posicionarJanela(_ window: NSWindow) {
        // Procura especificamente a tela com notch físico (a tela embutida do MacBook).
        // NSScreen.main NÃO é necessariamente essa tela: quando há um monitor externo
        // conectado e configurado como "principal", NSScreen.main retorna o monitor
        // externo. O código calculava x/y usando as dimensões dessa tela errada — e
        // ainda ignorava o "origin" da tela, assumindo que ela sempre começa em (0,0).
        // Em multi-monitor isso só é verdade para a tela principal do sistema; a
        // segunda tela (no caso, o MacBook) tem sua própria origem no espaço de
        // coordenadas global. Essa combinação é o que causava o desalinhamento.
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else {
            return
        }
        
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        
        let islandWidth: CGFloat = 400
        let islandHeight = menuBarHeight
        
        let x = screen.frame.origin.x + (screen.frame.width - islandWidth) / 2
        let y = screen.frame.origin.y + screen.frame.height - islandHeight
        
        let novaPosicao = NSRect(x: x, y: y, width: islandWidth, height: islandHeight)
        window.setFrame(novaPosicao, display: true)
    }
}

class IslandState: ObservableObject {
    @Published var hasNotch: Bool = false
}
