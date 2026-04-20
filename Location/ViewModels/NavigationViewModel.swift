import Foundation
import Combine
import CoreLocation

/// 室内导航 ViewModel
final class NavigationViewModel: ObservableObject {
    
    // MARK: - 用户输入
    
    @Published var selectedEntrance: String = "NW"       // NW / NE / SW
    @Published var destinationCode: String = ""          // e.g. "EB102"
    @Published var viewFloor: Int = 1                    // 当前查看的楼层
    @Published var showSatelliteMap: Bool = false         // 卫星地图图层开关
    
    // MARK: - 导航状态
    
    enum NavigationMode: Equatable {
        case idle
        case route
        case recommend    // SW入口 → 建议绕行NW
        case unreachable
    }
    
    @Published var mode: NavigationMode = .idle
    @Published var route: RouteResult?
    @Published var routeSteps: [RouteStep] = []
    @Published var statusMessage: String = ""
    
    // MARK: - 传感器融合
    
    @Published var sensorFloor: Int = 1                  // 气压计推算楼层
    @Published var userLocalPosition: CGPoint?           // GPS 投影到局部坐标
    
    // MARK: - 数据
    
    let graph: NavigationGraph
    let allRoomCodes: [String]
    
    private var barometerManager: BarometerManager?
    private var locationManager: LocationManager?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init(barometerManager: BarometerManager, locationManager: LocationManager) {
        self.barometerManager = barometerManager
        self.locationManager = locationManager
        self.graph = NavigationGraph()
        self.allRoomCodes = BuildingData.allRoomCodes()
        
        bindSensorsInternal()
    }
    
    /// 用于 @StateObject 的占位初始化
    private init() {
        self.graph = NavigationGraph()
        self.allRoomCodes = BuildingData.allRoomCodes()
    }
    
    static let placeholder = NavigationViewModel()
    
    /// 延迟绑定传感器（从 MainTabView.onAppear 调用）
    func bindSensors(barometer: BarometerManager, location: LocationManager) {
        self.barometerManager = barometer
        self.locationManager = location
        bindSensorsInternal()
    }
    
    // MARK: - 入口 ID
    
    var entranceNodeId: String {
        BuildingData.entrances[selectedEntrance]?.id ?? "NW-ENTRY"
    }
    
    var entranceLabel: String {
        BuildingData.entrances[selectedEntrance]?.hint ?? selectedEntrance
    }
    
    // MARK: - 操作
    
    func selectEntrance(_ key: String) {
        selectedEntrance = key
        refreshRoute()
    }
    
    func setDestination(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        destinationCode = trimmed
        refreshRoute()
    }
    
    func switchFloor(_ floor: Int) {
        guard BuildingData.allFloors.contains(floor) else { return }
        viewFloor = floor
    }
    
    func clearRoute() {
        destinationCode = ""
        route = nil
        routeSteps = []
        mode = .idle
        statusMessage = ""
    }
    
    // MARK: - 路径计算
    
    private func refreshRoute() {
        guard !destinationCode.isEmpty else {
            route = nil
            routeSteps = []
            mode = selectedEntrance == "SW" ? .recommend : .idle
            statusMessage = mode == .recommend ? "请先到西北入口" : "输入目标教室号"
            return
        }
        
        // 验证教室号
        guard allRoomCodes.contains(destinationCode) else {
            route = nil
            routeSteps = []
            mode = .unreachable
            statusMessage = "未找到教室 \(destinationCode)"
            return
        }
        
        // SW 入口特殊处理：建议绕行
        if selectedEntrance == "SW" {
            mode = .recommend
            route = nil
            routeSteps = [
                RouteStep(text: "你在西南入口"),
                RouteStep(text: "请先前往西北入口，再开始室内导航"),
                RouteStep(text: "然后搜索 \(destinationCode)"),
            ]
            statusMessage = "建议从西北入口进入"
            return
        }
        
        let destNodeId = "ROOM-\(destinationCode)"
        guard let result = graph.findRoute(from: entranceNodeId, to: destNodeId) else {
            route = nil
            routeSteps = []
            mode = .unreachable
            statusMessage = "无法到达 \(destinationCode)"
            return
        }
        
        route = result
        mode = .route
        routeSteps = graph.routeSteps(route: result, entranceLabel: entranceLabel, destCode: destinationCode)
        
        let distM = Int(result.distanceMeters)
        let timeSec = Int(result.estimatedTimeSeconds)
        statusMessage = "距离 ~\(distM)m · 预计 \(max(5, timeSec))s"
        
        // 自动切换到目标楼层
        if let destFloor = BuildingData.floorForRoom(destinationCode) {
            viewFloor = destFloor
        }
    }
    
    // MARK: - 传感器绑定
    
    private func bindSensorsInternal() {
        cancellables.removeAll()
        
        // 气压计 → 楼层
        barometerManager?.$floorCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                let floor = BuildingData.sensorConfig.baseFloor + count
                let clamped = max(BuildingData.allFloors.first ?? 1,
                                  min(BuildingData.allFloors.last ?? 3, floor))
                self?.sensorFloor = clamped
            }
            .store(in: &cancellables)
        
        // GPS → 局部坐标
        locationManager?.$lastLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in
                let pt = BuildingData.geoToLocal(lat: loc.coordinate.latitude,
                                                  lng: loc.coordinate.longitude)
                self?.userLocalPosition = pt
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 地图数据查询
    
    /// 获取指定楼层的房间
    func rooms(for floor: Int) -> [Room] {
        BuildingData.roomsByFloor[floor] ?? []
    }
    
    /// 获取指定楼层的走廊节点
    func corridorNodes(for floor: Int) -> [WalkableNode] {
        BuildingData.walkableNodes(for: floor)
    }
    
    /// 路径中属于指定楼层的节点坐标
    func routePoints(for floor: Int) -> [CGPoint] {
        guard let route = route else { return [] }
        return route.path.compactMap { nodeId -> CGPoint? in
            guard let node = graph.nodes[nodeId], node.floor == floor else { return nil }
            return CGPoint(x: node.x, y: node.y)
        }
    }
    
    /// 路径中的楼梯节点（在指定楼层）
    func stairMarkers(for floor: Int) -> [(id: String, position: CGPoint, label: String)] {
        guard let route = route else { return [] }
        return route.path.compactMap { nodeId -> (String, CGPoint, String)? in
            guard let node = graph.nodes[nodeId], node.floor == floor, node.kind == "stair" else { return nil }
            return (nodeId, CGPoint(x: node.x, y: node.y), node.label ?? "楼梯")
        }
    }
}
