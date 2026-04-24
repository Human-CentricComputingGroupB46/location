import SwiftUI
import MapKit

/// 室内地图叠加层 — 用 Canvas 绘制房间、走廊、路径、用户位置
struct BuildingMapView: View {
    @ObservedObject var vm: NavigationViewModel
    
    // 视口缩放：地图原始尺寸 1000×640 → 适配屏幕
    private let mapSize = CGSize(width: BuildingData.mapConfig.width,
                                  height: BuildingData.mapConfig.height)
    
    var body: some View {
        ZStack {
            // 卫星地图底图
            if vm.showSatelliteMap {
                SatelliteMapLayer()
            }
            
            canvasOverlay
        }
        .aspectRatio(mapSize.width / mapSize.height, contentMode: .fit)
    }
    
    // MARK: - Canvas 叠加层
    
    private var canvasOverlay: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / mapSize.width,
                            geo.size.height / mapSize.height)
            let offsetX = (geo.size.width - mapSize.width * scale) / 2
            let offsetY = (geo.size.height - mapSize.height * scale) / 2
            
            Canvas { context, size in
                let transform = CGAffineTransform(translationX: offsetX, y: offsetY)
                    .scaledBy(x: scale, y: scale)
                
                context.concatenate(transform)
                
                // 背景（卫星模式下半透明，纯寻路模式下不透明）
                let bgOpacity = vm.showSatelliteMap ? 0.0 : 0.08
                context.fill(Path(CGRect(origin: .zero, size: mapSize)),
                             with: .color(.gray.opacity(bgOpacity)))
                
                // 不可通行区域
                for area in BuildingData.inaccessibleAreas {
                    let rect = CGRect(x: area.x, y: area.y, width: area.w, height: area.h)
                    context.fill(Path(rect), with: .color(.red.opacity(0.06)))
                    context.stroke(Path(rect), with: .color(.red.opacity(0.15)), lineWidth: 1)
                }
                
                // 走廊连线
                drawCorridorEdges(context: &context, floor: vm.viewFloor)
                
                // 房间
                drawRooms(context: &context, floor: vm.viewFloor)
                
                // 路径
                drawRoute(context: &context, floor: vm.viewFloor)
                
                // 楼梯标记
                drawStairMarkers(context: &context, floor: vm.viewFloor)
                
                // 入口标记（仅1F）
                if vm.viewFloor == 1 {
                    drawEntrances(context: &context)
                }
                
                // 用户位置
                drawUserPosition(context: &context, floor: vm.viewFloor)
                
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    // MARK: - 绘制方法
    
    private func drawRooms(context: inout GraphicsContext, floor: Int) {
        let rooms = vm.rooms(for: floor)
        let isRouting = vm.mode == .route
        let destCode = vm.destinationCode
        
        for room in rooms {
            let pt = BuildingData.geoToLocal(lat: room.lat, lng: room.lng)
            let rect = CGRect(x: Double(pt.x) - room.w / 2,
                              y: Double(pt.y) - room.h / 2,
                              width: room.w, height: room.h)
            
            let isTarget = isRouting && room.code == destCode
            let fillColor: Color = isTarget ? .blue.opacity(0.3) : .cyan.opacity(0.15)
            let strokeColor: Color = isTarget ? .blue : .cyan.opacity(0.5)
            
            context.fill(Path(rect), with: .color(fillColor))
            context.stroke(Path(rect), with: .color(strokeColor), lineWidth: isTarget ? 2 : 1)
            
            // 房间号标签
            let text = Text(room.code).font(.system(size: 9, weight: .medium))
            context.draw(text, at: CGPoint(x: Double(pt.x), y: Double(pt.y)), anchor: .center)
        }
    }
    
    private func drawCorridorEdges(context: inout GraphicsContext, floor: Int) {
        let nodes = vm.corridorNodes(for: floor)
        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        
        for node in nodes {
            for link in node.links where link.kind == "corridor" {
                guard let target = nodeMap[link.to] else { continue }
                var path = Path()
                path.move(to: CGPoint(x: node.x, y: node.y))
                path.addLine(to: CGPoint(x: target.x, y: target.y))
                context.stroke(path, with: .color(.gray.opacity(0.25)), lineWidth: 2)
            }
        }
    }
    
    private func drawRoute(context: inout GraphicsContext, floor: Int) {
        let points = vm.routePoints(for: floor)
        guard points.count >= 2 else { return }
        
        var path = Path()
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        // 路径阴影
        context.stroke(path, with: .color(.blue.opacity(0.2)), lineWidth: 6)
        // 路径线
        context.stroke(path, with: .color(.blue), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        
        // 起点标记
        let startCircle = Path(ellipseIn: CGRect(x: points[0].x - 5, y: points[0].y - 5,
                                                  width: 10, height: 10))
        context.fill(startCircle, with: .color(.green))
        
        // 终点标记
        if let last = points.last {
            let endCircle = Path(ellipseIn: CGRect(x: last.x - 6, y: last.y - 6,
                                                    width: 12, height: 12))
            context.fill(endCircle, with: .color(.red))
        }
    }
    
    private func drawStairMarkers(context: inout GraphicsContext, floor: Int) {
        for stair in BuildingData.stairConnections {
            guard let pos = stair.floors[floor] else { continue }
            let rect = CGRect(x: Double(pos.x) - 8, y: Double(pos.y) - 8, width: 16, height: 16)
            context.fill(Path(rect), with: .color(.orange.opacity(0.3)))
            context.stroke(Path(rect), with: .color(.orange), lineWidth: 1.5)
            let text = Text(stair.shortLabel).font(.system(size: 7))
            context.draw(text, at: CGPoint(x: Double(pos.x), y: Double(pos.y) + 14), anchor: .center)
        }
    }
    
    private func drawEntrances(context: inout GraphicsContext) {
        for (key, entrance) in BuildingData.entrances {
            let isSelected = key == vm.selectedEntrance
            let radius: Double = isSelected ? 8 : 6
            let circle = Path(ellipseIn: CGRect(x: entrance.x - radius, y: entrance.y - radius,
                                                 width: radius * 2, height: radius * 2))
            context.fill(circle, with: .color(isSelected ? .green : .green.opacity(0.4)))
            context.stroke(circle, with: .color(.green.opacity(0.8)), lineWidth: 1.5)
            let text = Text(entrance.hint).font(.system(size: 8, weight: .bold))
            context.draw(text, at: CGPoint(x: entrance.x, y: entrance.y - radius - 6), anchor: .center)
        }
    }
    
    private func drawUserPosition(context: inout GraphicsContext, floor: Int) {
        guard floor == vm.sensorFloor, let pos = vm.userLocalPosition else { return }
        
        // 检查是否在地图范围内
        guard pos.x >= 0 && pos.x <= mapSize.width && pos.y >= 0 && pos.y <= mapSize.height else { return }
        
        // 外圈（精度光晕）
        let outerR: Double = 14
        let outerCircle = Path(ellipseIn: CGRect(x: pos.x - outerR, y: pos.y - outerR,
                                                   width: outerR * 2, height: outerR * 2))
        context.fill(outerCircle, with: .color(.blue.opacity(0.18)))
        
        // 方向箭头（如果有指南针数据）
        if let heading = vm.userHeading {
            let arrowLen: Double = 14
            // heading 是相对于正北的角度，需映射到画布（画布 y 轴向下，正北 = 上 = -y 方向）
            let rad = heading * .pi / 180
            let tip = CGPoint(x: pos.x + arrowLen * sin(rad), y: pos.y - arrowLen * cos(rad))
            var arrowPath = Path()
            arrowPath.move(to: pos)
            arrowPath.addLine(to: tip)
            context.stroke(arrowPath, with: .color(.blue.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            // 箭头尖端小三角
            let sideLen: Double = 4
            let rad1 = (heading + 140) * .pi / 180
            let rad2 = (heading - 140) * .pi / 180
            var triangle = Path()
            triangle.move(to: tip)
            triangle.addLine(to: CGPoint(x: tip.x + sideLen * sin(rad1), y: tip.y - sideLen * cos(rad1)))
            triangle.addLine(to: CGPoint(x: tip.x + sideLen * sin(rad2), y: tip.y - sideLen * cos(rad2)))
            triangle.closeSubpath()
            context.fill(triangle, with: .color(.blue))
        }
        
        // 内圈（用户点）
        let innerR: Double = 6
        let innerCircle = Path(ellipseIn: CGRect(x: pos.x - innerR, y: pos.y - innerR,
                                                   width: innerR * 2, height: innerR * 2))
        context.fill(innerCircle, with: .color(.blue))
        context.stroke(innerCircle, with: .color(.white), lineWidth: 2)
    }
}

// MARK: - 卫星地图底图

/// 使用 MapKit 显示建筑中心区域的卫星影像
struct SatelliteMapLayer: View {
    private let center = BuildingData.geoReference.centerCoordinate
    // 地图覆盖范围 ≈ 建筑尺寸（米）再加少量边距
    private let spanMeters: Double = max(BuildingData.mapConfig.width, BuildingData.mapConfig.height)
        / BuildingData.geoReference.unitsPerMeter * 1.2
    
    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: center,
            latitudinalMeters: spanMeters,
            longitudinalMeters: spanMeters * (BuildingData.mapConfig.width / BuildingData.mapConfig.height)
        ))) {
        }
        .mapStyle(.imagery)
        .disabled(true)        // 禁止手势干扰
        .allowsHitTesting(false)
    }
}
