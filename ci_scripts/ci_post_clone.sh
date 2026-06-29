#!/bin/sh
set -e

# Xcode Cloud の環境変数から GoogleService-Info.plist を生成する。
# ワークフローの Environment Variables に以下を登録してください（すべてシークレット）:
#   FIREBASE_API_KEY
#   FIREBASE_GOOGLE_APP_ID
#   FIREBASE_GCM_SENDER_ID
#   FIREBASE_PROJECT_ID
#   FIREBASE_STORAGE_BUCKET
#   FIREBASE_BUNDLE_ID

REQUIRED_VARS="FIREBASE_API_KEY FIREBASE_GOOGLE_APP_ID FIREBASE_GCM_SENDER_ID FIREBASE_PROJECT_ID FIREBASE_STORAGE_BUCKET FIREBASE_BUNDLE_ID"
for VAR in $REQUIRED_VARS; do
    if [ -z "$(eval echo \$$VAR)" ]; then
        echo "エラー: 環境変数 $VAR が設定されていません"
        exit 1
    fi
done

cat > "$CI_PRIMARY_REPOSITORY_PATH/GoogleService-Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>${FIREBASE_API_KEY}</string>
	<key>GOOGLE_APP_ID</key>
	<string>${FIREBASE_GOOGLE_APP_ID}</string>
	<key>GCM_SENDER_ID</key>
	<string>${FIREBASE_GCM_SENDER_ID}</string>
	<key>PROJECT_ID</key>
	<string>${FIREBASE_PROJECT_ID}</string>
	<key>STORAGE_BUCKET</key>
	<string>${FIREBASE_STORAGE_BUCKET}</string>
	<key>BUNDLE_ID</key>
	<string>${FIREBASE_BUNDLE_ID}</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<false/>
	<key>IS_APPINVITE_ENABLED</key>
	<true/>
	<key>IS_GCM_ENABLED</key>
	<true/>
	<key>IS_SIGNIN_ENABLED</key>
	<true/>
</dict>
</plist>
PLIST

echo "GoogleService-Info.plist を生成しました"
