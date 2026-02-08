//
//  NewspaperViewController.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import AsyncDisplayKit

final class NewspaperViewController: UIViewController {
    private let viewModel: NewspaperViewModel
    private let newspaperViewNode = NewspaperView()

    init(viewModel: NewspaperViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupView()
        viewModel.delegate = self
        viewModel.viewDidLoad()
    }

    private func setupView() {
        let nodeView = newspaperViewNode.view
        nodeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nodeView)

        NSLayoutConstraint.activate([
            nodeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            nodeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nodeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nodeView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension NewspaperViewController: NewspaperViewModelDelegate {
    func newspaperViewModel(_ viewModel: NewspaperViewModel, didUpdate viewState: NewspaperViewModel.ViewState) {
        title = viewState.screenTitle
        newspaperViewNode.update(newsCellViewModel: viewState.newsCellViewModel)
    }
}
