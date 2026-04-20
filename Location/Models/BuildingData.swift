import Foundation
import CoreLocation

// MARK: - 基础数据类型

/// 图中节点间的边描述
struct LinkDescriptor: Identifiable {
    let id = UUID()
    let to: String
    let kind: String
}

/// 入口
struct Entrance: Identifiable {
    let id: String       // 图节点 ID, e.g. "NW-ENTRY"
    let label: String    // 英文标签
    let x: Double        // 室内叠加层局部坐标
    let y: Double
    let hint: String     // 中文提示
    let links: [LinkDescriptor]
}

/// 服务点（电梯/楼梯旁）
struct ServicePoint: Identifiable {
    let id: String
    let label: String
    let x: Double
    let y: Double
    let entrance: String // 属于哪个入口
    let links: [LinkDescriptor]
}

/// 走廊/走道节点
struct WalkableNode: Identifiable {
    let id: String
    let x: Double
    let y: Double
    let label: String?
    let links: [LinkDescriptor]
}

/// 楼梯连接
struct StairConnection: Identifiable {
    let id: String              // e.g. "STAIR-NW"
    let label: String           // 显示名称
    let shortLabel: String      // 地图上的简短标签
    let floors: [Int: CGPoint]  // 楼层 → 局部坐标
    let cost: Double            // 每层的额外边权
    let peerLinks: [Int: [LinkDescriptor]]  // 楼层 → 连接到的走廊节点
}

/// 房间
struct Room: Identifiable {
    let id = UUID()
    let code: String
    let lat: Double
    let lng: Double
    let w: Double
    let h: Double
    let zone: String
    let links: [LinkDescriptor]
    let note: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

/// 不可通行区域
struct InaccessibleArea: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let label: String
}

// MARK: - 地理参考 & 地图配置

struct GeoReference {
    let centerLat: Double
    let centerLng: Double
    let unitsPerMeter: Double
    
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
    }
}

struct MapConfig {
    let width: Double
    let height: Double
}

struct SensorConfig {
    let floorHeightMeters: Double
    let baseFloor: Int
    let walkingSpeedMps: Double
}

// MARK: - EB 建筑数据（从 web_code/data.js 移植）

enum BuildingData {
    
    static let mapConfig = MapConfig(width: 1000, height: 640)
    
    static let geoReference = GeoReference(
        centerLat: 31.274397972,
        centerLng: 120.737789434,
        unitsPerMeter: 10
    )
    
    static let sensorConfig = SensorConfig(
        floorHeightMeters: 3.0,
        baseFloor: 1,
        walkingSpeedMps: 1.2
    )
    
    static let allFloors: [Int] = [1, 2, 3]
    
    // MARK: 入口
    
    static let entrances: [String: Entrance] = [
        "NW": Entrance(id: "NW-ENTRY", label: "North-West Entrance", x: 110, y: 125,
                       hint: "西北入口", links: [LinkDescriptor(to: "NW-HUB", kind: "connector")]),
        "NE": Entrance(id: "NE-ENTRY", label: "North-East Entrance", x: 910, y: 125,
                       hint: "东北入口", links: [LinkDescriptor(to: "NE-HUB", kind: "connector")]),
        "SW": Entrance(id: "SW-ENTRY", label: "South-West Entrance", x: 110, y: 570,
                       hint: "西南入口", links: []),
    ]
    
    // MARK: 服务点
    
    static let servicePoints: [ServicePoint] = [
        ServicePoint(id: "NW-SERVICE", label: "Lift / Stair", x: 135, y: 170, entrance: "NW",
                     links: [LinkDescriptor(to: "NW-HUB", kind: "connector"), LinkDescriptor(to: "STAIR-NW-F1", kind: "stair")]),
        ServicePoint(id: "NE-SERVICE", label: "Lift / Stair", x: 875, y: 170, entrance: "NE",
                     links: [LinkDescriptor(to: "NE-HUB", kind: "connector"), LinkDescriptor(to: "STAIR-NE-F1", kind: "stair")]),
        ServicePoint(id: "SW-SERVICE", label: "Lift / Stair", x: 150, y: 540, entrance: "SW",
                     links: [LinkDescriptor(to: "STAIR-SW-F1", kind: "stair")]),
    ]
    
    // MARK: 楼梯
    
    static let stairConnections: [StairConnection] = [
        StairConnection(
            id: "STAIR-NW", label: "NW Staircase", shortLabel: "NW Stair",
            floors: [1: CGPoint(x: 135, y: 180), 2: CGPoint(x: 135, y: 180), 3: CGPoint(x: 135, y: 180)],
            cost: 60,
            peerLinks: [
                1: [LinkDescriptor(to: "NW-HUB", kind: "stair"), LinkDescriptor(to: "NW-SERVICE", kind: "stair")],
                2: [LinkDescriptor(to: "F2-NW-HUB", kind: "stair")],
                3: [LinkDescriptor(to: "F3-NW-HUB", kind: "stair")],
            ]
        ),
        StairConnection(
            id: "STAIR-NE", label: "NE Staircase", shortLabel: "NE Stair",
            floors: [1: CGPoint(x: 875, y: 180), 2: CGPoint(x: 875, y: 180), 3: CGPoint(x: 875, y: 180)],
            cost: 60,
            peerLinks: [
                1: [LinkDescriptor(to: "NE-HUB", kind: "stair"), LinkDescriptor(to: "NE-SERVICE", kind: "stair")],
                2: [LinkDescriptor(to: "F2-NE-HUB", kind: "stair")],
                3: [LinkDescriptor(to: "F3-NE-HUB", kind: "stair")],
            ]
        ),
        StairConnection(
            id: "STAIR-SW", label: "SW Staircase", shortLabel: "SW Stair",
            floors: [1: CGPoint(x: 150, y: 550), 2: CGPoint(x: 150, y: 550)],
            cost: 60,
            peerLinks: [
                1: [LinkDescriptor(to: "SW-SERVICE", kind: "stair")],
                2: [],
            ]
        ),
    ]
    
    // MARK: 走廊节点（1楼）
    
    static let walkableNodesFloor1: [WalkableNode] = [
        WalkableNode(id: "NW-HUB", x: 145, y: 160, label: "NW hub", links: [
            LinkDescriptor(to: "NW-ENTRY", kind: "connector"), LinkDescriptor(to: "NW-SERVICE", kind: "connector"), LinkDescriptor(to: "NORTH-139", kind: "corridor")]),
        WalkableNode(id: "NORTH-139", x: 200, y: 160, label: nil, links: [
            LinkDescriptor(to: "NW-HUB", kind: "corridor"), LinkDescriptor(to: "NORTH-133", kind: "corridor"), LinkDescriptor(to: "ROOM-EB139", kind: "room")]),
        WalkableNode(id: "NORTH-133", x: 255, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-139", kind: "corridor"), LinkDescriptor(to: "NORTH-131", kind: "corridor"), LinkDescriptor(to: "ROOM-EB133", kind: "room")]),
        WalkableNode(id: "NORTH-131", x: 320, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-133", kind: "corridor"), LinkDescriptor(to: "NORTH-119", kind: "corridor"), LinkDescriptor(to: "ROOM-EB131", kind: "room")]),
        WalkableNode(id: "NORTH-119", x: 390, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-131", kind: "corridor"), LinkDescriptor(to: "NORTH-115", kind: "corridor"), LinkDescriptor(to: "ROOM-EB119", kind: "room")]),
        WalkableNode(id: "NORTH-115", x: 455, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-119", kind: "corridor"), LinkDescriptor(to: "NORTH-111", kind: "corridor"), LinkDescriptor(to: "ROOM-EB115", kind: "room")]),
        WalkableNode(id: "NORTH-111", x: 520, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-115", kind: "corridor"), LinkDescriptor(to: "NORTH-132", kind: "corridor"), LinkDescriptor(to: "ROOM-EB111", kind: "room")]),
        WalkableNode(id: "NORTH-132", x: 585, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-111", kind: "corridor"), LinkDescriptor(to: "NORTH-136", kind: "corridor"), LinkDescriptor(to: "ROOM-EB132", kind: "room")]),
        WalkableNode(id: "NORTH-136", x: 650, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-132", kind: "corridor"), LinkDescriptor(to: "EB138-SMALL-DOOR", kind: "doorway"),
            LinkDescriptor(to: "NORTH-104", kind: "corridor"), LinkDescriptor(to: "ROOM-EB136", kind: "room")]),
        WalkableNode(id: "EB138-SMALL-DOOR", x: 610, y: 315, label: "EB138 小门", links: [
            LinkDescriptor(to: "NORTH-136", kind: "doorway"), LinkDescriptor(to: "ROOM-EB138", kind: "room")]),
        WalkableNode(id: "NORTH-104", x: 760, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-136", kind: "corridor"), LinkDescriptor(to: "NORTH-102", kind: "corridor"), LinkDescriptor(to: "ROOM-EB104", kind: "room")]),
        WalkableNode(id: "NORTH-102", x: 830, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-104", kind: "corridor"), LinkDescriptor(to: "NORTH-106", kind: "doorway"),
            LinkDescriptor(to: "NORTH-155", kind: "corridor"), LinkDescriptor(to: "ROOM-EB102", kind: "room")]),
        WalkableNode(id: "NORTH-106", x: 830, y: 205, label: nil, links: [
            LinkDescriptor(to: "NORTH-102", kind: "doorway"), LinkDescriptor(to: "ROOM-EB106", kind: "room")]),
        WalkableNode(id: "NORTH-155", x: 875, y: 160, label: nil, links: [
            LinkDescriptor(to: "NORTH-102", kind: "corridor"), LinkDescriptor(to: "NE-HUB", kind: "corridor"), LinkDescriptor(to: "ROOM-EB155", kind: "room")]),
        WalkableNode(id: "NORTH-161", x: 925, y: 160, label: nil, links: [
            LinkDescriptor(to: "NE-HUB", kind: "corridor"), LinkDescriptor(to: "ROOM-EB161", kind: "room")]),
        WalkableNode(id: "NE-HUB", x: 890, y: 160, label: "NE hub", links: [
            LinkDescriptor(to: "NE-ENTRY", kind: "connector"), LinkDescriptor(to: "NE-SERVICE", kind: "connector"),
            LinkDescriptor(to: "NORTH-155", kind: "corridor"), LinkDescriptor(to: "NORTH-161", kind: "corridor")]),
    ]
    
    // MARK: 走廊节点（2楼）
    
    static let walkableNodesFloor2: [WalkableNode] = [
        WalkableNode(id: "F2-NW-HUB", x: 145, y: 160, label: "2F NW hub", links: [
            LinkDescriptor(to: "STAIR-NW-F2", kind: "stair"), LinkDescriptor(to: "F2-NORTH-201", kind: "corridor")]),
        WalkableNode(id: "F2-NORTH-201", x: 250, y: 160, label: nil, links: [
            LinkDescriptor(to: "F2-NW-HUB", kind: "corridor"), LinkDescriptor(to: "F2-NORTH-203", kind: "corridor"), LinkDescriptor(to: "ROOM-EB201", kind: "room")]),
        WalkableNode(id: "F2-NORTH-203", x: 350, y: 160, label: nil, links: [
            LinkDescriptor(to: "F2-NORTH-201", kind: "corridor"), LinkDescriptor(to: "F2-NORTH-205", kind: "corridor"), LinkDescriptor(to: "ROOM-EB203", kind: "room")]),
        WalkableNode(id: "F2-NORTH-205", x: 450, y: 160, label: nil, links: [
            LinkDescriptor(to: "F2-NORTH-203", kind: "corridor"), LinkDescriptor(to: "F2-NORTH-207", kind: "corridor"), LinkDescriptor(to: "ROOM-EB205", kind: "room")]),
        WalkableNode(id: "F2-NORTH-207", x: 550, y: 160, label: nil, links: [
            LinkDescriptor(to: "F2-NORTH-205", kind: "corridor"), LinkDescriptor(to: "F2-NORTH-204", kind: "corridor"), LinkDescriptor(to: "ROOM-EB207", kind: "room")]),
        WalkableNode(id: "F2-NORTH-204", x: 650, y: 160, label: nil, links: [
            LinkDescriptor(to: "F2-NORTH-207", kind: "corridor"), LinkDescriptor(to: "F2-NORTH-202", kind: "corridor"), LinkDescriptor(to: "ROOM-EB204", kind: "room")]),
        WalkableNode(id: "F2-NORTH-202", x: 760, y: 160, label: nil, links: [
            LinkDescriptor(to: "F2-NORTH-204", kind: "corridor"), LinkDescriptor(to: "F2-NE-HUB", kind: "corridor"), LinkDescriptor(to: "ROOM-EB202", kind: "room")]),
        WalkableNode(id: "F2-NE-HUB", x: 890, y: 160, label: "2F NE hub", links: [
            LinkDescriptor(to: "STAIR-NE-F2", kind: "stair"), LinkDescriptor(to: "F2-NORTH-202", kind: "corridor")]),
    ]
    
    // MARK: 走廊节点（3楼）
    
    static let walkableNodesFloor3: [WalkableNode] = [
        WalkableNode(id: "F3-NW-HUB", x: 145, y: 160, label: "3F NW hub", links: [
            LinkDescriptor(to: "STAIR-NW-F3", kind: "stair"), LinkDescriptor(to: "F3-NORTH-301", kind: "corridor")]),
        WalkableNode(id: "F3-NORTH-301", x: 300, y: 160, label: nil, links: [
            LinkDescriptor(to: "F3-NW-HUB", kind: "corridor"), LinkDescriptor(to: "F3-NORTH-303", kind: "corridor"), LinkDescriptor(to: "ROOM-EB301", kind: "room")]),
        WalkableNode(id: "F3-NORTH-303", x: 500, y: 160, label: nil, links: [
            LinkDescriptor(to: "F3-NORTH-301", kind: "corridor"), LinkDescriptor(to: "F3-NE-HUB", kind: "corridor"), LinkDescriptor(to: "ROOM-EB303", kind: "room")]),
        WalkableNode(id: "F3-NE-HUB", x: 890, y: 160, label: "3F NE hub", links: [
            LinkDescriptor(to: "STAIR-NE-F3", kind: "stair"), LinkDescriptor(to: "F3-NORTH-303", kind: "corridor")]),
    ]
    
    /// 按楼层获取走廊节点
    static func walkableNodes(for floor: Int) -> [WalkableNode] {
        switch floor {
        case 1: return walkableNodesFloor1
        case 2: return walkableNodesFloor2
        case 3: return walkableNodesFloor3
        default: return []
        }
    }
    
    // MARK: 房间数据
    
    static let roomsByFloor: [Int: [Room]] = [
        1: [
            Room(code: "EB139", lat: 31.274629984, lng: 120.737465674, w: 90, h: 56, zone: "north", links: [LinkDescriptor(to: "NORTH-139", kind: "room")], note: nil),
            Room(code: "EB133", lat: 31.274629094, lng: 120.737566070, w: 90, h: 56, zone: "north", links: [LinkDescriptor(to: "NORTH-133", kind: "room")], note: nil),
            Room(code: "EB131", lat: 31.274621993, lng: 120.737677663, w: 96, h: 64, zone: "north", links: [LinkDescriptor(to: "NORTH-131", kind: "room")], note: nil),
            Room(code: "EB119", lat: 31.274618878, lng: 120.737783023, w: 88, h: 56, zone: "north", links: [LinkDescriptor(to: "NORTH-119", kind: "room")], note: nil),
            Room(code: "EB115", lat: 31.274618868, lng: 120.737890016, w: 88, h: 56, zone: "north", links: [LinkDescriptor(to: "NORTH-115", kind: "room")], note: nil),
            Room(code: "EB111", lat: 31.274618563, lng: 120.738002523, w: 88, h: 56, zone: "north", links: [LinkDescriptor(to: "NORTH-111", kind: "room")], note: nil),
            Room(code: "EB132", lat: 31.274479740, lng: 120.737592668, w: 92, h: 56, zone: "north", links: [LinkDescriptor(to: "NORTH-132", kind: "room")], note: nil),
            Room(code: "EB136", lat: 31.274484053, lng: 120.737483411, w: 115, h: 92, zone: "north", links: [LinkDescriptor(to: "NORTH-136", kind: "room")], note: nil),
            Room(code: "EB138", lat: 31.274388920, lng: 120.737499193, w: 145, h: 108, zone: "north", links: [LinkDescriptor(to: "EB138-SMALL-DOOR", kind: "room")], note: "阶梯教室 / 2F连通"),
            Room(code: "EB102", lat: 31.274486460, lng: 120.738206644, w: 92, h: 56, zone: "east", links: [LinkDescriptor(to: "NORTH-102", kind: "room")], note: nil),
            Room(code: "EB104", lat: 31.274422003, lng: 120.738149586, w: 150, h: 82, zone: "east", links: [LinkDescriptor(to: "NORTH-104", kind: "room")], note: nil),
            Room(code: "EB106", lat: 31.274486926, lng: 120.738104429, w: 92, h: 56, zone: "east", links: [LinkDescriptor(to: "NORTH-106", kind: "room")], note: nil),
            Room(code: "EB155", lat: 31.274332704, lng: 120.738179733, w: 88, h: 52, zone: "east", links: [LinkDescriptor(to: "NORTH-155", kind: "room")], note: nil),
            Room(code: "EB161", lat: 31.274199055, lng: 120.738171387, w: 82, h: 54, zone: "east", links: [LinkDescriptor(to: "NORTH-161", kind: "room")], note: nil),
        ],
        2: [
            Room(code: "EB201", lat: 31.274620000, lng: 120.737540000, w: 90, h: 56, zone: "north", links: [LinkDescriptor(to: "F2-NORTH-201", kind: "room")], note: nil),
            Room(code: "EB203", lat: 31.274620000, lng: 120.737700000, w: 90, h: 56, zone: "north", links: [LinkDescriptor(to: "F2-NORTH-203", kind: "room")], note: nil),
            Room(code: "EB205", lat: 31.274620000, lng: 120.737860000, w: 88, h: 56, zone: "north", links: [LinkDescriptor(to: "F2-NORTH-205", kind: "room")], note: nil),
            Room(code: "EB207", lat: 31.274620000, lng: 120.738020000, w: 88, h: 56, zone: "north", links: [LinkDescriptor(to: "F2-NORTH-207", kind: "room")], note: nil),
            Room(code: "EB204", lat: 31.274480000, lng: 120.737700000, w: 100, h: 60, zone: "north", links: [LinkDescriptor(to: "F2-NORTH-204", kind: "room")], note: "大教室"),
            Room(code: "EB202", lat: 31.274480000, lng: 120.738150000, w: 92, h: 56, zone: "east", links: [LinkDescriptor(to: "F2-NORTH-202", kind: "room")], note: nil),
        ],
        3: [
            Room(code: "EB301", lat: 31.274620000, lng: 120.737620000, w: 100, h: 60, zone: "north", links: [LinkDescriptor(to: "F3-NORTH-301", kind: "room")], note: nil),
            Room(code: "EB303", lat: 31.274620000, lng: 120.737900000, w: 100, h: 60, zone: "north", links: [LinkDescriptor(to: "F3-NORTH-303", kind: "room")], note: nil),
        ],
    ]
    
    static let inaccessibleAreas: [InaccessibleArea] = [
        InaccessibleArea(x: 95, y: 330, w: 815, h: 235, label: "不可通行"),
        InaccessibleArea(x: 95, y: 265, w: 360, h: 55, label: "无走廊"),
        InaccessibleArea(x: 810, y: 330, w: 120, h: 150, label: "无走廊"),
    ]
    
    // MARK: - 查询辅助
    
    /// 获取所有房间号（按楼层排序）
    static func allRoomCodes() -> [String] {
        allFloors.flatMap { roomsByFloor[$0] ?? [] }.map(\.code).sorted()
    }
    
    /// 查找房间所在楼层
    static func floorForRoom(_ code: String) -> Int? {
        for (floor, rooms) in roomsByFloor {
            if rooms.contains(where: { $0.code == code }) { return floor }
        }
        return nil
    }
    
    /// 查找房间对象
    static func room(byCode code: String) -> Room? {
        for rooms in roomsByFloor.values {
            if let found = rooms.first(where: { $0.code == code }) { return found }
        }
        return nil
    }
    
    /// 楼梯节点 ID
    static func stairNodeId(_ stairId: String, floor: Int) -> String {
        "\(stairId)-F\(floor)"
    }
    
    // MARK: - 坐标转换
    
    /// 局部坐标 → 经纬度
    static func localToGeo(x: Double, y: Double) -> CLLocationCoordinate2D {
        let latMeters = (mapConfig.height / 2 - y) / geoReference.unitsPerMeter
        let lngMeters = (x - mapConfig.width / 2) / geoReference.unitsPerMeter
        let lat = geoReference.centerLat + latMeters / 111320
        let lng = geoReference.centerLng + lngMeters / (111320 * cos(geoReference.centerLat * .pi / 180))
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    /// 经纬度 → 局部坐标
    static func geoToLocal(lat: Double, lng: Double) -> CGPoint {
        let latMeters = (lat - geoReference.centerLat) * 111320
        let lngMeters = (lng - geoReference.centerLng) * 111320 * cos(geoReference.centerLat * .pi / 180)
        let x = mapConfig.width / 2 + lngMeters * geoReference.unitsPerMeter
        let y = mapConfig.height / 2 - latMeters * geoReference.unitsPerMeter
        return CGPoint(x: x, y: y)
    }
}
