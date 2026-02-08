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

final class MainFlowCoordinator: Coordinator {
    private let router: Router
    private let builder: MainFlowBuilder

    init(
        router: Router,
        builder: MainFlowBuilder = MainFlowBuilder()
    ) {
        self.router = router
        self.builder = builder
    }

    func start() {
        let mainModule = builder.makeMainModule()
        router.setRootModule(mainModule, animated: false)
    }
}
