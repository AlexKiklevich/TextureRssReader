//
//  NewspaperViewModel.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import Foundation

protocol NewspaperViewModelDelegate: AnyObject {
    func newspaperViewModel(_ viewModel: NewspaperViewModel, didUpdate viewState: NewspaperViewModel.ViewState)
}

final class NewspaperViewModel {
    struct ViewState {
        let screenTitle: String
        let newsCellViewModel: NewsCellViewModel
    }

    private enum Constants {
        static let screenTitle = "Newspaper"
    }

    weak var delegate: NewspaperViewModelDelegate?

    private let newsCellViewModel: NewsCellViewModel

    init(newsCellViewModel: NewsCellViewModel) {
        self.newsCellViewModel = newsCellViewModel
    }

    func viewDidLoad() {
        notifyDelegate()
    }
}

private extension NewspaperViewModel {
    func notifyDelegate() {
        delegate?.newspaperViewModel(
            self,
            didUpdate: ViewState(
                screenTitle: Constants.screenTitle,
                newsCellViewModel: newsCellViewModel
            )
        )
    }
}
