//
//  LoginAction.swift
//  TaskGroupDesign
//
//  Created by Marin Todorov on 2/17/22.
//

import Foundation
import CasePaths
import Combine

let logs = CurrentValueSubject<String, Never>("")
var attemptCount = 0

extension String: Error { }

struct APIClient {
	/// A logged user.
	struct User { let name = "James" }

	/// Predefined trace events.
	enum Event: String {
		case connected, login, completedLoginSequence
	}

	/// Logs the current user and returns the user object.
	@Sendable func logUserIn() async throws -> LoginTaskResult {

		sleep(1)
		attemptCount += 1
		guard attemptCount > 2 else {
			return .user(nil)
		}
		return .user(User())
	}

	/// Sends an event to trace in the logs.
	@MainActor
	@Sendable func traceEvent(_ event: Event) async throws -> LoginTaskResult {
		logs.send(event.rawValue)
		return .none
	}

	/// Connects to the remote API and returns an initialized client.
	@Sendable static func connect() async throws -> APIClient { return APIClient() }
}

enum LoginTaskResult {
	case none
	case client(APIClient)
	case user(APIClient.User?)
}

/// Gets the device location.
@Sendable func fetchLocation() async throws -> LoginTaskResult { return .none }

/// Asks the user for permissions.
@Sendable func askForUserPermissions() async throws -> LoginTaskResult { return .none }

extension ThrowingTaskGroup {

	func first<Value>(_ path: CasePath<ChildTaskResult, Value>) async throws -> Value? {
		for try await result in self {
			if let match = path.extract(from: result) {
				return match
			}
		}
		return nil
	}
}

/// Logs the user in.
func loginAction() async throws -> APIClient.User {
	try await withThrowingTaskGroup(of: LoginTaskResult.self, returning: APIClient.User.self) { group in

		group.addTask(operation: fetchLocation)
		group.addTask(operation: askForUserPermissions)
		group.addTask(priority: .high) {
			return .client(try await APIClient.connect())
		}

		guard let client = try await group.first(/LoginTaskResult.client) else {
			throw "Could not connect to API"
		}

		let tracer = client.traceEvent
		group.addTask {
			try await tracer(.connected)
		}

		var user: APIClient.User!

		while user == nil {
			group.addTask(operation: client.logUserIn)
			group.addTask {
				try await tracer(.login)
			}

			user = try await group.first(/LoginTaskResult.user)
		}

		try await group.waitForAll()

		_ = try await tracer(.completedLoginSequence)

		return user
	}
}
