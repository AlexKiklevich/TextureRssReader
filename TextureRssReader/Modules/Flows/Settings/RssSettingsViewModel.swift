//
//  RssSettingsViewModel.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 9.02.26.
//

import Foundation

protocol SettingsViewModelDelegate: AnyObject {
    func settingsViewModel(_ viewModel: SettingsViewModel, didUpdate viewState: SettingsViewModel.ViewState)
    func settingsViewModel(_ viewModel: SettingsViewModel, didReceiveErrorMessage message: String)
}

final class SettingsViewModel {
    struct SourceRow: Hashable, Identifiable {
        let id: String
        let title: String
        let urlString: String
    }

    struct ViewState {
        let screenTitle: String
        let refreshIntervalText: String
        let sources: [SourceRow]
        let isClearDataInProgress: Bool
    }

    private enum Constants {
        static let screenTitle = "Settings"
        static let invalidIntervalMessage = "Refresh interval must be a number greater than zero."
        static let emptySourceTitleMessage = "Source title is required."
        static let invalidSourceURLMessage = "Source URL must be a valid http or https link."
        static let duplicateSourceMessage = "Source with this URL already exists."
        static let saveSourceFailureMessage = "Failed to save source."
        static let deleteSourceFailureMessage = "Failed to delete source."
        static let loadSourcesFailureMessage = "Failed to load sources."
        static let clearDataFailureMessage = "Failed to clear local data."
        static let operationInProgressMessage = "Please wait until current operation is finished."
    }

    weak var delegate: SettingsViewModelDelegate?

    private let realmProvider: RealmProvider
    private let userDefaultsProvider: UserDefaultsProvider
    private let imageService: RssImageService
    private let onSettingsChanged: () -> Void

    private var refreshInterval: TimeInterval
    private var sources: [RssCatalogSource] = []
    private var isClearDataInProgress = false

    init(appService: AppService, onSettingsChanged: @escaping () -> Void) {
        self.realmProvider = appService.realmProvider
        self.userDefaultsProvider = appService.userDefaultsProvider
        self.imageService = appService.rssImageService
        self.onSettingsChanged = onSettingsChanged
        self.refreshInterval = appService.userDefaultsProvider.getPrefferedReloadTimerInterval()
    }

    func viewDidLoad() {
        notifyDelegate()
        loadSources()
    }

    @discardableResult
    func saveRefreshInterval(input: String) -> Bool {
        let sanitizedInput = input.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(sanitizedInput), value > 0 else {
            delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.invalidIntervalMessage)
            return false
        }

        refreshInterval = value
        userDefaultsProvider.set(prefferedReloadTimerInterval: value)
        notifyDelegate()
        onSettingsChanged()
        return true
    }

    @discardableResult
    func addSource(title: String, urlString: String) -> Bool {
        guard !isClearDataInProgress else {
            delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.operationInProgressMessage)
            return false
        }

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.emptySourceTitleMessage)
            return false
        }

        let normalizedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalizedURLString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.invalidSourceURLMessage)
            return false
        }

        guard !sources.contains(where: { $0.url.absoluteString == url.absoluteString }) else {
            delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.duplicateSourceMessage)
            return false
        }

        let source = RssCatalogSource(title: normalizedTitle, url: url)
        let previousSources = sources
        sources.append(source)
        notifyDelegate()

        Task {
            do {
                try await realmProvider.upsertCatalogSource(source)
                await MainActor.run {
                    self.onSettingsChanged()
                }
            } catch {
                await MainActor.run {
                    self.sources = previousSources
                    self.notifyDelegate()
                    self.delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.saveSourceFailureMessage)
                }
            }
        }
        return true
    }

    func removeSource(at index: Int) {
        guard !isClearDataInProgress else {
            delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.operationInProgressMessage)
            return
        }
        guard sources.indices.contains(index) else { return }
        let previousSources = sources
        let removedSource = previousSources[index]
        sources.remove(at: index)
        notifyDelegate()

        Task {
            do {
                try await realmProvider.deleteCatalog(source: removedSource)
                await MainActor.run {
                    self.onSettingsChanged()
                }
            } catch {
                await MainActor.run {
                    self.sources = previousSources
                    self.notifyDelegate()
                    self.delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.deleteSourceFailureMessage)
                }
            }
        }
    }

    func clearDatabaseAndImageCache() {
        guard !isClearDataInProgress else { return }
        isClearDataInProgress = true
        notifyDelegate()

        Task {
            do {
                try await realmProvider.deleteAllData()
                imageService.clearCache()
                userDefaultsProvider.set(hasLaunchedBefore: false)
                await MainActor.run {
                    self.sources = DefaultCatalogs.array
                    self.isClearDataInProgress = false
                    self.notifyDelegate()
                    self.onSettingsChanged()
                }
            } catch {
                await MainActor.run {
                    self.isClearDataInProgress = false
                    self.notifyDelegate()
                    self.delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.clearDataFailureMessage)
                }
            }
        }
    }
}

private extension SettingsViewModel {
    func loadSources() {
        Task {
            do {
                let loadedSources = try await realmProvider.readCatalogSources()
                await MainActor.run {
                    self.sources = loadedSources.isEmpty ? DefaultCatalogs.array : self.deduplicateSources(loadedSources)
                    self.notifyDelegate()
                }
            } catch {
                await MainActor.run {
                    self.sources = DefaultCatalogs.array
                    self.notifyDelegate()
                    self.delegate?.settingsViewModel(self, didReceiveErrorMessage: Constants.loadSourcesFailureMessage)
                }
            }
        }
    }

    func notifyDelegate() {
        delegate?.settingsViewModel(
            self,
            didUpdate: ViewState(
                screenTitle: Constants.screenTitle,
                refreshIntervalText: textValue(for: refreshInterval),
                sources: sources.map {
                    SourceRow(
                        id: $0.url.absoluteString,
                        title: $0.title,
                        urlString: $0.url.absoluteString
                    )
                },
                isClearDataInProgress: isClearDataInProgress
            )
        )
    }

    func textValue(for interval: TimeInterval) -> String {
        if interval.rounded(.towardZero) == interval {
            return String(Int(interval))
        }
        return String(interval)
    }

    func deduplicateSources(_ input: [RssCatalogSource]) -> [RssCatalogSource] {
        var result: [RssCatalogSource] = []
        var seenURLs = Set<String>()
        for source in input {
            let key = source.url.absoluteString
            guard seenURLs.insert(key).inserted else { continue }
            result.append(source)
        }
        return result
    }
}
