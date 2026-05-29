# SKILLS — HeyHo iOS 開発チートシート

定型パターンは Claude Code のプロジェクトスキルとして `.claude/skills/<name>/SKILL.md` に登録している。
Claude は `description` を見て関連するスキルを自動で参照する。このファイルは人間向けの索引。

### まず読む（地図）

| スキル | 内容 | こんな時に読む |
|--------|------|--------------|
| [codebase-map](./.claude/skills/codebase-map/SKILL.md) | ファイル→責務の地図・画面遷移・共通部品・データモデル | 「あの処理どこ？」を探す前にまず |

### 実装パターン

| スキル | 内容 | こんな時に読む |
|--------|------|--------------|
| [design-tokens](./.claude/skills/design-tokens/SKILL.md) | `AppColor` / `AppSpacing` / `AppTypography` / `AppSize` の一覧と使い方 | UI を作る・色や余白を指定する時 |
| [swiftui-patterns](./.claude/skills/swiftui-patterns/SKILL.md) | DataView/BodyView 分離・EnvironmentObject・エラー処理・ナビゲーション | View を新規追加・改修する時 |
| [firebase](./.claude/skills/firebase/SKILL.md) | Firestore 操作・データモデル・IconColorValue・プレミアムゲート・Cloud Functions | データ取得/保存・課金・関数を触る時 |
| [localization](./.claude/skills/localization/SKILL.md) | String Catalog（xcstrings）+ `String(localized:)` 統一ルール | 文言を追加・改修する時 |

### セキュリティ

| スキル | 内容 | こんな時に読む |
|--------|------|--------------|
| [security-rules](./.claude/skills/security-rules/SKILL.md) | `firestore.rules` の構造・`SEC-xxx`規約・検証関数・デプロイ前チェック | コレクション/フィールドを触る時 |
| [auth-and-secrets](./.claude/skills/auth-and-secrets/SKILL.md) | Apple Sign In・アカウント削除・秘密情報の非コミット・特権フラグ検証 | 認証・課金・機密情報を扱う時 |

### レビュー

| スキル | 内容 | こんな時に読む |
|--------|------|--------------|
| [review-checklist](./.claude/skills/review-checklist/SKILL.md) | レビュー観点・`/simplify` の制約 | 実装後のセルフレビュー時 |

> 共通原則: **メンテナンス楽ちん設計をキープ。** 値のハードコードを避け、デザイントークンや定数から参照する。同じ値が 2 箇所以上に出たら一元化を検討。「1箇所変えれば全部変わる」を目指す。
