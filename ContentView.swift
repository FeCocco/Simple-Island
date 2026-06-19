import SwiftUI
import Playgrounds

@main struct MyApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var islandState = IslandState()
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(islandState)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct ContentView: View {
    var body: some View {
        Text("")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(Color.white)
            .background(Color.black)
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    style: .continuous
                    
                ))
        
        
    }
}

#Preview {
    ContentView()
}
