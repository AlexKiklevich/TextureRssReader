//
//  Router.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import UIKit

protocol Router: AnyObject {
    var rootViewController: UIViewController { get }
    func setRootModule(_ module: UIViewController, animated: Bool)
    func push(_ module: UIViewController, animated: Bool)
    func pop(animated: Bool)
}

final class NavigationRouter: Router {
    private let navigationController: UINavigationController

    init(navigationController: UINavigationController = UINavigationController()) {
        self.navigationController = navigationController
    }

    var rootViewController: UIViewController {
        navigationController
    }

    func setRootModule(_ module: UIViewController, animated: Bool) {
        navigationController.setViewControllers([module], animated: animated)
    }

    func push(_ module: UIViewController, animated: Bool) {
        navigationController.pushViewController(module, animated: animated)
    }

    func pop(animated: Bool) {
        navigationController.popViewController(animated: animated)
    }
}
