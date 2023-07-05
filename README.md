# HummingbirdSpec

Unit testing for [Hummingbird](https://github.com/hummingbird-project/hummingbird) applications through declarative specifications.


## Install

Add the repository as a dependency:

```swift
.package(url: "https://github.com/binarybirds/hummingbird-spec", from: "1.0.0"),
```

Add Spec to the target dependencies:

```swift
.product(name: "HummingbirdSpec", package: "hummingbird-spec"),
```

Update the packages and you are ready.

## Usage example 

```swift
import HummingbirdSpec

final class HummingbirdSpecTests: XCTestCase {

    func testStatusCode() throws {
        let app = HBApplication(testing: .embedded)
        try app.XCTStart()
        defer { app.XCTStop() }

        try app
            .spec()
            .get("foo")
            .expect(.notFound)
            .test()
    }
    
    func testHeaderValues() throws {
        let app = HBApplication(testing: .embedded)
        app.router.get("hello") { _ in "hello" }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app
            .spec()
            .get("hello")
            .expect("Content-Length", ["5"])
            .expect("Content-Type", ["text/plain; charset=utf-8"])
            .test()
    }
    
    func testContentTypeHeader() throws {
        let app = HBApplication(testing: .embedded)
        app.router.get("hello") { _ in "hello" }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app
            .spec()
            .get("hello")
            .expect("text/plain; charset=utf-8")
            .test()
    }
    
    func testBodyValue() throws {
        let app = HBApplication(testing: .embedded)
        app.router.get("hello") { _ in "hello" }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app
            .spec()
            .get("hello")
            .expect(closure: { res in
                guard let body = res.body else {
                    return XCTFail()
                }
                let string = body.getString(at: 0, length: body.readableBytes)
                XCTAssertEqual(string, "hello")
            })
            .test()
    }
    
    func testJSON() throws {
        struct Test: Codable, HBResponseCodable {
            let foo: String
            let bar: Int
            let baz: Bool
        }

        let app = HBApplication(testing: .embedded)
        app.encoder = JSONEncoder()
        app.decoder = JSONDecoder()
        app.router.post("foo") { req in try req.decode(as: Test.self) }
        try app.XCTStart()
        defer { app.XCTStop() }

        let input = Test(foo: "foo", bar: 42, baz: true)
        try app
            .spec()
            .post("foo")
            .json(input, Test.self) { res in
                XCTAssertEqual(input.foo, res.foo)
                XCTAssertEqual(input.bar, res.bar)
                XCTAssertEqual(input.baz, res.baz)
            }
            .test()
    }
}
```
