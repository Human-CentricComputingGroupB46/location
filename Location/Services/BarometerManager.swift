import Foundation
import CoreMotion
import Combine

class BarometerManager: ObservableObject {
    private let altimeter = CMAltimeter()
    @Published var pressure: Double?
    @Published var relativeAltitude: Double? // 相对高度变化（米）
    @Published var floorCount: Int = 0 // 预估楼层变化（基于 ~3 米/层）
    
    // 楼层高度大约 3 米一层
    private let metersPerFloor: Double = 3.0
    
    func startUpdates() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { 
            print("Barometer not available")
            return 
        }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            // 记录气压（由于单位是 kilopascal/10，我们根据需求转为 kPa，或保留原值）
            self.pressure = data.pressure.doubleValue * 10
            
            // 记录相对高度
            self.relativeAltitude = data.relativeAltitude.doubleValue
            
            // 计算楼层变化（只关心整数层的变化）
            self.floorCount = Int(self.relativeAltitude! / self.metersPerFloor)
        }
    }
    
    func stopUpdates() {
        altimeter.stopRelativeAltitudeUpdates()
    }
}
