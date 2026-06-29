#!/bin/sh
set -e

# App Store Connect のワークフロー環境変数 GOOGLE_SERVICE_INFO_PLIST_BASE64 から
# GoogleService-Info.plist を復元する。
# 値の生成: base64 -i GoogleService-Info.plist | tr -d '\n' | pbcopy

if [ -z "$GOOGLE_SERVICE_INFO_PLIST_BASE64" ]; then
    echo "エラー: GOOGLE_SERVICE_INFO_PLIST_BASE64 が設定されていません"
    exit 1
fi

echo "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$CI_PRIMARY_REPOSITORY_PATH/GoogleService-Info.plist"
echo "GoogleService-Info.plist を復元しました"
