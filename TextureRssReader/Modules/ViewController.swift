//
//  ViewController.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import UIKit

final class ViewController: UIViewController {
    private let rssManager = RssManager()
    private let realmProvider = RealmProvider()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.80, green: 0.95, blue: 0.80, alpha: 1.0)
        Task {
            await loadRssChannels()
        }
    }

    private func loadRssChannels() async {
        guard let urlVedomosti = URL(string: "https://www.vedomosti.ru/info/rss"),
              let urlRbc = URL(string: "https://rssexport.rbc.ru/rbcnews/news/30/full.rss") else {
            return
        }
        let sources = [
            RssSource(title: "Vedomosti", url: urlVedomosti),
            RssSource(title: "Rbc", url: urlRbc)
        ]
        rssManager.performFetch(sources: sources, delegate: self)
    }
}

extension ViewController: RssManagerDelegate {
    func didReceiveCatalog(_ result: RssCatalogResult, source: RssSource) {
        print(result)
    }
    
    func didReceiveFeedItems(_ result: [RssFeedResult], sources: [RssSource]) {
        guard let items = result.first?.items else {
            return
        }
        Task.detached { [weak self] in
            do {
                try await self?.realmProvider.save(items: items)
            }
            catch let error {
                print("Failed to save items: \(error)")
                return
            }
            do {
                let items = try await self?.realmProvider.read()
                print("Saved items: \(items ?? [])")
            }
            catch let error {
                print("Failed to fetch items: \(error)")
            }
        }
    }
    
    func didReceiveUnsupported(_ result: RssUnsupportedResult, source: RssSource) {
        print(result)
    }
}
