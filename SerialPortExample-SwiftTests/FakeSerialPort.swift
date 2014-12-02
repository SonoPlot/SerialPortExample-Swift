import Foundation

class FakeSerialPort:SerialPort {
    
    enum TestSerialPortFunctionType {
        case GoodReadWrite
        case BadStatus
        case WrongByteCount(numberOfBytes:DWORD)
        case ResponseWithCustomBytes(bytes:[UInt8])
        case VerifyOutputBytes(bytesToMatch:[UInt8])
    }
    
    // MARK: Fake functions for testing serial communications
    
    func goodStatusFunction(FT_HANDLE, LPVOID, bytesToReadOrWrite:DWORD, bytesWrittenOrReadPointer:LPDWORD) -> FT_STATUS {
        var bytesWrittenOrRead = UnsafeMutablePointer<DWORD>(bytesWrittenOrReadPointer)
        bytesWrittenOrRead[0] = bytesToReadOrWrite
        return FT_STATUS(FT_OK)
    }
    
    func badStatusFunction(FT_HANDLE, LPVOID, DWORD, LPDWORD) -> FT_STATUS {
        return FT_STATUS(FT_OTHER_ERROR)
    }
    
    func wrongByteFunction(wrongBytes:DWORD)(FT_HANDLE, LPVOID, bytesToReadOrWrite:DWORD, bytesWrittenOrReadPointer:LPDWORD) -> FT_STATUS {
        var bytesWrittenOrRead = UnsafeMutablePointer<DWORD>(bytesWrittenOrReadPointer)
        bytesWrittenOrRead[0] = wrongBytes
        return FT_STATUS(FT_OK)
    }
    
    func customBytesFunction(bytes:[UInt8])(FT_HANDLE, byteArray:LPVOID, bytesToReadOrWrite:DWORD, bytesWrittenOrReadPointer:LPDWORD) -> FT_STATUS {
        var bytesWrittenOrRead = UnsafeMutablePointer<DWORD>(bytesWrittenOrReadPointer)
        bytesWrittenOrRead[0] = DWORD(bytes.count)
        
        var outputByteArray = UnsafeMutablePointer<UInt8>(byteArray)
        for indexOfByte in 0..<bytes.count {
            outputByteArray[indexOfByte] = bytes[indexOfByte]
        }
        
        return FT_STATUS(FT_OK)
    }

    func verifyOutputBytesFunction(bytesToMatch:[UInt8])(FT_HANDLE, byteArray:LPVOID, bytesToReadOrWrite:DWORD, bytesWrittenOrReadPointer:LPDWORD) -> FT_STATUS {
        var bytesWrittenOrRead = UnsafeMutablePointer<DWORD>(bytesWrittenOrReadPointer)
        if (bytesToReadOrWrite != DWORD(bytesToMatch.count)) {
            bytesWrittenOrRead[0] = DWORD(bytesToMatch.count)
            return FT_STATUS(FT_OK)
        }
        
        var outputByteArray = UnsafeMutablePointer<UInt8>(byteArray)
        for indexOfByte in 0..<bytesToMatch.count {
            if (outputByteArray[indexOfByte] != bytesToMatch[indexOfByte]) {
                return FT_STATUS(FT_OTHER_ERROR)
            }
        }

        bytesWrittenOrRead[0] = bytesToReadOrWrite
        return FT_STATUS(FT_OK)
    }

    
    // MARK: Configurable inputs and outputs for faking a serial port
    private var readFunctionQueue:Array<TestSerialPortFunctionType> = [.GoodReadWrite]
    private var writeFunctionQueue:Array<TestSerialPortFunctionType> = [.GoodReadWrite]
    
    func enqueueReadFunction(newReadFunction:TestSerialPortFunctionType) {
        readFunctionQueue.insert(newReadFunction, atIndex:0)
    }

    func initializeReadQueueWithFunction(newReadFunction:TestSerialPortFunctionType) {
        readFunctionQueue.removeAll()
        readFunctionQueue.append(newReadFunction)
    }
    
    func enqueueWriteFunction(newWriteFunction:TestSerialPortFunctionType) {
        writeFunctionQueue.insert(newWriteFunction, atIndex:0)
    }

    func initializeWriteQueueWithFunction(newWriteFunction:TestSerialPortFunctionType) {
        writeFunctionQueue.removeAll()
        writeFunctionQueue.append(newWriteFunction)
    }
    
    func initializeReadAndWriteQueuesWithFunctions(#readFunction:TestSerialPortFunctionType, writeFunction:TestSerialPortFunctionType) {
        self.initializeWriteQueueWithFunction(writeFunction)
        self.initializeReadQueueWithFunction(readFunction)
    }
    
    func enqueueReadAndWriteFunctions(#readFunction:TestSerialPortFunctionType, writeFunction:TestSerialPortFunctionType) {
        self.enqueueWriteFunction(writeFunction)
        self.enqueueReadFunction(readFunction)
    }

    private func dequeueFunction(inout queue:Array<TestSerialPortFunctionType>) -> TestSerialPortFunctionType {
        let currentFunction = queue.last!
        if (queue.count > 1) { // Once first function enqueued is reached, keep returning that
            queue.removeLast()
        }
        return currentFunction
    }

    override var readFunction: FTDIFunction {
        switch dequeueFunction(&readFunctionQueue) {
            case .GoodReadWrite: return goodStatusFunction
            case .BadStatus: return badStatusFunction
            case let .WrongByteCount(numberOfBytes): return wrongByteFunction(numberOfBytes)
            case let .ResponseWithCustomBytes(bytes): return customBytesFunction(bytes)
            case let .VerifyOutputBytes(bytesToMatch): return verifyOutputBytesFunction(bytesToMatch)
        }
    }
    
    override var writeFunction: FTDIFunction {
        switch dequeueFunction(&writeFunctionQueue) {
            case .GoodReadWrite: return goodStatusFunction
            case .BadStatus: return badStatusFunction
            case let .WrongByteCount(numberOfBytes): return wrongByteFunction(numberOfBytes)
            case let .ResponseWithCustomBytes(bytes): return customBytesFunction(bytes)
            case let .VerifyOutputBytes(bytesToMatch): return verifyOutputBytesFunction(bytesToMatch)
        }
    }
}

