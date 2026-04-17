import Foundation
import CoreLocation
import Combine

// 管理GPS定位信息
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    // GPS 原始定位数据（经纬度）
    @Published var lastLocation: CLLocation?
    // 初始空间点（使用 CLLocation 存储包含海拔的三维信息）
    @Published var initialLocation: CLLocation?
    // 当前空间点
    @Published var currentLocation: CLLocation?
    // 起点到当前位置的欧氏距离（米）
    @Published var distanceFromStart: Double = 0.0
    // 指南针/磁场方向数据（用于提供给加速度等其他模块判断移动方向）
    @Published var currentHeading: CLHeading?
    
    override init() {
        super.init()
        manager.delegate = self
        // 提高定位精度以获得更准确的初始高度
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = kCLHeadingFilterNone // 任何角度变化都通知，或者可以设置小角度如 1.0
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        currentLocation = location
        
        // 记录初始空间点，要求垂直精度有效（>0表示数据可信）
        if initialLocation == nil && location.verticalAccuracy > 0 {
            initialLocation = location
        }
        
        // 计算欧氏距离
        if let start = initialLocation {
            distanceFromStart = LocationManager.euclideanDistance(from: start, to: location)
        }
    }

    /// 计算空间两点的欧氏距离（单位：米）
    static func euclideanDistance(from: CLLocation, to: CLLocation) -> Double {
        // 经纬度转为弧度
        let lat1 = from.coordinate.latitude * .pi / 180
        let lon1 = from.coordinate.longitude * .pi / 180
        let lat2 = to.coordinate.latitude * .pi / 180
        let lon2 = to.coordinate.longitude * .pi / 180
        // 地球半径（米）
        let R = 6371000.0
        // 水平距离（Haversine公式）
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        let horizontal = R * c
        // 垂直距离
        let dz = to.altitude - from.altitude
        // 三维欧氏距离
        return sqrt(horizontal * horizontal + dz * dz)
    }
    
    // 获取指南针朝向数据
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // newHeading.trueHeading 或 newHeading.magneticHeading 都可以用来表示朝向
        // 其中 trueHeading 是地理正北方向（需开启GPS定位配合计算磁偏角），为负数时代表数据无效
        currentHeading = newHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
