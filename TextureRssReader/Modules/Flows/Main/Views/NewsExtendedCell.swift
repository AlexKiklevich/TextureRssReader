//
//  NewsExtendedCell.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import UIKit
import AsyncDisplayKit

final class NewsExtendedCell: ASCellNode {
    private enum Constants {
        static let horizontalInset: CGFloat = 16
        static let rowSpacing: CGFloat = 12
        static let imageWidth: CGFloat = 96
        static let minTitlePointSize: CGFloat = 11
        static let titleMaxLines: UInt = 2
    }

    private var viewModel: NewsCellViewModel

    private let imageNode: NewsImageNode
    private let titleNode = ASTextNode()
    private let summaryNode = ASTextNode()
    private var titleText = ""
    private var titleColor: UIColor = .label
    private var cachedTitleWidth: CGFloat = 0

    init(viewModel: NewsCellViewModel) {
        self.viewModel = viewModel
        self.imageNode = NewsImageNode(service: viewModel.imageService)
        super.init()
        automaticallyManagesSubnodes = true
        selectionStyle = .none
        configureStaticStyles()
        apply(item: viewModel.item)
    }

    func update(viewModel: NewsCellViewModel) {
        self.viewModel = viewModel
        apply(item: viewModel.item)
        setNeedsLayout()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let availableTitleWidth = max(
            0,
            constrainedSize.max.width
            - (Constants.horizontalInset * 2)
            - Constants.imageWidth
            - Constants.rowSpacing
        )
        updateTitleNodeIfNeeded(availableWidth: availableTitleWidth)

        titleNode.style.flexShrink = 1
        summaryNode.style.flexShrink = 1
        var textChildren: [ASLayoutElement] = [titleNode]
        if summaryNode.attributedText != nil {
            textChildren.append(summaryNode)
        }

        let textColumn = ASStackLayoutSpec.vertical()
        textColumn.spacing = 6
        textColumn.alignItems = .stretch
        textColumn.children = textChildren
        textColumn.style.flexGrow = 1
        textColumn.style.flexShrink = 1

        let row = ASStackLayoutSpec.horizontal()
        row.spacing = Constants.rowSpacing
        row.alignItems = .start
        row.children = [imageNode, textColumn]

        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(top: 10, left: Constants.horizontalInset, bottom: 10, right: Constants.horizontalInset),
            child: row
        )
    }
}

private extension NewsExtendedCell {
    func configureStaticStyles() {
        backgroundColor = .systemBackground

        imageNode.style.preferredSize = CGSize(width: 96, height: 72)
        imageNode.contentMode = .scaleAspectFill
        imageNode.clipsToBounds = true
        imageNode.backgroundColor = UIColor.systemGray5
        imageNode.cornerRadius = 12
    }

    func apply(item: NewsRowModel) {
        titleText = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        titleColor = item.isRead ? .secondaryLabel : .label
        cachedTitleWidth = 0
        titleNode.maximumNumberOfLines = Constants.titleMaxLines
        titleNode.truncationMode = .byTruncatingTail
        titleNode.attributedText = NSAttributedString(
            string: titleText,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .headline),
                .foregroundColor: titleColor
            ]
        )

        if let summary = item.summary {
            let summaryColor: UIColor = item.isRead ? .tertiaryLabel : .secondaryLabel
            let summaryAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .subheadline),
                .foregroundColor: summaryColor
            ]
            summaryNode.attributedText = NSAttributedString(string: summary, attributes: summaryAttributes)
            summaryNode.maximumNumberOfLines = 3
            summaryNode.truncationMode = .byTruncatingTail
        } else {
            summaryNode.attributedText = nil
        }

        imageNode.url = item.imageURL

        isAccessibilityElement = true
        accessibilityTraits = .staticText
        accessibilityValue = item.isRead ? "Read" : "Unread"
    }

    func updateTitleNodeIfNeeded(availableWidth: CGFloat) {
        guard availableWidth.isFinite, availableWidth > 0 else { return }
        guard abs(cachedTitleWidth - availableWidth) > 0.5 else { return }
        cachedTitleWidth = availableWidth

        let font = fittedTitleFont(for: titleText, width: availableWidth)
        titleNode.attributedText = NSAttributedString(
            string: titleText,
            attributes: [
                .font: font,
                .foregroundColor: titleColor
            ]
        )
    }

    func fittedTitleFont(for text: String, width: CGFloat) -> UIFont {
        let baseFont = UIFont.preferredFont(forTextStyle: .headline)
        let minimumPointSize = min(Constants.minTitlePointSize, baseFont.pointSize)
        var currentPointSize = baseFont.pointSize

        while currentPointSize > minimumPointSize {
            let candidateFont = baseFont.withSize(currentPointSize)
            if textFits(text, font: candidateFont, width: width) {
                return candidateFont
            }
            currentPointSize -= 1
        }

        return baseFont.withSize(minimumPointSize)
    }

    func textFits(_ text: String, font: UIFont, width: CGFloat) -> Bool {
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let maxHeight = ceil(font.lineHeight * CGFloat(Constants.titleMaxLines))
        return ceil(boundingRect.height) <= maxHeight
    }
}
