import Foundation

typealias FTDIFunction = (FT_HANDLE, LPVOID, DWORD, LPDWORD) -> FT_STATUS

class SerialPort {
    let ftdiCommPort:FT_HANDLE
    init(ftdiCommPort:FT_HANDLE) {
        self.ftdiCommPort = ftdiCommPort
    }
    
    var readFunction: FTDIFunction {
        return FT_Read
    }

    var writeFunction: FTDIFunction {
        return FT_Write
    }
}

func genericSerialCommunication(#bytesToReadOrWrite:[UInt8], #numberOfBytes:UInt, #serialPort:SerialPort, #communicationFunction:FTDIFunction)  -> Result<[UInt8], CommunicationsError> {
    var ftdiPortStatus: FT_STATUS = FT_STATUS(FT_OK)
    var bytesWrittenOrRead: DWORD = 0
    
    var bytesTransmitted = bytesToReadOrWrite
    
    runOnMainQueue {
        ftdiPortStatus = communicationFunction(serialPort.ftdiCommPort, LPVOID(bytesTransmitted), DWORD(numberOfBytes), &bytesWrittenOrRead)
    }
    
    if (ftdiPortStatus != FT_STATUS(FT_OK)) {
        return .Failure(Box(.ReadWriteTimeout))
    }
    
    if (bytesWrittenOrRead != DWORD(numberOfBytes)) {
        return .Failure(Box(.WrongByteCount(expectedByteCount:numberOfBytes, receivedByteCount:UInt(bytesWrittenOrRead))))
    }
    
    return .Success(Box(bytesTransmitted))
}

func writeBytesToSerialPort(#bytesToWrite:[UInt8], #serialPort:SerialPort) -> Result<(), CommunicationsError> {
    return ignoreValueButKeepError(genericSerialCommunication(bytesToReadOrWrite:bytesToWrite, numberOfBytes:UInt(bytesToWrite.count), serialPort:serialPort, communicationFunction:serialPort.writeFunction))
}

func readBytesFromSerialPort(#numberOfBytes:UInt, #serialPort:SerialPort) -> Result<[UInt8], CommunicationsError> {
    var bytesToRead = [UInt8](count:Int(numberOfBytes), repeatedValue:0)
    
    return genericSerialCommunication(bytesToReadOrWrite:bytesToRead, numberOfBytes:numberOfBytes, serialPort:serialPort, communicationFunction:serialPort.readFunction)
}