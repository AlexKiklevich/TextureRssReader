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
        displayMode: NewsDisplayMode,
        sections: [NewsSectionModel],
        cellViewModelsBySectionID: [UUID: [NewsCellViewModel]]
    )
}

final class MainViewModel {
    private enum Constants {
        static let screenTitle = "News"
        static let vedomostiTitle = "Vedomosti"
        static let rbcTitle = "Rbc"
        static let vedomostiURL = "https://www.vedomosti.ru/info/rss"
        static let rbcURL = "https://rssexport.rbc.ru/rbcnews/news/30/full.rss"
        static let uiUpdateThrottleInterval: TimeInterval = 0.12
    }

    private let rssManager: RssManager
    private let imageService: RssImageService

    weak var delegate: MainViewModelDelegate?
    weak var coordinator: MainFlowCoordinating?

    private var displayMode: NewsDisplayMode = .common
    private var isFetching = false
    private var pendingCallbacks = 0
    private var sectionsByCatalog: [String: NewsSectionModel] = [:]
    private var sectionOrder: [String] = []
    private var hasPendingUIUpdate = false
    private var pendingUIWorkItem: DispatchWorkItem?

    init(coordinator: MainFlowCoordinating, appService: AppService) {
        self.coordinator = coordinator
        self.rssManager = appService.rssManager
        self.imageService = appService.rssImageService
    }

    func viewDidLoad() {
        notifyDelegate()
        loadRssChannels()
    }

    func loadRssChannels() {
        guard !isFetching else { return }
        let sources = makeSources()
        guard !sources.isEmpty else { return }

        isFetching = true
        pendingCallbacks = sources.count
        pendingUIWorkItem?.cancel()
        pendingUIWorkItem = nil
        hasPendingUIUpdate = false
        rssManager.performFetch(catalogs: sources, delegate: self)
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
        coordinator?.showNewspaper(with: newsCellViewModel)
    }
}

private extension MainViewModel {
    func makeSources() -> [RssCatalogSource] {
        [
            (Constants.vedomostiTitle, Constants.vedomostiURL),
            (Constants.rbcTitle, Constants.rbcURL)
        ]
            .compactMap { title, urlString in
                guard let url = URL(string: urlString) else { return nil }
                return RssCatalogSource(title: title, url: url)
            }
    }

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
                NewsRowModel(
                    title: $0.title,
                    summary: $0.summary,
                    imageURL: $0.imageURL
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

    func completeCallback() -> Bool {
        guard pendingCallbacks > 0 else { return false }
        pendingCallbacks -= 1
        if pendingCallbacks == 0 {
            isFetching = false
            return true
        }
        return false
    }

    func replaceCatalogCallbackWithFeeds(feedCount: Int) {
        guard pendingCallbacks > 0 else { return }
        pendingCallbacks -= 1
        pendingCallbacks += feedCount
        if pendingCallbacks == 0 {
            isFetching = false
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
            displayMode: displayMode,
            sections: sections,
            cellViewModelsBySectionID: makeCellViewModelsBySectionID(from: sections)
        )
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
}

extension MainViewModel: RssManagerDelegate {
    func didReceiveCatalog(_ result: RssCatalogResult, source: RssCatalogSource) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let rssFeeds = result.rssSnapshots.map { snapshot in
                RssCatalogSource(title: "\(source.title). \(snapshot.title)", url: snapshot.url)
            }
            self.replaceCatalogCallbackWithFeeds(feedCount: rssFeeds.count)
            if rssFeeds.isEmpty, self.pendingCallbacks == 0 {
                self.flushPendingUIUpdate()
                return
            }
            self.rssManager.performFetch(catalogs: rssFeeds, delegate: self)
        }
    }

    func didReceiveFeedItems(_ result: [RssFeedResult], snapshots _: [RssItemSnapshot]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyFeedResults(result)
            self.requestUIUpdate()
            if self.completeCallback() {
                self.flushPendingUIUpdate()
            }
        }
    }

    func didReceiveUnsupported(_ _: RssUnsupportedResult, url _: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.completeCallback() {
                self.flushPendingUIUpdate()
            }
        }
    }
}
