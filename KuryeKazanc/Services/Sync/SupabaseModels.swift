import Foundation

/// SupabaseClient hatalari (yedekleme, giris, silme gibi hata firlatan cagrilar icin).
enum SupabaseError: Error, Equatable {
    case network
    case invalidResponse
    case http(Int)
    case notSignedIn
    case invalidPayload
}

extension SupabaseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .network:
            return "Sunucuya ulaşılamadı. İnternet bağlantını kontrol et."
        case .invalidResponse:
            return "Sunucudan beklenmeyen bir yanıt geldi."
        case .http(let status):
            return "Sunucu isteği reddetti (\(status))."
        case .notSignedIn:
            return "Bu işlem için Apple ile giriş yapmalısın."
        case .invalidPayload:
            return "Gönderilecek veri okunamadı."
        }
    }
}

/// Ham JSON degeri: yedek yukunu (jsonb) Codable ile tasimak icin.
enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            let value: [String: JSONValue] = try container.decode([String: JSONValue].self)
            self = .object(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

// MARK: - Istek govdeleri

struct RPCBody<Payload: Encodable>: Encodable {
    let payload: Payload
}

struct EmptyBody: Encodable {}

struct CalibrationBody: Encodable {
    let platformCode: String?
    let templateID: String?
    let lines: [RecognizedLine]

    enum CodingKeys: String, CodingKey {
        case platformCode = "platform_code"
        case templateID = "template_id"
        case lines
    }
}

struct RefreshBody: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct IDTokenBody: Encodable {
    let provider: String
    let idToken: String
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case provider
        case idToken = "id_token"
        case nonce
    }
}

struct BackupUploadRow: Encodable {
    let userID: String
    let payload: JSONValue

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case payload
    }
}

// MARK: - Yanitlar

/// GoTrue oturum yaniti: signup, refresh_token ve id_token uclari ayni bicimi doner.
struct TokenResponse: Decodable {
    struct User: Decodable {
        let id: String
        let isAnonymous: Bool?

        enum CodingKeys: String, CodingKey {
            case id
            case isAnonymous = "is_anonymous"
        }
    }

    let accessToken: String
    let refreshToken: String
    let expiresIn: Double
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }

    func session(now: Date) -> AuthSession {
        let expiry: Date = now.addingTimeInterval(expiresIn)
        let anonymous: Bool = user.isAnonymous ?? false
        return AuthSession(
            accessToken: accessToken, refreshToken: refreshToken,
            expiresAt: expiry, userID: user.id, isAnonymous: anonymous
        )
    }
}

/// `ocr_templates?select=body` satiri. Cozulemeyen sablon atlanir (tumu dusmesin).
struct TemplateRow: Decodable {
    let body: OCRTemplate?

    enum CodingKeys: String, CodingKey {
        case body
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        body = try? container.decode(OCRTemplate.self, forKey: .body)
    }
}

struct BackupDownloadRow: Decodable {
    let payload: JSONValue
}
