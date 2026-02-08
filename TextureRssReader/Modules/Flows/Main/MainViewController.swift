//
//  ViewController.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import UIKit
import AsyncDisplayKit

final class MainViewController: UIViewController {
    private let viewModel = MainViewModel()
    private let mainViewNode = MainView()
    private let screenTitleLabel = UILabel()
    private let displayModeButton = UIButton(type: .system)
    private lazy var titleStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [screenTitleLabel, displayModeButton])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        return stackView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupMainView()
        setupNavigationBar()
        setupMainViewCallbacks()
        viewModel.delegate = self
        viewModel.viewDidLoad()
    }

    private func setupMainView() {
        let nodeView = mainViewNode.view
        nodeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nodeView)

        NSLayoutConstraint.activate([
            nodeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            nodeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nodeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nodeView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNavigationBar() {
        screenTitleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        screenTitleLabel.textColor = .label
        screenTitleLabel.adjustsFontForContentSizeCategory = true
        screenTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        displayModeButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        displayModeButton.titleLabel?.adjustsFontForContentSizeCategory = true
        displayModeButton.setContentHuggingPriority(.required, for: .horizontal)
        displayModeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        displayModeButton.addTarget(self, action: #selector(toggleDisplayMode), for: .touchUpInside)
        displayModeButton.accessibilityTraits = .button

        navigationItem.titleView = titleStackView
    }

    private func setupMainViewCallbacks() {
        mainViewNode.onToggleSection = { [weak self] sectionID in
            self?.viewModel.toggleSection(id: sectionID)
        }
    }

    @objc
    private func toggleDisplayMode() {
        viewModel.toggleDisplayMode()
    }
}

extension MainViewController: MainViewModelDelegate {
    func mainViewModel(
        _ viewModel: MainViewModel,
        didUpdateScreenTitle screenTitle: String,
        navigationButtonTitle: String,
        displayMode: NewsDisplayMode,
        sections: [NewsSectionModel],
        cellViewModelsBySectionID: [UUID: [NewsCellViewModel]]
    ) {
        title = screenTitle
        screenTitleLabel.text = screenTitle
        displayModeButton.setTitle(navigationButtonTitle, for: .normal)
        mainViewNode.update(
            sections: sections,
            cellViewModelsBySectionID: cellViewModelsBySectionID,
            displayMode: displayMode
        )
    }
}
