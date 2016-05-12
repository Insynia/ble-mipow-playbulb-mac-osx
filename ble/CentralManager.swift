//
//  CentralManager.swift
//  ble
//
//  Created by Thibaut Roche on 12/05/2016.
//  Copyright © 2016 Thibaut Roche. All rights reserved.
//

import Foundation
import CoreBluetooth

let bufferSize = 8

func readline(fd: Int32) -> String {
    var buffer: [CChar] = Array(count: bufferSize, repeatedValue: 0)
        
    read(fd, &buffer, bufferSize)
    
    var len = -1
    var i = 0
    while (i < bufferSize)
    {
        if buffer[i] == 0x0a || buffer[i] == 0 {
            len = i + 1
            break
        }
        i += 1
    }
    if len == -1
    {
        len = bufferSize
    }
    //return String(buffer)
    return NSString(bytes: buffer, length:len, encoding:NSUTF8StringEncoding) as! String
}

class BLECentralManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate
{
    var             centralManager: CBCentralManager!
    var             peripheral: CBPeripheral?
    var             service: CBService?
    var             characteristic: CBCharacteristic?
    var             actualColor: NSData!
    
    //MARK:-
    //MARK: Init
    override init()
    {
        super.init()
    }
    
    func launch()
    {
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    //MARK: -
    //MARK: Bluetooth handling
    func scanForPeripherals()
    {
        self.centralManager.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func changeColor(br: String, r: String, g: String, b: String)
    {
        let bright = Int(br, radix: 16)!
        let red = Int(r, radix: 16)!
        let green = Int(g, radix: 16)!
        let blue = Int(b, radix: 16)!
        let bytes: [UInt8] = [UInt8(bright), UInt8(red), UInt8(green), UInt8(blue)]
        
        self.actualColor = NSData(bytes: bytes, length: bytes.count)
        
        self.actualColor = NSData(bytes: bytes, length: bytes.count)
        if self.peripheral != nil && self.characteristic != nil
        {
            self.peripheral!.writeValue(actualColor, forCharacteristic: self.characteristic!, type: .WithoutResponse)
        }
    }
    
    //MARK: -
    //MARK: Daemon
    func launchDaemon()
    {
        var address: sockaddr_un
        var socket_fd: Int32
        var connection_fd: Int32
        var address_length: socklen_t;
        let path: String = "./ble_socket.cunt"
        
        print("---- Launching Daemon ----")
        socket_fd = socket(PF_UNIX, SOCK_STREAM, 0)
        if socket_fd < 0
        {
            print("Error: Socket failed")
            return
        }
        unlink("./ble_socket.cunt");
        address = sockaddr_un()
        memset(&address, 0, sizeof(sockaddr_un))
        address.sun_family = UInt8(AF_UNIX)
        address.sun_len = UInt8(sizeof(sockaddr_un))
        path.withCString { p in
            withUnsafeMutablePointer(&address.sun_path) { sun_path in
                strcpy(UnsafeMutablePointer(sun_path), p)
            }
        }
        if bind(socket_fd, sockaddr_cast(&address), socklen_t((sizeof(sockaddr_un)))) != 0
        {
            print("bind() failed\n")
            return
        }
        
        if(listen(socket_fd, 5) != 0)
        {
            print("listen() failed\n")
            return
        }
        
        while true
        {
            address_length = socklen_t(sizeof(sockaddr_un));
            connection_fd = accept(socket_fd, sockaddr_cast(&address), &address_length)
            if connection_fd < 0
            {
                print("Je vais crasher")
                break
            }
            while true
            {
                let l: String = readline(connection_fd)
                
                if l == "EXIT0000" {
                    break
                }
                if l.characters.count == 8
                {
                    let index1 = l.startIndex.advancedBy(2)
                    let index2 = l.startIndex.advancedBy(4)
                    let index3 = l.startIndex.advancedBy(6)
                    let index4 = l.startIndex.advancedBy(8)
                    
                    let br: String = l[l.startIndex..<index1]
                    let r: String = l[index1..<index2]
                    let g: String = l[index2..<index3]
                    let b: String = l[index3..<index4]
                    
                    changeColor(br, r: r, g: g, b: b)
                }
            }
            close(connection_fd);
        }
        close(socket_fd);
        unlink("./ble_socket.cunt");
    }
    
    //MARK: -
    //MARK: CBCentralManagerDelegate
    func centralManagerDidUpdateState(central: CBCentralManager)
    {
        switch central.state
        {
        case .PoweredOn:
            print("Central State PoweredOn")
            self.scanForPeripherals()
        case .PoweredOff:
            print("Central State PoweredOFF")
        case .Resetting:
            print("Central State Resetting")
        case .Unauthorized:
            print("Central State Unauthorized")
        case .Unknown:
            print("Central State Unknown")
        case .Unsupported:
            print("Central State Unsupported")
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber)
    {
        if self.peripheral == nil && peripheral.name == "Touche a ton cul"
        {
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            self.centralManager.connectPeripheral(self.peripheral!, options: nil)
            self.centralManager.stopScan()
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral)
    {
        print("Connected to \(peripheral.name)")
        self.peripheral?.discoverServices(nil)
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?)
    {
        print("Ca a fail... C'est pas bien.")
    }
    
    //MARK: -
    //MARK: CBPeripheralDelegate
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?)
    {
        for service in peripheral.services!
        {
            if service.UUID.UUIDString == "FF0D"
            {
                self.service = service
                self.peripheral?.discoverCharacteristics(nil, forService: self.service!)
                print("Registered service: \(service.UUID.UUIDString)")
            }
        }
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?)
    {
        for charac in service.characteristics!
        {
            if charac.UUID.UUIDString == "FFFC"
            {
                let bytes: [UInt8] = [0x00, 0x00, 0x00, 0x00]
                self.actualColor = NSData(bytes: bytes, length: bytes.count)
                
                self.characteristic = charac
                print("Registered characteristic: \(charac.UUID.UUIDString)")
                
                self.actualColor = NSData(bytes: bytes, length: bytes.count)
                peripheral.writeValue(actualColor, forCharacteristic: charac, type: .WithoutResponse)

                launchDaemon()
            }
        }
    }
    
    //MARK: -
    //MARK: Utils
    func sockaddr_cast(p: UnsafeMutablePointer<sockaddr_un>) -> UnsafeMutablePointer<sockaddr>
    {
        return UnsafeMutablePointer<sockaddr>(p)
    }
}