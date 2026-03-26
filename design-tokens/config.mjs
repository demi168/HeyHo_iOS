import StyleDictionary from 'style-dictionary';

// dimension値をそのままCGFloatに変換するカスタムtransform
StyleDictionary.registerTransform({
  name: 'size/swift/pointToCGFloat',
  type: 'value',
  transitive: true,
  filter: (token) => token.$type === 'dimension',
  transform: (token) => {
    const raw = String(token.$value ?? token.value);
    // 既にCGFloat変換済みならスキップ
    if (raw.startsWith('CGFloat(')) return raw;
    const val = parseFloat(raw);
    return `CGFloat(${val.toFixed(2)})`;
  },
});

// hex → SwiftUI Color に変換するカスタムtransform
StyleDictionary.registerTransform({
  name: 'color/swiftui-color',
  type: 'value',
  transitive: true,
  filter: (token) => token.$type === 'color',
  transform: (token) => {
    const raw = String(token.$value ?? token.value);
    // 既にColor変換済みならスキップ
    if (raw.startsWith('Color(')) return raw;
    const hex = raw.replace('#', '');
    const r = parseInt(hex.substring(0, 2), 16) / 255;
    const g = parseInt(hex.substring(2, 4), 16) / 255;
    const b = parseInt(hex.substring(4, 6), 16) / 255;
    return `Color(red: ${r.toFixed(3)}, green: ${g.toFixed(3)}, blue: ${b.toFixed(3)})`;
  },
});

// ios-swiftベースのtransformGroupから remToCGFloat を除外し、カスタムtransformに差し替え
StyleDictionary.registerTransformGroup({
  name: 'ios-swift-pt',
  transforms: [
    'attribute/cti',
    'name/camel',
    'color/swiftui-color',
    'content/swift/literal',
    'asset/swift/literal',
    'size/swift/pointToCGFloat',
  ],
});

const sd = new StyleDictionary({
  source: ['tokens/**/*.json'],
  platforms: {
    'ios-swift': {
      transformGroup: 'ios-swift-pt',
      buildPath: 'build/ios-swift/',
      files: [
        // --- Primitive ---
        {
          destination: 'PrimitiveColor.swift',
          format: 'ios-swift/enum.swift',
          options: { className: 'PrimitiveColor', accessControl: 'internal' },
          filter: (token) => token.attributes?.category === 'color' && token.attributes?.type === 'primitive',
        },
        {
          destination: 'PrimitiveSpacing.swift',
          format: 'ios-swift/enum.swift',
          options: { className: 'PrimitiveSpacing', accessControl: 'internal' },
          filter: (token) => token.attributes?.category === 'spacing' && token.attributes?.type === 'primitive',
        },
        {
          destination: 'PrimitiveTypography.swift',
          format: 'ios-swift/enum.swift',
          options: { className: 'PrimitiveTypography', accessControl: 'internal' },
          filter: (token) => token.attributes?.category === 'typography' && token.attributes?.type === 'primitive',
        },
        {
          destination: 'PrimitiveRadius.swift',
          format: 'ios-swift/enum.swift',
          options: { className: 'PrimitiveRadius', accessControl: 'internal' },
          filter: (token) => token.attributes?.category === 'radius' && token.attributes?.type === 'primitive',
        },
        {
          destination: 'PrimitiveSize.swift',
          format: 'ios-swift/enum.swift',
          options: { className: 'PrimitiveSize', accessControl: 'internal' },
          filter: (token) => token.attributes?.category === 'size' && token.attributes?.type === 'primitive',
        },
        // --- Semantic ---
        {
          destination: 'SemanticColor.swift',
          format: 'ios-swift/enum.swift',
          options: { className: 'SemanticColor', accessControl: 'internal' },
          filter: (token) => token.attributes?.category === 'color' && token.attributes?.type === 'semantic',
        },
        {
          destination: 'SemanticSpacing.swift',
          format: 'ios-swift/enum.swift',
          options: { className: 'SemanticSpacing', accessControl: 'internal' },
          filter: (token) => token.attributes?.category === 'spacing' && token.attributes?.type === 'semantic',
        },
        {
          destination: 'SemanticTypography.swift',
          format: 'ios-swift/enum.swift',
          options: { className: 'SemanticTypography', accessControl: 'internal' },
          filter: (token) => token.attributes?.category === 'typography' && token.attributes?.type === 'semantic',
        },
        {
          destination: 'SemanticSize.swift',
          format: 'ios-swift/enum.swift',
          options: { className: 'SemanticSize', accessControl: 'internal' },
          filter: (token) => token.attributes?.category === 'size' && token.attributes?.type === 'semantic',
        },
      ],
    },
  },
});

await sd.buildAllPlatforms();
