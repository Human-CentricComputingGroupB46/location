import Foundation
import Combine
import CoreLocation

// ViewModel（Controller 角色），处理业务逻辑和视图绑定
class LocationViewModel: ObservableObject {
    // 气压 & 楼层数据
    @Published var floorChange: Int = 0
    @Published var relativeAltitudeStr: String = "未知"
    @Published var pressureStr: String = "未知"
    
    // GPS 数据
    @Published var gpsLocationStr: String = "未获取定位"
    @Published var gpsInitialAltitudeStr: String = "未知"
    
    // 加速度及位移数据
    @Published var displacementStr: String = "0.00 米"
    
    // Models（核心数据）
    private var barometerManager = BarometerManager()
    private var locationManager = LocationManager()
    private var accelerometerManager = AccelerometerManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        bindBarometer()
        bindLocation()
        bindAccelerometer()
    }
    
    private func bindBarometer() {
        barometerManager.$floorCount
            .receive(on: RunLoop.main)
            .assign(to: \.floorChange, on: self)
            .store(in: &cancellables)
            
        barometerManager.$relativeAltitude
            .receive(on: RunLoop.main)
            .map { alt -> String in
                guard let altStr = alt else { return "未知" }
                return String(format: "%.2f 米", altStr)
            }
            .assign(to: \.relativeAltitudeStr, on: self)
            .store(in: &cancellables)
            
        barometerManager.$pressure
            .receive(on: RunLoop.main)
            .map { p -> String in
                guard let pressure = p else { return "未知" }
                return String(format: "%.2f kPa", pressure)
            }
            .assign(to: \.pressureStr, on: self)
            .store(in: &cancellables)
    }
    
    private func bindLocation() {
        locationManager.$lastLocation
            .receive(on: RunLoop.main)
            .map { location -> String in
                guard let loc = location else { return "未获取定位" }
                return String(format: "Lat: %.4f, Lon: %.4f", loc.coordinate.latitude, loc.coordinate.longitude)
            }
            .assign(to: \.gpsLocationStr, on: self)
            .store(in: &cancellables)
            
        locationManager.$initialAltitude
            .receive(on: RunLoop.main)
            .map { alt -> String in
                guard let altitude = alt else { return "未知" }
                return String(format: "%.2f 米", altitude)
            }
            .assign(to: \.gpsInitialAltitudeStr, on: self)
            .store(in: &cancellables)
    }
    
    private func bindAccelerometer() {
        accelerometerManager.$distance
            .receive(on: RunLoop.main)
            .map { dist -> String in
                return String(format: "%.2f 米", dist)
            }
            .assign(to: \.displacementStr, on: self)
            .store(in: &cancellables)
    }
    
    // ====== 统一启动与停止 =======
    
    func startAllTracking() {
        barometerManager.startUpdates()
        locationManager.startUpdating()
        accelerometerManager.startUpdates()
    }
    
    func stopAllTracking() {
        barometerManager.stopUpdates()
        locationManager.stopUpdating()
        accelerometerManager.stopUpdates()
    }
}