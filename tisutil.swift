import Carbon
import Foundation

// List all keyboard input sources when called with "list"
func listSources() {
    guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
        print("Error: could not get input source list")
        return
    }
    for source in list {
        guard let idRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
        let id = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String

        guard let typeRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) else { continue }
        let type = Unmanaged<CFString>.fromOpaque(typeRef).takeUnretainedValue() as String

        // Only show keyboard layout and input method types
        if type == (kTISTypeKeyboardLayout as String) || type == (kTISTypeKeyboardInputMode as String) {
            guard let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { continue }
            let name = Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String
            print("\(id) | \(name)")
        }
    }
}

// Select input source by ID
func selectSource(id targetID: String) -> Bool {
    guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
        return false
    }
    for source in list {
        guard let idRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
        let id = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
        if id == targetID {
            let result = TISSelectInputSource(source)
            return result == noErr
        }
    }
    return false
}

// Get current input source ID
func currentSourceID() -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
    guard let idRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
    return Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
}

// Main
let args = CommandLine.arguments
if args.count < 2 {
    print("Usage: tisutil list | toggle | <source-id>")
    exit(1)
}

switch args[1] {
case "list":
    listSources()

case "current":
    if let id = currentSourceID() { print(id) } else { print("unknown") }

case "toggle":
    let sogou = "com.sogou.inputmethod.sogou.pinyin"
    let us = "com.apple.keylayout.USExtended"
    if let cur = currentSourceID() {
        if cur.contains("sogou") {
            if selectSource(id: us) { print("switched to: \(us)") }
            else { print("failed to select: \(us)") }
        } else {
            if selectSource(id: sogou) { print("switched to: \(sogou)") }
            else { print("failed to select: \(sogou)") }
        }
    } else {
        print("could not determine current source")
    }

case "select":
    if args.count >= 3 {
        if selectSource(id: args[2]) { print("selected: \(args[2])") }
        else { print("failed to select: \(args[2])") }
    } else {
        print("Usage: tisutil select <source-id>")
    }

default:
    if selectSource(id: args[1]) {
        print("selected: \(args[1])")
    } else {
        print("failed to select: \(args[1])")
    }
}
