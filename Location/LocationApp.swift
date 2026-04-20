//
//  LocationApp.swift
//  Location
//
//  Created by psg on 2026/3/16.
//

import SwiftUI
import CoreLocation // 导入定位
import CoreMotion   // 导入运动/气压

@main
struct LocationApp: App {
    @StateObject private var locationVM = LocationViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(locationVM)
        }
    }
}

/// 主 Tab 容器 — 在此处创建 NavigationViewModel 以保持生命周期稳定
struct MainTabView: View {
    @EnvironmentObject var locationVM: LocationViewModel
    @StateObject private var navVM: NavigationViewModel = .placeholder
    @State private var didInit = false
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("传感器", systemImage: "gauge.with.dots.needle.33percent")
                }
            
            IndoorNavigationView(vm: navVM)
                .tabItem {
                    Label("导航", systemImage: "map.fill")
                }
        }
        .onAppear {
            if !didInit {
                navVM.bindSensors(barometer: locationVM.barometerManagerRef,
                                  location: locationVM.locationManagerRef)
                didInit = true
            }
        }
    }
}
