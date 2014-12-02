import Cocoa
import XCTest

class SerialPort_Tests: XCTestCase {
    let fakeSerialPort = FakeSerialPort(ftdiCommPort: FT_HANDLE(bitPattern: 0))
    
    func testFakeSerialFunctions() {
        let testByteArray:[UInt8] = [1,2,3,4]
        var bytesRead:DWORD = 0
        XCTAssertTrue(fakeSerialPort.goodStatusFunction(fakeSerialPort.ftdiCommPort, LPVOID(testByteArray), bytesToReadOrWrite:DWORD(testByteArray.count), bytesWrittenOrReadPointer:&bytesRead) == FT_STATUS(FT_OK), "Status should have been FT_OK")
        XCTAssertTrue(fakeSerialPort.badStatusFunction(fakeSerialPort.ftdiCommPort, LPVOID(testByteArray), DWORD(testByteArray.count), &bytesRead) == FT_STATUS(FT_OTHER_ERROR), "Status should have been an FTDI error.")

        let wrongByteFunction_threeBytes = fakeSerialPort.wrongByteFunction(3)
        XCTAssertTrue(wrongByteFunction_threeBytes(fakeSerialPort.ftdiCommPort, LPVOID(testByteArray), bytesToReadOrWrite: DWORD(testByteArray.count), bytesWrittenOrReadPointer: &bytesRead) == FT_STATUS(FT_OK), "Status should have been FT_OK.")
        XCTAssertTrue(bytesRead == 3, "Should have returned 3 bytes from the wrong byte function.")

        let wrongByteFunction_tenBytes = fakeSerialPort.wrongByteFunction(10)
        XCTAssertTrue(wrongByteFunction_tenBytes(fakeSerialPort.ftdiCommPort, LPVOID(testByteArray), bytesToReadOrWrite: DWORD(testByteArray.count), bytesWrittenOrReadPointer: &bytesRead) == FT_STATUS(FT_OK), "Status should have been FT_OK.")
        XCTAssertTrue(bytesRead == 10, "Should have returned 10 bytes from the wrong byte function.")

        var testReadWriteByteArray:[UInt8] = [0,0,0,0,0]
        let customBytesFunction_12345 = fakeSerialPort.customBytesFunction([1,2,3,4,5])
        XCTAssertTrue(customBytesFunction_12345(fakeSerialPort.ftdiCommPort, byteArray:LPVOID(testReadWriteByteArray), bytesToReadOrWrite: DWORD(testReadWriteByteArray.count), bytesWrittenOrReadPointer: &bytesRead) == FT_STATUS(FT_OK), "Status should have been FT_OK.")
        XCTAssertTrue(bytesRead == 5, "Should have returned 5 bytes from the wrong byte function.")
        XCTAssertTrue(testReadWriteByteArray == [1,2,3,4,5], "Bytes should have been [1,2,3,4,5] in return.")

        var testReadWriteByteArray2:[UInt8] = [0,0,0,0,0]
        let customBytesFunction_1234 = fakeSerialPort.customBytesFunction([1,2,3,4])
        XCTAssertTrue(customBytesFunction_1234(fakeSerialPort.ftdiCommPort, byteArray:LPVOID(testReadWriteByteArray2), bytesToReadOrWrite: DWORD(testReadWriteByteArray2.count), bytesWrittenOrReadPointer: &bytesRead) == FT_STATUS(FT_OK), "Status should have been FT_OK.")
        XCTAssertTrue(bytesRead == 4, "Should have returned 4 bytes from the wrong byte function.")
        XCTAssertTrue(testReadWriteByteArray2 == [1,2,3,4,0], "Bytes should have been [1,2,3,4,5] in return.")
        
        let verifyBytesFunction_1234 = fakeSerialPort.verifyOutputBytesFunction([1,2,3,4])
        XCTAssertTrue(verifyBytesFunction_1234(fakeSerialPort.ftdiCommPort, byteArray:LPVOID(testByteArray), bytesToReadOrWrite: DWORD(testByteArray.count), bytesWrittenOrReadPointer: &bytesRead) == FT_STATUS(FT_OK), "Status should have been FT_OK.")
        XCTAssertTrue(verifyBytesFunction_1234(fakeSerialPort.ftdiCommPort, byteArray:LPVOID([1,2,4,4]), bytesToReadOrWrite: DWORD(testByteArray.count), bytesWrittenOrReadPointer: &bytesRead) == FT_STATUS(FT_OTHER_ERROR), "Status should have been FT_OTHER_ERROR.")
        XCTAssertTrue(verifyBytesFunction_1234(fakeSerialPort.ftdiCommPort, byteArray:LPVOID([1,2,3,4,5]), bytesToReadOrWrite: DWORD([1,2,3,4,5].count), bytesWrittenOrReadPointer: &bytesRead) == FT_STATUS(FT_OK), "Status should have been FT_OK.")
    }
    
    func testGenericSerialCommunication() {
        let testByteArray:[UInt8] = [1,2,3,4]
        let result1 = genericSerialCommunication(bytesToReadOrWrite:testByteArray, numberOfBytes:4, serialPort:fakeSerialPort, communicationFunction:fakeSerialPort.goodStatusFunction)
        assertResultsAreEqual(result1, .Success(Box([1,2,3,4])))

        let result2 = genericSerialCommunication(bytesToReadOrWrite:testByteArray, numberOfBytes:4, serialPort:fakeSerialPort, communicationFunction:fakeSerialPort.badStatusFunction)
        assertResultsAreEqual(result2, .Failure(Box(.ReadWriteTimeout)))
    }

    func testSerialReadFunction() {
        fakeSerialPort.initializeReadQueueWithFunction(.GoodReadWrite)
        let result1 = readBytesFromSerialPort(numberOfBytes: 4, serialPort: fakeSerialPort)
        assertResultsAreEqual(result1, .Success(Box([0,0,0,0])))

        fakeSerialPort.initializeReadQueueWithFunction(.BadStatus)
        let result2 = readBytesFromSerialPort(numberOfBytes: 4, serialPort: fakeSerialPort)
        assertResultsAreEqual(result2, .Failure(Box(.ReadWriteTimeout)))

        fakeSerialPort.initializeReadQueueWithFunction(.WrongByteCount(numberOfBytes:3))
        let result3 = readBytesFromSerialPort(numberOfBytes: 4, serialPort: fakeSerialPort)
        assertResultsAreEqual(result3, .Failure(Box(.WrongByteCount(expectedByteCount:4, receivedByteCount:3))))

        fakeSerialPort.initializeReadQueueWithFunction(.ResponseWithCustomBytes(bytes:[1,2,3,4]))
        let result4 = readBytesFromSerialPort(numberOfBytes: 4, serialPort: fakeSerialPort)
        assertResultsAreEqual(result4, .Success(Box([1,2,3,4])))

        let result5 = readBytesFromSerialPort(numberOfBytes: 5, serialPort: fakeSerialPort)
        assertResultsAreEqual(result5, .Failure(Box(.WrongByteCount(expectedByteCount:5, receivedByteCount:4))))
    }

    func testQueuedSerialReadFunction() {
        fakeSerialPort.initializeReadQueueWithFunction(.ResponseWithCustomBytes(bytes:[1,2,3,4]))
        fakeSerialPort.enqueueReadFunction(.ResponseWithCustomBytes(bytes:[4,3,2,1]))
        fakeSerialPort.enqueueReadFunction(.ResponseWithCustomBytes(bytes:[4,3,2,1,0]))
        fakeSerialPort.enqueueReadFunction(.WrongByteCount(numberOfBytes:3))
        fakeSerialPort.enqueueReadFunction(.BadStatus)

        
        let result1 = readBytesFromSerialPort(numberOfBytes: 4, serialPort: fakeSerialPort)
        assertResultsAreEqual(result1, .Success(Box([1,2,3,4])))
        let result2 = readBytesFromSerialPort(numberOfBytes: 4, serialPort: fakeSerialPort)
        assertResultsAreEqual(result2, .Success(Box([4,3,2,1])))
        let result3 = readBytesFromSerialPort(numberOfBytes: 5, serialPort: fakeSerialPort)
        assertResultsAreEqual(result3, .Success(Box([4,3,2,1,0])))
        let result4 = readBytesFromSerialPort(numberOfBytes: 4, serialPort: fakeSerialPort)
        assertResultsAreEqual(result4, .Failure(Box(.WrongByteCount(expectedByteCount:4, receivedByteCount:3))))
        let result5 = readBytesFromSerialPort(numberOfBytes: 4, serialPort: fakeSerialPort)
        assertResultsAreEqual(result5, .Failure(Box(.ReadWriteTimeout)))
    }

    func testSerialWriteFunction() {
        fakeSerialPort.initializeWriteQueueWithFunction(.GoodReadWrite)
        let result1 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result1, .Success(Box(())))
        
        fakeSerialPort.initializeWriteQueueWithFunction(.BadStatus)
        let result2 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result2, .Failure(Box(.ReadWriteTimeout)))
        
        fakeSerialPort.initializeWriteQueueWithFunction(.WrongByteCount(numberOfBytes:3))
        let result3 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result3, .Failure(Box(.WrongByteCount(expectedByteCount:4, receivedByteCount:3))))
        
        fakeSerialPort.initializeWriteQueueWithFunction(.ResponseWithCustomBytes(bytes:[1,2,3,4]))
        let result4 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result4, .Success(Box(())))

        fakeSerialPort.initializeWriteQueueWithFunction(.VerifyOutputBytes(bytesToMatch:[1,2,3,4]))
        let result5 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result5, .Success(Box(())))

        let result6 = writeBytesToSerialPort(bytesToWrite: [1,2,3,5], serialPort: fakeSerialPort)
        assertResultsAreEqual(result6, .Failure(Box(.ReadWriteTimeout)))

        let result7 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4,5], serialPort: fakeSerialPort)
        assertResultsAreEqual(result7, .Failure(Box(.WrongByteCount(expectedByteCount:5, receivedByteCount:4))))
    }

    func testQueuedSerialWriteFunction() {
        fakeSerialPort.initializeWriteQueueWithFunction(.GoodReadWrite)
        fakeSerialPort.enqueueWriteFunction(.GoodReadWrite)
        fakeSerialPort.enqueueWriteFunction(.GoodReadWrite)
        fakeSerialPort.enqueueWriteFunction(.BadStatus)
        fakeSerialPort.enqueueWriteFunction(.WrongByteCount(numberOfBytes:3))
        
        
        let result1 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result1, .Success(Box(())))
        let result2 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result2, .Success(Box(())))
        let result3 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result3, .Success(Box(())))
        let result4 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result4, .Failure(Box(.ReadWriteTimeout)))
        let result5 = writeBytesToSerialPort(bytesToWrite: [1,2,3,4], serialPort: fakeSerialPort)
        assertResultsAreEqual(result5, .Failure(Box(.WrongByteCount(expectedByteCount:4, receivedByteCount:3))))
    }

}
