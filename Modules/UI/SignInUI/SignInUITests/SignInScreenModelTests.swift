//
//  SignInScreenModelTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import Inject
import SessionManager
import SessionManagerTestHelpers
import SignInUIImpl
import Testing

@MainActor
struct SignInScreenModelTests {
    private func makeModel(session: MockSessionManager) -> SignInScreenModel {
        InjectionManager.register(SessionManager.self) { session }
        InjectionManager.resetCurrentContainer()
        return SignInScreenModel()
    }

    @Test func signInGoesThroughTheSessionManager() async throws {
        let session = MockSessionManager()
        let model = makeModel(session: session)

        try await model.viewModel.signInTask.run(#require(Username("alice")))

        #expect(try session.signInCalls == [#require(Username("alice"))])
    }

    @Test func invalidTextCanNotBeSubmitted() async throws {
        let model = makeModel(session: MockSessionManager())

        try await model.viewModel.textTask.run("_reserved")
        await settle { model.viewModel.showsValidationHint.value }

        #expect(model.viewModel.text.value == "_reserved")
        #expect(model.viewModel.submittableUsername.value == nil)
        #expect(model.viewModel.showsValidationHint.value)
    }

    @Test func validTextCanBeSubmitted() async throws {
        let model = makeModel(session: MockSessionManager())

        try await model.viewModel.textTask.run("Alice")
        await settle { model.viewModel.submittableUsername.value != nil }

        #expect(model.viewModel.submittableUsername.value?.rawValue == "alice")
        #expect(!model.viewModel.showsValidationHint.value)
    }

    @Test func emptyTextShowsNoHint() async throws {
        let model = makeModel(session: MockSessionManager())

        try await model.viewModel.textTask.run("   ")
        await settle { model.viewModel.text.value == "   " }

        #expect(!model.viewModel.showsValidationHint.value)
    }

    /// View model properties mirror the screen model's on a later main-actor
    /// turn, so wait (briefly) for the one under test to catch up.
    private func settle(_ condition: @MainActor () -> Bool) async {
        for _ in 0 ..< 50 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
