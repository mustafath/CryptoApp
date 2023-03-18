//
//  HomeViewModel.swift
//  CryptoApp
//
//  Created by Mustafa Girgin on 13.03.2023.
//

import Foundation
import Combine

class HomeViewModel : ObservableObject {
    
    @Published var statistics : [StatisticModel] = []
    @Published var allCoins : [CoinModel] = []
    @Published var portfolioCoins : [CoinModel] = []
    @Published var searchText : String = ""
    @Published var sortOption : SortOption = .holdings
    
    
    
    
    private let coinDataService = CoinDataService()
    private let marketDataService = MarketDataService()
    private let portfolioDataService = PortfolioDataService()
    private var cancallables = Set<AnyCancellable>()
    
    
    enum SortOption {
        case rank, rankReversed, holdings, holdingsReversed, price, priceReversed
    }
    
    
    init() {
        addSubscriber()
    }
    
    func addSubscriber() {
        
        
        self.$searchText
            .combineLatest(coinDataService.$allCoins, $sortOption)
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .map(filterAndSortCoins)
            .sink { [weak self] (returnedCoins) in
                self?.allCoins = returnedCoins
            }.store(in: &cancallables)
        
        self.marketDataService.$marketData
            .combineLatest($portfolioCoins)
            .sink { [weak self] (marketDataModel, portfolioCoins) in
                
                guard let data = marketDataModel else { return }
                
                let marketCap = StatisticModel(title: "Market Cap", value: data.marketCap, percentageChange: data.marketCapChangePercentage24HUsd)
                let volume = StatisticModel(title: "24H Volume", value: data.volume)
                let btcDominance = StatisticModel(title: "BTC Dominance", value: data.btcDominance)
                
                
                
                let portfolioValue = portfolioCoins.map { (coin) -> Double in
                    return coin.currentHoldingsValue
                }.reduce(0, +)
                
                
                let previousValue = portfolioCoins.map { (coin) -> Double in
                    let currentValue = coin.currentHoldingsValue
                    let percentChange = coin.priceChangePercentage24HInCurrency
                    let previousValue = currentValue * (percentChange ?? 0)
                    return previousValue
                }.reduce(0,+)
                
                let percentageChange = portfolioValue / previousValue
                
                
                let portfolio = StatisticModel(title: "Portfolio Value", value: portfolioValue.asCurrencyWith2Decimals(), percentageChange: percentageChange)
                
                let stats = [marketCap, volume, btcDominance, portfolio]
                
                self?.statistics = stats
                
            }.store(in: &cancallables)
        
        self.$allCoins
            .combineLatest(portfolioDataService.$savedEntities)
        .map { (coinModels, portfolioEntities) -> [CoinModel] in
            
            
            
            coinModels.compactMap { (coin) -> CoinModel? in
                
                guard let entity = portfolioEntities.first(where: {$0.coinID == coin.id}) else {
            
                    return nil}
                print("selammm \(entity)");
                return coin.updateHoldings(amount: entity.amount)
            }
            
        }
        .sink { [weak self] (returnedCoins) in
            guard let self = self else {return}
            
            
            self.portfolioCoins = self.sortPortfolioCoinsIfNeeded(coins: returnedCoins)
        }.store(in: &cancallables)
        
    }
    
    func reloadData() {
        marketDataService.getData()
        coinDataService.getCoins()
        HapticManager.notification(notificationType: .success)
    }
    
    
    func updatePortfolio(coin: CoinModel, amount: Double) {
        portfolioDataService.updatePortfolio(coin: coin, amount: amount)
    }
    
    
    private func sortCoins(sort: SortOption, coins: inout [CoinModel])  {
        switch sort {
        case .rank, .holdings:
            coins.sort(by: { $0.rank < $1.rank})
        case .rankReversed, .holdingsReversed:
            coins.sort(by: { $0.rank > $1.rank})
        case .price:
            coins.sort(by: { $0.currentPrice > $1.currentPrice})
        case .priceReversed:
            coins.sort(by: { $0.currentPrice < $1.currentPrice})
        
        
        }
    }
    
    
    private func sortPortfolioCoinsIfNeeded(coins: [CoinModel]) -> [CoinModel] {
        /// will only sort by holdings or reversedHoldings if needed
        switch(sortOption) {
        case . holdings:
            return coins.sorted(by: {$0.currentHoldingsValue > $1.currentHoldingsValue})
        case . holdingsReversed:
            return coins.sorted(by: {$0.currentHoldingsValue < $1.currentHoldingsValue})
        default:
            return coins
        }
    }
    
    private func filterAndSortCoins(text: String, coins: [CoinModel], sort: SortOption) -> [CoinModel] {
        var updatedCoins = filterCoins(text: text, coins: coins)
        sortCoins(sort: sort, coins: &updatedCoins)
        return updatedCoins
    }
    
    private func filterCoins(text: String, coins: [CoinModel]) -> [CoinModel] {
        guard !text.isEmpty else { return coins }
        let lowercasedText = text.lowercased()
        return coins.filter { coin in
            return
                coin.name.lowercased().contains(lowercasedText) ||
                coin.symbol.lowercased().contains(lowercasedText) ||
                coin.id.lowercased().contains(lowercasedText)
        }
    }
    
    
    private func mapGlobalMarketData(marketDataModel: MarketDataModel?) -> [StatisticModel] {
        print(marketDataModel)
        var stats: [StatisticModel] = []
        print("mapglobalmarketdata'dayım")
        guard let data = marketDataModel else {
            
            return stats}
        
        
        let marketCap = StatisticModel(title: "Market Cap", value: data.marketCap, percentageChange: data.marketCapChangePercentage24HUsd)
        let volume = StatisticModel(title: "24H Volume", value: data.volume)
        let btcDominance = StatisticModel(title: "BTC Dominance", value: data.btcDominance)
        let portfolio = StatisticModel(title: "Portfolio Value", value: "$0.00", percentageChange: 0)
        
        stats.append(contentsOf: [marketCap, volume, btcDominance, portfolio])
        print(stats)
        
        return stats
    }
    
    
}
