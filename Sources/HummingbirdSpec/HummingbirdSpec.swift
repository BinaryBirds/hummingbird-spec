import Foundation
import NIO
import XCTest
import Hummingbird
import HummingbirdFoundation
import HummingbirdXCT

private extension ByteBuffer {

    var data: Data? {
        guard let bytes = getBytes(at: 0, length: readableBytes) else {
            return nil
        }
        return .init(bytes)
    }
}

public protocol HBTestEncoder {
    func encode<T: Encodable>(_ value: T) throws -> Data
}

public protocol HBTestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from: Data) throws -> T
}

extension JSONEncoder: HBTestEncoder {}
extension JSONDecoder: HBTestDecoder {}

public extension HBApplication {

    /// creates a new spec with a given name
    func spec(_ name: String = #function) -> HummingbirdSpec {
        .init(name: name, app: self)
    }
}

/// a spec object to describe test cases
public final class HummingbirdSpec {

    private unowned var app: HBApplication

    private var name: String
    private var method: HTTPMethod = .GET
    private var uri: String = ""
    private var bearerToken: String? = nil
    private var headers: HTTPHeaders = [:]
    private var buffer: ByteBuffer? = nil
    private var expectations: [((HBXCTResponse) throws -> Void)] = []

    init(name: String, app: HBApplication) {
        self.name = name
        self.app = app
    }
}

public extension HummingbirdSpec {

    /// set the HTTPMethod and request path
    func on(_ method: HTTPMethod, _ uri: String) -> Self {
        self.method = method
        self.uri = uri
        return self
    }
    
    ///set the request method to GET and the uri to the given value
    func get(_ uri: String) -> Self { on(.GET, uri) }
    ///set the request method to POST and the uri to the given value
    func post(_ uri: String) -> Self { on(.POST, uri) }
    ///set the request method to PUT and the uri to the given value
    func put(_ uri: String) -> Self { on(.PUT, uri) }
    ///set the request method to PATCH and the uri to the given value
    func patch(_ uri: String) -> Self { on(.PATCH, uri) }
    ///set the request method to DELETE and the uri to the given value
    func delete(_ uri: String) -> Self { on(.DELETE, uri) }
}

public extension HummingbirdSpec {
    ///set a header value
    func header(_ name: String, _ value: String) -> Self {
        headers.replaceOrAdd(name: name, value: value)
        return self
    }
    
    ///set a bearer token Authorization header
    func bearerToken(_ token: String) -> Self {
        headers.replaceOrAdd(name: "Authorization", value:  "Bearer \(token)")
        return self
    }
    
    ///set a buffer as the request body
    func buffer(_ value: ByteBuffer) -> Self {
        buffer = value
        return self
    }

    ///set a content as the request body
    func body<T: Encodable>(
        _ body: T,
        encoder: HBTestEncoder? = nil
    ) throws -> Self {
        let encoder = encoder ?? {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return encoder
        }()
        let data = try encoder.encode(body)
        return buffer(.init(data: data))
    }
}

public extension HummingbirdSpec {
    ///expect a specific HTTPStatus
    func expect(
        file: StaticString = #file,
        line: UInt = #line,
        _ status: HTTPResponseStatus
    ) -> Self {
        expectations.append({ res in
            XCTAssertEqual(res.status, status, file: file, line: line)
        })
        return self
    }

    ///expect a specific header
    func expect(
        file: StaticString = #file,
        line: UInt = #line,
        _ header: String,
        _ values: [String]? = nil
    ) -> Self {
        expectations.append({ res in
            XCTAssertTrue(res.headers.contains(name: header))
            if let expectedValues = values {
                let headerValues = res.headers[header]
                XCTAssertEqual(headerValues, expectedValues, file: file, line: line)
            }
        })
        return self
    }

    ///expect a specific Content-Type header value
    func expect(
        file: StaticString = #file,
        line: UInt = #line,
        _ contentType: String
    ) -> Self {
        expectations.append({ res in
            let header = res.headers.first(name: "Content-Type")
            let contentType = try XCTUnwrap(header)
            XCTAssertEqual(contentType, contentType, file: file, line: line)
        })
        return self
    }

    ///expect a specific Content type, the decoded content will be available in the closure block
    func expect<T: Decodable>(
        file: StaticString = #file,
        line: UInt = #line,
        _ contentType: T.Type,
        decoder: HBTestDecoder? = nil,
        closure: @escaping ((T) -> Void) = { _ in }
    ) -> Self {
        expectations.append({ res in
            guard
                let body = res.body,
                let data = body.data
            else {
                return XCTFail("Missing response data.")
            }
            let decoder = decoder ?? {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return decoder
            }()
            let value = try decoder.decode(T.self, from: data)
            closure(value)
        })
        return self
    }

    /// expect a byte buffer as a response
    func expect(
        file: StaticString = #file,
        line: UInt = #line,
        closure: @escaping ((HBXCTResponse) throws -> Void)
    ) -> Self {
        expectations.append({ res in
            try closure(res)
        })
        return self
    }
}


public extension HummingbirdSpec {
    func json<T: Encodable, U: Decodable>(
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil,
        status: HTTPResponseStatus = .ok,
        _ data: T,
        _ type: U.Type,
        _ block: @escaping ((U) -> Void)
    ) throws -> Self {
        try self
            .header("Accept", "application/json")
            .header("Content-Type", "application/json")
            .body(data, encoder: encoder)
            .expect(status)
            .expect("application/json; charset=utf-8")
            .expect(U.self, decoder: decoder) { object in
                block(object)
            }
    }
    
    func json<T: Encodable>(
        encoder: JSONEncoder? = nil,
        status: HTTPResponseStatus = .ok,
        _ data: T,
        _ block: @escaping ((HBXCTResponse) -> Void)
    ) throws -> Self {
        try self
            .header("Accept", "application/json")
            .header("Content-Type", "application/json")
            .body(data, encoder: encoder)
            .expect(status)
            .expect { object in
                block(object)
            }
    }
    
    func json<U: Decodable>(
        decoder: JSONDecoder? = nil,
        status: HTTPResponseStatus = .ok,
        _ type: U.Type,
        _ block: @escaping ((U) -> Void)
    ) -> Self {
        self
            .header("Accept", "application/json")
            .expect(status)
            .expect("application/json; charset=utf-8")
            .expect(U.self, decoder: decoder) { object in
                block(object)
            }
    }
}

public extension HummingbirdSpec {
    func test(
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        var uri = uri
        if !uri.hasPrefix("/") {
            uri = "/" + uri
        }
        try app.XCTExecute(
            uri: uri,
            method: method,
            headers: headers,
            body: buffer,
            testCallback: { [unowned self] res in
                for expectation in self.expectations {
                    try expectation(res)
                }
            }
        )
    }
}
