//
//  MainFlowBuilder.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import UIKit

final class MainFlowBuilder {
    func makeMainModule(
        coordinator: MainFlowCoordinating,
        appService: AppService
    ) -> UIViewController {
        let viewModel = MainViewModel(coordinator: coordinator, appService: appService)
        return MainViewController(viewModel: viewModel)
    }

    func makeNewspaperModule(newsCellViewModel: NewsCellViewModel) -> UIViewController {
        let viewModel = NewspaperViewModel(newsCellViewModel: newsCellViewModel)
        return NewspaperViewController(viewModel: viewModel)
    }
}
