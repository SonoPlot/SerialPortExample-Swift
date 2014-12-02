# An example of serial port interaction in Swift #

Brad Larson

[@bradlarson](http://twitter.com/bradlarson)

Janie Clayton

[@RedQueenCoder](http://twitter.com/RedQueenCoder)

http://www.sonoplot.com

This is the sample code to accompany our [recent article on why we're rewriting our control software in Swift ](http://www.sunsetlakesoftware.com/2014/12/02/why-were-rewriting-our-robotics-software-swift). For posterity, that article has been reproduced below:

At SonoPlot, we just undertook a full rewrite of our robotic control software from Objective-C to Swift. While at first it might appear crazy to rework a large, stable project in a brand-new language, we did so after carefully examining sources of bugs in our Objective-C application and determining that Swift would prevent a large percentage of them. While we've only just started, we've learned enough so far that I thought there would be value in sharing this.

## Background ##

I should first start with a little background. I'm the CEO of a company called <a href="http://www.sonoplot.com">SonoPlot</a>, where we build <a href="http://www.sonoplot.com/products">robotic systems for printing liquid on the microscale</a>. These machines have a diverse range of applications, from <a href="http://pubs.acs.org/doi/abs/10.1021/nl202765b">printing microcircuitry for rapid prototyping</a> to <a href="http://www.sciencemag.org/content/345/6198/829.full">depositing biological materials for fabricating artificial cells</a>.

We originally built the software for these systems in a cross-platform manner, targeting Mac, Windows, and Linux using a C++ codebase. About eight years ago, we realized that as a small team we needed to focus on one platform in order to accelerate development and take on our much larger competitors.

After a lengthy evaluation of the Windows, Mac, and Linux development environments, we chose the Mac and Cocoa (despite none of us having much experience with the Mac before that). We rewrote our entire control software in Cocoa seven years ago, and looking back I feel that it was one of the best decisions our company has made.

To date, I have been the only one writing code at our company. However, with the significant growth of our business in recent years, and the fact that my role as CEO hasn't afforded me as much time to write software, it became clear I needed help. I hired <a href="http://redqueencoder.com">Janie Clayton</a> because I had worked with her on a successful National Science Foundation grant (which led to <a href="http://digitalworldbiology.com/dwb/products/molecule-world">this excellent molecular modeler</a>) and was incredibly impressed with her willingness to jump headfirst into difficult topics. Her story of going from not being a developer at all to being a coauthor of the new <a href="https://pragprog.com/book/adios2/ios-8-sdk-development">"iOS 8 SDK Development"</a> in just a couple years was also the talk of <a href="http://madisoncollege.edu/program-info/it-ios-applications-development">the iOS development program at Madison College</a>.

One of the first questions she asked me was whether we had plans to rewrite any part of our control software in Swift. My response at the time was the same as you'll hear from many others: there is no reason to rework a currently shipping Objective-C application in Swift. Swift might be useful for a new project (I've <a href="http://www.sunsetlakesoftware.com/2014/06/30/exploring-swift-using-gpuimage">had fun experimenting with it and GPUImage</a>), but I saw little to be gained by chasing the new shiny thing in a proven codebase.

## The problem ##

That was before we started taking a hard look at our control software and the issues we'd had in maintaining it over the last few years. We now have so many customers in the field, using these systems for so many different things, that even obscure bugs can affect a good number of people. The complexity of the software has also grown to the point that the chances of a change introducing a bug like this have increased dramatically. In fact, for a span of a year and a half we did nothing but fix one critical bug after another, with little forward progress on highly requested new features.

One of the first things we did after Janie was hired was to take an audit of all bugs that had shipped to customers in the last three years. We wanted to understand the root causes of the problems that had slipped through our testing. In several cases, these led to real, and very expensive, damage to hardware in the field.

We did indeed see surprising patterns in the causes of these bugs. I found myself repeatedly saying to myself or Janie that a particular bug wouldn't have even compiled under Swift, or would have thrown an immediate exception. When we totaled up bugs like this, we found that <a href="https://twitter.com/bradlarson/status/518053543866269696">~40% of bugs shipped to customers in the last three years would have been caught immediately by using Swift</a>. The primary classes of these bugs were:

- Silent failures due to nil-messaging
- Improperly handled NSErrors, or other Objective-C error failures
- Bad object typecasts
- Wrong enum lookup tables being used for values

When I'm referring to bad object typecasts, I'm usually talking about what Matt Drance coined <a href="http://rentzsch.tumblr.com/post/477428004/faith-based-casts">"faith-based casting"</a>. You might have an NSArray, which has no strong types for the objects contained within, and try to pull out what you assume to be an NSString, only to find at runtime it was really an NSNumber. Likewise, context objects provided as id types can be very dangerous if you believe they are one type of object, and instead are another (or either end is changed without updating the other). 

This can compile just fine, but cause nasty crashes or worse at runtime, some of which slipped through our tests. Swift's strong types prevent this at compile time, if used properly.

I'll talk more about Swift's new enum type later, but decoupling it from an integer numeric type means that you can guarantee one type of enum isn't accidentally used in the place of another. This is possible in Objective-C, leading to the wrong lookup table being used for something like an error classification. More than one subtle bug in our software was introduced by something like this. Also, Swift's descriptive enum cases make each case very clear at the point they're used, saving you a trip to the lookup table to know what they stand for.

The other two groups of bugs deserve a little more detail:

## nil, the silent killer ##

When I moved from C++ development to Objective-C, one of the things I enjoyed most was no longer needing to check nil pointers to prevent crashes. The silent failing of messages sent to nil objects seemed like a tremendous convenience, and allowed me to reduce the amount of code I wrote.

However, after doing this for a while, I've seen enough nasty failure cases of nil messaging that I enthusiastically welcome Swift's optionals. Messages sent to nil objects don't through compiler errors and they generally don't lead to crashes or obvious behavior you can catch at runtime. That makes improper nil messaging extremely hard to track down, even in thorough testing.

Every Cocoa programmer who has worked with Interface Builder has at some point forgotten to connect an IBOutlet between an interface element and one of their class properties, leaving that property nil. Usually we fumble around for a while trying to figure out why clicking a button doesn't do anything, then realize what we did wrong. However, with complex enough interfaces and last-minute changes in code, occasionally a missing connection is overlooked in testing and gets shipped out to customers. That can cause everything from irritation at disabled features to damage in the field, if said interface element did something like adjust movement speeds of a robotics system.

One way many of us address this is by using runtime assertions for all of our IBOutlets that crash on a nil connection, instead of silently failing (or returning a 0 value) when accessed. However, this requires us to identify each IBOutlet, write the assertion code, and make sure we keep that up to date. Missing a single one can lead to a bug slipping through.

Replacing these properties with optionals in Swift and then using forced unwrapping can help to protect against this. If used consistently, this can at least prevent the cases where these unconnected IBOutlets are accessed in code by crashing in a clear manner the instant they are messaged. This allows for these properties to be caught earlier in testing, before this is shipped to customers. It doesn't catch all cases, such as buttons that are never accessed in code, but it would have prevented all of our most troublesome bugs in this class.

Finally, let me talk about one specific bug with nil messaging that cost us a lot of money. In our software, we use an object to represent a coordinate in 3-D space (with associated methods for processing and manipulation). When the robot needs to be commanded to move to a particular location, that coordinate object is passed into a series of methods that end up coordinating the three axes of motion to travel to that point. At the lowest level, the X, Y, and Z coordinates of that point are retrieved from that object by accessing its properties.

Now, it turned out that under certain very rare circumstances a nil value ended up being passed in to these movement methods (due to premature invalidation of a coordinate object). In our robots, the lowest point on the Z axis is 0, with Z values increasing as the Z axis moves up. Now, what happens when you query the integer value of a property by sending a message to a nil object? You get back 0. So, when this nil object was passed into our movement methods, our robots would promptly drive their print heads clean into the deck of the positioning system, smashing them. The one bug maybe cost us $10k total in replacement hardware and other support expenses over all the times it triggered in the field.

Of all the new language features, optionals in Swift seem to be the most complained-about among the Objective-C developers I know. However, I believe that the safety they introduce against really nasty bugs far outweighs any inconvenience when writing code. Some of that inconvenience can even be alleviated using the syntactic sugar Apple has provided for these types, <a href="http://www.objc.io/snippets/9.html">along with techniques from the functional programming world</a>. I would much rather have my code fail early, preferably at compile time, than leave open the possibility of shipping another bug like the above to our customers.

## My problems with Objective-C error handling ##

Our control software makes extensive use of error handling. When interacting with multiple pieces of hardware, all kinds of things can cause errors: EM interference on sensor lines, dropped bytes on an RS-232 port, obstructions in the robot's path, a camera being unplugged, etc. We generate and handle lots of errors internally, many of which can be recovered from without involving the operator. Some do require manual intervention, with appropriate instructions and warnings.

As a result, we have a lot of code that uses the standard Objective-C pattern for handling errors. This typically looks something like the following:

```
- (BOOL)setTriggerValue:(unsigned char)newValue error:(NSError **)error;
{
	unsigned char triggerCommand[2];
	triggerCommand[0] = 'T';
	triggerCommand[1] = newValue;
	
	if (![self sendCommandToElectronics:triggerCommand ofSize:2 error:error])
	{
		return NO;
	}
	
	unsigned char characterToRead;
	if (![self readResponseFromElectronics:&characterToRead ofSize:1 error:error])
	{
		return NO;
	}

	if (characterToRead != 'T')
	{
		if (error != nil)
		{
			*error = [SPElectronics errorForElectronicsErrorType:CORRUPTRESPONSEFROMELECTRONICS recoveryAttempter:self];
		}
		return NO;
	}
	
	return YES;
}
```

The above method sends a two-byte command over a serial port to a piece of hardware, then reads back a single byte, which should be "T" to confirm a successful transmission. It can fail at multiple places: a timeout or corruption on writing a value, a timeout or incorrect number of bytes on reading the response, and a non-"T" value being read back if the command failed. All of these need to be accounted for.

Because Objective-C methods (and C functions) cannot return more than one value, in order to be able to return an error in parallel with a result, we have to pass in an NSError double pointer. We then have to check the return from the method to see if it signifies an error. Immediately, you can see that this is fairly clunky, with something that's intended as an output being passed in as an input.

It gets worse, though, in that for many Cocoa methods if you even try to access the error without checking the return value first, <a href="http://rentzsch.tumblr.com/post/260201639">you will crash due to the error being scribbled upon internally</a>. You have to pay attention to the failure state of the result, but that can vary between different data types. Returning nil for objects is sometimes the failure condition (sometimes leading to the silent failures described above if you're not diligent in processing your errors), a boolean is used in others, and for scalar types you might have a magic constant that denotes an error (which you hopefully would never return as a legitimate result).

Passing around that NSError double pointer can lead to problems. You have to create an NSError at the top level, pass it all the way down your execution chain, and then have it bubble all the way back up. At any point this can get screwed up, such as passing in a nil NSError** at the beginning. Note that I have to explicitly check for this when passing back my own custom error, or you'll hit a null pointer dereference and crash (or worse).

For me, a larger problem is that you never are forced to think about error states. You can freely pass in nil for an error, forget that you need to account for erroneous results due to failed operations, and regret it once that code ships to your customers. I want the compiler to make sure that I'm always accounting for failable operations, even if it's just to explicitly ignore the error case. I've been bitten too many times by missed error handling in my code.

For more about the problems with this method of error handling, I recommend listening to Jonathan 'Wolf' Rentzsch's diatribe on the <a href="http://edgecasesshow.com/007-if-you-look-at-the-error-you-will-crash.html">"If You Look at the Error, You Will Crash" episode of the Edge Cases podcast</a>.

Thankfully, Swift provides us with an elegant way of approaching this problem. My friend Chris Cieslak describes this in <a href="http://swiftlytyping.tumblr.com/post/88210131086/error-handling">his post here</a>, only days after Swift was announced, and I've seen many others converge on this method of error handling. This process relies on Swift's new enums that support associated valued (algebraic types), combined with generics.

If we use an enum, we can now represent the result from a failable operation as either the return value of the successful operation (whatever type that value may be) or the error generated by the operation. You either succeed or fail, and are only returned the value appropriate to either condition. Such a result type looks like the following in Swift (the Box is a temporary workaround for a current compiler shortcoming):

```
public enum Result<T, U> {
    case Success(Box<T>)
    case Failure(Box<U>)
}
```

This is effectively an Either type from Haskell, built to serve a similar purpose there. It moves the returnable error from an input to an output (relieving you of having to pass in a blank one), gets rid of magic constants and all the other ways of signifying a failure, prevents NSError pointer-related crashes, and forces you to think about the possibility of failure. (The general structure, and the Box() implementation, are drawn from Rob Napier's <a href="https://github.com/LlamaKit/LlamaKit">LlamaKit</a>.)

We're using generics for both the encapsulated success and failure types to make this as extensible as possible, while still preserving strong types. We want to make sure that you can still tell that an Int returned as a result can't be sent into something taking a String, etc. Also, we're leaving this open to various error types, not just NSError, for reasons I'll discuss shortly.

Now, you might be worried about all the switch statements you'll need to use to handle error and success cases. That's where we can learn a little more from Haskell and other functional languages and use a monadic bind to simplify this. While it has a scary name, a monadic bind is actually a simple function that either kicks back an error if the Result was a Failure or unwraps the Success value and passes it on if the operation succeeded. I've set this up as a method on Result called .then:

```
func then<V>(nextOperation:T -> Result<V, U>) -> Result<V, U> {
    switch self {
        case let .Failure(boxedError): return .Failure(boxedError)
        case let .Success(boxedResult): return nextOperation(boxedResult.unbox)
    }
}
```

only because using the >>= operator for bind, as in Haskell, doesn't read the cleanest. While I understand the arguments for maintaining names and building upon years of work in functional programming languages, I lean towards making my code more accessible.

Using Result and this bind operation, our above Objective-C method can be converted into a Swift function like this:

```
func setTriggerValue(#serialPort:SerialPort, #trigger:UInt8) -> Result<(), CommunicationsError> {
    let commandCharacter = UInt8(UnicodeScalar("T").value)
    let commandToWrite = [commandCharacter, trigger]
    
    let response = writeBytesToSerialPort(bytesToWrite:commandToWrite, serialPort:serialPort)
        .then{readBytesFromSerialPort(numberOfBytes:1, serialPort:serialPort)}
        .then{(bytesRead:Array<UInt8>) -> Result<(),CommunicationsError>  in
            if (bytesRead[0] == commandCharacter) {
                return .Success(Box(()))
            }
            else {
                return .Failure(Box(.CorruptedResponse(expectedResponse:[commandCharacter], receivedResponse:bytesRead)))
            }
        }
    
    return ignoreValueButKeepError(response)
}
```

The way this code works is by first writing a command to the serial port, which returns a Result value. If that Result is a .Failure, the .then() method bails and returns the .Failure and its associated error. Otherwise, it proceeds to the next step. We then read bytes from the serial port. Again, if that fails, it bails out and returns the error. If it succeeds, however, the bytes read from the serial port are unboxed from the .Success type and passed into the next operation. In there, the lone byte we read is checked to make sure it is the "T" value we expect. If so, .Success is returned. If not, we construct an error that contains all the context we need, wrap it in a .Failure, and return that.

We've gone from 28 lines of code to 18, while making this safer and more robust. We don't have to worry about NSError shenanigans or forgetting to handle the failure state, and everything is strongly typed the whole way through so we know the parts connect together correctly.

You may notice that I'm not using NSError at all as an error type in the above, but instead something called a CommunicationsError. I've come to believe that NSError, while a fine error type for Objective-C, is no longer the best way to do errors in Swift. I <a href="https://groups.google.com/d/msg/llamakit/cQdv2i2A4Zw/FYP10NuRYOwJ">talked about this in detail on Rob Napier's LlamaKit mailing list</a>, but I think that the power of enums with associated values makes them a better choice for an error type.

NSErrors rely on internal integer error codes, which you have to trust an enum lookup table for (as described above, sometimes the wrong table can be used for this). Their associated data dictionary is a very loosely typed bag of attached values, and it can be fun to look up or document keys that are used for this. Creation of a custom error, like I do in the Objective-C example above, can often require a helper method to encapsulate the setup code.

Instead, you can use Swift enums to provide strong types, just as much associated information as you need, and prevent any confusion as to the error value. My CommunicationsError looks something like the following:

```
enum CommunicationsError {
    case ReadWriteTimeout
    case WrongByteCount(expectedByteCount:UInt, receivedByteCount:UInt)
    case CorruptedResponse(expectedResponse:[UInt8], receivedResponse:[UInt8])
}
```

That's it. Simple, readable, yet containing the context you need. You want to return an error, just return a .ReadWriteTimeout, no helper method or lookup table required. We've replaced NSError with this for all our internal errors, and we consider this a large win.

## Reducing mutable state to avoid coupling ##

OK, so I've described ways that we can avoid or catch 40% of the bugs that made it out to our customers. What about the remaining 60%? While those may not be immediately eliminated by Swift language features, Swift provides us better ways of reducing or catching even those.

The largest remaining source of bugs is where changes in one section of code cause unanticipated effects in another seemingly unrelated section. As the codebase grew in complexity, so did the odds of this happening and the detrimental effects when it did. Almost always, this was due to shared mutable state of a variable or class.

When an object is mutable, and references to it are passed between multiple other objects, an operation performed in one area of your code that changes (mutates) the value of this object can lead to "spooky action at a distance" in another otherwise unrelated section. We saw clear evidence in many, many bugs during our audit. These kinds of interactions can lead to a level of complexity and fragility in your code that makes it incredibly hard to maintain.

Swift's enhanced value types (structs, enums) and stronger support for declaring things immutable makes it much easier to start decoupling this code and to avoid unexpected side-effects. I won't spend much more time describing how, but Andy Matuschak and Colin Barrett describe this clearly in <a href="https://developer.apple.com/videos/wwdc/2014/">WWDC 2014 Session 229: "Advanced iOS Application Architecture and Patterns"</a>, which I highly recommend you watch. While you're at it, read <a href="http://www.objc.io/issue-16/swift-classes-vs-structs.html">Andy's recent objc.io article on value types</a>. Finally, <a href="http://sydneycocoaheads.com/2014/08/27/swift-adopting-functional-programming-by-manuel-chakravarty/">Manuel Chakravarty's recent talk at the Sydney CocoaHeads</a> is a must-watch if you care about making your Swift applications safer in this regard.

## Writing testable code ##

Now, after reading through our issues with bugs that shipped to customers, you might be questioning how thorough our tests are. I'll be the first to admit that our codebase has pretty terrible unit test coverage. It's a clear example of <a href="http://www.amazon.com/Working-Effectively-Legacy-Michael-Feathers/dp/0131177052">"legacy code"</a>, and that's something we want to change. 

To date, we've relied on a higher-level testing protocol that required running the control software through a series of common actions on real hardware. This process takes a full day to run through and requires manual supervision to do so. It very clearly misses many bugs, so we wanted to provide lower-level unit test coverage, particularly in troublesome areas for known problems we've had.

However, the structure of our code has made this difficult to even start with. Complex, interacting objects that encapsulate lots of functionality and that interact with multiple pieces of hardware proved to be quite a challenge to write unit tests for. In addition to the coupling from mutable state we talked about before, we needed to rearchitect some of this to make it more testable.

I've been learning Haskell in parallel with Swift, and the strongly typed functional nature of that language has colored my interaction with Swift. (Something I highly recommend for Swift developers: start with <a href"http://learnyouahaskell.com">"Learn You a Haskell for Great Good"</a> and an <a href="https://github.com/gibiansky/IHaskell">IHaskell</a> session, or even just <a href="https://www.youtube.com/watch?v=jLj1QV11o9g">watch Simon Peyton-Jones introduce the language</a>.) One of the best lessons I've taken away from that is how to build "pure" functions that take in clear inputs, have clear outputs, and produce no other side effects. These pure functions are deterministic in nature, which makes them easy to unit test.

The Result type I describe above really helps with this, as it makes the inputs and outputs for a failable function very clear. While the sample serial port function I show above isn't pure, in that it involves a side effect of communication with an outside piece of hardware, it can be made deterministic for testing.

We do this using a fake serial port, something that lets us build unit tests for all kinds of functionality that we previously needed actual hardware to test. Our main, real serial port class looks something like this:

```
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
```

We're using FTDI's USB-to-serial chip in our hardware, and we communicate with it via their D2XX library. The read and write commands both have the same signature, so we can use higher-order functions to swap out the function to be used for reading or writing with the serial port. The generic function that handles the reads / writes and error cases is as follows, with one specialization:

```
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

func readBytesFromSerialPort(#numberOfBytes:UInt, #serialPort:SerialPort) -> Result<[UInt8], CommunicationsError> {

    // TODO: Test case about UInt vs. Int on the length here
    var bytesToRead = [UInt8](count:Int(numberOfBytes), repeatedValue:0)
    
    return genericSerialCommunication(bytesToReadOrWrite:bytesToRead, numberOfBytes:numberOfBytes, serialPort:serialPort, communicationFunction:serialPort.readFunction)
}
```

An organization like this makes it very easy for use to subclass the serial port and create our own fake port for testing purposes. Because higher-order functions are used, we can create our own communication functions that fail in controlled ways (to test communication errors) or that return specific sequences of bytes and provide those instead of the FTDI functions. With that, we can fully simulate actual hardware being attached to the computer, all the way up to the highest level in our code.

To do that, we have our fake serial port take in a list of enums representing sequential read and write responses from the serial port and then return the matching functions when interacted with. This lets us set up deterministic behavior for otherwise pure functions that take in a serial port as input.

As one example of how these functions can replace one of the library functions, we might need to have the serial port respond with a custom sequence of bytes. We'd need to provide a function that did this, but still matched the FTDI function signature shown above. For this, we use the following function:

```
func customBytesFunction(bytes:[UInt8])(FT_HANDLE, byteArray:LPVOID, bytesToReadOrWrite:DWORD, bytesWrittenOrReadPointer:LPDWORD) -> FT_STATUS {
    var bytesWrittenOrRead = UnsafeMutablePointer<DWORD>(bytesWrittenOrReadPointer)
    bytesWrittenOrRead[0] = DWORD(bytes.count)
    
    var outputByteArray = UnsafeMutablePointer<UInt8>(byteArray)
    for indexOfByte in 0..<bytes.count {
        outputByteArray[indexOfByte] = bytes[indexOfByte]
    }
    
    return FT_STATUS(FT_OK)
}
```

This is a good example of a curried function. A curried function is one where you can provide some of the arguments (in this case, the bytes to be passed back), but not all, and get back a function that is now only needs the remaining arguments to be specified. We provide the bytes we want to have this return, the function is specialized based on that, and the function will now fit into the signature for all other serial port communication functions.

Because we often need to test our Result types to both verify that we didn't get a .Failure when we expected a .Success (or vice versa) and that whatever was boxed in the .Failure or .Success type matches our expectation, we created helper functions like this:

```
func assertResultsAreEqual<T:Equatable,U:Equatable> (lhs: Result<T, U>, rhs: Result<T, U>, file: String = __FILE__, line: UInt = __LINE__) {
    switch (lhs, rhs) {
        case let (.Success(boxedValue), .Success(boxedValue2)):  XCTAssert(boxedValue.unbox == boxedValue2.unbox, "Expected .Success value of \(boxedValue2.unbox), and instead got back \(boxedValue.unbox).", file:file, line:line)
        case let (.Success, .Failure): XCTAssert(false, ".Success != .Failure", file:file, line:line)
        case let (.Failure, .Success): XCTAssert(false, ".Failure != .Success", file:file, line:line)
        case let (.Failure(boxedError), .Failure(boxedError2)): XCTAssert(boxedError.unbox == boxedError2.unbox, "Expected .Failure value of \(boxedError2.unbox) and got back \(boxedError.unbox).", file:file, line:line)
    }
}
```

Note the use of the __FILE__ and __LINE__ constants, which the Swift team describes in <a href="https://developer.apple.com/swift/blog/?id=15">this blog post</a> so that our XCTAsserts mark failures at the point where assertResultsAreEqual() is used, not within that function. We also have variants of this assertion for T or U not being Equatable types (where we're only caring about comparing a result type or an error type). 

As with the higher-order functions and function currying, Swift pattern matching in the switch statement and the use of generics make for clean, reusable code in our unit test cases. If you're intrigued by these functional Swift capabilities, I highly recommend reading <a href="http://www.objc.io/books/">"Functional Programming in Swift"</a> by Chris Eidhof, Florian Kugler, and Wouter Swierstra.

Overall, we've been writing unit tests as we convert each bit of functionality to Swift, and they've already exposed a number of subtle issues we missed before. The ability to set up artificial communication sequences will allow us to reproduce specific conditions that we might have otherwise only once in a week of continuous hardware operation.

I've had a number of people remark to me that the safety improvements and testing I propose here are really useful for safeguarding new developers, and might not be as useful for experienced ones. Let me tell you this: until very recently, I was the lone author of all of our control software, I consider myself a reasonably experienced Cocoa developer, yet I was responsible for all of the stupid bugs that got shipped to our customers. I warmly welcome anything that can prevent me from making the same mistakes over and over again.

## A long ways to go ##

I had wanted to write this once we had completed our rewrite of our control software, but that's still going to take a while to complete and we'd learned enough to date that I felt it worth sharing. I have a feeling I'll revisit all of this later with even more, as we get deeper into this project.

Likewise, it's still early days for Swift and its tools, so there are some problems we've encountered as we've been working on this. The largest is the need for the Box() wrapper class in the Result type we use everywhere, since the current compiler throws an "Unimplemented IR generation feature non-fixed multi-payload enum layout" error if you try to use the generics directly within an enum. I'm really hoping that gets fixed soon.

Also a challenge are the unclear and sometimes misdirecting error messages the compiler throws when it encounters mismatched types. In general, the fact that there's an error is almost always correct, but trying to puzzle out what the error is in a line of code tends to take longer than it should. The compiler has a tendency to tell you that a particular type is wrong, when instead it was another unrelated type in that line that was the actual problem. For example, I've seen the error "Could not find member Success" when really it was that the type used for Success was wrong (.Success(1) instead of .Success("text")). Still, when something compiles I feel very confident now that I've gotten it right.

There are other minor things, like string interpolation being broken for enums at present, but none of those are showstoppers for us.

That said, many of the complaints that I've read from developers about Swift come from trying to directly translate Objective-C code to this new language. Swift is a new language that presents us with the opportunity to approach common problems in a different way, and I think it's worth reexamining Objective-C patterns rather than blindly continuing with them. I hope that what I've written here illustrates how that might lead to cleaner, safer code.

If the code above seems complex or inscrutable by itself, we've created <a href="https://github.com/SonoPlot/SerialPortExample-Swift">a public repository of a stripped-down version of part of the code we're using on GitHub</a>. Grab that project and you can hopefully see and tinker with the general structure of what I've described here.

