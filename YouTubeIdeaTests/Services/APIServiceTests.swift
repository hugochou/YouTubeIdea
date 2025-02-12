import XCTest
@testable import YouTubeIdea

final class APIServiceTests: XCTestCase {
    var apiService: APIService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        apiService = APIService.shared
        // 使用测试配置的 API Key
        SettingsManager.shared.deepseekKey = TestConfig.deepseekKey
    }
    
    override func tearDownWithError() throws {
        apiService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 翻译测试
    
    func testTranslateText() async throws {
        // 准备测试数据
        let testCases = [
            "Hello, this is a test message.",
            "The quick brown fox jumps over the lazy dog.",
            "Machine learning is transforming the world."
        ]
        
        for englishText in testCases {
            do {
                let translatedText = try await apiService.translateText(englishText)
                
                // 验证翻译结果
                XCTAssertFalse(translatedText.isEmpty, "翻译结果不应为空")
                XCTAssertNotEqual(translatedText, englishText, "翻译结果不应与原文相同")
                
                // 打印结果以便检查
                print("原文：\(englishText)")
                print("译文：\(translatedText)\n")
                
            } catch {
                XCTFail("翻译失败：\(error.localizedDescription)")
            }
        }
    }
    
    func testTranslateEmptyText() async {
        do {
            _ = try await apiService.translateText("")
            XCTFail("空文本应该抛出错误")
        } catch {
            XCTAssertTrue(error is APIError, "应该抛出 APIError")
        }
    }
    
    func testTranslateInvalidKey() async {
        // 保存原始 key
        let originalKey = SettingsManager.shared.deepseekKey
        
        // 设置无效的 key
        SettingsManager.shared.deepseekKey = "invalid-key"
        
        do {
            _ = try await apiService.translateText("Test message")
            XCTFail("无效的 API Key 应该抛出错误")
        } catch {
            XCTAssertTrue(error is APIError, "应该抛出 APIError")
        }
        
        // 恢复原始 key
        SettingsManager.shared.deepseekKey = originalKey
    }
    
    // MARK: - 文本优化测试
    
    func testRefineText() async throws {
        let testText = "这是一段需要优化的文本。它包含一些基本信息，但可以变得更好。"
        
        do {
            let refinedText = try await apiService.refineText(testText)
            
            // 验证优化结果
            XCTAssertFalse(refinedText.isEmpty, "优化结果不应为空")
            XCTAssertNotEqual(refinedText, testText, "优化结果不应与原文完全相同")
            XCTAssert(refinedText.contains("标签："), "优化结果应包含标签")
            
            // 打印结果
            print("原文：\(testText)")
            print("优化后：\(refinedText)")
            
        } catch {
            XCTFail("文本优化失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - 性能测试
    
    func testTranslationPerformance() {
        let testText = "This is a performance test for the translation API."
        
        measure {
            let expectation = XCTestExpectation(description: "Translation completed")
            
            Task {
                do {
                    let start = Date()
                    _ = try await apiService.translateText(testText)
                    let duration = Date().timeIntervalSince(start)
                    
                    // 验证响应时间
                    XCTAssertLessThan(duration, TestConfig.timeout, "翻译响应时间过长")
                    expectation.fulfill()
                } catch {
                    XCTFail("性能测试失败：\(error.localizedDescription)")
                }
            }
            
            wait(for: [expectation], timeout: TestConfig.timeout)
        }
    }
    
    // MARK: - 并发测试
    
    func testConcurrentTranslations() async throws {
        let testTexts = [
            "First test message",
            "Second test message",
            "Third test message"
        ]
        
        // 并发执行多个翻译请求
        async let translations = withThrowingTaskGroup(of: String.self) { group in
            for text in testTexts {
                group.addTask {
                    try await self.apiService.translateText(text)
                }
            }
            
            var results: [String] = []
            for try await translation in group {
                results.append(translation)
            }
            return results
        }
        
        // 验证结果
        let results = try await translations
        XCTAssertEqual(results.count, testTexts.count, "应该完成所有翻译请求")
        
        // 打印结果
        for (original, translated) in zip(testTexts, results) {
            print("原文：\(original)")
            print("译文：\(translated)\n")
        }
    }
    
    // MARK: - 错误处理测试
    
    func testNetworkError() async {
        // 模拟网络错误
        let invalidURL = "invalid-url"
        do {
            _ = try await apiService.translateText(invalidURL)
            XCTFail("无效的 URL 应该抛出错误")
        } catch {
            XCTAssertTrue(error is APIError, "应该抛出 APIError")
        }
    }
    
    func testRetryMechanism() async throws {
        // 测试重试机制
        let testText = "Test retry mechanism"
        var attempts = 0
        
        do {
            let result = try await apiService.translateText(testText)
            XCTAssertFalse(result.isEmpty)
            print("重试机制测试成功，翻译结果：\(result)")
        } catch {
            XCTFail("重试机制测试失败：\(error.localizedDescription)")
        }
    }
} 
