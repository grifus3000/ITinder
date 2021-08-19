//
//  LoginViewController.swift
//  ITinder
//
//  Created by Daria Tokareva
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var toSignUpLabel: UILabel!
    @IBOutlet weak var forgotPasswordLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.hideKeyboardWhenTappedAround()
    }

    override func viewDidLayoutSubviews() {
        Utilities.stylePrimaryButton(loginButton)
        Utilities.styleCaptionLabel(toSignUpLabel)
        Utilities.styleCaptionLabel(forgotPasswordLabel)
        Utilities.stylePrimaryTextField(emailTextField)
        Utilities.stylePrimaryTextField(passwordTextField)
    }
    @IBAction func loginButtonTapped(_ sender: Any) {
        let email = emailTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let pasword = passwordTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Auth.auth().signIn(withEmail: email, password: pasword) { result, error in
            if error != nil {
                self.showAlert(title: "Ошибка входа", message: error?.localizedDescription)
            } else {
                self.transitionToMainTabBar()
            }
        }
    }
    
    private func transitionToMainTabBar() {
        let creatingUserInfoVC = storyboard?.instantiateViewController(identifier: "TabBarController")
        view.window?.rootViewController = creatingUserInfoVC
        view.window?.makeKeyAndVisible()
    }
}
