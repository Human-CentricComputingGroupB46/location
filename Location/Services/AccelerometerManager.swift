import Foundation
import CoreMotion
import Combine
import simd

// 管理加速度并通过积分估算位移（稳定版）
class AccelerometerManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    // MARK: - Published 状态
    @Published var distance: Double = 0.0         // 一维位移估算
    @Published var velocity: Double = 0.0         // 一维速度估算
    @Published var acceleration: CMAcceleration?  // 当前加速度
    
    @Published var distance3D: Double = 0.0       // 三维欧氏位移
    @Published var position = SIMD3<Double>(0, 0, 0)  // 三维位置
    private var velocity3D = SIMD3<Double>(0, 0, 0)   // 三维速度
    
    // MARK: - 参数
    private var lastUpdateTime: TimeInterval = 0
    private let noiseThreshold: Double = 0.05     // g
    private let velocityDamping: Double = 0.95    // 零速阻尼
    
    // MARK: - 启动更新
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.02 // 50Hz
        lastUpdateTime = ProcessInfo.processInfo.systemUptime
        
        distance = 0
        velocity = 0
        position = SIMD3(0,0,0)
        velocity3D = SIMD3(0,0,0)
        distance3D = 0
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            let currentTime = ProcessInfo.processInfo.systemUptime
            let dt = currentTime - self.lastUpdateTime
            self.lastUpdateTime = currentTime
            
            let accel = data.userAcceleration
            self.acceleration = accel
            
            // 1. 噪声滤波 & g -> m/s^2 转换
            func applyThreshold(_ value: Double) -> Double {
                if abs(value) > self.noiseThreshold {
                    return (abs(value) - self.noiseThreshold) * (value >= 0 ? 1 : -1) 
                }
                return 0
            }
            
            let ax = applyThreshold(accel.x)
            let ay = applyThreshold(accel.y)
            let az = applyThreshold(accel.z)
            
            let accelMagnitude = sqrt(ax*ax + ay*ay + az*az)
            
            // 2. 一维速度积分（沿加速度模方向）
            self.velocity += accelMagnitude * dt
            self.distance += self.velocity * dt
            
            // 3. 三维速度半步积分
            let vxNew = self.velocity3D.x + ax * dt
            let vyNew = self.velocity3D.y + ay * dt
            let vzNew = self.velocity3D.z + az * dt
            
            self.position.x += (self.velocity3D.x + vxNew)/2 * dt
            self.position.y += (self.velocity3D.y + vyNew)/2 * dt
            self.position.z += (self.velocity3D.z + vzNew)/2 * dt
            
            self.velocity3D.x = vxNew
            self.velocity3D.y = vyNew
            self.velocity3D.z = vzNew
            
            // 4. 三维欧氏距离
            self.distance3D = sqrt(self.position.x*self.position.x +
                                   self.position.y*self.position.y +
                                   self.position.z*self.position.z)
            
            // 5. 阻尼处理，减少漂移
            if accelMagnitude < self.noiseThreshold {
                self.velocity *= self.velocityDamping
                self.velocity3D *= self.velocityDamping
            }
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}