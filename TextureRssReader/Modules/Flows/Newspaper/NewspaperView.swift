//
//  NewspaperView.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import Foundation
import UIKit
import AsyncDisplayKit

final class NewspaperView: ASDisplayNode {
    private enum Constants {
        static let horizontalInset: CGFloat = 16
        static let verticalInset: CGFloat = 16
        static let contentSpacing: CGFloat = 12
        static let imageHeight: CGFloat = 240
    }

    private let scrollNode = ASScrollNode()
    private let titleNode = ASTextNode()
    private let summaryNode = ASTextNode()

    private var imageNode: NewsImageNode?

    override init() {
        super.init()
        automaticallyManagesSubnodes = true
        backgroundColor = .systemBackground

        scrollNode.automaticallyManagesContentSize = true
        scrollNode.automaticallyManagesSubnodes = true
        scrollNode.backgroundColor = .systemBackground
        scrollNode.view.showsVerticalScrollIndicator = true

        scrollNode.layoutSpecBlock = { [weak self] _, constrainedSize in
            guard let self else {
                return ASLayoutSpec()
            }
            return self.contentLayoutSpec(constrainedSize: constrainedSize)
        }
    }

    func update(newsCellViewModel: NewsCellViewModel) {
        if imageNode == nil {
            let node = NewsImageNode(service: newsCellViewModel.imageService)
            node.contentMode = .scaleAspectFill
            node.clipsToBounds = true
            node.cornerRadius = 12
            node.backgroundColor = UIColor.systemGray5
            imageNode = node
        }

        imageNode?.url = newsCellViewModel.item.imageURL

        titleNode.attributedText = NSAttributedString(
            string: newsCellViewModel.item.title.trimmingCharacters(in: .whitespacesAndNewlines),
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .title3),
                .foregroundColor: UIColor.label
            ]
        )
        titleNode.maximumNumberOfLines = 0

        if let summary = newsCellViewModel.item.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            summaryNode.attributedText = NSAttributedString(
                string: summary,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
            summaryNode.maximumNumberOfLines = 0
        } else {
            summaryNode.attributedText = nil
        }

        setNeedsLayout()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        ASInsetLayoutSpec(insets: .zero, child: scrollNode)
    }
}

private extension NewspaperView {
    func contentLayoutSpec(constrainedSize: ASSizeRange) -> ASLayoutSpec {
        var children: [ASLayoutElement] = []

        if let imageNode {
            let contentWidth = max(
                0,
                constrainedSize.max.width - (Constants.horizontalInset * 2)
            )
            imageNode.style.preferredSize = CGSize(width: contentWidth, height: Constants.imageHeight)
            children.append(imageNode)
        }

        children.append(titleNode)

        if summaryNode.attributedText != nil {
            children.append(summaryNode)
        }

        let contentStack = ASStackLayoutSpec.vertical()
        contentStack.spacing = Constants.contentSpacing
        contentStack.alignItems = .stretch
        contentStack.children = children

        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(
                top: Constants.verticalInset,
                left: Constants.horizontalInset,
                bottom: Constants.verticalInset,
                right: Constants.horizontalInset
            ),
            child: contentStack
        )
    }
}
