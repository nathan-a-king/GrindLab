//
//  OpenAIService.swift
//  Coffee Grind Analyzer
//
//  Created by Assistant on 8/31/25.
//

import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    
    private let apiEndpoint = "https://api.openai.com/v1/chat/completions"
    private var apiKey: String? {
        UserDefaults.standard.string(forKey: "openai_api_key")
    }
    
    private init() {}
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
        
        struct Message: Codable {
            let role: String
            let content: String
        }
    }
    
    struct ChatResponse: Codable {
        let choices: [Choice]
        
        struct Choice: Codable {
            let message: Message
            
            struct Message: Codable {
                let content: String
            }
        }
    }
    
    func generateBrewingRecommendations(
        analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) async throws -> String {
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }
        
        let systemPrompt = """
        You are an expert coffee consultant specializing in grind analysis and brewing optimization. 
        Your role is to provide personalized, actionable brewing recommendations based on scientific grind particle analysis and taste feedback.
        
        Format your response using markdown with:
        - Use **bold** for important parameters like temperatures, times, or ratios
        - Use bullet points (-) to list specific actions
        - Use headers (##) to organize different types of recommendations
        - Keep responses concise but helpful, focusing on 2-3 key recommendations
        - Use a friendly, conversational tone that's easy to understand
        
        Example format:
        ## Grind Adjustments
        - **Grind finer** by 2-3 clicks
        - This will increase extraction
        
        ## Brewing Parameters  
        - Water temperature: **205°F**
        - Brew time: **4 minutes**
        """
        
        let userPrompt = createUserPrompt(from: analysisResults, and: flavorProfile)
        
        let request = ChatRequest(
            model: "gpt-4-turbo-preview",
            messages: [
                ChatRequest.Message(role: "system", content: systemPrompt),
                ChatRequest.Message(role: "user", content: userPrompt)
            ],
            temperature: 0.7,
            max_tokens: 500
        )
        
        guard let url = URL(string: apiEndpoint) else {
            throw OpenAIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }
        
        return content
    }
    
    private func createUserPrompt(from results: CoffeeAnalysisResults, and profile: FlavorProfile) -> String {
        let isInRange = results.grindType.targetSizeMicrons.contains(results.averageSize)
        
        return """
        I need brewing recommendations based on my coffee grind analysis and taste feedback.
        
        GRIND ANALYSIS DATA:
        - Brew Method: \(results.grindType.displayName)
        - Average Particle Size: \(String(format: "%.0f", results.averageSize))μm (target: \(results.grindType.targetSizeRange))
        - Size Match: \(isInRange ? "In Range" : "Out of Range")
        - Uniformity Score: \(String(format: "%.1f", results.uniformityScore))%
        - Fines (<400μm): \(String(format: "%.1f", results.finesPercentage))%
        - Boulders (>1400μm): \(String(format: "%.1f", results.bouldersPercentage))%
        - Particle Count: \(results.particleCount)
        - Standard Deviation: \(String(format: "%.1f", results.standardDeviation))μm
        
        TASTE FEEDBACK:
        - Overall Taste: \(profile.overallTaste.rawValue)
        - Intensity: \(profile.intensity.rawValue)
        - Specific Issues: \(profile.flavorIssues.map { $0.rawValue }.joined(separator: ", "))
        \(profile.notes.map { "- Additional Notes: \($0)" } ?? "")
        
        Based on this data, what specific adjustments should I make to improve my coffee?
        Consider grind size adjustments, brewing parameters (time, temperature, ratio), and any technique improvements.
        Reply only in plain text. Be concise and to the point.
        """
    }
    
    enum OpenAIError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case invalidResponse
        case noContent
        case httpError(Int)
        case apiError(String)
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenAI API key not configured. Please add your API key in Settings."
            case .invalidURL:
                return "Invalid API endpoint URL"
            case .invalidResponse:
                return "Invalid response from OpenAI API"
            case .noContent:
                return "No content in API response"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .apiError(let message):
                return "API error: \(message)"
            }
        }
    }
}
