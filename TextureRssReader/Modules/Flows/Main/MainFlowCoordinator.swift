//
//  MainFlowCoordinator.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import UIKit

protocol Coordinator: AnyObject {
    func start()
}

protocol MainFlowCoordinating: AnyObject {
    func showNewspaper(with newsCellViewModel: NewsCellViewModel)
}

final class MainFlowCoordinator: Coordinator {
    private let router: Router
    private let builder: MainFlowBuilder
    private let appService: AppService

    init(
        router: Router,
        appService: AppService,
        builder: MainFlowBuilder = MainFlowBuilder()
    ) {
        self.router = router
        self.appService = appService
        self.builder = builder
    }

    func start() {
        let mainModule = builder.makeMainModule(coordinator: self, appService: appService)
        router.setRootModule(mainModule, animated: false)
    }
}

extension MainFlowCoordinator: MainFlowCoordinating {
    func showNewspaper(with newsCellViewModel: NewsCellViewModel) {
        let newspaperModule = builder.makeNewspaperModule(newsCellViewModel: newsCellViewModel)
        router.push(newspaperModule, animated: true)
    }
}
