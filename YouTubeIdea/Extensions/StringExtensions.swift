import Foundation

extension String {
    var containsChineseCharacters: Bool {
        return self.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
    
    var dominantLanguage: String? {
        let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        tagger.string = self
        return tagger.dominantLanguage
    }
    
    var needsTranslation: Bool {
        guard let language = dominantLanguage else {
            return true
        }
        // 如果不是中文就需要翻译
        return !["zh-Hans", "zh-Hant", "zh"].contains(language)
    }
    
    var containsNonChineseCharacters: Bool {
        // 使用原始字符串避免转义问题
        let pattern = #"^[\u4e00-\u9fa5，。！？、；：""''（）【】《》]+$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return !predicate.evaluate(with: self)
    }
    
    func trim() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 