//
//  SwifterMessages.swift
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

public extension Swifter {

    /*
    GET	direct_messages

    Returns the 20 most recent direct messages sent to the authenticating user. Includes detailed information about the sender and recipient user. You can request up to 200 direct messages per call, up to a maximum of 800 incoming DMs.
    */
    public func getDirectMessagesSinceID(_ sinceID: String? = nil, maxID: String? = nil, count: Int? = nil, includeEntities: Bool? = nil, skipStatus: Bool? = nil, success: ((_ messages: [JSONValue]?) -> Void)? = nil, failure: FailureHandler? = nil) {
        let path = "direct_messages.json"

        var parameters = Dictionary<String, Any>()
        if sinceID != nil {
            parameters["since_id"] = sinceID!
        }
        if maxID != nil {
            parameters["max_id"] = maxID!
        }
        if count != nil {
            parameters["count"] = count!
        }
        if includeEntities != nil {
            parameters["include_entities"] = includeEntities!
        }
        if skipStatus != nil {
            parameters["skip_status"] = skipStatus!
        }

        self.getJSONWithPath(path, baseURL: self.apiURL, parameters: parameters, uploadProgress: nil, downloadProgress: nil, success: {
            json, response in

            success?(messages: json.array)
            return

            }, failure: failure)
    }

    /*
    GET    direct_messages/sent

    Returns the 20 most recent direct messages sent by the authenticating user. Includes detailed information about the sender and recipient user. You can request up to 200 direct messages per call, up to a maximum of 800 outgoing DMs.
    */
    public func getSentDirectMessagesSinceID(_ sinceID: String? = nil, maxID: String? = nil, count: Int? = nil, page: Int? = nil, includeEntities: Bool? = nil, success: ((_ messages: [JSONValue]?) -> Void)? = nil, failure: FailureHandler? = nil) {
        let path = "direct_messages/sent.json"

        var parameters = Dictionary<String, Any>()
        if sinceID != nil {
            parameters["since_id"] = sinceID!
        }
        if maxID != nil {
            parameters["max_id"] = maxID!
        }
        if count != nil {
            parameters["count"] = count!
        }
        if page != nil {
            parameters["page"] = page!
        }
        if includeEntities != nil {
            parameters["include_entities"] = includeEntities!
        }

        self.getJSONWithPath(path, baseURL: self.apiURL, parameters: parameters, uploadProgress: nil, downloadProgress: nil, success: {
            json, response in

            success?(messages: json.array)
            return

            }, failure: failure)
    }

    /*
    GET    direct_messages/show

    Returns a single direct message, specified by an id parameter. Like the /1.1/direct_messages.format request, this method will include the user objects of the sender and recipient.
    */
    public func getDirectMessagesShowWithID(_ id: String, success: ((_ messages: [JSONValue]?) -> Void)? = nil, failure: FailureHandler? = nil) {
        let path = "direct_messages/show.json"

        var parameters = Dictionary<String, Any>()
        parameters["id"] = id

        self.getJSONWithPath(path, baseURL: self.apiURL, parameters: parameters, uploadProgress: nil, downloadProgress: nil, success: {
            json, response in

            success?(messages: json.array)
            return

            }, failure: failure)
    }

    /*
    POST	direct_messages/destroy

    Destroys the direct message specified in the required ID parameter. The authenticating user must be the recipient of the specified direct message.
    */
    public func postDestroyDirectMessageWithID(_ id: String, includeEntities: Bool? = nil, success: ((_ messages: Dictionary<String, JSONValue>?) -> Void)? = nil, failure: FailureHandler? = nil) {
        let path = "direct_messages/destroy.json"

        var parameters = Dictionary<String, Any>()
        parameters["id"] = id

        if includeEntities != nil {
            parameters["include_entities"] = includeEntities!
        }

        self.postJSONWithPath(path, baseURL: self.apiURL, parameters: parameters, uploadProgress: nil, downloadProgress: nil, success: {
            json, response in

            success?(messages: json.object)
            return

            }, failure: failure)
    }

    /*
    POST	direct_messages/new

    Sends a new direct message to the specified user from the authenticating user. Requires both the user and text parameters and must be a POST. Returns the sent message in the requested format if successful.
    */
    public func postDirectMessageToUser(_ userID: String, text: String, success: ((_ statuses: Dictionary<String, JSONValue>?) -> Void)? = nil, failure: FailureHandler? = nil) {
        let path = "direct_messages/new.json"

        var parameters = Dictionary<String, Any>()
        parameters["user_id"] = userID
        parameters["text"] = text

        self.postJSONWithPath(path, baseURL: self.apiURL, parameters: parameters, uploadProgress: nil, downloadProgress: nil, success: {
            json, response in
            
            success?(statuses: json.object)
            return
            
            }, failure: failure)
    }
    
}
