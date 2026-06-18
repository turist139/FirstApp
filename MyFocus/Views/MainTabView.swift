import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ScreenTimeView()
                .tabItem {
                    Label("Детокс", systemImage: "hourglass.circle.fill")
                }
            
            PracticesView()
                .tabItem {
                    Label("Практики", systemImage: "sparkles")
                }
            
            MotivationContainerView()
                .tabItem {
                    Label("Смыслы", systemImage: "flame.fill")
                }
                
            StatisticsView()
                .tabItem {
                    Label("Статистика", systemImage: "chart.bar.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
        }
        .tint(.green)
    }
}

#Preview {
    MainTabView()
}
