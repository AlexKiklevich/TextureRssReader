//
//  MainView.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 7.02.26.
//

import Foundation
import UIKit
import AsyncDisplayKit

final class MainView: ASDisplayNode {
    private struct ViewState {
        let sections: [NewsSectionModel]
        let cellViewModelsBySectionID: [UUID: [NewsCellViewModel]]
        let displayMode: NewsDisplayMode
    }

    private struct ContentDiffUpdate {
        let insertedSections: IndexSet
        let deletedSections: IndexSet
        let reloadedSections: IndexSet
        let reloadedRows: [IndexPath]

        var hasChanges: Bool {
            !insertedSections.isEmpty
                || !deletedSections.isEmpty
                || !reloadedSections.isEmpty
                || !reloadedRows.isEmpty
        }
    }

    private struct DisplayModeUpdate {
        let rowIndexPaths: [IndexPath]
    }

    private struct SectionToggleUpdate {
        let sectionIndex: Int
        let rowCount: Int
        let isExpanded: Bool
    }

    private let tableNode = ASTableNode(style: .plain)

    private var sections: [NewsSectionModel] = []
    private var cellViewModelsBySectionID: [UUID: [NewsCellViewModel]] = [:]
    private var displayMode: NewsDisplayMode = .common
    private var isApplyingAnimatedUpdate = false
    private var pendingViewState: ViewState?

    var onPrefetch: (() -> Void)?
    var onToggleSection: ((UUID) -> Void)?
    var onSelectNews: ((NewsCellViewModel) -> Void)?

    override init() {
        super.init()
        automaticallyManagesSubnodes = true
        backgroundColor = .systemBackground

        tableNode.backgroundColor = .systemBackground
        tableNode.dataSource = self
        tableNode.delegate = self
        tableNode.leadingScreensForBatching = 2
        tableNode.view.separatorStyle = .none
        tableNode.view.showsVerticalScrollIndicator = true
    }

    func update(
        sections: [NewsSectionModel],
        cellViewModelsBySectionID: [UUID: [NewsCellViewModel]],
        displayMode: NewsDisplayMode
    ) {
        let nextState = ViewState(
            sections: sections,
            cellViewModelsBySectionID: cellViewModelsBySectionID,
            displayMode: displayMode
        )

        if isApplyingAnimatedUpdate {
            pendingViewState = nextState
            return
        }
        if tableNode.isProcessingUpdates {
            pendingViewState = nextState
            tableNode.onDidFinishProcessingUpdates { [weak self] in
                self?.applyPendingViewStateIfNeeded()
            }
            return
        }

        let previousSections = self.sections
        let previousCellViewModels = self.cellViewModelsBySectionID
        let previousDisplayMode = self.displayMode

        if let update = displayModeUpdate(
            oldSections: previousSections,
            oldCellViewModelsBySectionID: previousCellViewModels,
            oldDisplayMode: previousDisplayMode,
            newSections: sections,
            newCellViewModelsBySectionID: cellViewModelsBySectionID,
            newDisplayMode: displayMode
        ) {
            self.sections = sections
            self.cellViewModelsBySectionID = cellViewModelsBySectionID
            self.displayMode = displayMode
            applyDisplayModeUpdate(update)
            return
        }

        if let update = sectionToggleUpdate(
            oldSections: previousSections,
            oldCellViewModelsBySectionID: previousCellViewModels,
            oldDisplayMode: previousDisplayMode,
            newSections: sections,
            newCellViewModelsBySectionID: cellViewModelsBySectionID,
            newDisplayMode: displayMode
        ) {
            self.sections = sections
            self.cellViewModelsBySectionID = cellViewModelsBySectionID
            self.displayMode = displayMode
            applySectionToggleUpdate(update)
            return
        }

        if let update = contentDiffUpdate(
            oldSections: previousSections,
            oldCellViewModelsBySectionID: previousCellViewModels,
            oldDisplayMode: previousDisplayMode,
            newSections: sections,
            newCellViewModelsBySectionID: cellViewModelsBySectionID,
            newDisplayMode: displayMode
        ) {
            self.sections = sections
            self.cellViewModelsBySectionID = cellViewModelsBySectionID
            self.displayMode = displayMode
            applyContentDiffUpdate(update)
            return
        }

        self.sections = sections
        self.cellViewModelsBySectionID = cellViewModelsBySectionID
        self.displayMode = displayMode
        reloadData()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        ASInsetLayoutSpec(insets: .zero, child: tableNode)
    }
}

private extension MainView {
    func reloadData() {
        tableNode.reloadData()
    }

    private func displayModeUpdate(
        oldSections: [NewsSectionModel],
        oldCellViewModelsBySectionID: [UUID: [NewsCellViewModel]],
        oldDisplayMode: NewsDisplayMode,
        newSections: [NewsSectionModel],
        newCellViewModelsBySectionID: [UUID: [NewsCellViewModel]],
        newDisplayMode: NewsDisplayMode
    ) -> DisplayModeUpdate? {
        guard oldDisplayMode != newDisplayMode else { return nil }
        guard oldSections.count == newSections.count else { return nil }

        var rowIndexPaths: [IndexPath] = []

        for sectionIndex in oldSections.indices {
            let oldSection = oldSections[sectionIndex]
            let newSection = newSections[sectionIndex]

            guard oldSection.id == newSection.id,
                  oldSection.title == newSection.title,
                  oldSection.isExpanded == newSection.isExpanded else {
                return nil
            }

            let oldRowsCount = oldCellViewModelsBySectionID[oldSection.id]?.count ?? 0
            let newRowsCount = newCellViewModelsBySectionID[newSection.id]?.count ?? 0
            guard oldRowsCount == newRowsCount else {
                return nil
            }

            guard oldSection.isExpanded, oldRowsCount > 0 else {
                continue
            }

            rowIndexPaths.append(
                contentsOf: (1...oldRowsCount).map { IndexPath(row: $0, section: sectionIndex) }
            )
        }

        return DisplayModeUpdate(rowIndexPaths: rowIndexPaths)
    }

    private func contentDiffUpdate(
        oldSections: [NewsSectionModel],
        oldCellViewModelsBySectionID: [UUID: [NewsCellViewModel]],
        oldDisplayMode: NewsDisplayMode,
        newSections: [NewsSectionModel],
        newCellViewModelsBySectionID: [UUID: [NewsCellViewModel]],
        newDisplayMode: NewsDisplayMode
    ) -> ContentDiffUpdate? {
        guard oldDisplayMode == newDisplayMode else { return nil }

        let oldIDs = oldSections.map(\.id)
        let newIDs = newSections.map(\.id)
        guard Set(oldIDs).count == oldIDs.count,
              Set(newIDs).count == newIDs.count else {
            return nil
        }

        let oldSet = Set(oldIDs)
        let newSet = Set(newIDs)

        let oldCommonOrder = oldIDs.filter { newSet.contains($0) }
        let newCommonOrder = newIDs.filter { oldSet.contains($0) }
        guard oldCommonOrder == newCommonOrder else {
            return nil
        }

        let deletedSections = IndexSet(
            oldSections.indices.filter { !newSet.contains(oldSections[$0].id) }
        )
        let insertedSections = IndexSet(
            newSections.indices.filter { !oldSet.contains(newSections[$0].id) }
        )
        let hasStructureChanges = !insertedSections.isEmpty || !deletedSections.isEmpty

        let oldIndexByID = Dictionary(uniqueKeysWithValues: oldSections.enumerated().map { ($0.element.id, $0.offset) })
        let newIndexByID = Dictionary(uniqueKeysWithValues: newSections.enumerated().map { ($0.element.id, $0.offset) })

        var reloadedSections = IndexSet()
        var reloadedRows: [IndexPath] = []

        for id in oldCommonOrder {
            guard let oldIndex = oldIndexByID[id],
                  let newIndex = newIndexByID[id] else {
                continue
            }

            let oldSection = oldSections[oldIndex]
            let newSection = newSections[newIndex]

            let oldRowsCount = oldCellViewModelsBySectionID[id]?.count ?? 0
            let newRowsCount = newCellViewModelsBySectionID[id]?.count ?? 0

            let hasExpandedRowCountChange = oldSection.isExpanded
                && newSection.isExpanded
                && oldRowsCount != newRowsCount

            if hasStructureChanges {
                if oldSection.title != newSection.title
                    || oldSection.isExpanded != newSection.isExpanded
                    || hasExpandedRowCountChange {
                    return nil
                }
                continue
            }

            if oldSection.isExpanded != newSection.isExpanded {
                return nil
            }

            if hasExpandedRowCountChange {
                return nil
            }

            let needsSectionReload = oldSection.title != newSection.title

            if needsSectionReload {
                reloadedSections.insert(newIndex)
                continue
            }

            guard newSection.isExpanded, newRowsCount > 0 else { continue }

            reloadedRows.append(
                contentsOf: (1...newRowsCount).map { IndexPath(row: $0, section: newIndex) }
            )
        }

        let update = ContentDiffUpdate(
            insertedSections: insertedSections,
            deletedSections: deletedSections,
            reloadedSections: reloadedSections,
            reloadedRows: reloadedRows
        )
        return update.hasChanges ? update : nil
    }

    private func applyDisplayModeUpdate(_ update: DisplayModeUpdate) {
        guard !tableNode.isProcessingUpdates else {
            reloadData()
            return
        }
        guard !update.rowIndexPaths.isEmpty else {
            return
        }

        isApplyingAnimatedUpdate = true
        tableNode.performBatchUpdates({
            tableNode.reloadRows(at: update.rowIndexPaths, with: .none)
        }, completion: { [weak self] _ in
            self?.finishAnimatedUpdate()
        })
    }

    private func applyContentDiffUpdate(_ update: ContentDiffUpdate) {
        guard !tableNode.isProcessingUpdates else {
            reloadData()
            return
        }

        isApplyingAnimatedUpdate = true
        tableNode.performBatchUpdates({
            if !update.deletedSections.isEmpty {
                tableNode.deleteSections(update.deletedSections, with: .fade)
            }
            if !update.insertedSections.isEmpty {
                tableNode.insertSections(update.insertedSections, with: .fade)
            }
            if !update.reloadedSections.isEmpty {
                tableNode.reloadSections(update.reloadedSections, with: .none)
            }
            if !update.reloadedRows.isEmpty {
                tableNode.reloadRows(at: update.reloadedRows, with: .none)
            }
        }, completion: { [weak self] _ in
            self?.finishAnimatedUpdate()
        })
    }

    private func sectionToggleUpdate(
        oldSections: [NewsSectionModel],
        oldCellViewModelsBySectionID: [UUID: [NewsCellViewModel]],
        oldDisplayMode: NewsDisplayMode,
        newSections: [NewsSectionModel],
        newCellViewModelsBySectionID: [UUID: [NewsCellViewModel]],
        newDisplayMode: NewsDisplayMode
    ) -> SectionToggleUpdate? {
        guard oldDisplayMode == newDisplayMode else { return nil }
        guard oldSections.count == newSections.count else { return nil }

        var changedSectionIndex: Int?
        var changedSectionExpanded = false
        var changedSectionRowCount = 0

        for sectionIndex in oldSections.indices {
            let oldSection = oldSections[sectionIndex]
            let newSection = newSections[sectionIndex]

            guard oldSection.id == newSection.id,
                  oldSection.title == newSection.title else {
                return nil
            }

            let oldRowsCount = oldCellViewModelsBySectionID[oldSection.id]?.count ?? 0
            let newRowsCount = newCellViewModelsBySectionID[newSection.id]?.count ?? 0
            guard oldRowsCount == newRowsCount else {
                return nil
            }

            if oldSection.isExpanded != newSection.isExpanded {
                guard changedSectionIndex == nil else { return nil }
                changedSectionIndex = sectionIndex
                changedSectionExpanded = newSection.isExpanded
                changedSectionRowCount = newRowsCount
            }
        }

        guard let changedSectionIndex else { return nil }
        return SectionToggleUpdate(
            sectionIndex: changedSectionIndex,
            rowCount: changedSectionRowCount,
            isExpanded: changedSectionExpanded
        )
    }

    private func applySectionToggleUpdate(_ update: SectionToggleUpdate) {
        guard !tableNode.isProcessingUpdates else {
            reloadData()
            return
        }

        let headerIndexPath = IndexPath(row: 0, section: update.sectionIndex)
        let itemIndexPaths = update.rowCount > 0
            ? (1...update.rowCount).map { IndexPath(row: $0, section: update.sectionIndex) }
            : []

        isApplyingAnimatedUpdate = true
        tableNode.performBatchUpdates({
            tableNode.reloadRows(at: [headerIndexPath], with: .none)
            guard !itemIndexPaths.isEmpty else { return }

            if update.isExpanded {
                tableNode.insertRows(at: itemIndexPaths, with: .automatic)
            } else {
                tableNode.deleteRows(at: itemIndexPaths, with: .automatic)
            }
        }, completion: { [weak self] _ in
            self?.finishAnimatedUpdate()
        })
    }

    private func finishAnimatedUpdate() {
        isApplyingAnimatedUpdate = false
        applyPendingViewStateIfNeeded()
    }

    private func applyPendingViewStateIfNeeded() {
        guard let pendingViewState else { return }
        self.pendingViewState = nil
        update(
            sections: pendingViewState.sections,
            cellViewModelsBySectionID: pendingViewState.cellViewModelsBySectionID,
            displayMode: pendingViewState.displayMode
        )
    }

    func rowViewModel(for indexPath: IndexPath) -> NewsCellViewModel? {
        guard sections.indices.contains(indexPath.section) else { return nil }
        let section = sections[indexPath.section]
        guard section.isExpanded else { return nil }

        let index = indexPath.row - 1
        guard let cellViewModels = cellViewModelsBySectionID[section.id],
              cellViewModels.indices.contains(index) else { return nil }
        return cellViewModels[index]
    }
}

extension MainView: ASTableDataSource {
    func numberOfSections(in tableNode: ASTableNode) -> Int {
        sections.count
    }

    func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
        guard sections.indices.contains(section) else { return 0 }
        let model = sections[section]
        let itemCount = cellViewModelsBySectionID[model.id]?.count ?? 0
        return 1 + (model.isExpanded ? itemCount : 0)
    }

    func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        guard sections.indices.contains(indexPath.section) else {
            return { ASCellNode() }
        }

        let sectionModel = sections[indexPath.section]
        if indexPath.row == 0 {
            return { [weak self, sectionModel] in
                NewsSection(model: sectionModel) { sectionID in
                    self?.onToggleSection?(sectionID)
                }
            }
        }

        guard let cellViewModel = rowViewModel(for: indexPath) else {
            return { ASCellNode() }
        }

        let mode = displayMode
        return { [cellViewModel] in
            switch mode {
            case .common:
                return NewsCommonCell(viewModel: cellViewModel)
            case .extended:
                return NewsExtendedCell(viewModel: cellViewModel)
            }
        }
    }
}

extension MainView: ASTableDelegate {
    func shouldBatchFetch(for tableNode: ASTableNode) -> Bool {
        onPrefetch != nil
    }

    func tableNode(_ tableNode: ASTableNode, willBeginBatchFetchWith context: ASBatchContext) {
        onPrefetch?()
        context.completeBatchFetching(true)
    }

    func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
        tableNode.deselectRow(at: indexPath, animated: true)
        guard indexPath.row > 0,
              let viewModel = rowViewModel(for: indexPath) else {
            return
        }
        onSelectNews?(viewModel)
    }
}
