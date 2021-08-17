//
//  SwipeViewController.swift
//  ITinder
//
//  Created by Alexander on 07.08.2021.
//

import UIKit

class SwipeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        addCards()
    }
    
    private let cardsLimit = 3
    private var cards = [SwipeCardModel]()
    
    private var shownUserId: String? {
        cards.first?.userId
    }
    
    private var isLoading: Bool = false {
        didSet {
            if isLoading {
                loaderView.startAnimating()
            } else {
                loaderView.stopAnimating()
            }
        }
    }
    
    private let loaderView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.hidesWhenStopped = true
        return view
    }()
    
    private let emptyShimmerView: EmptyShimmerView = {
        let view = EmptyShimmerView()
        view.isHidden = true
        return view
    }()
    
    private lazy var profileContainerView: SwipeProfileContainerView = {
        let view = SwipeProfileContainerView()
        view.delegate = self
        view.isHidden = true
        return view
    }()
    
    private func configure() {
        view.backgroundColor = .white
        
        [loaderView, profileContainerView, emptyShimmerView].forEach { subview in
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            loaderView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loaderView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            profileContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            profileContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            profileContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            profileContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            emptyShimmerView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyShimmerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyShimmerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyShimmerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func addCards() {
        isLoading = true
        UserService.shared.getNextUsers(usersCount: cardsLimit) { [weak self] users in
            guard let self = self else { return }
            
            guard let users = users else {
                self.isLoading = false
                self.showEmptyShimmer()
                return
            }
            
            let cardModels = users
                .compactMap { $0 }
                .map { SwipeCardModel(from: $0) }
            
            self.profileContainerView.fill(cardModels)
            self.cards.append(contentsOf: cardModels)
            self.isLoading = false
            self.profileContainerView.isHidden = false
        }
    }
    
    private func showEmptyShimmer() {
        if cards.isEmpty {
            emptyShimmerView.isHidden = false
            profileContainerView.isHidden = true
        }
    }
    
    private func checkForMatch(currentUser: User?) {
        guard let shownUserId = shownUserId else { return }
        //UserService.shared.set(match: shownUserId)
        //show match
    }
}

extension SwipeViewController: SwipeCardDelegate {
    func profileInfoDidTap() {
        guard let shownUserId = shownUserId else { return }
        UserService.shared.getUserBy(id: shownUserId) { user in
            Router.showUserProfile(user: user, parent: self)
        }
    }
    
    func swipeDidEnd(type: SwipeCardType) {
        cards.removeFirst()
        
        if !isLoading && cards.count < cardsLimit {
            addCards()
        }
        
        if type == .like {
            guard let shownUserId = shownUserId else { return }
//            UserService.shared.set(like: shownUserId) { [weak self] user in
//                self?.checkForMatch(currentUser: user)
//            }
        }
    }
}
