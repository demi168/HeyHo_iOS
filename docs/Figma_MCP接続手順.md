# フリープランの Figma ファイルを MCP で接続する

## ポイント

- **フリープラン（スターター）**: **リモート MCP サーバー** のみ利用可能（デスクトップ MCP は有料プランの Dev/フルシートが必要）。
- リモートサーバーは **ブラウザで開いている Figma ファイル** と連携し、デスクトップアプリは不要。
- 制限: スターターまたは閲覧/コラボシートのみのユーザーは **1か月あたり最大 6 回のツールコール**。

---

## 手順（リモート MCP で Cursor に接続）

### 1. Cursor で Figma MCP を有効にする

**方法 A: 設定から手動で追加（確実）**

1. **Cursor メニュー** → **基本設定** → **Cursor Settings** を開く。
2. 左側で **「Tools & MCP」** または **「MCP」** を開く。
3. **「Add new MCP server」** や **「Edit in mcp.json」** などで MCP 設定を開く。
4. 次のいずれかで Figma を追加する。
   - 一覧に「Figma」があればそれを選び、**Connect** で認証する。
   - 一覧にない場合は、**mcp.json を直接編集**し、以下を追加する（既存の `mcpServers` がある場合はその中に `figma` を足す）。

```json
{
  "mcpServers": {
    "figma": {
      "url": "https://mcp.figma.com/mcp",
      "type": "http"
    }
  }
}
```

5. 保存後、Figma の行で **Connect** または **Start** を押し、ブラウザで Figma の OAuth 許可を行う。

**方法 B: コマンドパレットから MCP 設定を開く**

1. `Shift + Cmd + P`（Mac） / `Shift + Ctrl + P`（Win）でコマンドパレットを開く。
2. **「MCP: Open User Configuration」** または **「MCP: Open Workspace Folder MCP Configuration」** を実行する。
3. 開いた `mcp.json` に、上記の `figma` のブロックを追加・保存する。
4. 設定画面の MCP 一覧で Figma を **Connect** し、Figma で許可する。

**補足**: 「Figma Connect」という名前のコマンドは Cursor にはありません。接続は **Cursor メニュー > 基本設定 > Cursor Settings > MCP** の一覧で Figma の Connect ボタンか、**mcp.json に URL を書いたうえで Connect** で行います。

### 2. Figma 側でやること

- 接続後は **ブラウザで Figma のファイルを開いた状態** で利用する。
- コード生成やデザイン取得を依頼するときは、**フレームやレイヤーへのリンク** を Cursor のチャットに貼る。
  - 例: `https://figma.com/design/xxxxx/ファイル名?node-id=1-2`
- ノード ID が URL から読み取られ、MCP がそのノードのデザイン情報を返す。

### 3. Cursor での使い方

- チャットで「この Figma のリンクの画面を SwiftUI で実装して」のように指示する。
- リンクに含まれる `node-id` を使って、MCP がデザインコンテキストを取得する。

---

## 403 エラーが出るとき

**403 = 認証は通っているが、そのファイルへのアクセス権がない** という意味です。

### 確認すること

1. **同じ Figma アカウントか**
   - MCP の Connect でログインしたアカウントと、そのファイルを開けるアカウントが同じか確認する。
   - 別アカウントで作ったファイルのリンクを貼っていると 403 になりやすい。

2. **ファイルの共有設定**
   - ファイルのオーナーに、あなたのアカウントを **編集可** または **閲覧可** で招待してもらう。
   - または「リンクを知っている全員が閲覧可」など、リンク共有であなたのアカウントがアクセスできる状態にする。
   - 自分がオーナーのファイルなら、共有設定で「自分」に閲覧以上が付いているか確認する。

3. **MCP の再接続**
   - Cursor Settings > MCP で Figma の **Connect** をやり直し、ブラウザで再度 Figma の許可を行う。
   - 別アカウントで許可してしまっていないか確認する。

4. **URL の形式**
   - `https://www.figma.com/design/ファイルキー/ファイル名?node-id=0-1` のように、`node-id` が含まれたリンクを使う（Figma でフレームを右クリック → 「リンクをコピー」で取得できる）。

---

## 制限（フリープラン）

| 項目 | 内容 |
|------|------|
| 利用できる MCP | **リモートサーバーのみ**（デスクトップサーバーは不可） |
| ツールコール | **月 6 回まで**（スターター / 閲覧・コラボシートのみの場合） |
| 有料プラン | Dev またはフルシートでデスクトップ MCP 利用可。ツールコールは分単位のレート制限（REST API Tier 1 相当）。 |

---

## 参考リンク

- [Figma MCPサーバーのガイド（公式ヘルプ）](https://help.figma.com/hc/ja/articles/32132100833559)
- [Figma MCP リモートサーバー設置（開発者向け）](https://developers.figma.com/docs/figma-mcp-server/remote-server-installation/)
- [Figma のプランと機能](https://help.figma.com/hc/ja/articles/360040328273-Figma-plans-and-features)
