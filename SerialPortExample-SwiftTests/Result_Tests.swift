import Cocoa
import XCTest


// MARK: -
// MARK: Result testing helper functions

func errorGeneratingFunction(arbitraryInput:Int) -> Result<Int, CommunicationsError> {
    return .Failure(Box(.ReadWriteTimeout))
}

func properlyOperatingFunction(arbitraryInput:Int) -> Result<Int, CommunicationsError> {
    return .Success(Box(arbitraryInput))
}

func properlyOperatingFunction2(arbitraryInput:Int) -> Result<String, CommunicationsError> {
    return .Success(Box("\(arbitraryInput)"))
}


// MARK: -
// MARK: Result-based unit testing assertions

func assertResultsAreEqual<T:Equatable,U:Equatable> (lhs: Result<T, U>, rhs: Result<T, U>, file: String = __FILE__, line: UInt = __LINE__) {
    switch (lhs, rhs) {
        case let (.Success(boxedValue), .Success(boxedValue2)):  XCTAssert(boxedValue.unbox == boxedValue2.unbox, "Expected .Success value of \(boxedValue2.unbox), and instead got back \(boxedValue.unbox).", file:file, line:line)
        case let (.Success, .Failure): XCTAssert(false, ".Success != .Failure", file:file, line:line)
        case let (.Failure, .Success): XCTAssert(false, ".Failure != .Success", file:file, line:line)
        case let (.Failure(boxedError), .Failure(boxedError2)): XCTAssert(boxedError.unbox == boxedError2.unbox, "Expected .Failure value of \(boxedError2.unbox) and got back \(boxedError.unbox).", file:file, line:line)
    }
}

func assertResultsAreEqual<T,U:Equatable> (lhs: Result<T, U>, rhs: Result<T, U>, file: String = __FILE__, line: UInt = __LINE__) {
    switch (lhs, rhs) {
        case let (.Success, .Success):  XCTAssert(false, "Tried to compare incomparable types", file:file, line:line)
        case let (.Success, .Failure): XCTAssert(false, ".Success != .Failure", file:file, line:line)
        case let (.Failure, .Success): XCTAssert(false, ".Failure != .Success", file:file, line:line)
        case let (.Failure(boxedError), .Failure(boxedError2)): XCTAssert(boxedError.unbox == boxedError2.unbox, "Expected .Failure value of \(boxedError2.unbox) and got back \(boxedError.unbox).", file:file, line:line)
    }
}

func assertResultsAreEqual<T:Equatable,U> (lhs: Result<T, U>, rhs: Result<T, U>, file: String = __FILE__, line: UInt = __LINE__) {
    switch (lhs, rhs) {
        case let (.Success(boxedValue), .Success(boxedValue2)):  XCTAssert(boxedValue.unbox == boxedValue2.unbox, ".Success values of \(boxedValue.unbox) and \(boxedValue2.unbox) did not match.", file:file, line:line)
        case let (.Success, .Failure): XCTAssert(false, ".Success != .Failure", file:file, line:line)
        case let (.Failure, .Success): XCTAssert(false, ".Failure != .Success", file:file, line:line)
        case let (.Failure, .Failure): XCTAssert(false, "Tried to compare incomparable types", file:file, line:line)
    }
}

func assertResultsAreEqual<U:Equatable> (lhs: Result<[UInt8], U>, rhs: Result<[UInt8], U>, file: String = __FILE__, line: UInt = __LINE__) {
    switch (lhs, rhs) {
        case let (.Success(boxedValue), .Success(boxedValue2)):  XCTAssert(equal(boxedValue.unbox, boxedValue2.unbox), "Expected .Success value of \(boxedValue2.unbox), and instead got back \(boxedValue.unbox).", file:file, line:line)
        case let (.Success, .Failure): XCTAssert(false, ".Success != .Failure", file:file, line:line)
        case let (.Failure, .Success): XCTAssert(false, ".Failure != .Success", file:file, line:line)
        case let (.Failure(boxedError), .Failure(boxedError2)): XCTAssert(boxedError.unbox == boxedError2.unbox, "Expected .Failure value of \(boxedError2.unbox) and got back \(boxedError.unbox).", file:file, line:line)
    }
}

func assertResultsAreEqual<U:Equatable> (lhs: Result<Void, U>, rhs: Result<Void, U>, file: String = __FILE__, line: UInt = __LINE__) {
    switch (lhs, rhs) {
        case let (.Success, .Success):  XCTAssert(true, ".Success voids should never be different.", file:file, line:line)
        case let (.Success, .Failure): XCTAssert(false, ".Success != .Failure", file:file, line:line)
        case let (.Failure, .Success): XCTAssert(false, ".Failure != .Success", file:file, line:line)
        case let (.Failure(boxedError), .Failure(boxedError2)): XCTAssert(boxedError.unbox == boxedError2.unbox, "Expected .Failure value of \(boxedError2.unbox) and got back \(boxedError.unbox).", file:file, line:line)
    }
}


// MARK: -
// MARK: Tests

class Result_Tests: XCTestCase {

    func testSuccess() {
        let successfulResult = properlyOperatingFunction(1)
        assertResultsAreEqual(successfulResult, .Success(Box(1)))
        
        let successfulResult2 = properlyOperatingFunction(10)
        assertResultsAreEqual(successfulResult2, .Success(Box(10)))
    }

    func testFailure() {
        let failedResult = errorGeneratingFunction(1)
        assertResultsAreEqual(failedResult, .Failure(Box(.ReadWriteTimeout)))
    }

    func testThen() {
        let chainedResult1 = properlyOperatingFunction(1)
                            .then(properlyOperatingFunction)
        assertResultsAreEqual(chainedResult1, .Success(Box(1)))

        let chainedResult2 = properlyOperatingFunction(1)
                            .then(errorGeneratingFunction)
        assertResultsAreEqual(chainedResult2, .Failure(Box(.ReadWriteTimeout)))

        let chainedResult3 = errorGeneratingFunction(1)
                            .then(properlyOperatingFunction)
        assertResultsAreEqual(chainedResult3, .Failure(Box(.ReadWriteTimeout)))

        let chainedResult4 = errorGeneratingFunction(1)
                            .then(errorGeneratingFunction)
        assertResultsAreEqual(chainedResult4, .Failure(Box(.ReadWriteTimeout)))

        let chainedResult5 = properlyOperatingFunction(1)
                            .then(properlyOperatingFunction2)
        assertResultsAreEqual(chainedResult5, .Success(Box("1")))
        
        let chainedResult6 = properlyOperatingFunction(1)
                            .then{myIntValue in
                                  properlyOperatingFunction2(myIntValue)}
        assertResultsAreEqual(chainedResult6, .Success(Box("1")))
    }

    func testBind() {
        let chainedResult1 = properlyOperatingFunction(1) >>== properlyOperatingFunction
        assertResultsAreEqual(chainedResult1, .Success(Box(1)))
        
        let chainedResult2 = properlyOperatingFunction(1) >>== errorGeneratingFunction
        assertResultsAreEqual(chainedResult2, .Failure(Box(.ReadWriteTimeout)))

        let chainedResult3 = errorGeneratingFunction(1) >>== properlyOperatingFunction
        assertResultsAreEqual(chainedResult3, .Failure(Box(.ReadWriteTimeout)))
        
        let chainedResult4 = errorGeneratingFunction(1) >>== errorGeneratingFunction
        assertResultsAreEqual(chainedResult4, .Failure(Box(.ReadWriteTimeout)))

        let chainedResult5 = properlyOperatingFunction(1) >>== properlyOperatingFunction2
        assertResultsAreEqual(chainedResult5, .Success(Box("1")))
    }
}
