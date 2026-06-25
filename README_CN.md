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
- 通过只读 Binance API key 查看账户概览、余额、持仓、未实现盈亏、杠杆和强平参考。
- 设置保存在本机，API key 存入 macOS Keychain。
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

## Binance API Key

Candlebar 只需要读取权限。

创建 Binance API key 时，请保持交易、提现、划转和创建密钥等权限关闭。API key 会保存在 macOS Keychain 中，只用于从你的 Mac 向 Binance 请求账户快照。

不填写 API key 也可以使用 Candlebar，价格查看功能不依赖账户权限。

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
