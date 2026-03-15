import Foundation
import CoreLocation
import Combine

// 管理GPS定位信息
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    // GPS 原始定位数据（经纬度）
    @Published var lastLocation: CLLocation?
    
    // GPS 初始绝对高度
    @Published var initialAltitude: Double?
    
    override init() {
        super.init()
        manager.delegate = self
        // 提高定位精度以获得更准确的初始高度
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 记录最新定位
        lastLocation = location
        
        // 如果还没有记录初始高度，则记录第一次有效的高度数据
        if initialAltitude == nil && location.verticalAccuracy > 0 {
            initialAltitude = location.altitude
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
