#!/bin/sh
set -e

# Xcode Cloud が各ワークフロー実行ごとに払い出す連番 CI_BUILD_NUMBER を
# CURRENT_PROJECT_VERSION（ビルド番号）へ反映する。
# TestFlight は同一バージョン内でビルド番号の重複を許さないため、
# ここで自動採番することで手動インクリメントを不要にする。
cd "$CI_PRIMARY_REPOSITORY_PATH"
agvtool new-version -all "$CI_BUILD_NUMBER"
echo "ビルド番号を $CI_BUILD_NUMBER に更新しました"
