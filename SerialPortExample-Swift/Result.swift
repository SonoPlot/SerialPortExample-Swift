import Foundation

// Boxed version drawn from LlamaKit: https://github.com/LlamaKit/LlamaKit/blob/master/LlamaKit/Result.swift

final public class Box<T> {
    public let unbox: T
    public init(_ value: T) { self.unbox = value }
}

public enum Result<T, U> {
    case Success(Box<T>)
    case Failure(Box<U>)
    
    // Monadic bind, with a contextually more readable name
    func then<V>(nextOperation:T -> Result<V, U>) -> Result<V, U> {
        switch self {
            case let .Failure(boxedError): return .Failure(boxedError)
            case let .Success(boxedResult): return nextOperation(boxedResult.unbox)
        }
    }
}

func ignoreValueButKeepError<T,U>(result:Result<T, U>) -> Result<(), U> {
    switch (result) {
        case let .Failure(boxedError): return .Failure(boxedError)
        case .Success: return .Success(Box(()))
    }
}

// MARK: -
// MARK: Monadic bind operator

infix operator >>== {}

func >>==<T,U,V>(response:Result<T, U>, f:T -> Result<V, U>) -> Result<V, U> {
    switch(response) {
    case let .Failure(boxedError): return .Failure(boxedError)
    case let .Success(boxedResult): return f(boxedResult.unbox)
    }
}