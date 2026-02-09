//
//  NewsSection.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import UIKit
import AsyncDisplayKit

final class NewsSection: ASCellNode {
    private var model: NewsSectionModel
    private let onToggle: (UUID) -> Void

    private let titleNode = ASTextNode()
    private let toggleButtonNode = ASButtonNode()

    init(
        model: NewsSectionModel,
        onToggle: @escaping (UUID) -> Void = { _ in }
    ) {
        self.model = model
        self.onToggle = onToggle
        super.init()
        automaticallyManagesSubnodes = true
        selectionStyle = .none
        configureStaticStyles()
        apply(model: model)
    }

    func update(model: NewsSectionModel) {
        self.model = model
        apply(model: model)
        setNeedsLayout()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        titleNode.style.flexShrink = 1
        titleNode.style.flexGrow = 1
        toggleButtonNode.style.flexShrink = 0

        let row = ASStackLayoutSpec.horizontal()
        row.alignItems = .center
        row.justifyContent = .spaceBetween
        row.spacing = 12
        row.children = [titleNode, toggleButtonNode]

        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(top: 12, left: 16, bottom: 8, right: 16),
            child: row
        )
    }
}

private extension NewsSection {
    func configureStaticStyles() {
        backgroundColor = .systemBackground

        toggleButtonNode.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        toggleButtonNode.backgroundColor = UIColor.secondarySystemBackground
        toggleButtonNode.cornerRadius = 8
        toggleButtonNode.addTarget(self, action: #selector(toggleButtonTapped), forControlEvents: .touchUpInside)
    }

    func apply(model: NewsSectionModel) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: UIColor.label
        ]
        titleNode.attributedText = NSAttributedString(string: model.title, attributes: titleAttributes)
        titleNode.maximumNumberOfLines = 1
        titleNode.truncationMode = .byTruncatingTail

        let buttonAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
            .foregroundColor: UIColor.systemBlue
        ]
        let toggleText = "\(model.isExpanded ? "▼" : "▲")"
        toggleButtonNode.setAttributedTitle(NSAttributedString(string: toggleText, attributes: buttonAttributes), for: .normal)
        toggleButtonNode.accessibilityTraits = .button
    }

    @objc
    func toggleButtonTapped() {
        onToggle(model.id)
    }
}
