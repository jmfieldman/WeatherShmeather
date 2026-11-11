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

    @Test func invalidTextCanNotBeSubmitted() {
        let model = makeModel(session: MockSessionManager())

        model.viewModel.text = "_reserved"

        #expect(model.viewModel.submittableUsername == nil)
        #expect(model.viewModel.showsValidationHint)
    }

    @Test func emptyTextShowsNoHint() {
        let model = makeModel(session: MockSessionManager())

        model.viewModel.text = "   "

        #expect(!model.viewModel.showsValidationHint)
    }
}
