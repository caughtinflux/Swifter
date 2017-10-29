//
//  SwifterAuth.swift
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

public extension Swifter {

    public typealias TokenSuccessHandler = (_ accessToken: SwifterCredential.OAuthAccessToken?, _ response: URLResponse) -> Void

    public func authorizeWithCallbackURL(_ callbackURL: URL, success: TokenSuccessHandler?, failure: ((_ error: NSError) -> Void)? = nil, openQueryURL: ((_ url: URL) -> Void)?, closeQueryURL:(() -> Void)? = nil) {
        self.postOAuthRequestTokenWithCallbackURL(callbackURL, success: {
            token, response in

            var requestToken = token!

            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: CallbackNotification.notificationName), object: nil, queue: OperationQueue.main, using:{
                notification in

                NotificationCenter.default.removeObserver(self)
                closeQueryURL?()
                let url = notification.userInfo![CallbackNotification.optionsURLKey] as! URL

                let parameters = url.query!.parametersFromQueryString()
                requestToken.verifier = parameters["oauth_verifier"]

                self.postOAuthAccessTokenWithRequestToken(requestToken, success: {
                    accessToken, response in

                    self.client.credential = SwifterCredential(accessToken: accessToken!)
                    success?(accessToken!, response)

                    }, failure: failure)
                })

            let authorizeURL = URL(string: "/oauth/authorize", relativeTo: self.apiURL as URL)
            let queryURL = URL(string: authorizeURL!.absoluteString + "?oauth_token=\(token!.key)")
            
            if openQueryURL != nil {
                openQueryURL?(queryURL!)
            } else {
                #if os(iOS)
                    UIApplication.shared.openURL(queryURL!)
                #else
                    NSWorkspace.sharedWorkspace().openURL(queryURL!)
                #endif
            }
            
            }, failure: failure)
    }

    public class func handleOpenURL(_ url: URL) {
        let notification = Notification(name: Notification.Name(rawValue: CallbackNotification.notificationName), object: nil,
            userInfo: [CallbackNotification.optionsURLKey: url])
        NotificationCenter.default.post(notification)
    }

    public func authorizeAppOnlyWithSuccess(_ success: TokenSuccessHandler?, failure: FailureHandler?) {
        self.postOAuth2BearerTokenWithSuccess({
            json, response in

            if let tokenType = json["token_type"].string {
                if tokenType == "bearer" {
                    let accessToken = json["access_token"].string

                    let credentialToken = SwifterCredential.OAuthAccessToken(key: accessToken!, secret: "")

                    self.client.credential = SwifterCredential(accessToken: credentialToken)

                    success?(accessToken: credentialToken, response: response)
                }
                else {
                    let error = NSError(domain: "Swifter", code: SwifterError.appOnlyAuthenticationErrorCode, userInfo: [NSLocalizedDescriptionKey: "Cannot find bearer token in server response"]);
                    failure?(error: error)
                }
            }
            else if let errors = json["errors"].object {
                let error = NSError(domain: SwifterError.domain, code: errors["code"]!.integer!, userInfo: [NSLocalizedDescriptionKey: errors["message"]!.string!]);
                failure?(error: error)
            }
            else {
                let error = NSError(domain: SwifterError.domain, code: SwifterError.appOnlyAuthenticationErrorCode, userInfo: [NSLocalizedDescriptionKey: "Cannot find JSON dictionary in response"]);
                failure?(error: error)
            }

        }, failure: failure)
    }

    public func postOAuth2BearerTokenWithSuccess(_ success: JSONSuccessHandler?, failure: FailureHandler?) {
        let path = "/oauth2/token"

        var parameters = Dictionary<String, Any>()
        parameters["grant_type"] = "client_credentials"

        self.jsonRequestWithPath(path, baseURL: self.apiURL, method: "POST", parameters: parameters, success: success, failure: failure)
    }

    public func postOAuth2InvalidateBearerTokenWithSuccess(_ success: TokenSuccessHandler?, failure: FailureHandler?) {
        let path = "/oauth2/invalidate_token"

        self.jsonRequestWithPath(path, baseURL: self.apiURL, method: "POST", parameters: [:], success: {
            json, response in

            if let accessToken = json["access_token"].string {
                self.client.credential = nil

                let credentialToken = SwifterCredential.OAuthAccessToken(key: accessToken, secret: "")

                success?(accessToken: credentialToken, response: response)
            }
            else {
                success?(accessToken: nil, response: response)
            }

            }, failure: failure)
    }

    public func postOAuthRequestTokenWithCallbackURL(_ callbackURL: URL, success: @escaping TokenSuccessHandler, failure: FailureHandler?) {
        let path = "/oauth/request_token"

        var parameters =  Dictionary<String, Any>()

        parameters["oauth_callback"] = callbackURL.absoluteString

        self.client.post(path, baseURL: self.apiURL, parameters: parameters, uploadProgress: nil, downloadProgress: nil, success: {
            data, response in

            let responseString = NSString(data: data, encoding: String.Encoding.utf8)
            let accessToken = SwifterCredential.OAuthAccessToken(queryString: responseString as String!)
            success(accessToken: accessToken, response: response)

            }, failure: failure)
    }

    public func postOAuthAccessTokenWithRequestToken(_ requestToken: SwifterCredential.OAuthAccessToken, success: @escaping TokenSuccessHandler, failure: FailureHandler?) {
        if let verifier = requestToken.verifier {
            let path =  "/oauth/access_token"

            var parameters = Dictionary<String, Any>()
            parameters["oauth_token"] = requestToken.key
            parameters["oauth_verifier"] = verifier

            self.client.post(path, baseURL: self.apiURL, parameters: parameters, uploadProgress: nil, downloadProgress: nil, success: {
                data, response in

                let responseString = NSString(data: data, encoding: String.Encoding.utf8)
                let accessToken = SwifterCredential.OAuthAccessToken(queryString: responseString! as String)
                success(accessToken: accessToken, response: response)

                }, failure: failure)
        }
        else {
            let userInfo = [NSLocalizedFailureReasonErrorKey: "Bad OAuth response received from server"]
            let error = NSError(domain: SwifterError.domain, code: NSURLErrorBadServerResponse, userInfo: userInfo)
            failure?(error)
        }
    }

}
