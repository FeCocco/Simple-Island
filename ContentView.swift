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
    
    
    var larguraAtual: CGFloat {
        let expansaoBounce: CGFloat = isBouncing ? 20 : 0
        
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
                        bottomRadius: islandState.hasNotch ? 10 : (monitor.faixaAtual != nil ? 12 : 8)
                    )
                )
                .overlay(alignment: .bottom) {
                    // Só desenha o conteúdo da música se tiver algo tocando
                    if let faixa = monitor.faixaAtual {
                        HStack {
                            // ESQUERDA: Capa do Álbum
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(faixa.fonte.cor).opacity(0.8), Color(faixa.fonte.cor).opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Image(systemName: faixa.fonte == .spotify ? "waveform.circle.fill" : "applelogo")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(width: 20, height: 20)
                            
                            Spacer()
                            
                            // DIREITA: Playerzinho Animado (Waveform)
                            WaveformAnimada(cor: Color(faixa.fonte.cor))
                        }
                        .padding(.horizontal, 12)
                        // Ajusta o padding para a capa não "vazar" da ilha
                        .padding(.bottom, islandState.hasNotch ? 3 : 5)
                        // Evita que o conteúdo apareça esmagado enquanto a ilha cresce
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: larguraAtual)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: alturaAtual)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: monitor.faixaAtual)
                .onHover { isHovering in
                    if isHovering {
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
        }
        .onChange(of: monitor.faixaAtual) {
            guard monitor.faixaAtual != nil else { return }
            dispararBounce()
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
