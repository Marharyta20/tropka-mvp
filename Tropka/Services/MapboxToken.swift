import Foundation

/// Single source of truth for the Mapbox public access token.
///
/// The token is injected by `Secrets.xcconfig` into `Info.plist`. Historically the
/// Maps SDK key (`MBXAccessToken`) and the hand-rolled search service key
/// (`MAPBOX_ACCESS_TOKEN`) drifted apart, which silently broke search. Read every
/// known key here so there is exactly one place to change if it moves again.
enum MapboxToken {

    /// Keys are probed in order; the first non-empty value wins.
    private static let candidateKeys = [
        "MBXAccessToken",         // Mapbox Maps SDK v10+ (what Info.plist actually defines)
        "MGLMapboxAccessToken",   // legacy Mapbox GL key, also present in Info.plist
        "MAPBOX_ACCESS_TOKEN"     // kept for backwards compatibility
    ]

    static let value: String = {
        for key in candidateKeys {
            if let token = Bundle.main.object(forInfoDictionaryKey: key) as? String,
               !token.isEmpty,
               // xcconfig placeholders resolve to the literal "$(NAME)" when unset
               !token.hasPrefix("$(") {
                return token
            }
        }
        return ""
    }()

    static var isConfigured: Bool { !value.isEmpty }

    static var missingTokenError: Error {
        NSError(
            domain: "Mapbox",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: """
            Missing Mapbox access token. Copy Secrets.xcconfig.example to Secrets.xcconfig \
            and set MBXAccessToken to your public token from mapbox.com/account/access-tokens.
            """]
        )
    }
}
