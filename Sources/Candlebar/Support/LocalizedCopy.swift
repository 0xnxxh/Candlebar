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
    case keychainError
    case language
    case noKeyCopy
    case noKeyRiskCopy
    case none
    case noneOrNotLoaded
    case on
    case off
    case pinMainPanel
    case pinMainPanelOff
    case showSidebar
    case showAccountRing
    case sidebarAccount
    case openMainPanel
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
    case summaryColumns
    case summaryObservationColumns
    case summaryUnavailableColumns
    case summaryObservedShort
    case summaryTodayShort
    case summaryWalletHelp
    case summaryBaselineUnavailable
    case summaryTotalHelp
    case summaryTotal
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
    static func walletName(_ name: String, language: AppLanguage) -> String {
        guard language == .chinese else { return name }
        switch name {
        case "Spot": return "现货"
        case "Funding": return "资金"
        case "Earn": return "理财"
        case "USDⓈ-M Futures", "USD-M Futures": return "U 本位合约"
        case "COIN-M Futures": return "币本位合约"
        case "Cross Margin": return "全仓杠杆"
        case "Isolated Margin": return "逐仓杠杆"
        case "Options": return "期权"
        case "Trading Bots": return "交易机器人"
        case "Copy Trading": return "跟单交易"
        default: return name
        }
    }

    static func accountChangeColumns(_ basis: AccountChangeBasis?, language: AppLanguage) -> String {
        switch basis {
        case .utcMidnight: text(.summaryColumns, language: language)
        case .observation: text(.summaryObservationColumns, language: language)
        case nil: text(.summaryUnavailableColumns, language: language)
        }
    }

    static func accountBaselineText(_ date: Date?, basis: AccountChangeBasis?, language: AppLanguage) -> String {
        guard let date, let basis else { return text(.summaryBaselineUnavailable, language: language) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm:ss"
        let time = formatter.string(from: date)
        if basis == .observation {
            return language == .chinese
                ? "自 UTC \(time) 起观察，非完整今日变化；含充提。"
                : "Since \(time) UTC, not a full day; includes deposits/withdrawals."
        }
        return language == .chinese
            ? "日初近似基准：UTC \(time) 采样，含充提影响。"
            : "Approx. midnight baseline: \(time) UTC; includes deposits/withdrawals."
    }

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
        case "KEYCHAIN ERROR":
            text(.keychainError, language: language)
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
        case .keychainError: "KEYCHAIN ERROR"
        case .language: "LANGUAGE"
        case .noKeyCopy: "Add a Binance key with read permission only."
        case .noKeyRiskCopy: "Trading, withdrawal, transfer and key creation are never used."
        case .none: "NONE"
        case .noneOrNotLoaded: "NONE / NOT LOADED"
        case .on: "ON"
        case .off: "OFF"
        case .pinMainPanel: "Keep panel open"
        case .pinMainPanelOff: "Hide panel when clicking outside"
        case .showSidebar: "Show edge sidebar"
        case .showAccountRing: "Show account row in sidebar"
        case .sidebarAccount: "Account"
        case .openMainPanel: "Open full panel"
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
        case .summaryColumns: "BALANCE / TODAY (UTC) · USDT"
        case .summaryObservationColumns: "BALANCE / SINCE OBSERVATION · USDT"
        case .summaryUnavailableColumns: "BALANCE / CHANGE · USDT"
        case .summaryObservedShort: "OBS"
        case .summaryTodayShort: "TODAY"
        case .summaryWalletHelp: "Binance wallet value in USDT / change since the displayed baseline. Includes transfers; this is not unrealized PnL."
        case .summaryBaselineUnavailable: "Change unavailable: waiting for comparable wallet data."
        case .summaryTotalHelp:
            "Total sums all Binance wallet estimates in USDT. Change = current value minus the displayed baseline, including deposits and withdrawals. A sample within the first UTC minute enables approximate Today change; otherwise Since Observation starts at the first successful refresh of the day. The baseline survives restarts that day. Percentage = change / positive baseline × 100. Unavailable or incomparable data shows --."
        case .summaryTotal: "Total"
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
        case .keychainError: "钥匙串错误"
        case .language: "语言"
        case .noKeyCopy: "添加只读权限的 Binance API key。"
        case .noKeyRiskCopy: "不会使用交易、提现、划转或创建密钥权限。"
        case .none: "无"
        case .noneOrNotLoaded: "无 / 未加载"
        case .on: "开"
        case .off: "关"
        case .pinMainPanel: "固定主界面"
        case .pinMainPanelOff: "点击外部收回主界面"
        case .showSidebar: "显示边缘侧边栏"
        case .showAccountRing: "侧边栏显示账户行"
        case .sidebarAccount: "账户"
        case .openMainPanel: "打开完整面板"
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
        case .summaryColumns: "余额 / 今日变化 (UTC) · USDT"
        case .summaryObservationColumns: "余额 / 观察以来变化 · USDT"
        case .summaryUnavailableColumns: "余额 / 变化 · USDT"
        case .summaryObservedShort: "观察"
        case .summaryTodayShort: "今日"
        case .summaryWalletHelp: "Binance 钱包 USDT 估值 / 相对标明起始时间的资产变化，包含划转影响。此处不表示未实现盈亏。"
        case .summaryBaselineUnavailable: "变化暂不可用，等待可比较的钱包数据。"
        case .summaryTotalHelp:
            "总计汇总 Binance 返回的全部钱包 USDT 估值。变化 = 当前估值 − 标明时间的基准，包含充提影响。UTC 首分钟采样可用于近似今日变化；否则从当日首次成功刷新开始计算观察以来变化。同日重启保留基准。百分比 = 变化 / 正数基准 × 100。数据不可用或无法比较时显示 --。"
        case .summaryTotal: "总计"
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
