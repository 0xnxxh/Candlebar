# Candlebar

中文 | [English](README.md)

<p align="center">
  <img src="Resources/Logo/candlebar-logo.svg" width="128" alt="Candlebar logo">
</p>

Candlebar 是一个 macOS 菜单栏应用，用来快速查看加密货币价格，并在需要时查看只读的 Binance 账户概览。

它适合放在菜单栏长期运行：默认交易对会直接显示在菜单栏里，点开后可以查看关注列表、现货估值、合约持仓、未实现盈亏、杠杆和强平参考等信息。

## 功能

- 在菜单栏实时显示默认交易对价格。
- 支持 Binance 现货、U 本位合约、币本位合约关注列表。
- 可选的屏幕边缘侧边栏：每个关注交易对一行，直接显示实时价格、当日涨跌幅和迷你走势线，另有账户行；拖动即可停靠到任意显示器的左侧或右侧。
- 通过只读 Binance API key 查看账户概览、余额、持仓、未实现盈亏、杠杆和强平参考。
- 设置保存在本机，API key 存入 macOS Keychain。
- 可选的开机自启，由 macOS 登录项管理。
- 支持英文和中文界面。
- 通过 Sparkle 从 GitHub Releases 检查和安装更新。

## 系统要求

- macOS 14 或更高版本。
- 能访问 Binance 行情和账户 API。
- 如需账户数据，需要一个只读权限的 Binance API key。

## 安装

1. 从 GitHub Releases 下载最新的 `Candlebar-v<version>.dmg`。
2. 打开 `.dmg`，把 `Candlebar.app` 拖入 `Applications`。
3. 因为当前应用还没有 Apple Developer ID 签名，安装后请先执行一次：

```bash
xattr -cr /Applications/Candlebar.app
```

4. 从 `Applications` 打开 `Candlebar.app`。

macOS 仍可能在首次启动时提示未签名应用。如果出现提示，请到系统设置的隐私与安全性中允许打开 Candlebar。

## 开机自启

将 Candlebar 安装到 `Applications` 后，打开**设置 > 通用**，开启**开机自启**。下次登录 Mac 时，Candlebar 会自动在菜单栏启动。关闭开关会移除登录项，当前运行的应用仍会保持打开。

默认关闭。开关读取 macOS 的实际登录项状态，也会反映你在系统设置中的修改。如果显示“等待批准”，点击**打开登录项设置**并允许 Candlebar，再返回应用刷新状态。注册失败时，设置页会显示具体错误。

## Binance API Key

Candlebar 只需要读取权限。

创建 Binance API key 时，请保持交易、提现、划转和创建密钥等权限关闭。API key 会保存在 macOS Keychain 中，只用于从你的 Mac 向 Binance 请求账户快照。

不填写 API key 也可以使用 Candlebar，价格查看功能不依赖账户权限。

## 账户总计与每日变化

总计通过 Binance 只读接口 [`GET /sapi/v1/asset/wallet/balance`](https://developers.binance.com/docs/wallet/asset/query-user-wallet-balance)，指定 `quoteAsset=USDT`，汇总接口返回的全部钱包，包括现货（全部币种）、资金、理财、U 本位、币本位、杠杆及其他钱包。分项使用同一接口的估值，不再另加合约未实现盈亏。这是 **USDT 估值**，不是美元；估值时刻、Binance API 覆盖范围可能造成与网页的差异。

汇总行显示余额及相对标明起始时间的资产变化，包含充值、提现和划转影响；内部钱包划转在总计中相互抵消。百分比 = 变化 ÷ 正数基准 × 100，基准为零或负数时不显示百分比。持仓的未实现盈亏仍在持仓详情中单独显示。

若当日首次完整钱包响应在 **UTC 00:00:00–00:00:59**（新加坡/中国时间 08:00 首分钟）内收到，则作为零点近似基准，标题显示**今日变化（UTC）**。其他时间首次启动，从首次成功刷新开始记录，标题明确显示**观察以来变化**及起始时间。首次采样变化为零，后续刷新均减去同一起点，不会每次重置；观察以来变化不代表完整今日变化。

当日基准保存在本机，同日重启继续使用，并以 API key 的哈希隔离账户，不把凭证写入基准数据。进入新的 UTC 日后按上述规则建立新基准。钱包覆盖范围变化或数据不可用时显示 `--`。Binance 的 SPOT/MARGIN/FUTURES 日快照不能重建完整钱包总览，不用于替代完整基准。

钱包请求失败或金额格式异常时，不以局部账户余额冒充总计。隐藏小额钱包只影响列表，不影响总额。

## 更新

在应用菜单中点击 `Check for Updates...`，Candlebar 会通过 Sparkle 检查 GitHub Releases 上的新版本。

首次安装仍然使用 `.dmg` 文件。后续更新由 Sparkle 校验 release 签名并引导完成。

## 隐私

Candlebar 不运行后端服务，也不会把你的 Binance API key 发送到除 Binance API 以外的地方。

诊断信息会先脱敏再显示。分享诊断内容前，仍建议你自行检查一遍。

## 从源码构建

```bash
script/build_and_run.sh --build-only
```

生成本地 release `.dmg`：

```bash
script/release_dmg.sh
```

生成 Sparkle appcast：

```bash
script/generate_appcast.sh
```

运行完整本地发布检查：

```bash
script/release_check.sh
```

生成的 `.dmg` 和 `appcast.xml` 会写入 `dist/`。发布时需要把这两个文件上传到对应版本的 GitHub Release。
