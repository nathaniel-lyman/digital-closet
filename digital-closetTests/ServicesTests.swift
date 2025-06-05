import XCTest
@testable import digital_closet

class ServicesTests: XCTestCase {
    func testOpenAIService() {
        let service = OpenAIService()
        
        // Test with mock data
        let expectation = XCTestExpectation(description: "OpenAI API call")
        
        // Add your test cases here
        // Note: You'll want to mock the network calls for testing
    }
    
    func testRemBgService() {
        let service = RemBgService()
        
        // Test with mock data
        let expectation = XCTestExpectation(description: "RemBg API call")
        
        // Add your test cases here
        // Note: You'll want to mock the network calls for testing
    }
} 