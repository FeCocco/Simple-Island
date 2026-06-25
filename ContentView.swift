import SwiftUI
import AppKit

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

struct ContentView: View {

    @ObservedObject var islandState: IslandState
    let screen: NSScreen
    @ObservedObject var monitor: MonitorDeReproducao
    
    @State private var menuBarHeight: CGFloat = 24
    @State private var notchWidth: CGFloat = 150
    @State private var isBouncing: Bool = false
    @State private var isExpanded: Bool = false
    @State private var globalClickMonitor: Any?
    
    // MARK: - Cálculos Dinâmicos de Tamanho
    var larguraAtual: CGFloat {
        let expansaoBounce: CGFloat = isBouncing ? 20 : 0
        
        if isExpanded {
            return 360 + expansaoBounce
        }
        
        if islandState.hasNotch {
            let expansaoMusica: CGFloat = monitor.faixaAtual != nil ? 110 : 0
            return notchWidth + expansaoMusica + expansaoBounce
        } else {
            let larguraBase: CGFloat = monitor.faixaAtual != nil ? 200 : 80
            return larguraBase + expansaoBounce
        }
    }
    
    var alturaAtual: CGFloat {
        let expansaoBounce: CGFloat = isBouncing ? 4 : 0
        
        if isExpanded {
            return 160 + expansaoBounce
        }
        
        if islandState.hasNotch {
            return (menuBarHeight - 2) + expansaoBounce
        } else {
            let alturaBase: CGFloat = monitor.faixaAtual != nil ? (menuBarHeight / 1.2) : (menuBarHeight / 4)
            return alturaBase + expansaoBounce
        }
    }
    
    // MARK: - Interface Visual
    
    var body: some View {
        ZStack(alignment: .top) {
            
            Color.clear
            
            Rectangle()
                .fill(Color.black)
                .frame(width: larguraAtual, height: alturaAtual)
                .clipShape(
                    MacNotchShape(
                        flareRadius: 6,
                        bottomRadius: isExpanded ? 30 : (islandState.hasNotch ? 10 : (monitor.faixaAtual != nil ? 12 : 8))
                    )
                )
                .overlay(alignment: .top) {
                    ZStack(alignment: .bottom) {
                        if let faixa = monitor.faixaAtual {
                            if isExpanded {
                                LayoutExpandido(faixa: faixa, capa: monitor.capaAtual)
                                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                            } else {
                                LayoutCompacto(faixa: faixa, capa: monitor.capaAtual, isNotch: islandState.hasNotch)
                                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                            }
                        }
                    }
                    .frame(width: larguraAtual, height: alturaAtual)
                    .clipped()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: larguraAtual)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: alturaAtual)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: monitor.faixaAtual)
            
                // MARK: - Gestos de Clique
                .onTapGesture(count: 2) {
                    // DUPLO CLIQUE: Abre a aplicação 
                    if let fonte = monitor.faixaAtual?.fonte {
                        abrirAppFonte(fonte)
                        withAnimation { isExpanded = false }
                    }
                }
                .onTapGesture(count: 1) {
                    // CLIQUE ÚNICO: Apenas EXPande a ilha (se ainda não estiver expandida)
                    if monitor.faixaAtual != nil {
                        if !isExpanded {
                            withAnimation {
                                isExpanded = true
                            }
                        }
                    } else {
                        dispararBounce()
                    }
                }
            
                .onHover { isHovering in
                    if isHovering && !isExpanded {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                            isBouncing = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                isBouncing = false
                            }
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            atualizarMetricasDaTela()
            configurarMonitorDeCliquesFora()
        }
        .onChange(of: monitor.faixaAtual) {
            if monitor.faixaAtual == nil {
                withAnimation { isExpanded = false }
            } else {
                dispararBounce()
            }
        }
    }
    
    // MARK: - Funções Auxiliares
    
    private func configurarMonitorDeCliquesFora() {
        // Interceta qualquer clique (esquerdo ou direito) que aconteça FORA da nossa janela
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            // Se a ilha estiver aberta e o utilizador clicar noutro sítio, fecha a ilha suavemente
            if isExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }
    }
    
    private func abrirAppFonte(_ fonte: FonteMusical) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: fonte.bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }
    
    private func atualizarMetricasDaTela() {
        islandState.hasNotch = screen.safeAreaInsets.top > 0
        menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        
        let leftArea = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightArea = screen.auxiliaryTopRightArea?.width ?? 0
        
        if leftArea > 0 && rightArea > 0 {
            notchWidth = screen.frame.width - leftArea - rightArea
        }
    }
    
    private func dispararBounce() {
        guard !isExpanded else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            isBouncing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isBouncing = false
            }
        }
    }
}

// MARK: - Componentes de Layout

struct LayoutCompacto: View {
    var faixa: FaixaAtual
    var capa: NSImage?
    var isNotch: Bool
    
    var body: some View {
        HStack {
            ZStack {
                if let capa = capa {
                    Image(nsImage: capa)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .transition(.opacity)
                } else {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color(faixa.fonte.cor).opacity(0.8), Color(faixa.fonte.cor).opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .transition(.opacity)
                    
                    Image(systemName: faixa.fonte == .spotify ? "waveform.circle.fill" : "applelogo")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                        .transition(.opacity)
                }
            }
            .frame(width: 20, height: 20)
            .animation(.easeInOut(duration: 0.3), value: capa)
            
            Spacer()
            
            WaveformAnimada(cor: Color(faixa.fonte.cor))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, isNotch ? 3 : 5)
    }
}

struct LayoutExpandido: View {
    var faixa: FaixaAtual
    var capa: NSImage?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                if let capa = capa {
                    Image(nsImage: capa)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(faixa.titulo)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(faixa.artista)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.top, 4)
                
                Spacer()
                
                Image(systemName: faixa.fonte == .spotify ? "waveform.circle.fill" : "applelogo")
                    .font(.system(size: 20))
                    .foregroundColor(Color(faixa.fonte.cor))
            }
            
            HStack(spacing: 40) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Image(systemName: "pause.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - Componente do Visualizador (Waveform)

struct WaveformAnimada: View {
    var cor: Color
    @State private var phase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 2.5) {
            Barra(fase: phase, offset: 0, cor: cor)
            Barra(fase: phase, offset: 1.5, cor: cor)
            Barra(fase: phase, offset: 3.0, cor: cor)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
    
    struct Barra: View {
        var fase: CGFloat
        var offset: CGFloat
        var cor: Color
        
        var body: some View {
            let altura = 8 + 4 * sin(fase + offset)
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(cor)
                .frame(width: 3, height: altura)
        }
    }
}

// MARK: - Formato do Notch

struct MacNotchShape: Shape {
    var flareRadius: CGFloat
    var bottomRadius: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(flareRadius, bottomRadius) }
        set {
            flareRadius = newValue.first
            bottomRadius = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: flareRadius, y: flareRadius), control: CGPoint(x: flareRadius, y: 0))
        path.addLine(to: CGPoint(x: flareRadius, y: rect.maxY - bottomRadius))
        path.addQuadCurve(to: CGPoint(x: flareRadius + bottomRadius, y: rect.maxY), control: CGPoint(x: flareRadius, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - flareRadius - bottomRadius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - flareRadius, y: rect.maxY - bottomRadius), control: CGPoint(x: rect.maxX - flareRadius, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - flareRadius, y: flareRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: 0), control: CGPoint(x: rect.maxX - flareRadius, y: 0))
        path.closeSubpath()
        
        return path
    }
}
