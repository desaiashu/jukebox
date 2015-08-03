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

struct k {
    static let server_url = "http://192.168.1.7:5000/"
    static let youtube_url = "https://www.googleapis.com/youtube/v3/search?key=AIzaSyBK4c6lUvrKyH3rt3dbsSS-jUVPDjRGyT0&part=snippet&type=video&videoCategoryId=10&order=relevance&maxResults=50&fields=items(id(videoId)%2Csnippet(title))&q="
}

struct g {
    static var phone_number = "+16504305130"
    static var code = "foobar"
    static var last_updated = 0
    static let realm = Realm()
    static var user: User?
    static var player = SongPlayer()
    static var permissions = Permissions()
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        Fabric.with([Crashlytics()])
        
        if let user = g.realm.objects(User).first {
            g.user = user
            println("yay")
            
            //Edge cases
            //No address book permissions
            //No name
            //No Code
            
            //If user but not address book permissions
            //If user but not user name
        } else {
            g.user = User()
            g.user!.phone_number = g.phone_number
            g.user!.code = g.code
            g.user!.last_updated = 0
            
            g.realm.write() {
                g.realm.add(g.user!)
            }
        }
        
        g.permissions.authorizeAddressBook()
        
        return true
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

