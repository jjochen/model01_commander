//
//  UserPrompter.swift
//  model01_commander
//
//  Created by Jochen on 26.04.18.
//  Copyright © 2018 Jochen Pfeiffer. All rights reserved.
//

import Foundation

struct UserPrompter {
    static func printIntroduction() {
        print("This program demonstrates the use of ORSSerialPort")
        print("in a Foundation-based command-line tool.")
        print("Please see http://github.com/armadsen/ORSSerialPort.\n")
    }

    static func printPrompt() {
        print("\n> ", terminator: "")
    }

    static func promptForSerialPort() {
        print("\nPlease select a serial port: \n")
        let availablePorts = ORSSerialPortManager.shared().availablePorts
        var index = 0
        for port in availablePorts {
            print("\(index). \(port.name)")
            index += 1
        }
        printPrompt()
    }

    static func promptForBaudRate() {
        print("\nPlease enter a baud rate: ", terminator: "")
    }
}
