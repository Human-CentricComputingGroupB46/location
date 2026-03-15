import Foundation
import CoreMotion
import Combine

// 管理加速度并通过积分估算位移
class AccelerometerManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    // 当前状态
    @Published var distance: Double = 0.0     // 估算的位移距离 (m)
    @Published var velocity: Double = 0.0     // 估算的速度 (m/s)
    @Published var acceleration: CMAcceleration?
    
    private var lastUpdateTime: TimeInterval = 0
    
    // 用作简易 PID 或阻尼修正，对抗积分漂移
    // 当加速度较小时，强制速度按比例衰减，避免误差无限累积（类似 P 控制 / ZUPT）
    private let velocityDamping: Double = 0.95 
    private let noiseThreshold: Double = 0.05 // 噪声阈值 (g)
    
    // 三维空间距离（向量积分）
    @Published var distance3D: Double = 0.0
    // 相对三维位置增量
    private var position = SIMD3<Double>(0, 0, 0)
    // 相对三维速度增量
    private var velocity3D = SIMD3<Double>(0, 0, 0)
    
    func startUpdates() {
        // 使用 DeviceMotion 可以获取剔除重力后的 userAcceleration
        guard motionManager.isDeviceMotionAvailable else { 
            print("Device motion is not available")
            return 
        }
        
        motionManager.deviceMotionUpdateInterval = 0.02 // 50Hz 采样率提高积分精度
        lastUpdateTime = ProcessInfo.processInfo.systemUptime
        distance = 0.0
        velocity = 0.0
        position = SIMD3<Double>(0, 0, 0)
        velocity3D = SIMD3<Double>(0, 0, 0)
        distance3D = 0.0
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            let currentTime = ProcessInfo.processInfo.systemUptime
            let dt = currentTime - self.lastUpdateTime
            self.lastUpdateTime = currentTime
            
            // 获取用户消除重力后的 3 轴加速度
            let accel = data.userAcceleration
            self.acceleration = CMAcceleration(x: accel.x, y: accel.y, z: accel.z)
            
            // 计算三轴合成加速度大小
            let accelMagnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
            
            // 1. 滤除微小噪声
            var effectiveAccel = 0.0
            if accelMagnitude > self.noiseThreshold {
                effectiveAccel = accelMagnitude - self.noiseThreshold
            }
            
            // 将加速度从 g 转换为 m/s^2
            let accelerationInMetersPerSecondSquare = effectiveAccel * 9.81
            
            // 2. 积分计算速度 (v = v0 + a * dt)
            self.velocity += accelerationInMetersPerSecondSquare * dt/2
            
            // 3维向量计算
            if accelMagnitude > self.noiseThreshold {
                self.velocity3D.x += accel.x * 9.81 * dt
                self.velocity3D.y += accel.y * 9.81 * dt
                self.velocity3D.z += accel.z * 9.81 * dt
            }
            
            // // 3. 仿 PID (P反馈) 及零速更新 (ZUPT)
            // // 当检测到没有明显运动时，强制逐渐收敛速度至0，消除长期累积漂移
            // if effectiveAccel == 0.0 {
            //     self.velocity *= self.velocityDamping
            //     self.velocity3D *= self.velocityDamping
            // }
            
            // 4. 积分计算位移 (s = s0 + v * dt)
            self.distance += self.velocity * dt
            
            self.position.x += self.velocity3D.x * dt
            self.position.y += self.velocity3D.y * dt
            self.position.z += self.velocity3D.z * dt
            
            // 计算三维空间欧氏距离
            self.distance3D = sqrt(pow(self.position.x, 2) + pow(self.position.y, 2) + pow(self.position.z, 2))
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}
