//
//  ConfirmationCodeViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class ConfirmationCodeViewController: UIViewController {
    
    @IBOutlet weak var confirmationCodeTextField: UITextField!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var resendButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.goButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        self.resendButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
        if identifier == "AuthenticatedSegue" {
            return false
        }
        return true
    }
    
    @IBAction func goPressed(sender: UIButton) {
        self.confirmationCodeTextField.resignFirstResponder()
        self.statusLabel.text = "Loading..."
        self.statusLabel.hidden = false
        self.goButton.enabled = false
        self.resendButton.enabled = false
        User.user.code = self.confirmationCodeTextField.text
        Server.server.authenticateUser(self.authenticateCallback)
    }
    
    @IBAction func resendPressed(sender: UIButton) {
        self.resendButton.enabled = false
        self.resendButton.titleLabel?.text = "Sending"
        Server.server.registerUser({success in
            self.resendButton.titleLabel?.text = "Resend Code"
            self.resendButton.enabled = true
        })
    }
    
    func authenticateCallback(success: Bool) {
        if success {
            realm.write(){
                realm.add(User.user)
            }
            self.performSegueWithIdentifier("AuthenticatedSegue", sender: self)
        } else {
            //This method should also take in an error code (ie if you're not connected to the server)
            self.statusLabel.text = "Incorrect code or error connecting to server"
            self.goButton.enabled = true
            self.resendButton.enabled = true
            User.user.code = ""
        }
    }
}

extension ConfirmationCodeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
