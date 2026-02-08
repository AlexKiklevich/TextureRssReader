//
//  NewsCommonCell.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import UIKit
import AsyncDisplayKit

final class NewsCommonCell: ASCellNode {
    private var viewModel: NewsCellViewModel

    private let imageNode: NewsImageNode
    private let titleNode = ASTextNode()

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
        titleNode.style.flexShrink = 1
        titleNode.style.flexGrow = 1

        let row = ASStackLayoutSpec.horizontal()
        row.spacing = 12
        row.alignItems = .start
        row.children = [imageNode, titleNode]

        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16),
            child: row
        )
    }
}

private extension NewsCommonCell {
    func configureStaticStyles() {
        backgroundColor = .systemBackground

        imageNode.style.preferredSize = CGSize(width: 96, height: 72)
        imageNode.contentMode = .scaleAspectFill
        imageNode.clipsToBounds = true
        imageNode.backgroundColor = UIColor.systemGray5
        imageNode.cornerRadius = 12
    }

    func apply(item: NewsRowModel) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: UIColor.label
        ]
        titleNode.attributedText = NSAttributedString(
            string: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
            attributes: titleAttributes
        )
        titleNode.maximumNumberOfLines = 3
        titleNode.truncationMode = .byTruncatingTail

        imageNode.url = item.imageURL

        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }
}
