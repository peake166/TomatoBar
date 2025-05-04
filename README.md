<p align="center">
<img src="https://raw.githubusercontent.com/ivoronin/TomatoBar/main/TomatoBar/Assets.xcassets/AppIcon.appiconset/icon_128x128%402x.png" width="128" height="128"/>
<p>
 
<h1 align="center">TomatoBar</h1>
<p align="center">
<img src="https://img.shields.io/github/actions/workflow/status/ivoronin/TomatoBar/main.yml?branch=main"/> <img src="https://img.shields.io/github/downloads/ivoronin/TomatoBar/total"/> <img src="https://img.shields.io/github/v/release/ivoronin/TomatoBar?display_name=tag"/> <img src="https://img.shields.io/homebrew/cask/v/tomatobar"/>
</p>

<img
  src="https://github.com/ivoronin/TomatoBar/raw/main/screenshot.png?raw=true"
  alt="Screenshot"
  width="50%"
  align="right"
/>

## 概述
你听说过番茄工作法吗？这是一种很棒的技术，可以帮助你在学习或工作期间跟踪时间并保持专注。在<a href="https://en.wikipedia.org/wiki/Pomodoro_Technique">维基百科</a>上阅读更多相关信息。

TomatoBar是macOS菜单栏上最简洁的番茄钟计时器。它包含所有基本功能 - 可配置的工作和休息间隔、可选声音提示、谨慎的可操作通知以及全局快捷键。

TomatoBar完全沙盒化，不需要任何特殊权限。

在<a href="https://github.com/ivoronin/TomatoBar/releases/latest/">这里</a>下载最新版本，或使用Homebrew安装：
```
$ brew install --cask tomatobar
```

如果应用无法启动，请使用`--no-quarantine`标志安装：
```
$ brew install --cask --no-quarantine tomatobar
```

## 与其他工具集成
### 事件日志
TomatoBar以JSON格式将状态转换记录到`~/Library/Containers/com.github.ivoronin.TomatoBar/Data/Library/Caches/TomatoBar.log`。使用这些数据分析你的生产力并丰富其他数据源。
### 启动和停止计时器
TomatoBar可以通过`tomatobar://`URL进行控制。要从命令行启动或停止计时器，使用`open tomatobar://startStop`。

## 旧版本
Touch Bar集成和较早的macOS版本（早于Big Sur）在TomatoBar 3.0之前的版本中受支持。

## 许可证
 - 计时器声音从buddhabeats获得授权
