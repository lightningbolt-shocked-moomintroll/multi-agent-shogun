# multi-agent-shogun

<div align="center">

**Multi-Agent Orchestration System for Claude Code**

*One command. Eight AI agents working in parallel.*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet)](https://claude.ai)
[![tmux](https://img.shields.io/badge/tmux-required-green)](https://github.com/tmux/tmux)

[English](README_en.md) | [Japanese / 日本語](README_ja.md)

</div>

---

## What is this?

a fork from multi-agent-shogun.

- ペイン分割からウィンドウに変更
- コスト圧縮のため足軽をHaiku化、Memory MCPの活用
- 連続対話が一番重いのでコンテキストを外部化する
- 家老にログを出力させる、足軽にも1行出力をさせ、必要なら詳細を読ませられるようにする
- 文字サイズの設定によりAAの幅が広くて入らないので削る
- WSL2上の Debianでも動くように指示をカスタマイズ(apt-get)
- パーミッションを厳密に（全自動にしないで確認を入れる）
- dashboard軽量化
- セッションの保存と選択して復元を可能にする（別の作業をはさむと情報が消えるので）


## 🙏 Credits

Based on [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa.
Based on [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) by yohei-w.

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

