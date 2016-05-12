//
//  main.swift
//  ble
//
//  Created by Thibaut Roche on 12/05/2016.
//  Copyright © 2016 Thibaut Roche. All rights reserved.
//

import Foundation

let bleManager = BLECentralManager()

let date = NSDate()
let timer = NSTimer(fireDate: date, interval: 0.01, target: bleManager, selector: #selector(bleManager.launch), userInfo: nil, repeats: false)

let runLoop = NSRunLoop.currentRunLoop()
runLoop.addTimer(timer, forMode: NSDefaultRunLoopMode)
runLoop.run()
