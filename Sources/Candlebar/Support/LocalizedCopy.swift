import Foundation

enum CopyKey {
    case account
    case accountDetailsCollapse
    case accountDetailsExpand
    case accountStatusCheckFailed
    case accountStatusLive
    case accountStatusOffline
    case accountStatusPartial
    case add
    case apiKey
    case apiKeys
    case appearance
    case checkForUpdates
    case compactMenuBar
    case current
    case defaultSymbol
    case deleteKey
    case diagnostics
    case exportDiagnostics
    case headerKlineInterval
    case headerKlineWidth
    case hideBalances
    case hideLowValueAccount
    case keyStored
    case language
    case noKeyCopy
    case noKeyRiskCopy
    case none
    case noneOrNotLoaded
    case on
    case off
    case pinMainPanel
    case pinMainPanelOff
    case pixelTheme
    case positions
    case priceDecimals
    case quit
    case readOnlyKey
    case readOnlyKeyCopy
    case saveAndTest
    case searchPlaceholder
    case settings
    case spotEstimate
    case tickerRefresh
    case lastError
    case keyStatusMissing
    case watchlist
    case watchlistLimit
    case watchlistSparkInterval
    case watching
    case positionBreakeven
    case positionEntry
    case positionFundingFee
    case positionLeverage
    case positionLiquidation
    case positionMark
    case positionNotional
    case positionRatio
    case positionRealizedPnL
    case positionSummaryHelp
    case positionSize
    case positionUnrealizedPnL
    case summaryCoinM
    case summaryPreviousDayUnavailable
    case summarySpot
    case summaryTotalHelp
    case summaryTotal
    case summaryUsdM
    case defaultRow
    case setDefault
    case moveUp
    case moveDown
    case remove
    case refresh
    case updated
    case version
}

enum LocalizedCopy {
    static func text(_ key: CopyKey, language: AppLanguage) -> String {
        switch language {
        case .english:
            english(key)
        case .chinese:
            chinese(key)
        }
    }

    static func apiKeyStatusText(_ statusText: String, language: AppLanguage) -> String {
        switch statusText {
        case "KEY STORED":
            text(.keyStored, language: language)
        case "READ-ONLY KEY NEEDED":
            text(.keyStatusMissing, language: language)
        default:
            statusText
        }
    }

    static func accountStatusText(_ statusText: String, language: AppLanguage) -> String {
        switch statusText {
        case "ACCOUNT LIVE":
            text(.accountStatusLive, language: language)
        case "ACCOUNT PARTIAL":
            text(.accountStatusPartial, language: language)
        case "ACCOUNT CHECK FAILED":
            text(.accountStatusCheckFailed, language: language)
        case "OFFLINE":
            text(.accountStatusOffline, language: language)
        case "READ-ONLY KEY NEEDED":
            text(.keyStatusMissing, language: language)
        default:
            statusText
        }
    }

    private static func english(_ key: CopyKey) -> String {
        switch key {
        case .account: "ACCOUNT"
        case .accountDetailsCollapse: "Collapse account details"
        case .accountDetailsExpand: "Expand account details"
        case .accountStatusCheckFailed: "ACCOUNT CHECK FAILED"
        case .accountStatusLive: "ACCOUNT LIVE"
        case .accountStatusOffline: "OFFLINE"
        case .accountStatusPartial: "ACCOUNT PARTIAL"
        case .add: "ADD"
        case .apiKey: "API key"
        case .apiKeys: "API KEYS"
        case .appearance: "APPEARANCE"
        case .checkForUpdates: "CHECK FOR UPDATES"
        case .compactMenuBar: "COMPACT MENU BAR"
        case .current: "CURRENT"
        case .defaultSymbol: "Default symbol"
        case .deleteKey: "DELETE KEY"
        case .diagnostics: "DIAGNOSTICS"
        case .exportDiagnostics: "EXPORT REDACTED DIAGNOSTICS"
        case .headerKlineInterval: "TOP KLINE"
        case .headerKlineWidth: "TOP WIDTH"
        case .hideBalances: "HIDE BALANCES"
        case .hideLowValueAccount: "HIDE LOW-VALUE ACCOUNT"
        case .keyStored: "KEY STORED"
        case .language: "LANGUAGE"
        case .noKeyCopy: "Add a Binance key with read permission only."
        case .noKeyRiskCopy: "Trading, withdrawal, transfer and key creation are never used."
        case .none: "NONE"
        case .noneOrNotLoaded: "NONE / NOT LOADED"
        case .on: "ON"
        case .off: "OFF"
        case .pinMainPanel: "Keep panel open"
        case .pinMainPanelOff: "Hide panel when clicking outside"
        case .pixelTheme: "PIXEL THEME"
        case .positions: "POSITIONS"
        case .priceDecimals: "PRICE DECIMALS"
        case .quit: "QUIT"
        case .readOnlyKey: "BINANCE READ-ONLY KEY"
        case .readOnlyKeyCopy: "Keep trading, withdrawal and transfer permissions disabled."
        case .saveAndTest: "SAVE & TEST"
        case .searchPlaceholder: "Search BTC, BTCUSDT, USDT"
        case .settings: "SETTINGS"
        case .spotEstimate: "SPOT EST"
        case .tickerRefresh: "Ticker refresh"
        case .lastError: "Last error"
        case .keyStatusMissing: "READ-ONLY KEY NEEDED"
        case .watchlist: "WATCHLIST"
        case .watchlistLimit: "WATCHLIST LIMIT"
        case .watchlistSparkInterval: "LIST LINE"
        case .watching: "WATCHING"
        case .positionBreakeven: "BE"
        case .positionEntry: "ENTRY"
        case .positionFundingFee: "FUNDING"
        case .positionLeverage: "LEV"
        case .positionLiquidation: "LIQ"
        case .positionMark: "MARK"
        case .positionNotional: "VALUE"
        case .positionRatio: "RATIO"
        case .positionRealizedPnL: "RPNL"
        case .positionSummaryHelp:
            "Realized PnL is the 90-day sum of realized PnL, funding fees, and commissions from Binance futures income history. Funding shows funding fees only."
        case .positionSize: "SIZE"
        case .positionUnrealizedPnL: "UPNL"
        case .summaryCoinM: "COIN-M"
        case .summaryPreviousDayUnavailable: "PREV DAY N/A"
        case .summarySpot: "Spot"
        case .summaryTotalHelp:
            "Total = spot stablecoin estimate plus USD-M wallet balance. Change shows the completed previous UTC day from yesterday 00:00 to today 00:00 when Binance daily account snapshots are available. COIN-M is not mixed into this USD estimate."
        case .summaryTotal: "Total"
        case .summaryUsdM: "USD-M"
        case .defaultRow: "DEFAULT"
        case .setDefault: "Set default"
        case .moveUp: "Move up"
        case .moveDown: "Move down"
        case .remove: "Remove"
        case .refresh: "Refresh"
        case .updated: "UPDATED"
        case .version: "VERSION"
        }
    }

    private static func chinese(_ key: CopyKey) -> String {
        switch key {
        case .account: "账户"
        case .accountDetailsCollapse: "折叠账户详情"
        case .accountDetailsExpand: "展开账户详情"
        case .accountStatusCheckFailed: "账户检查失败"
        case .accountStatusLive: "账户正常"
        case .accountStatusOffline: "离线"
        case .accountStatusPartial: "账户部分可用"
        case .add: "添加"
        case .apiKey: "API 密钥"
        case .apiKeys: "API 密钥"
        case .appearance: "外观"
        case .checkForUpdates: "检查更新"
        case .compactMenuBar: "紧凑菜单栏"
        case .current: "当前列表"
        case .defaultSymbol: "默认交易对"
        case .deleteKey: "删除密钥"
        case .diagnostics: "诊断"
        case .exportDiagnostics: "导出脱敏诊断"
        case .headerKlineInterval: "顶部 K 线"
        case .headerKlineWidth: "顶部宽度"
        case .hideBalances: "隐藏金额"
        case .hideLowValueAccount: "隐藏低资产账户"
        case .keyStored: "密钥已保存"
        case .language: "语言"
        case .noKeyCopy: "添加只读权限的 Binance API key。"
        case .noKeyRiskCopy: "不会使用交易、提现、划转或创建密钥权限。"
        case .none: "无"
        case .noneOrNotLoaded: "无 / 未加载"
        case .on: "开"
        case .off: "关"
        case .pinMainPanel: "固定主界面"
        case .pinMainPanelOff: "点击外部收回主界面"
        case .pixelTheme: "像素主题"
        case .positions: "持仓"
        case .priceDecimals: "价格小数位"
        case .quit: "退出"
        case .readOnlyKey: "BINANCE 只读密钥"
        case .readOnlyKeyCopy: "请保持交易、提现和划转权限关闭。"
        case .saveAndTest: "保存并测试"
        case .searchPlaceholder: "搜索 BTC、BTCUSDT、USDT"
        case .settings: "设置"
        case .spotEstimate: "现货估值"
        case .tickerRefresh: "行情刷新"
        case .lastError: "最近错误"
        case .keyStatusMissing: "需要只读密钥"
        case .watchlist: "关注列表"
        case .watchlistLimit: "关注列表上限"
        case .watchlistSparkInterval: "列表走势"
        case .watching: "关注中"
        case .positionBreakeven: "两平"
        case .positionEntry: "开仓"
        case .positionFundingFee: "资金费"
        case .positionLeverage: "杠杆"
        case .positionLiquidation: "强平"
        case .positionMark: "标记"
        case .positionNotional: "面值"
        case .positionRatio: "盈亏比"
        case .positionRealizedPnL: "已实现盈亏"
        case .positionSummaryHelp:
            "已实现盈亏为最近 90 天 Binance 合约收入历史中的平仓盈亏、资金费和手续费合计。资金费仅显示资金费。"
        case .positionSize: "仓位"
        case .positionUnrealizedPnL: "未实现盈亏"
        case .summaryCoinM: "币本位合约"
        case .summaryPreviousDayUnavailable: "昨日无基线"
        case .summarySpot: "现货"
        case .summaryTotalHelp:
            "总计为现货稳定币估值加 U 本位合约钱包余额。涨跌显示已完成的上一 UTC 日，即昨天 00:00 到今天 00:00；需要 Binance 每日账户快照可用。币本位不混入此 USD 估值。"
        case .summaryTotal: "总计"
        case .summaryUsdM: "U 本位合约"
        case .defaultRow: "默认"
        case .setDefault: "设为默认"
        case .moveUp: "上移"
        case .moveDown: "下移"
        case .remove: "删除"
        case .refresh: "刷新"
        case .updated: "更新"
        case .version: "版本"
        }
    }
}
