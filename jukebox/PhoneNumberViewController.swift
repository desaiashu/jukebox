//
//  PhoneNumberViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class PhoneNumberViewController: UIViewController {
    
    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.goButton.setTitleColor(UIColor.lightGray, for: UIControlState.disabled)
        User.user.phoneNumber = ""
        User.user.code = ""
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "RegisteredSegue" {
            return false
        }
        return true
    }
    
    @IBAction func goPressed(_ sender: UIButton){
        self.phoneNumberTextField.resignFirstResponder()
        var phoneNumber = phoneNumberTextField.text!
        if phoneNumber != "" {
            if let phoneInt = Int(phoneNumber) {
                phoneNumber = String(phoneInt) //Remove leading 0's, need to enable this for longer numbers
            }
            if phoneNumber.characters.count == 10 && Permissions.permissions.localDialingCode == "1" { //Automatically including 1 for US numbers
                phoneNumber = "1" + phoneNumber
            }
            User.user.phoneNumber = "+" + phoneNumber
            self.goButton.isEnabled = false
            self.statusLabel.text = "Loading..."
            Server.server.registerUser(self.registerCallback)
        }
    }
    
    func registerCallback(_ success: Bool) {
        if success {
            self.performSegue(withIdentifier: "RegisteredSegue", sender: self)
        } else {
            //This method should also take in an error code (ie if you're not connected to the server)
            self.statusLabel.text = "Error connecting to server, try again"
            self.goButton.isEnabled = true
            User.user.phoneNumber = ""
            User.user.code = ""
        }
    }
    
    @IBAction func prepareForUnwind(_ segue:UIStoryboardSegue) {
        self.statusLabel.text = "Include country code"
        self.goButton.isEnabled = true
        User.user.phoneNumber = ""
    }
}
