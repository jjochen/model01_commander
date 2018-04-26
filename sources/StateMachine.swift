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
    let prompter = UserPrompter()

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
        if availablePorts.count == 0 {
            print("No connected serial ports found.")
            print("Please connect your USB to serial adapter(s) and run the program again.\n")
            exit(EXIT_SUCCESS)
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
        if let index = Int(selectionString) {
            let clampedIndex = min(max(index, 0), availablePorts.count - 1)
            serialPort = availablePorts[clampedIndex]
            return true
        } else {
            return false
        }
    }

    func setBaudRateOnPortWithString(_ selectionString: String) -> Bool {
        var selectionString = selectionString
        selectionString = selectionString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if let baudRate = Int(selectionString) {
            serialPort?.baudRate = NSNumber(value: baudRate)
            print("Baud rate set to \(baudRate)", terminator: "")
            return true
        } else {
            return false
        }
    }
}

// MARK: - Data Processing

extension StateMachine {
    func handleUserInput(_ dataFromUser: Data) {
        if let string = NSString(data: dataFromUser, encoding: String.Encoding.utf8.rawValue) as String? {
            if string.lowercased().hasPrefix("exit") ||
                string.lowercased().hasPrefix("quit") {
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
    }
}

// MARK: - ORSSerialPortDelegate

extension StateMachine: ORSSerialPortDelegate {
    func serialPort(_: ORSSerialPort, didReceive data: Data) {
        if let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            print("\nReceived: \"\(string)\" \(data)", terminator: "")
        }
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
