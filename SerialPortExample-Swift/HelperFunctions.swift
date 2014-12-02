import Foundation

func runOnMainQueue(blockToRun:() -> ()) {
    if (NSThread.isMainThread()) {
        blockToRun()
    } else {
        dispatch_sync(dispatch_get_main_queue(), blockToRun)
    }
}