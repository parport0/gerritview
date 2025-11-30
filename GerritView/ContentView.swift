import SwiftUI

let backgroundGradient = LinearGradient(
    colors: [Color.red, Color.yellow],
    startPoint: .top, endPoint: .bottom
)

struct hideScrollEdgeEffectModifier: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .scrollEdgeEffectHidden()
        } else {
            content
        }
    }
}
extension View {
    func hideScrollEdgeEffect() -> some View {
        self.modifier(hideScrollEdgeEffectModifier())
    }
}

struct ContentView: View {
    @State var settings = Settings()
    
    var body: some View {
        NavigationStack {
            VStack {
                ChangeListView()
            }
            .toolbar {
                Group {
                    ToolbarItem(placement: .principal) {
                        Text("\(Image(systemName: "plus.square.fill")) \(Image(systemName: "minus.square"))")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Text(Image(systemName: "gear"))
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            //.hideScrollEdgeEffect()
            //.toolbarBackground(backgroundGradient)
            //.toolbarBackgroundVisibility(.visible, for: ToolbarPlacement)
        }.environment(settings)
    }
}

#Preview {
    ContentView()
}
