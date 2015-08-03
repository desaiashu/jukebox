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

class Permissions {
    
    dynamic var authorizationStatus = ABAddressBookGetAuthorizationStatus()
    
    var addressBook: ABAddressBookRef?
    
    func createAddressBook(){
        var error: Unmanaged<CFError>?
        addressBook = ABAddressBookCreateWithOptions(nil, &error).takeRetainedValue()
    }
    
    func authorizeAddressBook (){
        
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
    
    func saveAddressBook (){
        
        let userPhoneNumber = g.user?.phone_number
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
        
            let realm = Realm()
            
            let localDialingCode = self.getLocalDialingCode()
            
            var contacts = [String:[String:String]]()
            
            let allPeople = ABAddressBookCopyArrayOfAllPeople(self.addressBook).takeRetainedValue() as NSArray
            
            for person: ABRecordRef in allPeople {
                
                if let phoneNumbers: ABMultiValueRef = ABRecordCopyValue(person, kABPersonPhoneProperty).takeRetainedValue() as? ABMultiValueRef {
                    
                    if ABMultiValueGetCount(phoneNumbers) > 0 {
                        
                        var firstName = ""
                        var lastName = ""
                        
                        if let first = ABRecordCopyValue(person, kABPersonFirstNameProperty)?.takeRetainedValue() as? String {
                            firstName = first
                        }
                        if let last = ABRecordCopyValue(person, kABPersonLastNameProperty)?.takeRetainedValue() as? String {
                            lastName = last
                        }
                        
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
                        g.realm.write() {
                            g.user?.first_name = v["firstName"]!
                            g.user?.last_name = v["lastName"]!
                        }
                    }
                } else {
                    
                    if let friend = realm.objects(Friend).filter("phoneNumber='"+k+"'").first {
                        realm.write() {
                            friend.firstName = v["firstName"]!
                            friend.lastName = v["lastName"]!
                        }
                    } else {
                        var newFriend = Friend()
                        newFriend.phoneNumber = k
                        newFriend.firstName = v["firstName"]!
                        newFriend.lastName = v["lastName"]!
                        realm.write() {
                            realm.add(newFriend)
                        }
                    }
                }
            }
            
        })
        
    }
    
    func getLocalDialingCode () -> String {
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
    
    func enablePush (){
        
    }
    
}
