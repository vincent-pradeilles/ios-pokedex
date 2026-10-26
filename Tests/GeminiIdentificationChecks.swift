import Foundation

// Standalone checks: compile with the three production source files listed in README.
@main
struct GeminiIdentificationChecks {
  static func main() async throws {
    let identity = #"{"recognized":true,"name":"Pikachu","number":25,"type":"Electric","summary":"An Electric-type Pokémon. It stores electricity in its cheeks."}"#
    func response(_ text: String, finish: String = "STOP") throws -> Data {
      try JSONSerialization.data(withJSONObject: ["candidates": [[
        "finishReason": finish,
        "content": ["parts": [["text": "Private reasoning", "thought": true], ["text": text]]]
      ]]])
    }
    let valid = try response(identity)
    let decoded = try GeminiIdentificationService.decode(valid)
    precondition(decoded.number == 25 && decoded.name == "Pikachu")
    let unknown = try response(#"{"recognized":false,"name":"Unknown","number":0,"type":"Unknown","summary":"Try a clearer photo."}"#)
    let unknownResult = try GeminiIdentificationService.decode(unknown)
    precondition(!unknownResult.recognized)
    for invalid in [Data("{}".utf8), Data("not json".utf8), try response(identity, finish: "SAFETY"), try response(identity, finish: "MAX_TOKENS"), try response("{}"), try response(identity.replacingOccurrences(of: "25", with: "0"))] {
      do {
        _ = try GeminiIdentificationService.decode(invalid)
        fatalError("Accepted invalid or incomplete identification")
      } catch is DexError { }
    }
    let request = try GeminiIdentificationService.request(image: Data([1, 2, 3]), key: "test-key")
    precondition(request.value(forHTTPHeaderField: "x-goog-api-key") == "test-key")
    precondition(request.url?.query == nil)
    let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    let contents = body["contents"] as! [[String: Any]]
    let parts = contents[0]["parts"] as! [[String: Any]]
    let image = parts[0]["inlineData"] as! [String: String]
    precondition(image["data"] == "AQID" && image["mimeType"] == "image/png")
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    let service = GeminiIdentificationService(session: session)
    for status in [200, 400, 401, 403, 429, 500] {
      StubProtocol.status = status
      StubProtocol.payload = valid
      do {
        let result = try await service.identify(Data([1]), key: "test-key")
        precondition(status == 200 && result.number == 25)
      } catch is DexError {
        precondition(status != 200)
      }
    }
    print("Gemini checks passed: identification, unknown, malformed/blocked/truncated output, request framing, and HTTP error handling.")
  }
}

private final class StubProtocol: URLProtocol {
  static var status = 200
  static var payload = Data()
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.payload)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() { }
}
