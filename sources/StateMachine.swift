//
//  StateMachine.swift
//  model01_commander
//
//  Created by Jochen on 26.04.18.
//  Copyright © 2018 Jochen Pfeiffer. All rights reserved.
//

import Foundation

enum ApplicationState {
    case initializationState
    case waitingForPortSelectionState([ORSSerialPort])
    case waitingForBaudRateInputState
    case waitingForUserInputState
}

class StateMachine: NSObject {
    var currentState = ApplicationState.initializationState
    let standardInputFileHandle = FileHandle.standardInput

    var serialPort: ORSSerialPort? {
        didSet {
            serialPort?.delegate = self
            serialPort?.open()
        }
    }

    func runProcessingInput() {
        setbuf(stdout, nil)
        standardInputFileHandle.readabilityHandler = { (fileHandle: FileHandle) in
            let data = fileHandle.availableData
            DispatchQueue.main.async {
                self.handleUserInput(data)
            }
        }

        UserPrompter.printIntroduction()

        let availablePorts = ORSSerialPortManager.shared().availablePorts
        guard availablePorts.count > 0 else {
            print("No connected serial ports found.")
            print("Please connect your USB to serial adapter(s) and run the program again.\n")
            exit(EXIT_FAILURE)
        }

        UserPrompter.promptForSerialPort()
        currentState = .waitingForPortSelectionState(availablePorts)

        RunLoop.current.run() // Required to receive data from ORSSerialPort and to process user input
    }
}

// MARK: - Port Settings

extension StateMachine {
    func setupAndOpenPortWithSelectionString(_ selectionString: String, availablePorts: [ORSSerialPort]) -> Bool {
        var selectionString = selectionString
        selectionString = selectionString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard let index = Int(selectionString) else {
            return false
        }
        let clampedIndex = min(max(index, 0), availablePorts.count - 1)
        serialPort = availablePorts[clampedIndex]
        return true
    }

    func setBaudRateOnPortWithString(_ selectionString: String) -> Bool {
        var selectionString = selectionString
        selectionString = selectionString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard let baudRate = Int(selectionString) else {
            return false
        }
        serialPort?.baudRate = NSNumber(value: baudRate)
        print("Baud rate set to \(baudRate)", terminator: "")
        return true
    }
}

// MARK: - Data Processing

extension StateMachine {
    func handleUserInput(_ dataFromUser: Data) {
        guard let string = NSString(data: dataFromUser, encoding: String.Encoding.utf8.rawValue) as String? else {
            return
        }

        if string.lowercased().hasPrefix("exit") || string.lowercased().hasPrefix("quit") {
            print("Quitting...")
            exit(EXIT_SUCCESS)
        }

        switch currentState {
        case let .waitingForPortSelectionState(availablePorts):
            if !setupAndOpenPortWithSelectionString(string, availablePorts: availablePorts) {
                print("\nError: Invalid port selection.", terminator: "")
                UserPrompter.promptForSerialPort()
                return
            }
        case .waitingForBaudRateInputState:
            if !setBaudRateOnPortWithString(string) {
                print("\nError: Invalid baud rate.", terminator: "")
                print("Baud rate should consist only of numeric digits.", terminator: "")
                UserPrompter.promptForBaudRate()
                return
            }
            currentState = .waitingForUserInputState
            UserPrompter.printPrompt()
        case .waitingForUserInputState:
            serialPort?.send(dataFromUser)
            UserPrompter.printPrompt()
        default:
            break
        }
    }

    func handleReceivedData(_ receivedData: Data) {
        guard let string = NSString(data: receivedData, encoding: String.Encoding.utf8.rawValue) as String? else {
            return
        }

        print("\nReceived: \"\(string)\" \(receivedData)", terminator: "")

        let appPrefix = "app:"
        if string.hasPrefix(appPrefix) {
            let app = String(string.dropFirst(appPrefix.count))
            open(app)
            return
        }
    }

    func open(_ app: String) {
        guard app.count > 0 else {
            return
        }
        print("Opening \(app) ...")
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", app]
        task.launch()
    }
}

// MARK: - ORSSerialPortDelegate

extension StateMachine: ORSSerialPortDelegate {
    func serialPort(_: ORSSerialPort, didReceive data: Data) {
        handleReceivedData(data)
        UserPrompter.printPrompt()
    }

    func serialPortWasRemovedFromSystem(_: ORSSerialPort) {
        serialPort = nil
    }

    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print("Serial port (\(serialPort)) encountered error: \(error)")
    }

    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print("Serial port \(serialPort) was opened", terminator: "")
        UserPrompter.promptForBaudRate()
        currentState = .waitingForBaudRateInputState
    }
}
