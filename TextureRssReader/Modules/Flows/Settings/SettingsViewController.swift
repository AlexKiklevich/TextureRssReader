//
//  SettingsViewController.swift
//  TextureRssReader
//
//  Created by Codex on 10.02.26.
//

import UIKit

final class SettingsViewController: UIViewController {
    private enum Constants {
        static let contentInset: CGFloat = 16
        static let sectionSpacing: CGFloat = 20
        static let controlSpacing: CGFloat = 10
        static let sourceCellReuseIdentifier = "SourceCell"
    }

    private let viewModel: SettingsViewModel
    private var currentSources: [SettingsViewModel.SourceRow] = []
    private var isClearDataInProgress = false

    private let refreshLabel = UILabel()
    private let refreshTextField = UITextField()
    private let refreshButton = UIButton(type: .system)

    private let sourceSectionLabel = UILabel()
    private let sourceTitleTextField = UITextField()
    private let sourceURLTextField = UITextField()
    private let addSourceButton = UIButton(type: .system)
    private let clearDataButton = UIButton(type: .system)

    private let errorLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(viewModel: SettingsViewModel) {
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
        setupUI()
        bindViewModel()
        viewModel.viewDidLoad()
    }
}

private extension SettingsViewController {
    func setupUI() {
        setupRefreshSection()
        setupSourceSection()
        setupClearDataButton()
        setupErrorLabel()
        setupTableView()
        layoutUI()
    }

    func setupRefreshSection() {
        refreshLabel.text = "Refresh interval (seconds)"
        refreshLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        refreshLabel.textColor = .label

        refreshTextField.borderStyle = .roundedRect
        refreshTextField.keyboardType = .decimalPad
        refreshTextField.placeholder = "e.g. 300"
        refreshTextField.accessibilityLabel = "Refresh interval"

        refreshButton.setTitle("Save Interval", for: .normal)
        refreshButton.addTarget(self, action: #selector(saveRefreshInterval), for: .touchUpInside)
    }

    func setupSourceSection() {
        sourceSectionLabel.text = "News sources"
        sourceSectionLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        sourceSectionLabel.textColor = .label

        sourceTitleTextField.borderStyle = .roundedRect
        sourceTitleTextField.placeholder = "Source title"
        sourceTitleTextField.autocapitalizationType = .words
        sourceTitleTextField.autocorrectionType = .no

        sourceURLTextField.borderStyle = .roundedRect
        sourceURLTextField.placeholder = "https://example.com/rss.xml"
        sourceURLTextField.autocorrectionType = .no
        sourceURLTextField.autocapitalizationType = .none
        sourceURLTextField.keyboardType = .URL
        sourceURLTextField.textContentType = .URL

        addSourceButton.setTitle("Add Source", for: .normal)
        addSourceButton.addTarget(self, action: #selector(addSource), for: .touchUpInside)
    }

    func setupClearDataButton() {
        clearDataButton.setTitle("Delete Database + Image Cache", for: .normal)
        clearDataButton.tintColor = .systemRed
        clearDataButton.addTarget(self, action: #selector(confirmClearLocalData), for: .touchUpInside)
    }

    func setupErrorLabel() {
        errorLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
    }

    func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.sourceCellReuseIdentifier)
        tableView.isEditing = true
    }

    func layoutUI() {
        let refreshStack = UIStackView(arrangedSubviews: [refreshLabel, refreshTextField, refreshButton])
        refreshStack.axis = .vertical
        refreshStack.spacing = Constants.controlSpacing

        let addSourceStack = UIStackView(arrangedSubviews: [sourceSectionLabel, sourceTitleTextField, sourceURLTextField, addSourceButton])
        addSourceStack.axis = .vertical
        addSourceStack.spacing = Constants.controlSpacing

        let contentStack = UIStackView(arrangedSubviews: [refreshStack, addSourceStack, clearDataButton, errorLabel, tableView])
        contentStack.axis = .vertical
        contentStack.spacing = Constants.sectionSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.contentInset),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.contentInset),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.contentInset),
            contentStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Constants.contentInset),

            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])
    }

    func bindViewModel() {
        viewModel.delegate = self
    }

    func showError(_ message: String?) {
        guard let message, !message.isEmpty else {
            errorLabel.isHidden = true
            errorLabel.text = nil
            return
        }
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    func applyClearDataState(_ isInProgress: Bool) {
        isClearDataInProgress = isInProgress
        refreshButton.isEnabled = !isInProgress
        addSourceButton.isEnabled = !isInProgress
        tableView.isUserInteractionEnabled = !isInProgress
        tableView.isEditing = !isInProgress
        clearDataButton.isEnabled = !isInProgress
        let clearTitle = isInProgress ? "Clearing..." : "Delete Database + Image Cache"
        clearDataButton.setTitle(clearTitle, for: .normal)
    }
}

@objc
private extension SettingsViewController {
    func saveRefreshInterval() {
        showError(nil)
        _ = viewModel.saveRefreshInterval(input: refreshTextField.text ?? "")
    }

    func addSource() {
        showError(nil)
        let didAdd = viewModel.addSource(
            title: sourceTitleTextField.text ?? "",
            urlString: sourceURLTextField.text ?? ""
        )
        if didAdd {
            sourceTitleTextField.text = nil
            sourceURLTextField.text = nil
        }
    }

    func confirmClearLocalData() {
        guard !isClearDataInProgress else { return }
        showError(nil)

        let alert = UIAlertController(
            title: "Delete local data?",
            message: "Saved catalogs, news and cached images will be deleted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.viewModel.clearDatabaseAndImageCache()
        })
        present(alert, animated: true)
    }
}

extension SettingsViewController: SettingsViewModelDelegate {
    func settingsViewModel(_ viewModel: SettingsViewModel, didUpdate viewState: SettingsViewModel.ViewState) {
        title = viewState.screenTitle
        if refreshTextField.text?.isEmpty ?? true {
            refreshTextField.text = viewState.refreshIntervalText
        }
        applyClearDataState(viewState.isClearDataInProgress)
        currentSources = viewState.sources
        tableView.reloadData()
    }

    func settingsViewModel(_ viewModel: SettingsViewModel, didReceiveErrorMessage message: String) {
        showError(message)
    }
}

extension SettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currentSources.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.sourceCellReuseIdentifier, for: indexPath)
        guard currentSources.indices.contains(indexPath.row) else {
            return cell
        }

        let source = currentSources[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = source.title
        content.secondaryText = source.urlString
        content.secondaryTextProperties.numberOfLines = 2
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }
}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        !isClearDataInProgress && currentSources.indices.contains(indexPath.row)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .delete
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }
        showError(nil)
        viewModel.removeSource(at: indexPath.row)
    }
}
