//
//  NetworkService.swift
//  Combine
//
//  Created by Zaman, Haris on 11.07.2020.
//  Copyright © 2020 Haris Zaman. All rights reserved.
//

import Foundation
import Combine

func decode<T: Decodable>(_ data: Data) -> AnyPublisher<T, APIError> {
  
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    
    return Just(data)
        .decode(type: T.self, decoder: decoder)
        .mapError { error in
            if let error = error as? DecodingError {
                var errorToReport = error.localizedDescription
                switch error {
                case .dataCorrupted(let context):
                    let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                    errorToReport = "\(context.debugDescription) - (\(details))"
                case .keyNotFound(let key, let context):
                    let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                    errorToReport = "\(context.debugDescription) (key: \(key), \(details))"
                case .typeMismatch(let type, let context), .valueNotFound(let type, let context):
                    let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                    errorToReport = "\(context.debugDescription) (type: \(type), \(details))"
                @unknown default:
                    break
                }
                return APIError.parserError(reason: errorToReport)
            }  else {
                return APIError.apiError(reason: error.localizedDescription)
            }
    }
    .eraseToAnyPublisher()
}

func networkRequestGeneric<T: Decodable>(with request: URLRequest, apiName: String) -> AnyPublisher<T, APIError> {
    
    return URLSession.shared.dataTaskPublisher(for: request)
        .mapError { error in
            .network(reason: error.localizedDescription)
    }
    .flatMap { data, response -> AnyPublisher<T, APIError> in
        decodeJsonFromAPI(data, response: response, apiName: apiName)
    }
    .eraseToAnyPublisher()
}

func decodeJsonFromAPI<T: Decodable>(_ data: Data, response: URLResponse, apiName: String) -> AnyPublisher<T, APIError> {
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    
    if let httpResponse = response as? HTTPURLResponse,
        (200...299).contains(httpResponse.statusCode){
        
        return Just(data)
            .decode(type: T.self, decoder: decoder)
            .mapError { error in
                if let error = error as? DecodingError {
                    var reason = error.localizedDescription
                    return constructDecodingError(error, &reason)
                }  else {
                    return APIError.parserError(reason: error.localizedDescription)
                }
        }
        .eraseToAnyPublisher()
    } else {
        let error = APIError.apiError(reason: "\(apiName) API call failed with invalid http response")
        return Fail(error: error).eraseToAnyPublisher()
            .eraseToAnyPublisher()
    }
}

fileprivate func constructDecodingError(_ error: DecodingError, _ reason: inout String) -> APIError {
    switch error {
    case .dataCorrupted(let context):
        let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
        reason = "\(context.debugDescription) - (\(details))"
    case .keyNotFound(let key, let context):
        let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
        reason = "\(context.debugDescription) (key: \(key), \(details))"
    case .typeMismatch(let type, let context), .valueNotFound(let type, let context):
        let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
        reason = "\(context.debugDescription) (type: \(type), \(details))"
    @unknown default:
        break
    }
    return APIError.parserError(reason: reason)
}


