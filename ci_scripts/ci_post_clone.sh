#!/bin/sh
set -e

# Xcode Cloud ワークフローの環境変数 GOOGLE_SERVICE_INFO_PLIST_BASE64 から
# GoogleService-Info.plist を復元する。
# 設定方法: base64 GoogleService-Info.plist | pbcopy でコピーし、
# Xcode Cloud のワークフロー > 環境変数 に貼り付ける（シークレット扱い）。

if [ -z "$GOOGLE_SERVICE_INFO_PLIST_BASE64" ]; then
    echo "エラー: GOOGLE_SERVICE_INFO_PLIST_BASE64 が設定されていません"
    exit 1
fi

echo "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$CI_PRIMARY_REPOSITORY_PATH/GoogleService-Info.plist"
echo "GoogleService-Info.plist を復元しました"
