import Foundation
import Combine
import CoreLocation

// ViewModel（Controller 角色），处理业务逻辑和视图绑定
class LocationViewModel: ObservableObject {
    // 气压 & 楼层数据
    @Published var floorChange: Int = 0
    @Published var relativeAltitudeStr: String = "未知"
    @Published var altitudeFromSurfaceStr: String = "未知" // 新增地表高度估算
    @Published var absoluteAltitudeStr: String = "未知"    // 新增系统绝对海拔
    @Published var pressureStr: String = "未知"
    
    // GPS 数据
    @Published var gpsLocationStr: String = "未获取定位"
    @Published var gpsInitialAltitudeStr: String = "未知"
    @Published var gpsDistanceStr: String = "0.00 米" // 空间欧氏距离
    
    // 网络与气象数据
    @Published var weatherSurfacePressureStr: String = "未知"
    
    // 加速度及位移数据
    @Published var displacementStr: String = "0.00 米" // 一维位移估算
    @Published var distance3DStr: String = "0.00 米"   // 加速度三维空间距离估算
    
    // Models（核心数据）
    private var barometerManager = BarometerManager()
    private var locationManager = LocationManager()
    let accelerometerManager = AccelerometerManager() // 暴露给外部图表使用
    private var networkManager = NetworkManager()
    
    /// 导航模块需要访问的传感器引用
    var barometerManagerRef: BarometerManager { barometerManager }
    var locationManagerRef: LocationManager { locationManager }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        bindBarometer()
        bindLocation()
        bindAccelerometer()
        bindNetwork()
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
            
        barometerManager.$altitudeFromSurface
            .receive(on: RunLoop.main)
            .map { alt -> String in
                guard let altStr = alt else { return "需等待地表气压数据" }
                return String(format: "%.2f 米", altStr)
            }
            .assign(to: \.altitudeFromSurfaceStr, on: self)
            .store(in: &cancellables)
            
        barometerManager.$absoluteAltitude
            .receive(on: RunLoop.main)
            .map { alt -> String in
                guard let altStr = alt else { return "未获取到绝对气压高度" }
                return String(format: "%.2f 米", altStr)
            }
            .assign(to: \.absoluteAltitudeStr, on: self)
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
        locationManager.$currentHeading
            .receive(on: RunLoop.main)
            .sink { [weak self] heading in
                guard let self = self, let heading = heading else { return }
                // 优先使用真实地理航向校准，如果没有则用磁北航向
                let degrees = heading.trueHeading > 0 ? heading.trueHeading : heading.magneticHeading
                self.accelerometerManager.currentHeading = degrees
            }
            .store(in: &cancellables)
            
        locationManager.$lastLocation
            .receive(on: RunLoop.main)
            .map { location -> String in
                guard let loc = location else { return "未获取定位" }
                // 如果有网络，且有了坐标，试着去请求当前气象气压
                self.networkManager.fetchSurfacePressure(for: loc.coordinate)
                
                return String(format: "Lat: %.4f, Lon: %.4f", loc.coordinate.latitude, loc.coordinate.longitude)
            }
            .assign(to: \.gpsLocationStr, on: self)
            .store(in: &cancellables)
            
        locationManager.$initialLocation
            .receive(on: RunLoop.main)
            .map { location -> String in
                guard let loc = location else { return "未知" }
                return String(format: "%.2f 米", loc.altitude)
            }
            .assign(to: \.gpsInitialAltitudeStr, on: self)
            .store(in: &cancellables)
            
        locationManager.$distanceFromStart
            .receive(on: RunLoop.main)
            .map { dist -> String in
                return String(format: "%.2f 米", dist)
            }
            .assign(to: \.gpsDistanceStr, on: self)
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
            
        accelerometerManager.$distance3D
            .receive(on: RunLoop.main)
            .map { dist -> String in
                return String(format: "%.2f 米", dist)
            }
            .assign(to: \.distance3DStr, on: self)
            .store(in: &cancellables)
    }
    
    private func bindNetwork() {
        networkManager.$surfacePressure
            .receive(on: RunLoop.main)
            .map { [weak self] pressure -> String in
                guard let p = pressure else { return "未知" }
                // 当获取到网络地表气压时，同步给气压传感器做高度计算参考底座
                self?.barometerManager.surfacePressureLog = p
                return String(format: "%.2f hPa", p)
            }
            .assign(to: \.weatherSurfacePressureStr, on: self)
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