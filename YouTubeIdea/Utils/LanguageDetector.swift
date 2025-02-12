struct LanguageDetector {
    static func isChineseText(_ text: String) -> Bool {
        let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        tagger.string = text
        let language = tagger.dominantLanguage
        return language == "zh-Hans" || language == "zh-Hant" || language == "zh"
    }
} 