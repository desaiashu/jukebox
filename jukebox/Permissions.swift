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
    
    dynamic var authorizationStatus = ABAddressBookGetAuthorizationStatus()
    
    static var addressBook: ABAddressBookRef?
    
    class func createAddressBook(){
        var error: Unmanaged<CFError>?
        addressBook = ABAddressBookCreateWithOptions(nil, &error).takeRetainedValue()
    }
    
    class func authorizeAddressBook (){
        
        //TODO: failure
        
        switch ABAddressBookGetAuthorizationStatus(){
        case .Authorized:
            println("Already authorized")
            createAddressBook()
            self.saveAddressBook()

        case .Denied:
            println("Denied access to address book")
            
        case .NotDetermined:
            createAddressBook()
            if let theBook: ABAddressBookRef = addressBook{
                ABAddressBookRequestAccessWithCompletion(theBook,
                    {(granted: Bool, error: CFError!) in
                        
                        if granted{
                            println("Access granted")
                            self.saveAddressBook()
                        } else {
                            println("Access not granted")
                        }
                        
                })
            }
            
        case .Restricted:
            println("Access restricted")
            
        default:
            println("Other Problem")
        }
    }
    
    class func saveAddressBook (){
        
        let userPhoneNumber = User.user.phoneNumber
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            
            let backgroundRealm = Realm()
            
            let localDialingCode = self.getLocalDialingCode()
            let allPeople = ABAddressBookCopyArrayOfAllPeople(self.addressBook).takeRetainedValue() as NSArray
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
                    
                    //Remove 411 / all number names?
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
                        backgroundRealm.write() {
                            friend.firstName = v["firstName"]!
                            friend.lastName = v["lastName"]!
                        }
                    } else {
                        var newFriend = Friend()
                        newFriend.phoneNumber = k
                        newFriend.firstName = v["firstName"]!
                        newFriend.lastName = v["lastName"]!
                        backgroundRealm.write() {
                            backgroundRealm.add(newFriend)
                        }
                    }
                }
            }
            
            println("friends saved")
            
        })
    }

    static func getLocalDialingCode () -> String {
        var myDict: NSDictionary?
        if let path = NSBundle.mainBundle().pathForResource("DialingCodes", ofType: "plist") {
            myDict = NSDictionary(contentsOfFile: path)
        }
        if let dict = myDict {
            // Use your dict here
            if let countryCode = NSLocale.currentLocale().objectForKey(NSLocaleCountryCode) as? String {
                
                let callingCode = dict[countryCode.lowercaseString]! as! String
                return callingCode
            }
            
        }
        return ""
    }
    
    static func enablePush (){
        var type = UIUserNotificationType.Badge | UIUserNotificationType.Alert | UIUserNotificationType.Sound;
        var setting = UIUserNotificationSettings(forTypes: type, categories: nil);
        UIApplication.sharedApplication().registerUserNotificationSettings(setting);
        UIApplication.sharedApplication().registerForRemoteNotifications();
    }
    
}
