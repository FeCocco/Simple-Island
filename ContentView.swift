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
    
    @State private var menuBarHeight: CGFloat = 24
    @State private var notchWidth: CGFloat = 150
    @State private var isBouncing: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            
            Color.clear
            
            Rectangle()
                .fill(Color.black)
                .frame(
                    width: (islandState.hasNotch ? notchWidth : 80) + (isBouncing ? 10 : 0),
                    height: (islandState.hasNotch ? menuBarHeight : menuBarHeight/4) + (isBouncing ? 2 : 0)
                )
                .clipShape(
                    islandState.hasNotch
                    ? AnyShape(UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16, style: .continuous))
                    : AnyShape(MacNotchShape(flareRadius: 6, bottomRadius: 8))
                )
                .onHover { isHovering in
                    if isHovering {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                            isBouncing = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
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
    }
    
    private func atualizarMetricasDaTela() {
        // Lemos as propriedades DIRETAMENTE da `screen` injetada para esta janela
        islandState.hasNotch = screen.safeAreaInsets.top > 0
        menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        
        let leftArea = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightArea = screen.auxiliaryTopRightArea?.width ?? 0
        
        if leftArea > 0 && rightArea > 0 {
            notchWidth = screen.frame.width - leftArea - rightArea
        }
    }
}

struct MacNotchShape: Shape {
    var flareRadius: CGFloat = 8
    var bottomRadius: CGFloat = 16
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: 0, y: 0))
        
        path.addQuadCurve(
            to: CGPoint(x: flareRadius, y: flareRadius),
            control: CGPoint(x: flareRadius, y: 0)
        )
        
        path.addLine(to: CGPoint(x: flareRadius, y: rect.maxY - bottomRadius))
        
        path.addQuadCurve(
            to: CGPoint(x: flareRadius + bottomRadius, y: rect.maxY),
            control: CGPoint(x: flareRadius, y: rect.maxY)
        )
        
        path.addLine(to: CGPoint(x: rect.maxX - flareRadius - bottomRadius, y: rect.maxY))
        
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - flareRadius, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.maxX - flareRadius, y: rect.maxY)
        )
        
        path.addLine(to: CGPoint(x: rect.maxX - flareRadius, y: flareRadius))
        
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: 0),
            control: CGPoint(x: rect.maxX - flareRadius, y: 0)
        )
        
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    ContentView(islandState: IslandState(), screen: NSScreen.main!)
}
