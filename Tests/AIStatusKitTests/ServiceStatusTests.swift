import Testing
@testable import AIStatusKit

@Test func `operational is healthy`() {
    #expect(ServiceStatus.operational.isHealthy == true)
}

@Test func `minor is not healthy`() {
    #expect(ServiceStatus.minor.isHealthy == false)
}

@Test func `major is not healthy`() {
    #expect(ServiceStatus.major.isHealthy == false)
}

@Test func `unknown is not healthy`() {
    #expect(ServiceStatus.unknown.isHealthy == false)
}

@Test func `operational severity is lowest`() {
    #expect(ServiceStatus.operational < ServiceStatus.minor)
    #expect(ServiceStatus.minor < ServiceStatus.major)
    #expect(ServiceStatus.major < ServiceStatus.unknown)
}

@Test func `worst returns highest severity`() {
    let statuses: [ServiceStatus] = [.operational, .minor, .operational]
    #expect(ServiceStatus.worst(statuses) == .minor)
}

@Test func `worst of empty returns unknown`() {
    #expect(ServiceStatus.worst([]) == .unknown)
}
