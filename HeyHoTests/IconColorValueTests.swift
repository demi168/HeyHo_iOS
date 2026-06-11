import Testing

/// IconColorValue（アイコンカラーの Firestore 文字列との相互変換）のテスト
struct IconColorValueTests {

    // MARK: - パース

    @Test func ソリッドhexをパースする() {
        #expect(IconColorValue(firestoreString: "FF6B6B") == .solid(hex: "FF6B6B"))
    }

    @Test func グラデーションプリセットをパースする() {
        #expect(IconColorValue(firestoreString: "gradient:sunset") == .gradient(presetId: "sunset"))
    }

    @Test func カスタムグラデーションをパースする() {
        #expect(
            IconColorValue(firestoreString: "gradient_custom:FF6B6B,34C759,0088FF")
            == .customGradient(hexStops: ["FF6B6B", "34C759", "0088FF"])
        )
    }

    // MARK: - nil / 空 → デフォルト

    @Test(arguments: [nil, ""])
    func nilと空文字はデフォルト黄色にフォールバックする(_ input: String?) {
        #expect(IconColorValue(firestoreString: input) == .solid(hex: "FFD700"))
    }

    // MARK: - シリアライズ

    @Test func ソリッドのシリアライズはhexそのまま() {
        #expect(IconColorValue.solid(hex: "0088FF").firestoreString == "0088FF")
    }

    @Test func プリセットのシリアライズはプレフィックス付き() {
        #expect(IconColorValue.gradient(presetId: "aurora").firestoreString == "gradient:aurora")
    }

    @Test func カスタムのシリアライズはカンマ区切り() {
        #expect(
            IconColorValue.customGradient(hexStops: ["A", "B", "C"]).firestoreString
            == "gradient_custom:A,B,C"
        )
    }

    // MARK: - ラウンドトリップ

    @Test(arguments: [
        "FF6B6B",
        "gradient:sunset",
        "gradient_custom:FF6B6B,34C759",
    ])
    func ラウンドトリップで元の文字列に戻る(_ original: String) {
        #expect(IconColorValue(firestoreString: original).firestoreString == original)
    }

    // MARK: - gradientPreset 解決

    @Test func ソリッドはgradientPresetを持たない() {
        #expect(IconColorValue.solid(hex: "FF6B6B").gradientPreset == nil)
    }

    @Test func 既知プリセットIDはGradientPresetに解決される() {
        let preset = IconColorValue.gradient(presetId: "sunset").gradientPreset
        #expect(preset?.id == "sunset")
        #expect(preset == GradientPreset.premiumPresets.first { $0.id == "sunset" })
    }

    @Test func 未知プリセットIDはnil() {
        #expect(IconColorValue.gradient(presetId: "nonexistent").gradientPreset == nil)
    }

    @Test func カスタムはhexStopsからGradientPresetを生成する() {
        let preset = IconColorValue.customGradient(hexStops: ["FF6B6B", "34C759"]).gradientPreset
        #expect(preset?.hexStops == ["FF6B6B", "34C759"])
    }
}
