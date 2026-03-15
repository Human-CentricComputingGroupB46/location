import Foundation
import Combine
import CoreLocation

// 用于解析 Open-Meteo API 响应的结构体
struct WeatherResponse: Codable {
    let current: CurrentWeather
}

struct CurrentWeather: Codable {
    let surface_pressure: Double
}

class NetworkManager: ObservableObject {
    // 发布获取到的地表气压 (单位通常为 hPa)
    @Published var surfacePressure: Double?
    
    // 这里以免费免 Key 的 Open-Meteo API 为例获取当前经纬度的气象气压
    func fetchSurfacePressure(for coordinate: CLLocationCoordinate2D) {
        // 请求参数中包含 current=surface_pressure 来获取当前地表气压
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&current=surface_pressure"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Network request error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
                
                // 返回主线程更新 Published 属性
                DispatchQueue.main.async {
                    self?.surfacePressure = weatherResponse.current.surface_pressure
                }
            } catch {
                print("JSON decoding error: \(error.localizedDescription)")
            }
        }.resume()
    }
}
