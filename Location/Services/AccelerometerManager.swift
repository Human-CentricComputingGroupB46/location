import Foundation
import CoreMotion
import Combine
import simd

// 管理加速度并通过积分估算位移（稳定版）

// 用于图表绘制的数据点
struct AccelerationDataPoint: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval // 相对时间（例如自启动以来的秒数）
    let x: Double
    let y: Double
    let z: Double
}

class AccelerometerManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    // MARK: - Published 状态
    @Published var distance: Double = 0.0         // 一维位移估算
    @Published var velocity: Double = 0.0         // 一维速度估算
    @Published var acceleration: CMAcceleration?  // 当前加速度
    
    @Published var distance3D: Double = 0.0       // 三维欧氏位移
    @Published var position = SIMD3<Double>(0, 0, 0)  // 三维位置
    private var velocity3D = SIMD3<Double>(0, 0, 0)   // 三维速度
    
    // 计步器状态
    @Published var stepCount: Int = 0
    @Published var stepDirectionMessage: String = "未检测到步数"
    var currentHeading: Double? = nil // 从外部注入的磁场方向（度数，以地理北极为 0）
    private var lastStepTime: TimeInterval = 0 // 防抖时间
    
    // 图表用的加速度历史轨迹（保存近 N 秒的数据用来绘图）
    @Published var chartData: [AccelerationDataPoint] = []
    private var startTime: TimeInterval = 0
    private let maxDataPoints = 500 // 限制图表点数防止内存激增 (以100Hz计约保存最新的3秒。如果要展示更多，可以适当降低采样率或调大点数)
    
    // MARK: - 参数
    private var lastUpdateTime: TimeInterval = 0
    private let noiseThreshold: Double = 0.13     // g
    private let velocityDamping: Double = 0.95    // 零速阻尼
    
    // MARK: - 启动更新
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.01 // 100Hz
        lastUpdateTime = 0 // 初始化为 0，防止首次采样时间增量错误
        startTime = 0
        
        distance = 0
        velocity = 0
        position = SIMD3(0,0,0)
        velocity3D = SIMD3(0,0,0)
        distance3D = 0
        stepCount = 0
        stepDirectionMessage = "未检测到步数"
        lastStepTime = 0
        chartData.removeAll()
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            // 使用 CoreMotion 返回的高精度时间戳
            let currentTime = data.timestamp
            if self.startTime == 0 {
                self.startTime = currentTime
            }
            let dt = self.lastUpdateTime == 0 ? 0 : min((currentTime - self.lastUpdateTime), 0.01)
            self.lastUpdateTime = currentTime
            
            // 相对启动经过的时间
            let elapsedTime = currentTime - self.startTime
            
            // 1. 获取剔除重力后的加速度 (设备坐标系, 此时单位为 g)
            let rawAccel = data.userAcceleration
            self.acceleration = rawAccel
            
            // 2. 将设备坐标系的加速度经过姿态矩阵（四元数或旋转矩阵）投影到世界坐标系
            // data.attitude 代表了设备从启动/参考系到当前的三维旋转
            let attitude = data.attitude
            let gravity = data.gravity // 虽然这里提供但用attitude更容易
            
            // CoreMotion 提供直接使用旋转矩阵转换到基准平面的方法
            let r = attitude.rotationMatrix
            
            // 将设备坐标系的(x,y,z)与旋转矩阵相乘，得到相对于全球或初始参考坐标系的加速度
            // 注意这里仍是 g，后续统一转换
            let worldX = r.m11 * rawAccel.x + r.m12 * rawAccel.y + r.m13 * rawAccel.z
            let worldY = r.m21 * rawAccel.x + r.m22 * rawAccel.y + r.m23 * rawAccel.z
            let worldZ = r.m31 * rawAccel.x + r.m32 * rawAccel.y + r.m33 * rawAccel.z
            
            // 3. 噪声滤波 & g -> m/s^2 转换 (1 G ≈ 9.81 m/s^2)
            func applyThreshold(_ value: Double) -> Double {
                if abs(value) > self.noiseThreshold {
                    // 转为 m/s^2
                    return (abs(value) - self.noiseThreshold) * (value >= 0 ? 1 : -1) * 9.81
                }
                return 0
            }
            
            let ax = applyThreshold(worldX)
            let ay = applyThreshold(worldY)
            let az = applyThreshold(worldZ)
            
            let currentAccelVector = SIMD3<Double>(ax, ay, az)
            let accelMagnitude = simd_length(currentAccelVector)
            
            // 4. 一维速度与距离（取主要运动方向的投影或简化处理，这里修正为仅代表标量路径长度）
            // 注意: 真实的位移应以三维坐标系(position)为准。用 accelMagnitude 累积只能表示"运动路程(不管方向)"
            if accelMagnitude > 0 {
                self.velocity += accelMagnitude * dt
            }
            self.distance += self.velocity * dt
            
            // 5. 三维速度半步积分 (基于世界坐标系的加速度)
            let vxNew = self.velocity3D.x + ax * dt
            let vyNew = self.velocity3D.y + ay * dt
            let vzNew = self.velocity3D.z + az * dt
            
            self.position.x += (self.velocity3D.x + vxNew) / 2.0 * dt
            self.position.y += (self.velocity3D.y + vyNew) / 2.0 * dt
            self.position.z += (self.velocity3D.z + vzNew) / 2.0 * dt
            
            self.velocity3D.x = vxNew
            self.velocity3D.y = vyNew
            self.velocity3D.z = vzNew
            
            // 6. 三维欧氏距离
            self.distance3D = length(self.position)
            
            // 7. 阻尼处理，减少稳定后的积分漂移 (零速更新 ZUPT)
            // 当合成有效加速度几乎为 0 时触发
            if accelMagnitude == 0 {
                self.velocity *= self.velocityDamping
                self.velocity3D *= self.velocityDamping
            }
            
            // 8. 简单的计步与方向判定模块
            // 只要平面上的水平加速度某方向分量或合成大于 2 m/s^2 就触发
            if (abs(ax) > 2.0 || abs(ay) > 2.0) {
                // 防抖，假设每步至少需要 0.3 秒的间隔
                if currentTime - self.lastStepTime > 0.3 {
                    self.lastStepTime = currentTime
                    self.stepCount += 1
                    
                    if let heading = self.currentHeading {
                        // 根据地理正北角度判断大致方向
                        let directions = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
                        // 将 360 度分为 8 个扇区（每扇区 45 度）
                        let index = Int(((heading + 22.5) / 45.0).truncatingRemainder(dividingBy: 8))
                        let dirStr = directions[index < 0 ? 0 : index]
                        self.stepDirectionMessage = "向 \(dirStr) 方向走了 \(self.stepCount) 步"
                    } else {
                        self.stepDirectionMessage = "向未知方向走了 \(self.stepCount) 步"
                    }
                }
            }
            
            // 9. 记录绘图数据（记录真实的带符号的滤波后世界加速度）
            let dataPoint = AccelerationDataPoint(timestamp: elapsedTime, x: ax, y: ay, z: az)
            self.chartData.append(dataPoint)
            if self.chartData.count > self.maxDataPoints {
                self.chartData.removeFirst() // 保持图表窗口不无限增大
            }
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}