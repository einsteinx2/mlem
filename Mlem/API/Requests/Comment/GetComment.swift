//
//  GetComment.swift
//  Mlem
//
//  Created by Jonathan de Jong on 13.06.2023.
//

import Foundation

// lemmy_api_common::comment::
struct GetCommentRequest: APIGetRequest {

    typealias Response = CommentResponse

    let instanceURL: URL
    let path = "comment"
    let queryItems: [URLQueryItem]

    init(
        session: APISession,
        id: Int
    ) {
        self.instanceURL = session.URL
        self.queryItems = [
            .init(name: "id", value: id.description),
            .init(name: "auth", value: session.token)
        ]
    }
}
