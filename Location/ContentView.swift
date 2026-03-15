//
//  ContentView.swift
//  Location
//
//  Created by psg on 2026/3/16.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LocationViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "figure.walk")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .padding(.top, 20)
                
                Text("综合定位追踪")
                    .font(.title2)
                    .bold()
                
                // 1. GPS 基础定位与高度
                VStack(alignment: .leading, spacing: 10) {
                    Text("📍 GPS 信息").font(.headline)
                    Text("当前定位：\(viewModel.gpsLocationStr)")
                    Text("初始海拔：\(viewModel.gpsInitialAltitudeStr)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
                // 2. 气压计 楼层与相对高度估算
                VStack(alignment: .leading, spacing: 10) {
                    Text("🏢 气压与楼层").font(.headline)
                    Text("当前气压：\(viewModel.pressureStr)")
                    Text("高度变化：\(viewModel.relativeAltitudeStr)")
                    Text("估测层数变化：\(viewModel.floorChange) 层")
                        .foregroundColor(viewModel.floorChange == 0 ? .primary : .green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                
                // 3. 惯性导航 (加速度与 PID 预估位移)
                VStack(alignment: .leading, spacing: 10) {
                    Text("🏃 加速度运动追踪").font(.headline)
                    Text("实时推算位移：\(viewModel.displacementStr)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
                
                // 4. 控制按钮
                HStack(spacing: 20) {
                    Button("开始追踪") {
                        viewModel.startAllTracking()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("停止") {
                        viewModel.stopAllTracking()
                    }
                    .buttonStyle(.bordered)
                        .tint(.red)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    ContentView()
}
