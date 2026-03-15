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
                    Text("📍 GPS 空间绝对信息").font(.headline)
                    Text("当前定位：\(viewModel.gpsLocationStr)")
                    Text("初始海拔：\(viewModel.gpsInitialAltitudeStr)")
                    Text("距起点欧氏距离：\(viewModel.gpsDistanceStr)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
                // 2. 气压计 楼层与相对高度估算
                VStack(alignment: .leading, spacing: 10) {
                    Text("🏢 气压、气象与楼层").font(.headline)
                    Text("机内传感器气压：\(viewModel.pressureStr)")
                    Text("气象局地表气压：\(viewModel.weatherSurfacePressureStr)")
                    Text("系统绝对海拔(直取)：\(viewModel.absoluteAltitudeStr)")
                    Text("预估地表海拔(演算)：\(viewModel.altitudeFromSurfaceStr)")
                    Text("相对位移(距启动)：\(viewModel.relativeAltitudeStr)")
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
                    Text("一维累积位移：\(viewModel.displacementStr)")
                    Text("三维空间直线距离：\(viewModel.distance3DStr)")
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
