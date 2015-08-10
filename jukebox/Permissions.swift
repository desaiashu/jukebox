//
//  AddressBook.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import Foundation
import AddressBook
import RealmSwift
import UIKit

class Permissions {
    
    static var addressBookCallback: ((Bool)->Void)?
    static var pushCallback: (()->Void)?
    
    class func promptUserToChangeAddressBookSettings(forced: Bool) {
        let alertController = UIAlertController(title: "Contacts", message: "We need access to your contacts so you can send songs to your friends. Tap go to enable access to contacts in settings.", preferredStyle: UIAlertControllerStyle.Alert)
        if !forced {
            alertController.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel, handler:nil))
        }
        alertController.addAction(
            UIAlertAction(title: "Go", style: UIAlertActionStyle.Default, handler: { UIAlertAction in
                UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
            })
        )
        UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alertController, animated: true, completion: nil)
    }
    
    class func authorizeAddressBook (callback: (Bool)->Void){
        switch ABAddressBookGetAuthorizationStatus(){
        case .Authorized, .NotDetermined:
            self.addressBookCallback = callback
            self.loadAddressBook()
        case .Denied, .Restricted:
            self.promptUserToChangeAddressBookSettings(true)
            callback(false)
        }
    }
    
    class func loadAddressBook() {
        var error: Unmanaged<CFError>?
        let addressBook: ABAddressBook = ABAddressBookCreateWithOptions(nil, &error).takeRetainedValue()
        ABAddressBookRequestAccessWithCompletion(addressBook,
            {(granted: Bool, error: CFError!) in
                if granted{
                    dispatch_async(dispatch_get_main_queue()) {
                        self.saveAddressBook(addressBook)
                        if let callback = self.addressBookCallback {
                            callback(true)
                            self.addressBookCallback = nil
                        }
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.promptUserToChangeAddressBookSettings(false)
                        if let callback = self.addressBookCallback {
                            callback(false)
                            self.addressBookCallback = nil
                        }
                    }
                }
        })
    }
    
    class func saveAddressBook (addressBook: ABAddressBookRef){
        
        let userPhoneNumber = User.user.phoneNumber
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            
            let backgroundRealm = Realm()
            
            let localDialingCode = self.getLocalDialingCode()
            let allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook).takeRetainedValue() as NSArray
            var contacts = [String:[String:String]]()
            
            for person: ABRecordRef in allPeople {
                
                let phoneNumbers: ABMultiValueRef = ABRecordCopyValue(person, kABPersonPhoneProperty).takeRetainedValue() as ABMultiValueRef
                
                if ABMultiValueGetCount(phoneNumbers) > 0 {
                    
                    var firstName = ""
                    var lastName = ""
                    
                    if let first = ABRecordCopyValue(person, kABPersonFirstNameProperty)?.takeRetainedValue() as? String {
                        firstName = first
                    }
                    if let last = ABRecordCopyValue(person, kABPersonLastNameProperty)?.takeRetainedValue() as? String {
                        lastName = last
                    }
                    
                    if firstName+lastName != "" {
                        let phoneNumber = ABMultiValueCopyValueAtIndex(phoneNumbers, 0).takeUnretainedValue() as! NSString
                        
                        var arr:[String] = phoneNumber.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "+1234567890").invertedSet) as! [String]
                        var strippedNumber = "".join(arr)
                        
                        if strippedNumber.rangeOfString("+") == nil {
                            if let startIndex = strippedNumber.rangeOfString(localDialingCode)?.startIndex {
                                if startIndex == strippedNumber.startIndex {
                                    strippedNumber = "+".stringByAppendingString(strippedNumber)
                                } else {
                                    strippedNumber = "+".stringByAppendingString(localDialingCode).stringByAppendingString(strippedNumber)
                                }
                            } else {
                                strippedNumber = "+".stringByAppendingString(localDialingCode).stringByAppendingString(strippedNumber)
                            }
                        }
                        
                        contacts[strippedNumber as String] = ["firstName":firstName, "lastName":lastName]
                    }
                }
            }
            
            backgroundRealm.write() {
                for (k, v) in contacts {
                    if k == userPhoneNumber {
                        dispatch_async(dispatch_get_main_queue()) {
                            realm.write() {
                                User.user.firstName = v["firstName"]!
                                User.user.lastName = v["lastName"]!
                            }
                        }
                    } else {
                        if let friend = backgroundRealm.objects(Friend).filter("phoneNumber='"+k+"'").first {
                            friend.firstName = v["firstName"]!
                            friend.lastName = v["lastName"]!
                        } else {
                            var newFriend = Friend()
                            newFriend.phoneNumber = k
                            newFriend.firstName = v["firstName"]!
                            newFriend.lastName = v["lastName"]!
                            backgroundRealm.add(newFriend)
                        }
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue()) {
                self.checkName()
                realm.write() {
                    User.user.addressBookLoaded = true
                }
            }
        })
    }
    
    static func checkName() {
        if User.user.firstName+User.user.lastName == "" {
            self.requestName("Name")
        } else if User.user.firstName == "" {
            self.requestName("First Name")
        } else if User.user.lastName == "" {
            self.requestName("Last Name")
        }
    }
    
    static func requestName(nameType: String) {
        let alertController = UIAlertController(title: "Enter "+nameType, message: nil, preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addTextFieldWithConfigurationHandler { textField in
            switch (nameType) {
            case "First Name":
                textField.placeholder = "First Name"
            case "Last Name":
                textField.placeholder = "Last Name"
            default:
                textField.placeholder = "First Last"
            }
        }
        alertController.addAction(
            UIAlertAction(title: "Save", style: UIAlertActionStyle.Default, handler: { UIAlertAction in
                if let textField = alertController.textFields?[0] as? UITextField {
                    if textField.text != "" {
                        realm.write() {
                            switch (nameType) {
                            case "First Name":
                                User.user.firstName = textField.text
                            case "Last Name":
                                User.user.lastName = textField.text
                            default:
                                if textField.text == "" {
                                    //Need better handling of this! maybe just re-request?
                                    User.user.firstName = User.user.phoneNumber
                                } else {
                                    let name = textField.text.componentsSeparatedByString(" ")
                                    User.user.firstName = name[0]
                                    if name.count > 1 {
                                        User.user.lastName = name[1]
                                    }
                                }
                            }
                        }
                    }
                }
            })
        )
        UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alertController, animated: true, completion: nil)
    }

    static func getLocalDialingCode () -> String {
        var myDict: NSDictionary?
        if let path = NSBundle.mainBundle().pathForResource("DialingCodes", ofType: "plist") {
            myDict = NSDictionary(contentsOfFile: path)
        }
        if let dict = myDict {
            if let countryCode = NSLocale.currentLocale().objectForKey(NSLocaleCountryCode) as? String {
                let callingCode = dict[countryCode.lowercaseString]! as! String
                return callingCode
            }
        }
        return ""
    }
    
    static func enablePush (callback: ()->Void){
        self.pushCallback = callback
        var type = UIUserNotificationType.Badge | UIUserNotificationType.Alert | UIUserNotificationType.Sound;
        var setting = UIUserNotificationSettings(forTypes: type, categories: nil);
        UIApplication.sharedApplication().registerUserNotificationSettings(setting);
        UIApplication.sharedApplication().registerForRemoteNotifications();
    }
    
    static func pushEnabled(deviceToken: NSData){
        realm.write() {
            User.user.pushToken = deviceToken.description
                .stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>"))
                .stringByReplacingOccurrencesOfString(" ", withString: "" )
        }
        Server.sendPushToken()
        if let pushCallback = self.pushCallback {
            pushCallback()
            self.pushCallback = nil
        }
    }
    
    static func pushDisabled(){
        if let pushCallback = self.pushCallback {
            self.promptUserToChangePushNotificationSettings() //Only do this when you're first enabling push
            pushCallback()
            self.pushCallback = nil
        }
    }
    
    class func promptUserToChangePushNotificationSettings() {
        let alertController = UIAlertController(title: "Push Notifications", message: "We recommend turning push notifications on in order to use the app. Tap go to enable push notifications in settings.", preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel, handler:nil))
        alertController.addAction(
            UIAlertAction(title: "Go", style: UIAlertActionStyle.Default, handler: { UIAlertAction in
                UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
            })
        )
        UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alertController, animated: true, completion: nil)
    }
}
