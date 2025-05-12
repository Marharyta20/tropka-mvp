import MapboxMaps

final class MapService {
  static let shared = MapService()
  let mapInitOptions: MapInitOptions

  private init() {
    
      let raw = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken")
      let token = (raw as? String) ?? "[nil]"
      print("🔑 Mapbox token in bundle:", token)
      
      mapInitOptions = MapInitOptions()
  }
}
