//
//  ContentView.swift
//  Location
//
//  Created by psg on 2026/3/16.
//

import SwiftUI
import Charts

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
                    
                    Text("计步状态：\(viewModel.accelerometerManager.stepDirectionMessage)")
                        .foregroundColor(.purple)
                        .bold()
                    
                    // 嵌入新的历史实时加速度图表
                    AccelerationChartView(accelerometerManager: viewModel.accelerometerManager)
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

// 独立的图表 View 组件，附加到当前文件避免修改工程结构
struct AccelerationChartView: View {
    @ObservedObject var accelerometerManager: AccelerometerManager
    
    var body: some View {
        VStack {
            Text("实时加速度图形 (世界坐标系)")
                .font(.subheadline)
                .bold()
                .padding(.top, 5)
            
            Text("三轴加速度历史轨迹 (m/s²)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 获取最新时间作为基准（0秒）
            let latestTime = accelerometerManager.chartData.last?.timestamp ?? 0
            
            Chart {
                ForEach(accelerometerManager.chartData) { dataPoint in
                    // 计算相对时间，最新点为 0，旧点为负数 (例如：-3.0s 到 0s)
                    let relativeTime = dataPoint.timestamp - latestTime
                    
                    // X轴 加速度
                    LineMark(
                        x: .value("Time", relativeTime),
                        y: .value("X", dataPoint.x),
                        series: .value("Axis", "X")
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    
                    // Y轴 加速度
                    LineMark(
                        x: .value("Time", relativeTime),
                        y: .value("Y", dataPoint.y),
                        series: .value("Axis", "Y")
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    
                    // Z轴 加速度
                    LineMark(
                        x: .value("Time", relativeTime),
                        y: .value("Z", dataPoint.z),
                        series: .value("Axis", "Z")
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }
            .chartXScale(domain: -3.0 ... 0.0) // 强制固定显示窗口为最近 3 秒
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel() {
                        if let time = value.as(Double.self) {
                            Text(String(format: "%.1fs", time))
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding(.top, 10)
            
            // 图例说明
            HStack(spacing: 20) {
                legendItem(color: .red, label: "X轴")
                legendItem(color: .green, label: "Y轴")
                legendItem(color: .blue, label: "Z轴")
            }
            .padding(.bottom, 5)
        }
        .background(Color(UIColor.systemBackground).opacity(0.8))
        .cornerRadius(8)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
        }
    }
}
