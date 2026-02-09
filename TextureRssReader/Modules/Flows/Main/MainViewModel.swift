//
//  MainViewModel.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 7.02.26.
//

import Foundation

protocol MainViewModelDelegate: AnyObject {
    func mainViewModel(
        _ viewModel: MainViewModel,
        didUpdateScreenTitle screenTitle: String,
        navigationButtonTitle: String,
        isForceRefreshEnabled: Bool,
        displayMode: NewsDisplayMode,
        sections: [NewsSectionModel],
        cellViewModelsBySectionID: [UUID: [NewsCellViewModel]]
    )
}

final class MainViewModel {
    private enum Constants {
        static let screenTitle = "News"
        static let uiUpdateThrottleInterval: TimeInterval = 0.12
    }

    private let rssManager: RssManager
    private let imageService: RssImageService
    private let userDefaultsProvider: UserDefaultsProvider

    weak var delegate: MainViewModelDelegate?
    weak var coordinator: MainFlowCoordinating?

    private var displayMode: NewsDisplayMode = .common
    private var isFetching = false
    private var activeLoadingOperations = 0
    private var sectionsByCatalog: [String: NewsSectionModel] = [:]
    private var sectionOrder: [String] = []
    private var readNewsKeys: Set<String> = []
    private var hasPendingUIUpdate = false
    private var pendingUIWorkItem: DispatchWorkItem?
    private var reloadTimer: Timer?
    private var shouldReloadAfterCurrentFetch = false

    init(coordinator: MainFlowCoordinating, appService: AppService) {
        self.coordinator = coordinator
        self.rssManager = appService.rssManager
        self.imageService = appService.rssImageService
        self.userDefaultsProvider = appService.userDefaultsProvider
    }

    func viewDidLoad() {
        notifyDelegate()
        configureReloadTimer()
        loadRssChannels()
    }

    private func loadRssChannels() {
        guard !isFetching else { return }

        setFetchingState(true)
        pendingUIWorkItem?.cancel()
        pendingUIWorkItem = nil
        hasPendingUIUpdate = false
        rssManager.downloadStoredCatalogs(delegate: self)
    }

    func toggleDisplayMode() {
        displayMode.toggle()
        notifyDelegate()
    }

    func toggleSection(id: UUID) {
        guard let sectionKey = sectionsByCatalog.first(where: { $0.value.id == id })?.key,
              var section = sectionsByCatalog[sectionKey] else {
            return
        }
        section.isExpanded.toggle()
        sectionsByCatalog[sectionKey] = section
        notifyDelegate()
    }

    func selectNews(_ newsCellViewModel: NewsCellViewModel) {
        guard let coordinator else { return }

        let didUpdateReadState = markNewsAsRead(newsCellViewModel.item)
        let selectedItem = makeReadItem(from: newsCellViewModel.item)
        let selectedViewModel = NewsCellViewModel(item: selectedItem, imageService: imageService)

        if didUpdateReadState {
            notifyDelegate()
        }
        coordinator.showNewspaper(with: selectedViewModel)
    }

    func openSettings() {
        coordinator?.showSettings { [weak self] in
            DispatchQueue.main.async {
                self?.applySettingsChanges()
            }
        }
    }

    func forceRefresh() {
        if isFetching {
            shouldReloadAfterCurrentFetch = true
            return
        }
        loadRssChannels()
    }

    deinit {
        reloadTimer?.invalidate()
    }
}

private extension MainViewModel {
    func applyFeedResults(_ feedResults: [RssFeedResult]) {
        for result in feedResults where result.error == nil {
            let sortedItems = result.items.enumerated().sorted { lhs, rhs in
                switch (lhs.element.publishedAt, rhs.element.publishedAt) {
                case let (leftDate?, rightDate?):
                    if leftDate == rightDate {
                        return lhs.offset < rhs.offset
                    }
                    return leftDate > rightDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.offset < rhs.offset
                }
            }.map(\.element)

            let items = sortedItems.map {
                let key = newsKey(for: $0)
                return NewsRowModel(
                    title: $0.title,
                    summary: $0.summary,
                    imageURL: $0.imageURL,
                    linkURL: $0.link,
                    isRead: readNewsKeys.contains(key)
                )
            }
            let sectionKey = result.parentCatalog.url.absoluteString

            if var existing = sectionsByCatalog[sectionKey] {
                existing.items = items
                sectionsByCatalog[sectionKey] = existing
            } else {
                sectionOrder.append(sectionKey)
                sectionsByCatalog[sectionKey] = NewsSectionModel(
                    title: result.parentCatalog.title,
                    isExpanded: false,
                    items: items
                )
            }
        }
    }

    func orderedSections() -> [NewsSectionModel] {
        let ordered = sectionOrder.compactMap { sectionsByCatalog[$0] }
        if ordered.count == sectionsByCatalog.count {
            return ordered
        }
        let orderedIDs = Set(ordered.map(\.id))
        return ordered + sectionsByCatalog.values.filter { section in
            !orderedIDs.contains(section.id)
        }
    }

    func makeCellViewModelsBySectionID(from sections: [NewsSectionModel]) -> [UUID: [NewsCellViewModel]] {
        var result: [UUID: [NewsCellViewModel]] = [:]
        for section in sections {
            result[section.id] = section.items.map {
                NewsCellViewModel(item: $0, imageService: imageService)
            }
        }
        return result
    }

    func notifyDelegate() {
        let sections = orderedSections()
        delegate?.mainViewModel(
            self,
            didUpdateScreenTitle: Constants.screenTitle,
            navigationButtonTitle: displayMode.navigationButtonTitle,
            isForceRefreshEnabled: !isFetching,
            displayMode: displayMode,
            sections: sections,
            cellViewModelsBySectionID: makeCellViewModelsBySectionID(from: sections)
        )
    }

    func setFetchingState(_ newValue: Bool) {
        guard isFetching != newValue else { return }
        isFetching = newValue
        notifyDelegate()
    }

    func requestUIUpdate() {
        hasPendingUIUpdate = true

        if !isFetching {
            flushPendingUIUpdate()
            return
        }

        guard pendingUIWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingUIWorkItem = nil
            self.flushPendingUIUpdate()
        }
        pendingUIWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.uiUpdateThrottleInterval, execute: workItem)
    }

    func flushPendingUIUpdate() {
        pendingUIWorkItem?.cancel()
        pendingUIWorkItem = nil
        guard hasPendingUIUpdate else { return }
        hasPendingUIUpdate = false
        notifyDelegate()
    }

    func configureReloadTimer() {
        reloadTimer?.invalidate()
        let interval = userDefaultsProvider.getPrefferedReloadTimerInterval()
        guard interval > 0 else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.loadRssChannels()
        }
        RunLoop.main.add(timer, forMode: .common)
        reloadTimer = timer
    }

    func applySettingsChanges() {
        configureReloadTimer()
        sectionsByCatalog.removeAll()
        sectionOrder.removeAll()
        notifyDelegate()

        if isFetching {
            shouldReloadAfterCurrentFetch = true
            return
        }
        loadRssChannels()
    }

    func markNewsAsRead(_ item: NewsRowModel) -> Bool {
        let key = newsKey(for: item)
        let inserted = readNewsKeys.insert(key).inserted
        var didUpdateItem = false

        for (sectionKey, var section) in sectionsByCatalog {
            guard let itemIndex = section.items.firstIndex(where: { $0.id == item.id }) else {
                continue
            }
            guard !section.items[itemIndex].isRead else {
                continue
            }

            section.items[itemIndex].isRead = true
            sectionsByCatalog[sectionKey] = section
            didUpdateItem = true
        }

        return inserted || didUpdateItem
    }

    func makeReadItem(from item: NewsRowModel) -> NewsRowModel {
        guard !item.isRead else { return item }
        var updated = item
        updated.isRead = true
        return updated
    }

    func newsKey(for item: RssItem) -> String {
        if let link = item.link?.absoluteString, !link.isEmpty {
            return "link:\(link)"
        }
        let summary = item.summary ?? ""
        return "text:\(item.title.lowercased())|\(summary.lowercased())"
    }

    func newsKey(for item: NewsRowModel) -> String {
        if let link = item.linkURL?.absoluteString, !link.isEmpty {
            return "link:\(link)"
        }
        let summary = item.summary ?? ""
        return "text:\(item.title.lowercased())|\(summary.lowercased())"
    }
}

extension MainViewModel: RssManagerDelegate {
    func didStartLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.activeLoadingOperations == 0 {
                self.setFetchingState(true)
            }
            self.activeLoadingOperations += 1
        }
    }

    func didFinishLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activeLoadingOperations = max(0, self.activeLoadingOperations - 1)
            if self.activeLoadingOperations == 0 {
                self.setFetchingState(false)
                self.flushPendingUIUpdate()
                if self.shouldReloadAfterCurrentFetch {
                    self.shouldReloadAfterCurrentFetch = false
                    self.loadRssChannels()
                }
            }
        }
    }

    func didReceiveCatalog(_ _: RssCatalogResult, source _: RssCatalogSource) {}

    func didReceiveFeedItems(_ result: [RssFeedResult], snapshots _: [RssItemSnapshot]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyFeedResults(result)
            self.requestUIUpdate()
        }
    }

    func didReceiveUnsupported(_ _: RssUnsupportedResult, url _: URL) {}
}
