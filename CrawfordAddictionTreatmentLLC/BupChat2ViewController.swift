//
//  BupChat2ViewController.swift
//  CrawfordAddictionTreatmentLLC
//
//  Created by Jason Crawford on 1/5/17.
//  Copyright © 2017 Jason Crawford. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuthUI
import FirebaseGoogleAuthUI

class BupChat2ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: Properties

    var messages: [FIRDataSnapshot]! = [FIRDataSnapshot]()
    var ref: FIRDatabaseReference!
    var storageRef: FIRStorageReference!
    var remoteConfig: FIRRemoteConfig!
    let imageCache = NSCache<NSString, UIImage>()
    var placeholderImage = UIImage(named: "ic_account_circle")
    fileprivate var _authHandle: FIRAuthStateDidChangeListenerHandle!
    private var _refHandle: FIRDatabaseHandle!
    var user: FIRUser?
    var displayName = "Anonymous"
    
    // MARK: Outlets
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var imageMessage: UIButton!
    @IBOutlet weak var signOutButton: UIButton!
    @IBOutlet weak var signInButton: UIButton!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.textField.delegate = self
        
        ConfigureDatabase()
        
        //        NotificationCenter.default.addObserver(self, selector: #selector(BupChat2ViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: self.view.window)
        //
        //        NotificationCenter.default.addObserver(self, selector: #selector(BupChat2ViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: self.view.window)
        configureAuth()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        //logout
        /* let firebaseAuth = FIRAuth.auth()
         do {
         try firebaseAuth?.signOut()
         } catch let signOutError as NSError {
         print("error signing out")
         } */
        
//        if (FIRAuth.auth()?.currentUser == nil) {
//            let vc = self.storyboard?.instantiateViewController(withIdentifier: "firebaseLoginViewController")
//            self.navigationController?.present(vc!, animated: true, completion: nil)
//        }
        subscribeToKeyboardNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: self.view.window)
        //        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: self.view.window)
        unsubscribeFromKeyboardNotifications()
    }
    
    // MARK: Config
    
    func configureAuth() {
        // config auth providers
        
        // listen for changes in authorization state
        _authHandle = FIRAuth.auth()?.addStateDidChangeListener { (auth: FIRAuth, user: FIRUser?) in
            // refresh table data
            self.messages.removeAll(keepingCapacity: false)
            self.tableView.reloadData()
            
            //check if there is a current user
            if let activeUser = user {
                // check if the current app user is the current FIRUser
                if self.user != activeUser {
                    self.user = activeUser
                    self.signedInStatus(isSignedIn: true)
                    let name = user!.email!.components(separatedBy: "@")[0]
                    self.displayName = name
                }
            } else {
                // user must sign in
                self.signedInStatus(isSignedIn: false)
                self.loginSession()
            }
        }
    }
    
    deinit {
        self.ref.child("messages").removeObserver(withHandle: _refHandle)
        FIRAuth.auth()?.removeStateDidChangeListener(_authHandle)
    }
    
    func ConfigureDatabase () {
        ref = FIRDatabase.database().reference()
        _refHandle = self.ref.child("messages").observe(.childAdded, with: {(snapshot: FIRDataSnapshot) -> Void in
            self.messages.append(snapshot)
            self.tableView.insertRows(at: [IndexPath(row: self.messages.count-1, section: 0)], with: .automatic)
            self.scrollToBottomMessage()
        })
    }
    
    func configureStorage() {
        // configure storage using your firebase storage
        storageRef = FIRStorage.storage().reference()
    }
    
    func configureRemoteConfig() {
        // configure remote configuration settings
        let remoteConfigSettings = FIRRemoteConfigSettings(developerModeEnabled: true)
        remoteConfig = FIRRemoteConfig.remoteConfig()
        remoteConfig.configSettings = remoteConfigSettings!
    }
    
    func fetchConfig() {
        var expirationDuration: Double = 3600
        // update to the current configuratation
        if remoteConfig.configSettings.isDeveloperModeEnabled {
            expirationDuration = 0
        }
        // fetch config
        remoteConfig.fetch(withExpirationDuration: expirationDuration) { (status, error) in
            if status == .success {
                print("config fetched")
                self.remoteConfig.activateFetched()
                //let friendlyMsgLength = self.remoteConfig["friendly_msg_length"]
                //if friendlyMsgLength.source != .static {
                    //self.msglength = friendlyMsgLength.numberValue!
                //print("friend msg length config: \(self.msglength)")
                //}
            } else {
                print("config not fetched")
                print("error: \(error)")
            }
        }
    }
    
    // MARK: Sign In and Out
    
    func signedInStatus(isSignedIn: Bool) {
        //signInButton.isHidden = isSignedIn
        signOutButton.isHidden = !isSignedIn
        tableView.isHidden = !isSignedIn
        textField.isHidden = !isSignedIn
        //sendButton.isHidden = !isSignedIn
        imageMessage.isHidden = !isSignedIn
        
       if (isSignedIn) {
//            
//            // remove background blur (will use when showing image messages)
//            messagesTable.rowHeight = UITableViewAutomaticDimension
//            messagesTable.estimatedRowHeight = 122.0
//            backgroundBlur.effect = nil
//            messageTextField.delegate = self
//            
            // Set up app to send and receive messages when signed in
            ConfigureDatabase()
            configureStorage()
            configureRemoteConfig()
            fetchConfig()
        }
    }
    
    func loginSession() {
        //let authViewController = FUIAuth.defaultAuthUI()!.authViewController()
        let authViewController = FIRAuthUI.authUI()!.authViewController()
        self.present(authViewController, animated: true, completion: nil)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = self.tableView.dequeueReusableCell(withIdentifier: "tableViewCell", for: indexPath)
        
        let messageSnap: FIRDataSnapshot! = self.messages[indexPath.row]
        let message = messageSnap.value as! [String:String]
        let name = message[Constants.MessageFields.name] ?? "[username]"
        
        // if photo message, then grab image and display it
        if let imageUrl = message[Constants.MessageFields.imageUrl] {
            cell.textLabel?.text = "sent by: \(name)"
            // download and display image
            FIRStorage.storage().reference(forURL: imageUrl).data(withMaxSize: INT64_MAX) { (data, error) in
                guard error == nil else {
                    print("error downloading: \(error!)")
                    return
                }
                // display image
                let messageImage = UIImage.init(data: data!, scale: 50)
                // check if the cell is still on screen, if so, update cell image
                if cell == tableView.cellForRow(at: indexPath) {
                    DispatchQueue.main.async {
                        cell.imageView?.image = messageImage
                        cell.setNeedsLayout()
                    }
                }
            }
        } else {
//            let text = message[Constants.MessageFields.text] ?? "[message]"
//            cell.textLabel?.text = name + ": " + text
//            cell.imageView?.image = placeholderImage
            if let text = message[Constants.MessageFields.text] as String! {
                cell.textLabel?.text = text
            }
            if let subText = message[Constants.MessageFields.dateTime] {
                cell.detailTextLabel?.text = subText
            }
        }
        
        return cell
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String:Any]) {
        // constant to hold the information about the photo
        if let photo = info[UIImagePickerControllerOriginalImage] as? UIImage, let photoData = UIImageJPEGRepresentation(photo, 0.8) {
            // call function to upload photo message
            sendPhotoMessage(photoData: photoData)
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func sendMessage(data: [String: String]) {
        var packet = data
        packet[Constants.MessageFields.dateTime] = Utilities().GetDate()
        self.ref.child("messages").childByAutoId().setValue(packet)
    }
    
    func sendPhotoMessage(photoData: Data) {
        // create method that pushes message w/ photo to the firebase database
        // build a path using the user's ID and a timestamp
        let imagePath = "chat_photos/" + FIRAuth.auth()!.currentUser!.uid + "/\(Double(Date.timeIntervalSinceReferenceDate * 1000)).jpg"
        // set content type to "image/jpeg" in firebase storage meta data
        let metadata = FIRStorageMetadata()
        metadata.contentType = "image/jpeg"
        // create a child node at imagePath with photoData and metadata
        storageRef!.child(imagePath).put(photoData, metadata: metadata) { (metadata, error) in
            if let error = error {
                print("error uploading: \(error)")
                return
            }
            // use sendMessage to add imageURL to database
            self.sendMessage(data: [Constants.MessageFields.imageUrl: self.storageRef!.child((metadata?.path)!).description])
        }
    }
    
    // MARK: Alert
    
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let dismissAction = UIAlertAction(title: "Dismiss", style: .destructive, handler: nil)
            alert.addAction(dismissAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: Scroll Messages
    
    func scrollToBottomMessage() {
        if messages.count == 0 { return }
        let bottomMessageIndex = IndexPath(row: tableView.numberOfRows(inSection: 0) - 1, section: 0)
        tableView.scrollToRow(at: bottomMessageIndex, at: .bottom, animated: true)
    }
    
    // MARK: Actions
    
    @IBAction func showLoginView(_ sender: AnyObject) {
        loginSession()
    }
    
    @IBAction func didTapAddPhoto(_ sender: AnyObject) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func signOut(_ sender: UIButton) {
        do {
            try FIRAuth.auth()?.signOut()
        } catch {
            print("unable to sign out: \(error)")
        }
    }
    
    func subscribeToKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(BupChat2ViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(BupChat2ViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func keyboardWillShow(_ notification: NSNotification) {
        resetViewFrame()
        if textField.isFirstResponder {
            view.frame.origin.y = getKeyboardHeight(notification) * -1
        }
    }
    
    func keyboardWillHide(_ notification: NSNotification) {
        if textField.isFirstResponder {
            resetViewFrame()
        }
    }
    
    func resetViewFrame(){
        view.frame.origin.y = 0
    }
    
    func getKeyboardHeight(_ notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue // of CGRect
        return keyboardSize.cgRectValue.height
    }
    
    func unsubscribeFromKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
//    func keyboardWillHide (_ sender: Notification) {
//        let userInfo: [NSObject:AnyObject] = (sender as NSNotification).userInfo! as [NSObject : AnyObject]
//        
//        //let keyboardSize: CGSize = userInfo[UIKeyboardFrameBeginUserInfoKey]!.cgRectValue().size
//        let keyboardSize = userInfo[UIKeyboardFrameBeginUserInfoKey]!.cg
//        self.view.frame.origin.y += keyboardSize.height
//        if keyboardOnScreen {
//                        self.view.frame.origin.y += self.keyboardHeight(Notification)
//                    }
        
        //view.frame.origin.y = 0
//    }
    

    
    //func keyboardWillShow(_ sender: NSNotification) {
//        let userInfo: [NSObject:Any] = sender.userInfo! as [NSObject : Any]
//        
//        let keyboardSize: CGSize = userInfo[UIKeyboardFrameBeginUserInfoKey]!.cgRectValue().size
//        let offset: CGSize = userInfo[UIKeyboardFrameEndUserInfoKey]!.cgRectValue().size
//        
//        if keyboardSize.height == offset.height {
//            if self.view.frame.origin.y == 0 {
//                UIView.animate(withDuration: 0.15, animations: {
//                    self.view.frame.origin.y -= keyboardSize.height
//                })
//            }
//        }
//        else {
//            UIView.animate(withDuration: 0.15, animations: {
//                self.view.frame.origin.y += keyboardSize.height - offset.height
//            })
//        }
//        if !keyboardOnScreen {
//            self.view.frame.origin.y += self.keyboardHeight(NSNotification)
        
        //        view.frame.origin.y = 0
        //view.frame.origin.y = getKeyboardHeight(notification) * -1
    //}
    
//    func getKeyboardHeight(_ notification: NSNotification) -> CGFloat {
//        let userInfo = notification.userInfo
//        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue // of CGRect
//        return keyboardSize.cgRectValue.height
//    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
//        if (textField.text?.characters.count == 0) {
//            return true
//        }
//        
//        let data = [Constants.MessageFields.text: textField.text! as String]
//        SendMessage(data: data)
//        print("ended editing")
//        textField.text = ""
//        self.view.endEditing(true)
        
        textField.resignFirstResponder()
        let data = [Constants.MessageFields.text: textField.text! as String]
        sendMessage(data: data)
        textField.text = ""
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}
