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

    func makeSettingsModule(
        appService: AppService,
        onSettingsChanged: @escaping () -> Void
    ) -> UIViewController {
        let viewModel = SettingsViewModel(appService: appService, onSettingsChanged: onSettingsChanged)
        return SettingsViewController(viewModel: viewModel)
    }
}
