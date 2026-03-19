import SwiftUI
import Testing
@testable import AIStatusKit

@Test func `operational is healthy`() {
    #expect(AIStatus.operational.isHealthy == true)
}

@Test func `minor is not healthy`() {
    #expect(AIStatus.minor.isHealthy == false)
}

@Test func `major is not healthy`() {
    #expect(AIStatus.major.isHealthy == false)
}

@Test func `unknown is not healthy`() {
    #expect(AIStatus.unknown.isHealthy == false)
}

@Test func `operational severity is lowest`() {
    #expect(AIStatus.operational < AIStatus.minor)
    #expect(AIStatus.minor < AIStatus.major)
    #expect(AIStatus.major < AIStatus.unknown)
}

@Test func `worst returns highest severity`() {
    let statuses: [AIStatus] = [.operational, .minor, .operational]
    #expect(AIStatus.worst(statuses) == .minor)
}

@Test func `worst of empty returns unknown`() {
    #expect(AIStatus.worst([]) == .unknown)
}

@Test func `operational color is green`() {
    #expect(AIStatus.operational.color == .green)
}

@Test func `minor color is orange`() {
    #expect(AIStatus.minor.color == .orange)
}

@Test func `major color is red`() {
    #expect(AIStatus.major.color == .red)
}

@Test func `unknown color is gray`() {
    #expect(AIStatus.unknown.color == .gray)
}
