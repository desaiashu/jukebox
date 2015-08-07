//
//  AppDelegate.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import RealmSwift

public let realm = Realm()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        Fabric.with([Crashlytics()])
        
        //Needs to be moved into "didBecomeActive"
        //Also need to include "update" functions in "didBecomeActive" + "didRecieveNotification"
        Server.checkVersion()
        
        if let user = realm.objects(User).first {
            User.user = user
            
            if user.addressBookLoaded {
                Permissions.checkName()
                Permissions.loadAddressBook()
            } else {
                self.presentPermissions()
            }
        } else {
            self.presentAuthentication()
        }
        
        return true
    }
    
    func presentAuthentication() {
        let welcomeViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("WelcomeViewController") as! UIViewController
        let navigationController = UINavigationController(rootViewController: welcomeViewController)
        navigationController.navigationBarHidden = true
        window?.rootViewController = navigationController
    }
    
    func presentCore() {
        let coreNavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("CoreNavigationController") as! UINavigationController
        window?.rootViewController = coreNavigationController
    }
    
    func presentPermissions() {
        let permissionsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("PermissionsViewController") as! UIViewController
        let navigationController = UINavigationController(rootViewController: permissionsViewController)
        navigationController.navigationBarHidden = true
        window?.rootViewController = navigationController
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        Permissions.pushEnabled(deviceToken)
    }
    
    //Called if unable to register for APNS.
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        Permissions.pushDisabled()
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

