//
//  UserService.swift
//  ITinder
//
//  Created by Alexander on 08.08.2021.
//

import UIKit
import Firebase
import FirebaseDatabase
import FirebaseStorage

class UserService {
    private static let imageStorage = Storage.storage().reference().child(kAvatarsRef)
    private static let usersDatabase = Database.database().reference().child(kUsersRef)
    private static var lastUserId = ""
    
    static var currentUserId: String? {
        Auth.auth().currentUser.map { $0.uid }
    }
    
    static func getUserBy(id: String, completion: @escaping (User?) -> Void) {
        usersDatabase.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.childSnapshot(forPath: id).value as? [String: Any] else {
                assertionFailure()
                completion(nil)
                return
            }
            completion(User(dictionary: value))
        } withCancel: { _ in
            assertionFailure()
            completion(nil)
        }
    }
    
    static func getCurrentUser(completion: @escaping (User?) -> Void) {
        guard let currentUserId = currentUserId else {
            assertionFailure()
            completion(nil)
            return
        }
        getUserBy(id: currentUserId) { user in
            completion(user)
        }
    }
    
    static func getNextUsers(usersCount: Int, completion: @escaping ([User]?) -> Void) {
        var query = usersDatabase.queryOrderedByKey()
        
        if lastUserId != "" {
            query = query.queryEnding(beforeValue: lastUserId)
        }
        
        query.queryLimited(toLast: UInt(usersCount)).observeSingleEvent(of: .value) { snapshot in
            guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                assertionFailure()
                completion(nil)
                return
            }
            
            var users = [User]()
            
            children.forEach {
                if let value = $0.value as? [String: Any] {
                    users.append(User(dictionary: value))
                }
            }
            
            guard let lastUserId = users.first?.identifier else {
                completion(nil)
                return
            }
            Self.lastUserId = lastUserId
            users.reverse()
            
            let filteredUsers = filtered(users)
            
            if filteredUsers.isEmpty {
                getNextUsers(usersCount: usersCount) { users in
                    completion(users)
                }
            } else {
                completion(filteredUsers)
            }
        } withCancel: { _ in
            completion(nil)
        }
    }
    
    private static func filtered(_ users: [User]) -> [User] {
        users.filter {
            guard let currentUserId = currentUserId else { return false }
            return $0.identifier != currentUserId && !$0.likes.contains(currentUserId)
        }
    }
    
    static func persist(user: User, withImage: UIImage?, completion: @escaping ((User?) -> Void)) {
        guard let image = withImage else {
            persist(user) { user in
                completion(user)
            }
            return
        }
        
        upload(image: image, forUserId: user.identifier) { urlString in
            guard let urlString = urlString else { completion(nil); return }
            
            var newUser = user
            newUser.imageUrl = urlString
            persist(newUser) { user in
                completion(user)
            }
        }
    }
    
    private static func upload(image: UIImage, forUserId: String, completion: @escaping ((String?) -> Void)) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { completion(nil); return }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageStorage.child("\(forUserId).jpg").putData(imageData, metadata: metadata) { _, error in
            guard error == nil else { completion(nil); return }
            
            imageStorage.child("\(forUserId).jpg").downloadURL { url, error in
                guard error == nil, let urlString = url?.absoluteString else {
                    completion(nil)
                    return
                }
                completion(urlString)
            }
        }
    }
    
    private static func persist(_ user: User, completion: @escaping ((User?) -> Void)) {
        usersDatabase.child(user.identifier).setValue(user.userDictionary) { error, _ in
            guard error == nil else { completion(nil); return }
            completion(user)
        }
    }
    
    static func set(like: String, forUserId: String, completion: @escaping ((User?) -> Void)) {
        guard let currentUserId = currentUserId else {
            assertionFailure()
            completion(nil)
            return
        }
        
        getUserBy(id: forUserId) { user in
            guard var user = user else {
                assertionFailure()
                completion(nil)
                return
            }
            user.likes.append(currentUserId)
            
            usersDatabase.child(forUserId).updateChildValues([kLikes: user.likes]) { error, _ in
                guard error == nil else { completion(nil); return }
                completion(user)
            }
        }
    }
    
    static func setMatchIfNeededWith(likedUser: User?, completion: @escaping ((User?) -> Void)) {
        guard var likedUser = likedUser else { completion(nil); return }
        
        getCurrentUser { user in
            guard var currentUser = user else {
                assertionFailure()
                completion(nil)
                return
            }
            
            guard currentUser.likes.contains(likedUser.identifier) else { completion(nil); return }
            
            currentUser.matches.append(likedUser.identifier)
            likedUser.matches.append(currentUser.identifier)
            
            usersDatabase.child(currentUser.identifier).updateChildValues([kMatches: currentUser.matches]) { error, _ in
                guard error == nil else { completion(nil); return }
                
                usersDatabase.child(likedUser.identifier).updateChildValues([kMatches: likedUser.matches]) { error, _ in
                    guard error == nil else { completion(nil); return }
                    completion(likedUser)
                }
            }
        }
    }
    
    // reset likes and matches for all users
    static func resetUsers(completion: @escaping ((Bool) -> Void)) {
        lastUserId = ""
        usersDatabase
            .queryOrderedByKey()
            .observeSingleEvent(of: .value) { snapshot in
                guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                    completion(false)
                    return
                }
                
                var updates = [String: Any]()
                children.forEach {
                    if let value = $0.value as? [String: Any] {
                        if let userId = value[kIdentifier] as? String {
                            updates[userId + "/" + kLikes] = []
                            updates[userId + "/" + kMatches] = []
                        }
                    }
                }
                usersDatabase.updateChildValues(updates) { error, _ in
                    guard error == nil else { completion(false); return }
                    completion(true)
                }
            }
    }
}

extension User {
    init(dictionary: [String: Any]) {
        identifier = dictionary[kIdentifier] as? String ?? ""
        email = dictionary[kEmail] as? String ?? ""
        imageUrl = dictionary[kImageUrl] as? String ?? ""
        name = dictionary[kName] as? String ?? ""
        position = dictionary[kPosition] as? String ?? ""
        description = dictionary[kDescription] as? String
        birthDate = dictionary[kBirthDate] as? String
        city = dictionary[kCity] as? String
        education = dictionary[kEducation] as? String
        company = dictionary[kCompany] as? String
        employment = dictionary[kEmployment] as? String
        likes = dictionary[kLikes] as? [String] ?? []
        matches = dictionary[kMatches] as? [String] ?? []
    }
    
    var userDictionary: [String: Any] {
        [kIdentifier: identifier,
         kEmail: email,
         kImageUrl: imageUrl,
         kName: name,
         kPosition: position,
         kDescription: description ?? "",
         kBirthDate: birthDate ?? "",
         kCity: city ?? "",
         kEducation: education ?? "",
         kCompany: company ?? "",
         kEmployment: employment ?? "",
         kLikes: likes,
         kMatches: matches]
    }
}
