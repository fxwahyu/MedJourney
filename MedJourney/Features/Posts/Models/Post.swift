//
//  Post.swift
//  MedJourney
//
//  Feature: Posts — Network DTO model
//

import Foundation

/// Data transfer object for JSONPlaceholder `/posts` API.
///
/// This demonstrates a clean network model (DTO) separate from
/// any persistence model. In a real app, you'd map DTOs to domain models.
struct Post: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}
