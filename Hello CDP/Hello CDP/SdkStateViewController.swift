//
//  ViewController.swift
//  Hello CDP
//
//  Copyright © 2020 Salesforce. All rights reserved.
//

import UIKit
import Cdp
import SFMCSDK
import CoreLocation
import Foundation
import MarketingCloudSDK



class SdkStateViewController: UIViewController {
    var locationManager = CLLocationManager()
    var currentLocation: CLLocation?
    var authToken: String?
    
    @IBOutlet var token: UIView!
    @IBOutlet weak var outputSegmentedControl: UISegmentedControl!
    @IBOutlet var optInSwitch: UISwitch!
    @IBOutlet weak var outputTextView: UITextView!
    @IBOutlet weak var profileEventButton: UIButton!
    @IBOutlet weak var setLocationButton: UIButton!
    @IBOutlet weak var engagmentEventButton: UIButton!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        optInSwitch.isOn = SFMCSdk.cdp.getConsent() == Consent.optIn
        refreshOutput()
    }
    
    @IBAction func toggleConsent(_ sender: Any) {
        let consent = optInSwitch.isOn ? Consent.optIn : Consent.optOut
        SFMCSdk.cdp.setConsent(consent: consent)
        
        refreshOutput()
    }
    
    @IBAction func segmentedControlValueChanged(_ sender: Any) {
        refreshOutput()
    }
    
    @IBAction func clearButtonPressed(_ sender: Any) {
        self.outputTextView.text = nil
        HelloCDPLogOutputter.shared.logMessages = []
    }
    
    @IBAction func sendProfileEvent(_ sender: Any) {
        if let deviceID = getDeviceID() {
                print("Using Device ID: \(deviceID)")
                authenticate { [weak self] success in
                    guard let self = self else { return }
                    if success {
                        self.postEvents(deviceID: deviceID)
                    } else {
                        print("Authentication failed")
                    }
                    self.refreshOutput()
                }
            } else {
                print("Device ID not available")
            }
        refreshOutput()
    }
    
    // Get Device ID
    func getDeviceID() -> String? {
        // Get the device ID and update the label
        if let deviceID = MarketingCloudSDK.sharedInstance().sfmc_deviceIdentifier() {
            // Update the label with the device ID
            return deviceID
            // Assuming deviceIDLabel is an IBOutlet connected to a UILabel
        } else {
            print("Failed to retrieve device ID")
            return nil
        }
    }
    
    // Authenticate
    func authenticate(completion: @escaping (Bool) -> Void){
        DispatchQueue.main.async {
            let url = URL(string: AppDelegate.shared.cdpEndpoint + "/authentication")!
            print("url:", url)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("AWSALB=RHEV6Z5aevN/Zu4nLIVJzQYzcZFbU29nN+dZv3GcNbxsgfr7VfhxNWmpgyi39RNotaM2RzWb0fH8CqVwUV4U8z8bdC+rAwjYftL7fBA8UkurrtfO7s7/dhGBCwyR; AWSALBCORS=RHEV6Z5aevN/Zu4nLIVJzQYzcZFbU29nN+dZv3GcNbxsgfr7VfhxNWmpgyi39RNotaM2RzWb0fH8CqVwUV4U8z8bdC+rAwjYftL7fBA8UkurrtfO7s7/dhGBCwyR", forHTTPHeaderField: "Cookie")
            
            let body: [String: Any] = [
                "appSourceId": AppDelegate.shared.cdpAppId,
                "deviceId": "MobileSDKDevice"
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            
            let session = URLSession.shared
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Client error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    print("Server error")
                    completion(false)
                    return
                }
                
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let token = json["token"] as? String {
                    self.authToken = token
                    completion(true)
                } else {
                    print("Failed to parse token")
                    completion(false)
                }
            }
            task.resume()
        }
    }
    
    func postEvents(deviceID: String){
        DispatchQueue.main.async {
            guard let authToken = self.authToken else {
                print("Auth token is not available")
                return
            }
            
            let url = URL(string: AppDelegate.shared.cdpEndpoint + "/events")!
            print("url:", url)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(authToken, forHTTPHeaderField: "auth_token")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = """
            {
                "events": [
                    {
                        "deviceId": "\(deviceID)",
                        "individualId": "Testing",
                        "eventId": "event-id-2222222222",
                        "dateTime": "2023-02-08T22:03:00.000Z",
                        "eventType": "individual",
                        "category": "profile",
                        "sessionId": "41315BE2-8D90-4D86-BB39-814262F38BA3",
                        "firstName": "yaw",
                        "lastName": "ankomah"
                    },
                    {
                        "deviceId": "\(deviceID)",
                        "individualId": "Testing",
                        "eventId": "event-id-2222222222",
                        "dateTime": "2023-07-04T22:03:00.000Z",
                        "eventType": "device",
                        "category": "profile",
                        "sessionId": "41315BE2-8D90-4D86-BB39-814262F38BA3",
                        "deviceSystemToken": "\(AppDelegate.shared.deviceToken)",
                        "deviceType": "iPhone",
                        "gcmSenderId": "gcm123",
                        "osName": "iOS",
                        "osVersion": "17.4"
                    },
                    {
                        "deviceId": "\(deviceID)",
                        "contactPointAppId": "Testing",
                        "isActive": "True",
                        "eventId": "event-id-2222222222",
                        "dateTime": "2023-07-04T22:03:00.000Z",
                        "eventType": "contactPointApp",
                        "individualId": "yaw-test1",
                        "category": "profile",
                        "sessionId": "41315BE2-8D90-4D86-BB39-814262F38BA3",
                        "sdkVersionName": "ver1",
                        "isUndeliverable": 0
                    }
                ]
            }
            """.data(using: .utf8)
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                }
                
                if let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    print("Response: \(responseString ?? "No data received")")
                }
            }
            task.resume()
        }
    }
        
        // Store Token
        // Create Events
        
        @IBAction func sendEngagmentEvent(_ sender: Any) {
            // collecting the structured AddToCartEvent
            SFMCSdk.track(event: AddToCartEvent(
                lineItem: LineItem(
                    catalogObjectType: "Product",
                    catalogObjectId: "product-1",
                    quantity: 1,
                    price: 20.0,
                    currency: "USD",
                    // attributes can contain any custom field data
                    // as long as the schema is modified to define them
                    attributes: [
                        "gift_wrap": false
                    ]
                )
            ))
            refreshOutput()
        }
        
        @IBAction func sendCustomEngagmentEvent(_ sender: Any) {
            // collecting an unstructured CustomEvent
            SFMCSdk.track(event: CustomEvent(
                name: "CartAbandonment",
                attributes: [
                    "sku": "COFFEE-NTR-06",
                    "price": 19.99
                ]
            )!)
            refreshOutput()
        }
        
    @IBAction func Token(_ sender: Any) {
        let token = AppDelegate.shared.deviceToken
            print("Retrieved Device Token: \(token)")
//        print("MarketingCloudSDK.sharedInstance().sfmc_getSDKState()", MarketingCloudSDK.sharedInstance().sfmc_getSDKState().map { String(format: "%02.2hhx", $0) })
    }
    @IBAction func setLocationTracking(_ sender: Any) {
            // prepare the coordinates, use the CdpCoordinates wrapper
            let coordinates = CdpCoordinates(latitude: 54.187738, longitude: 15.554440)
            
            // set the location coordinates and expiration time in seconds
            SFMCSdk.cdp.setLocation(coordinates: coordinates, expiresIn: 60)
            
            refreshOutput()
        }
        
        func refreshOutput() {
            DispatchQueue.main.async { [weak self] in
                guard let unwrappedSelf = self else { return }
                
                if unwrappedSelf.outputSegmentedControl.selectedSegmentIndex == 0 {
                    unwrappedSelf.outputTextView.text = CdpModule.shared.state // SFMCSdk.state()
                } else if unwrappedSelf.outputSegmentedControl.selectedSegmentIndex == 1 {
                    unwrappedSelf.outputTextView.text = HelloCDPLogOutputter.shared.logMessages.reversed().map{ $0 }.joined(separator: "\n\n---------------------\n\n")
                }
                unwrappedSelf.outputTextView.setContentOffset(.zero, animated: true)
                
            }
        }
        
    }

