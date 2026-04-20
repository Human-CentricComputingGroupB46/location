import Foundation

// MARK: - 图节点

struct GraphNode {
    let id: String
    let x: Double
    let y: Double
    let floor: Int
    let kind: String           // entrance | service | corridor | room | stair
    let label: String?
    let roomCode: String?      // 仅 kind == "room"
    let stairGroup: String?    // 仅 kind == "stair"
}

// MARK: - 图边

struct GraphEdge {
    let to: String
    let weight: Double
}

// MARK: - 路径结果

struct RouteResult {
    let path: [String]
    let distance: Double
    
    /// 基于 unitsPerMeter 估算的实际距离（米）
    var distanceMeters: Double {
        distance / BuildingData.geoReference.unitsPerMeter
    }
    
    /// 基于步行速度估算时间（秒）
    var estimatedTimeSeconds: Double {
        distanceMeters / BuildingData.sensorConfig.walkingSpeedMps
    }
}

/// 路径中的步骤提示
struct RouteStep: Identifiable {
    let id = UUID()
    let text: String
}

// MARK: - 导航图

final class NavigationGraph {
    
    private(set) var nodes: [String: GraphNode] = [:]
    private(set) var edges: [String: [GraphEdge]] = [:]
    private var linkedPairs: Set<String> = []
    
    init() {
        build()
    }
    
    // MARK: Dijkstra 最短路径
    
    func findRoute(from startId: String, to endId: String) -> RouteResult? {
        guard nodes[startId] != nil, nodes[endId] != nil else { return nil }
        
        var dist: [String: Double] = [:]
        var prev: [String: String] = [:]
        var visited: Set<String> = []
        
        // 简易优先队列 (id, distance)
        var pq: [(String, Double)] = []
        
        for id in nodes.keys { dist[id] = .infinity }
        dist[startId] = 0
        pq.append((startId, 0))
        
        while !pq.isEmpty {
            pq.sort { $0.1 < $1.1 }
            let (u, d) = pq.removeFirst()
            if visited.contains(u) { continue }
            visited.insert(u)
            if u == endId { break }
            
            for edge in edges[u] ?? [] {
                if visited.contains(edge.to) { continue }
                let nd = d + edge.weight
                if nd < (dist[edge.to] ?? .infinity) {
                    dist[edge.to] = nd
                    prev[edge.to] = u
                    pq.append((edge.to, nd))
                }
            }
        }
        
        guard let endDist = dist[endId], endDist < .infinity else { return nil }
        
        var path: [String] = []
        var cur: String? = endId
        while let c = cur {
            path.insert(c, at: 0)
            cur = prev[c]
        }
        
        return RouteResult(path: path, distance: endDist)
    }
    
    // MARK: 路线描述步骤
    
    func routeSteps(route: RouteResult, entranceLabel: String, destCode: String) -> [RouteStep] {
        var steps: [RouteStep] = []
        let destFloor = BuildingData.floorForRoom(destCode)
        let floorLabel = destFloor.map { " (\($0)F)" } ?? ""
        
        steps.append(RouteStep(text: "从 \(entranceLabel) (1F) 出发"))
        
        var currentFloor = 1
        var seen: Set<String> = []
        
        for nodeId in route.path {
            // 楼梯节点: STAIR-XX-F#
            if let match = nodeId.range(of: #"^STAIR-(\w+)-F(\d+)$"#, options: .regularExpression) {
                let parts = nodeId[match].split(separator: "-")
                if parts.count >= 3, let stairFloor = Int(parts.last!.dropFirst()) {
                    let stairName = String(parts[1])
                    let stairConn = BuildingData.stairConnections.first { $0.id == "STAIR-\(stairName)" }
                    let stairLabel = stairConn?.label ?? "\(stairName) Staircase"
                    
                    if stairFloor != currentFloor {
                        let direction = stairFloor > currentFloor ? "上行" : "下行"
                        steps.append(RouteStep(text: "经 \(stairLabel) \(direction)，从 \(currentFloor)F 到 \(stairFloor)F"))
                        currentFloor = stairFloor
                        continue
                    }
                    if !seen.contains(nodeId) {
                        steps.append(RouteStep(text: "在 \(stairLabel) (\(currentFloor)F)"))
                        seen.insert(nodeId)
                    }
                    continue
                }
            }
            
            // 其他有标签的非房间节点
            if let node = nodes[nodeId], let label = node.label, node.kind != "room", !seen.contains(nodeId) {
                steps.append(RouteStep(text: "经过 \(label)"))
                seen.insert(nodeId)
            }
        }
        
        steps.append(RouteStep(text: "到达 \(destCode)\(floorLabel)"))
        return steps
    }
    
    // MARK: - 图构建
    
    private func build() {
        // 1F 入口
        for entrance in BuildingData.entrances.values {
            addNode(GraphNode(id: entrance.id, x: entrance.x, y: entrance.y, floor: 1,
                              kind: "entrance", label: entrance.label, roomCode: nil, stairGroup: nil))
        }
        
        // 1F 服务点
        for sp in BuildingData.servicePoints {
            addNode(GraphNode(id: sp.id, x: sp.x, y: sp.y, floor: 1,
                              kind: "service", label: sp.label, roomCode: nil, stairGroup: nil))
        }
        
        // 各楼层走廊节点
        for floor in BuildingData.allFloors {
            for wn in BuildingData.walkableNodes(for: floor) {
                addNode(GraphNode(id: wn.id, x: wn.x, y: wn.y, floor: floor,
                                  kind: "corridor", label: wn.label, roomCode: nil, stairGroup: nil))
            }
        }
        
        // 各楼层房间节点
        for floor in BuildingData.allFloors {
            for room in BuildingData.roomsByFloor[floor] ?? [] {
                let pt = BuildingData.geoToLocal(lat: room.lat, lng: room.lng)
                addNode(GraphNode(id: "ROOM-\(room.code)", x: Double(pt.x), y: Double(pt.y),
                                  floor: floor, kind: "room", label: room.code,
                                  roomCode: room.code, stairGroup: nil))
            }
        }
        
        // 楼梯节点 + 垂直边
        for stair in BuildingData.stairConnections {
            let floorNums = stair.floors.keys.sorted()
            
            for floor in floorNums {
                guard let pos = stair.floors[floor] else { continue }
                let nodeId = BuildingData.stairNodeId(stair.id, floor: floor)
                let peerLinks = stair.peerLinks[floor] ?? []
                addNode(GraphNode(id: nodeId, x: Double(pos.x), y: Double(pos.y),
                                  floor: floor, kind: "stair",
                                  label: "\(stair.label) (\(floor)F)",
                                  roomCode: nil, stairGroup: stair.id))
                // 连接楼梯到同层节点
                for peerLink in peerLinks {
                    link(nodeId, peerLink.to)
                }
            }
            
            // 垂直边（相邻楼层间）
            for i in 0..<floorNums.count - 1 {
                let lower = floorNums[i]
                let upper = floorNums[i + 1]
                let floorsTraversed = Double(upper - lower)
                link(BuildingData.stairNodeId(stair.id, floor: lower),
                     BuildingData.stairNodeId(stair.id, floor: upper),
                     weight: stair.cost * floorsTraversed)
            }
        }
        
        // 连接所有节点的 links
        for entrance in BuildingData.entrances.values {
            for l in entrance.links { link(entrance.id, l.to) }
        }
        for sp in BuildingData.servicePoints {
            for l in sp.links { link(sp.id, l.to) }
        }
        for floor in BuildingData.allFloors {
            for wn in BuildingData.walkableNodes(for: floor) {
                for l in wn.links { link(wn.id, l.to) }
            }
            for room in BuildingData.roomsByFloor[floor] ?? [] {
                for l in room.links { link("ROOM-\(room.code)", l.to) }
            }
        }
    }
    
    private func addNode(_ node: GraphNode) {
        nodes[node.id] = node
        if edges[node.id] == nil { edges[node.id] = [] }
    }
    
    private func link(_ a: String, _ b: String, weight: Double? = nil) {
        let pairKey = [a, b].sorted().joined(separator: "::")
        guard !linkedPairs.contains(pairKey) else { return }
        guard let na = nodes[a], let nb = nodes[b] else { return }
        
        let w = weight ?? hypot(na.x - nb.x, na.y - nb.y)
        edges[a, default: []].append(GraphEdge(to: b, weight: w))
        edges[b, default: []].append(GraphEdge(to: a, weight: w))
        linkedPairs.insert(pairKey)
    }
}
