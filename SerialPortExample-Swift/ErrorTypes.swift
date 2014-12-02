import Foundation

// MARK: -
// MARK: Error protocols

public protocol ErrorType {}

protocol PresentableError {
    var errorTitle: String { get }
    var errorInfo: String { get }
}

// MARK: -
// MARK: Error types

enum CommunicationsError: ErrorType, Printable, Equatable {
    case ReadWriteTimeout
    case WrongByteCount(expectedByteCount:UInt, receivedByteCount:UInt)
    case CorruptedResponse(expectedResponse:[UInt8], receivedResponse:[UInt8])
    
    var description : String {
        get {
            switch (self) {
                case .ReadWriteTimeout: return ".ReadWriteTimeout"
                case let .WrongByteCount(expectedByteCount, receivedByteCount): return ".WrongByteCount(expectedByteCount:\(expectedByteCount), receivedByteCount:\(receivedByteCount)"
                case let .CorruptedResponse(expectedResponse, receivedResponse): return ".CorruptedResponse(expectedResponse:\(expectedResponse), receivedResponse:\(receivedResponse)"
            }
        }
    }
}

enum ElectronicsError: ErrorType, Printable, Equatable {
    case ElectronicsDisconnected
    case UnrecoverableCommunicationNoise
    
    var description : String {
        get {
            switch (self) {
                case .ElectronicsDisconnected: return ".ElectronicsDisconnected"
                case .UnrecoverableCommunicationNoise: return ".UnrecoverableCommunicationNoise"
            }
        }
    }
}

// MARK: -
// MARK: Equatable protocol compliance for these errors

func == (lhs: CommunicationsError, rhs: CommunicationsError) -> Bool {
    switch (lhs, rhs) {
        case let (.ReadWriteTimeout, .ReadWriteTimeout): return true
        case let (.ReadWriteTimeout, _): return false
        case let (.WrongByteCount(expectedByteCount, receivedByteCount), .WrongByteCount(expectedByteCount2, receivedByteCount2)):  return ((expectedByteCount == expectedByteCount2) && (receivedByteCount == receivedByteCount2))
        case let (.WrongByteCount, _): return false
        case let (.CorruptedResponse(expectedResponse, receivedResponse), .CorruptedResponse(expectedResponse2, receivedResponse2)): return (equal(expectedResponse, expectedResponse2) && equal(receivedResponse, receivedResponse2))
        case let (.CorruptedResponse, _): return false
    }
}

func == (lhs: ElectronicsError, rhs: ElectronicsError) -> Bool {
    switch (lhs, rhs) {
        case (.ElectronicsDisconnected, .ElectronicsDisconnected): return true
        case (.ElectronicsDisconnected, _): return false
        case (.UnrecoverableCommunicationNoise, .UnrecoverableCommunicationNoise): return true
        case (.UnrecoverableCommunicationNoise, _): return false
    }
}

// MARK: -
// MARK: Helpers to aid error recovery

func tryOperationAgainIfFirstAttemptFails<T,U>(command:()->Result<T, U>) -> Result<T, U> {
    let result = command()
    switch(result) {
        case .Success: return result
        case .Failure: return command()
    }
}

func runCommandAndAttemptSoftRecovery<T>(command:()->Result<T, CommunicationsError>) -> Result<T, ElectronicsError> {
    let result = tryOperationAgainIfFirstAttemptFails(command)
    switch (result) {
        case let .Success(boxedValue): return .Success(boxedValue)
        case let .Failure(boxedError): switch (boxedError.unbox) {
            case .ReadWriteTimeout: return .Failure(Box(.ElectronicsDisconnected))
            case .WrongByteCount, .CorruptedResponse: return .Failure(Box(.UnrecoverableCommunicationNoise))
        }
    }
}

// The more specific error recovery, only attempting a retry if the error was not a timeout
func runCommandAndAttemptRestrictedSoftRecovery<T>(command:()->Result<T, CommunicationsError>) -> Result<T, ElectronicsError> {
    switch(command()) {
    case let .Success(boxedValue): return .Success(boxedValue)
    case let .Failure(boxedError):
        switch (boxedError.unbox) {
            case .ReadWriteTimeout: return .Failure(Box(.ElectronicsDisconnected))
            case .WrongByteCount, .CorruptedResponse:
                switch(command()) {
                    case let .Success(boxedValue): return .Success(boxedValue)
                    case .Failure: return .Failure(Box(.UnrecoverableCommunicationNoise))
                }
        }
    }
}

