import SwiftUI

/// 室内导航主界面
struct IndoorNavigationView: View {
    @ObservedObject var vm: NavigationViewModel
    @State private var roomInput: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbar
            
            // 地图
            BuildingMapView(vm: vm)
                .padding(.horizontal, 4)
            
            // 底部面板
            bottomPanel
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 顶部栏
    
    private var toolbar: some View {
        VStack(spacing: 8) {
            // 楼层切换
            HStack(spacing: 12) {
                Text("楼层")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(BuildingData.allFloors, id: \.self) { floor in
                    Button {
                        vm.autoFollowFloor = false   // 手动切换后暂停自动跟随
                        vm.switchFloor(floor)
                    } label: {
                        Text("\(floor)F")
                            .font(.system(size: 14, weight: floor == vm.viewFloor ? .bold : .regular))
                            .foregroundColor(floor == vm.viewFloor ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(floor == vm.viewFloor ? Color.blue : Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // 卫星图层切换
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        vm.showSatelliteMap.toggle()
                    }
                } label: {
                    Image(systemName: vm.showSatelliteMap ? "map.fill" : "map")
                        .font(.system(size: 13))
                        .foregroundColor(vm.showSatelliteMap ? .white : .secondary)
                        .padding(6)
                        .background(vm.showSatelliteMap ? Color.blue : Color(.systemGray5))
                        .cornerRadius(6)
                }
                
                // 楼层自动跟随按钮
                Button {
                    vm.autoFollowFloor.toggle()
                    if vm.autoFollowFloor {
                        vm.switchFloor(vm.sensorFloor)
                    }
                } label: {
                    Image(systemName: vm.autoFollowFloor ? "location.fill" : "location.slash")
                        .font(.system(size: 13))
                        .foregroundColor(vm.autoFollowFloor ? .white : .secondary)
                        .padding(6)
                        .background(vm.autoFollowFloor ? Color.blue : Color(.systemGray5))
                        .cornerRadius(6)
                }
                
                // 传感器楼层 + 定位状态
                HStack(spacing: 4) {
                    Circle()
                        .fill(vm.isTracking ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text("\(vm.sensorFloor)F")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
            .padding(.horizontal)
            
            // 入口选择
            HStack(spacing: 8) {
                Text("入口")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(["NW", "NE", "SW"], id: \.self) { key in
                    let entrance = BuildingData.entrances[key]
                    Button {
                        vm.selectEntrance(key)
                    } label: {
                        Text(entrance?.hint ?? key)
                            .font(.system(size: 12, weight: key == vm.selectedEntrance ? .semibold : .regular))
                            .foregroundColor(key == vm.selectedEntrance ? .white : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(key == vm.selectedEntrance ? Color.green : Color(.systemGray5))
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 底部面板
    
    private var bottomPanel: some View {
        VStack(spacing: 10) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("输入教室号 (如 EB102)", text: $roomInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onSubmit {
                        vm.setDestination(roomInput)
                    }
                
                if !roomInput.isEmpty {
                    Button {
                        roomInput = ""
                        vm.clearRoute()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("搜索") {
                    vm.setDestination(roomInput)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // 状态 / 路线信息
            if vm.mode != .idle {
                routeCard
            }
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - 路线卡片
    
    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                switch vm.mode {
                case .route:
                    let destFloor = BuildingData.floorForRoom(vm.destinationCode)
                    let floorStr = destFloor.map { " (\($0)F)" } ?? ""
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .foregroundColor(.blue)
                    Text("\(vm.entranceLabel) → \(vm.destinationCode)\(floorStr)")
                        .font(.subheadline.bold())
                case .recommend:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("建议使用西北入口")
                        .font(.subheadline.bold())
                case .unreachable:
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(.red)
                    Text("无法到达")
                        .font(.subheadline.bold())
                case .idle:
                    EmptyView()
                }
                
                Spacer()
                
                if vm.mode == .route, let route = vm.route {
                    Text("~\(Int(route.distanceMeters))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("~\(max(5, Int(route.estimatedTimeSeconds)))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 状态消息
            Text(vm.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 步骤
            if !vm.routeSteps.isEmpty {
                Divider()
                ForEach(Array(vm.routeSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(stepColor(index: index, total: vm.routeSteps.count))
                            .cornerRadius(9)
                        Text(step.text)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .padding(.horizontal)
    }
    
    private func stepColor(index: Int, total: Int) -> Color {
        if index == 0 { return .green }
        if index == total - 1 { return .red }
        return .blue
    }
}
