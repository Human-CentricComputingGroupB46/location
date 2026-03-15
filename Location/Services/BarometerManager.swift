import Foundation
import CoreMotion
import Combine

class BarometerManager: ObservableObject {
    private let altimeter = CMAltimeter()
    @Published var pressure: Double?
    @Published var relativeAltitude: Double? // 相对启动时的高度变化（米）
    @Published var floorCount: Int = 0 // 预估楼层变化（基于 ~3 米/层）
    
    // 基于网络当前地表气压算出的真实相对海拔高度（米）
    @Published var altitudeFromSurface: Double?
    
    // 系统直接提供的绝对海拔高度（米，iOS 15+）
    @Published var absoluteAltitude: Double?
    
    // 从 NetworkManager 获取到的当地地表气压 (hPa)
    var surfacePressureLog: Double?
    
    // 楼层高度大约 3 米一层
    private let metersPerFloor: Double = 3.0
    
    func startUpdates() {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                guard let self = self, let data = data else { return }
                
                // 记录气压（由于单位是 kilopascal/10，我们根据需求转为 kPa，或保留原值）
                self.pressure = data.pressure.doubleValue * 10
                
                // 记录相对高度 (相比于传感器启动时)
                self.relativeAltitude = data.relativeAltitude.doubleValue
                
                // 计算楼层变化（只关心整数层的变化）
                self.floorCount = Int(self.relativeAltitude! / self.metersPerFloor)
                
                // 使用标准大气公式，通过网络地表气压估算当前绝对/地表相对海拔
                if let surfaceP = self.surfacePressureLog {
                    // 此时 self.pressure 是 kPa，需乘 10 转为 hPa (同 surfaceP 单位)
                    let currentHPa = data.pressure.doubleValue * 10
                    // 高度公式：h = 44330 * (1 - ( P / P0 ) ^ 0.1903)
                    self.altitudeFromSurface = 44330.0 * (1.0 - pow((currentHPa / surfaceP), 0.1903))
                }
            }
        } else {
            print("Relative Barometer not available")
        }
        
        // 如果系统支持 (iOS 15.0+)，独立获取基于系统的绝对海拔
        if #available(iOS 15.0, *) {
            if CMAltimeter.isAbsoluteAltitudeAvailable() {
                altimeter.startAbsoluteAltitudeUpdates(to: .main) { [weak self] data, error in
                    guard let self = self, let data = data else { return }
                    self.absoluteAltitude = data.altitude
                }
            } else {
                print("Absolute Barometer not available")
            }
        }
    }
    
    func stopUpdates() {
        altimeter.stopRelativeAltitudeUpdates()
        if #available(iOS 15.0, *) {
            altimeter.stopAbsoluteAltitudeUpdates()
        }
    }
}
