//
//  Swifter.swift
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
import Accounts

open class Swifter {

    // MARK: - Types

    public typealias JSONSuccessHandler = (_ json: JSON, _ response: HTTPURLResponse) -> Void
    public typealias FailureHandler = (_ error: NSError) -> Void

    internal struct CallbackNotification {
        static let notificationName = "SwifterCallbackNotificationName"
        static let optionsURLKey = "SwifterCallbackNotificationOptionsURLKey"
    }

    internal struct SwifterError {
        static let domain = "SwifterErrorDomain"
        static let appOnlyAuthenticationErrorCode = 1
    }

    internal struct DataParameters {
        static let dataKey = "SwifterDataParameterKey"
        static let fileNameKey = "SwifterDataParameterFilename"
    }

    // MARK: - Properties

    internal(set) var apiURL: URL
    internal(set) var uploadURL: URL
    internal(set) var streamURL: URL
    internal(set) var userStreamURL: URL
    internal(set) var siteStreamURL: URL

    open var client: SwifterClientProtocol

    // MARK: - Initializers

    public convenience init(consumerKey: String, consumerSecret: String) {
        self.init(consumerKey: consumerKey, consumerSecret: consumerSecret, appOnly: false)
    }

    public init(consumerKey: String, consumerSecret: String, appOnly: Bool) {
        if appOnly {
            self.client = SwifterAppOnlyClient(consumerKey: consumerKey, consumerSecret: consumerSecret)
        }
        else {
            self.client = SwifterOAuthClient(consumerKey: consumerKey, consumerSecret: consumerSecret)
        }

        self.apiURL = URL(string: "https://api.twitter.com/1.1/")!
        self.uploadURL = URL(string: "https://upload.twitter.com/1.1/")!
        self.streamURL = URL(string: "https://stream.twitter.com/1.1/")!
        self.userStreamURL = URL(string: "https://userstream.twitter.com/1.1/")!
        self.siteStreamURL = URL(string: "https://sitestream.twitter.com/1.1/")!
    }

    public init(consumerKey: String, consumerSecret: String, oauthToken: String, oauthTokenSecret: String) {
        self.client = SwifterOAuthClient(consumerKey: consumerKey, consumerSecret: consumerSecret , accessToken: oauthToken, accessTokenSecret: oauthTokenSecret)

        self.apiURL = URL(string: "https://api.twitter.com/1.1/")!
        self.uploadURL = URL(string: "https://upload.twitter.com/1.1/")!
        self.streamURL = URL(string: "https://stream.twitter.com/1.1/")!
        self.userStreamURL = URL(string: "https://userstream.twitter.com/1.1/")!
        self.siteStreamURL = URL(string: "https://sitestream.twitter.com/1.1/")!
    }

    public init(account: ACAccount) {
        self.client = SwifterAccountsClient(account: account)

        self.apiURL = URL(string: "https://api.twitter.com/1.1/")!
        self.uploadURL = URL(string: "https://upload.twitter.com/1.1/")!
        self.streamURL = URL(string: "https://stream.twitter.com/1.1/")!
        self.userStreamURL = URL(string: "https://userstream.twitter.com/1.1/")!
        self.siteStreamURL = URL(string: "https://sitestream.twitter.com/1.1/")!
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - JSON Requests

    internal func jsonRequestWithPath(_ path: String, baseURL: URL, method: String, parameters: Dictionary<String, Any>, uploadProgress: SwifterHTTPRequest.UploadProgressHandler? = nil, downloadProgress: JSONSuccessHandler? = nil, success: JSONSuccessHandler? = nil, failure: SwifterHTTPRequest.FailureHandler? = nil) -> SwifterHTTPRequest {
        let jsonDownloadProgressHandler: SwifterHTTPRequest.DownloadProgressHandler = {
            data, _, _, response in

            if downloadProgress == nil {
                return
            }

            do {
                let jsonResult = try JSON.parseJSONData(data)
                downloadProgress?(json: jsonResult, response: response)
            } catch _ as NSError {
                
                let jsonString = NSString(data: data, encoding: String.Encoding.utf8)
                let jsonChunks = jsonString!.components(separatedBy: "\r\n") as [String]

                for chunk in jsonChunks {
                    if chunk.utf16.count == 0 {
                        continue
                    }

                    if let chunkData = chunk.data(using: String.Encoding.utf8) {
                        do {
                            let jsonResult = try JSON.parseJSONData(chunkData)
                            downloadProgress?(json: jsonResult, response: response)
                        } catch _ as NSError {
                            
                        } catch {
                            fatalError()
                        }
                    }
                }
            } catch {
                fatalError()
            }
        }

        let jsonSuccessHandler: SwifterHTTPRequest.SuccessHandler = {
            data, response in

            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                var error: NSError?
                do {
                    let jsonResult = try JSON.parseJSONData(data)
                    DispatchQueue.main.async {
                        if let success = success {
                            success(json: jsonResult, response: response)
                        }
                    }
                } catch let error1 as NSError {
                    error = error1
                    DispatchQueue.main.async {
                        if let failure = failure {
                            failure(error: error!)
                        }
                    }
                } catch {
                    fatalError()
                }
            }
        }

        if method == "GET" {
            return self.client.get(path, baseURL: baseURL, parameters: parameters, uploadProgress: uploadProgress, downloadProgress: jsonDownloadProgressHandler, success: jsonSuccessHandler, failure: failure)
        }
        else {
            return self.client.post(path, baseURL: baseURL, parameters: parameters, uploadProgress: uploadProgress, downloadProgress: jsonDownloadProgressHandler, success: jsonSuccessHandler, failure: failure)
        }
    }

    internal func getJSONWithPath(_ path: String, baseURL: URL, parameters: Dictionary<String, Any>, uploadProgress: SwifterHTTPRequest.UploadProgressHandler?, downloadProgress: JSONSuccessHandler?, success: JSONSuccessHandler?, failure: SwifterHTTPRequest.FailureHandler?) -> SwifterHTTPRequest {
        return self.jsonRequestWithPath(path, baseURL: baseURL, method: "GET", parameters: parameters, uploadProgress: uploadProgress, downloadProgress: downloadProgress, success: success, failure: failure)
    }

    internal func postJSONWithPath(_ path: String, baseURL: URL, parameters: Dictionary<String, Any>, uploadProgress: SwifterHTTPRequest.UploadProgressHandler?, downloadProgress: JSONSuccessHandler?, success: JSONSuccessHandler?, failure: SwifterHTTPRequest.FailureHandler?) -> SwifterHTTPRequest {
        return self.jsonRequestWithPath(path, baseURL: baseURL, method: "POST", parameters: parameters, uploadProgress: uploadProgress, downloadProgress: downloadProgress, success: success, failure: failure)
    }
    
}
