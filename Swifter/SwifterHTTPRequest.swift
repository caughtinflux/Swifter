//
//  SwifterHTTPRequest.swift
//  Swifter
//
//  Copyright (c) 2014 Matt Donnelly.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

open class SwifterHTTPRequest: NSObject, NSURLConnectionDataDelegate {

    public typealias UploadProgressHandler = (_ bytesWritten: Int, _ totalBytesWritten: Int, _ totalBytesExpectedToWrite: Int) -> Void
    public typealias DownloadProgressHandler = (_ data: Data, _ totalBytesReceived: Int, _ totalBytesExpectedToReceive: Int, _ response: HTTPURLResponse) -> Void
    public typealias SuccessHandler = (_ data: Data, _ response: HTTPURLResponse) -> Void
    public typealias FailureHandler = (_ error: NSError) -> Void

    internal struct DataUpload {
        var data: Data
        var parameterName: String
        var mimeType: String?
        var fileName: String?
    }

    let URL: Foundation.URL
    let HTTPMethod: String

    var request: NSMutableURLRequest?
    var connection: NSURLConnection!

    var headers: Dictionary<String, String>
    var parameters: Dictionary<String, Any>
    var encodeParameters: Bool

    var uploadData: [DataUpload]

    var dataEncoding: String.Encoding

    var timeoutInterval: TimeInterval

    var HTTPShouldHandleCookies: Bool

    var response: HTTPURLResponse!
    var responseData: NSMutableData

    var uploadProgressHandler: UploadProgressHandler?
    var downloadProgressHandler: DownloadProgressHandler?
    var successHandler: SuccessHandler?
    var failureHandler: FailureHandler?

    public convenience init(URL: Foundation.URL) {
        self.init(URL: URL, method: "GET", parameters: [:])
    }

    public init(URL: Foundation.URL, method: String, parameters: Dictionary<String, Any>) {
        self.URL = URL
        self.HTTPMethod = method
        self.headers = [:]
        self.parameters = parameters
        self.encodeParameters = false
        self.uploadData = []
        self.dataEncoding = String.Encoding.utf8
        self.timeoutInterval = 60
        self.HTTPShouldHandleCookies = false
        self.responseData = NSMutableData()
    }

    public init(request: URLRequest) {
        self.request = request as? NSMutableURLRequest
        self.URL = request.url!
        self.HTTPMethod = request.httpMethod!
        self.headers = [:]
        self.parameters = [:]
        self.encodeParameters = true
        self.uploadData = []
        self.dataEncoding = String.Encoding.utf8
        self.timeoutInterval = 60
        self.HTTPShouldHandleCookies = false
        self.responseData = NSMutableData()
    }

    open func start() {
        if request == nil {
            self.request = NSMutableURLRequest(url: self.URL)
            self.request!.httpMethod = self.HTTPMethod
            self.request!.timeoutInterval = self.timeoutInterval
            self.request!.httpShouldHandleCookies = self.HTTPShouldHandleCookies

            for (key, value) in headers {
                self.request!.setValue(value, forHTTPHeaderField: key)
            }

            let charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(self.dataEncoding.rawValue))

            let nonOAuthParameters = self.parameters.filter { key, _ in !key.hasPrefix("oauth_") }

            if self.uploadData.count > 0 {
                let boundary = "----------SwIfTeRhTtPrEqUeStBoUnDaRy"

                let contentType = "multipart/form-data; boundary=\(boundary)"
                self.request!.setValue(contentType, forHTTPHeaderField:"Content-Type")

                let body = NSMutableData();

                for dataUpload: DataUpload in self.uploadData {
                    let multipartData = SwifterHTTPRequest.mulipartContentWithBounday(boundary, data: dataUpload.data, fileName: dataUpload.fileName, parameterName: dataUpload.parameterName, mimeType: dataUpload.mimeType)

                    body.append(multipartData)
                }

                for (key, value): (String, Any) in nonOAuthParameters {
                    body.append("\r\n--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
                    body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
                    body.append("\(value)".data(using: String.Encoding.utf8)!)
                }

                body.append("\r\n--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)

                self.request!.setValue("\(body.length)", forHTTPHeaderField: "Content-Length")
                self.request!.httpBody = body as Data
            }
            else if nonOAuthParameters.count > 0 {
                if self.HTTPMethod == "GET" || self.HTTPMethod == "HEAD" || self.HTTPMethod == "DELETE" {
                    let queryString = nonOAuthParameters.urlEncodedQueryStringWithEncoding(self.dataEncoding)
                    self.request!.url = self.URL.URLByAppendingQueryString(queryString)
                    self.request!.setValue("application/x-www-form-urlencoded; charset=\(charset)", forHTTPHeaderField: "Content-Type")
                }
                else {
                    var queryString = String()
                    if self.encodeParameters {
                        queryString = nonOAuthParameters.urlEncodedQueryStringWithEncoding(self.dataEncoding)
                        self.request!.setValue("application/x-www-form-urlencoded; charset=\(charset)", forHTTPHeaderField: "Content-Type")
                    }
                    else {
                        queryString = nonOAuthParameters.queryStringWithEncoding()
                    }

                    if let data = queryString.data(using: self.dataEncoding) {
                        self.request!.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
                        self.request!.httpBody = data
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.connection = NSURLConnection(request: self.request! as URLRequest, delegate: self)
            self.connection.start()

            #if os(iOS)
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            #endif
        }
    }

    open func stop() {
        self.connection.cancel()
    }

    open func addMultipartData(_ data: Data, parameterName: String, mimeType: String?, fileName: String?) -> Void {
        let dataUpload = DataUpload(data: data, parameterName: parameterName, mimeType: mimeType, fileName: fileName)
        self.uploadData.append(dataUpload)
    }

    fileprivate class func mulipartContentWithBounday(_ boundary: String, data: Data, fileName: String?, parameterName: String,  mimeType mimeTypeOrNil: String?) -> Data {
        let mimeType = mimeTypeOrNil ?? "application/octet-stream"

        let tempData = NSMutableData()

        tempData.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)

        let fileNameContentDisposition = fileName != nil ? "filename=\"\(fileName)\"" : ""
        let contentDisposition = "Content-Disposition: form-data; name=\"\(parameterName)\"; \(fileNameContentDisposition)\r\n"

        tempData.append(contentDisposition.data(using: String.Encoding.utf8)!)
        tempData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: String.Encoding.utf8)!)
        tempData.append(data)
        tempData.append("\r\n".data(using: String.Encoding.utf8)!)

        return tempData as Data
    }

    open func connection(_ connection: NSURLConnection, didReceive response: URLResponse) {
        self.response = response as? HTTPURLResponse

        self.responseData.length = 0
    }

    open func connection(_ connection: NSURLConnection, didSendBodyData bytesWritten: Int, totalBytesWritten: Int, totalBytesExpectedToWrite: Int) {
        self.uploadProgressHandler?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }

    open func connection(_ connection: NSURLConnection, didReceive data: Data) {
        self.responseData.append(data)

        let expectedContentLength = Int(self.response!.expectedContentLength)
        let totalBytesReceived = self.responseData.length

        if (data.count > 0) {
            self.downloadProgressHandler?(data, totalBytesReceived, expectedContentLength, self.response)
        }
    }

    open func connection(_ connection: NSURLConnection, didFailWithError error: Error) {
        #if os(iOS)
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        #endif

        self.failureHandler?(error as NSError)
    }

    open func connectionDidFinishLoading(_ connection: NSURLConnection) {
        #if os(iOS)
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        #endif

        if self.response.statusCode >= 400 {
            let responseString = NSString(data: self.responseData as Data, encoding: self.dataEncoding.rawValue)
            let responseErrorCode = SwifterHTTPRequest.responseErrorCode(self.responseData as Data) ?? 0
            let localizedDescription = SwifterHTTPRequest.descriptionForHTTPStatus(self.response.statusCode, responseString: responseString! as String)
            let userInfo = [
                NSLocalizedDescriptionKey: localizedDescription,
                "Response-Headers": self.response.allHeaderFields,
                "Response-ErrorCode": responseErrorCode] as [String : Any]
            let error = NSError(domain: NSURLErrorDomain, code: self.response.statusCode, userInfo: userInfo as [AnyHashable: Any])
            self.failureHandler?(error)
            return
        }

        self.successHandler?(self.responseData as Data, self.response)
    }

    class func stringWithData(_ data: Data, encodingName: String?) -> String {
        var encoding: UInt = String.Encoding.utf8.rawValue

        if encodingName != nil {
            let encodingNameString = encodingName! as NSString as CFString
            encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(encodingNameString))

            if encoding == UInt(kCFStringEncodingInvalidId) {
                encoding = String.Encoding.utf8.rawValue; // by default
            }
        }

        return NSString(data: data, encoding: encoding)! as String
    }

    class func responseErrorCode(_ data: Data) -> Int? {
        do {
            let json: AnyObject = try JSONSerialization.jsonObject(with: data, options: [])
            if let dictionary = json as? NSDictionary {
                if let errors = dictionary["errors"] as? [NSDictionary] {
                    if let code = errors.first?["code"] as? Int {
                        return code
                    }
                }
            }
        } catch _ {
        }
        return nil
    }

    class func descriptionForHTTPStatus(_ status: Int, responseString: String) -> String {
        var s = "HTTP Status \(status)"

        var description: String?
        // http://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml
        if status == 400 { description = "Bad Request" }
        if status == 401 { description = "Unauthorized" }
        if status == 402 { description = "Payment Required" }
        if status == 403 { description = "Forbidden" }
        if status == 404 { description = "Not Found" }
        if status == 405 { description = "Method Not Allowed" }
        if status == 406 { description = "Not Acceptable" }
        if status == 407 { description = "Proxy Authentication Required" }
        if status == 408 { description = "Request Timeout" }
        if status == 409 { description = "Conflict" }
        if status == 410 { description = "Gone" }
        if status == 411 { description = "Length Required" }
        if status == 412 { description = "Precondition Failed" }
        if status == 413 { description = "Payload Too Large" }
        if status == 414 { description = "URI Too Long" }
        if status == 415 { description = "Unsupported Media Type" }
        if status == 416 { description = "Requested Range Not Satisfiable" }
        if status == 417 { description = "Expectation Failed" }
        if status == 422 { description = "Unprocessable Entity" }
        if status == 423 { description = "Locked" }
        if status == 424 { description = "Failed Dependency" }
        if status == 425 { description = "Unassigned" }
        if status == 426 { description = "Upgrade Required" }
        if status == 427 { description = "Unassigned" }
        if status == 428 { description = "Precondition Required" }
        if status == 429 { description = "Too Many Requests" }
        if status == 430 { description = "Unassigned" }
        if status == 431 { description = "Request Header Fields Too Large" }
        if status == 432 { description = "Unassigned" }
        if status == 500 { description = "Internal Server Error" }
        if status == 501 { description = "Not Implemented" }
        if status == 502 { description = "Bad Gateway" }
        if status == 503 { description = "Service Unavailable" }
        if status == 504 { description = "Gateway Timeout" }
        if status == 505 { description = "HTTP Version Not Supported" }
        if status == 506 { description = "Variant Also Negotiates" }
        if status == 507 { description = "Insufficient Storage" }
        if status == 508 { description = "Loop Detected" }
        if status == 509 { description = "Unassigned" }
        if status == 510 { description = "Not Extended" }
        if status == 511 { description = "Network Authentication Required" }
        
        if description != nil {
            s = s + ": " + description! + ", Response: " + responseString
        }
        
        return s
    }

}
