import Foundation

/// Spec §3.4 — ValidationErrorCode
enum ValidationErrorCode: String, Codable, Equatable, Sendable {
    case emptyName
    case zeroTarget
    case endNotAfterStart
    case splitNotHundred
    case amountExceedsSaved
    case goalBelowZero
    case noDedicatedAccount
}

/// Spec §3.4 — ValidationError
struct ValidationError: Error, Codable, Equatable, Sendable {
    var field: String
    var message: String
    var code: ValidationErrorCode
}

/// Spec §3.3 — SyncError
enum SyncError: Error, Equatable, Sendable {
    case networkError
    case permissionDenied
    case accountNotFound
}

/// Spec §3.3 — PinError
enum PinError: Error, Equatable, Sendable {
    case wrongPin
    case cancelled
    case otherApp
}

/// Spec §3.3 — GrokError
enum GrokError: Error, Equatable, Sendable {
    case unavailable
    case invalidDraft
    case rateLimited
}

/// Spec §3.4 — AppError
enum AppError: Error, Equatable, Sendable {
    case validationError(ValidationError)
    case syncError(SyncError)
    case grokError(GrokError)
    case persistenceError(String)
}
