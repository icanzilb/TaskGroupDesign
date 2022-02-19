//
//  ContentView.swift
//  TaskGroupDesign
//
//  Created by Marin Todorov on 2/17/22.
//

import SwiftUI

@main
struct TaskGroupDesignApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}

struct ContentView: View {
	@State var text = "Tracer:"
	@State var user: APIClient.User? = nil

	var body: some View {
		VStack {
			Text("User Login")
				.padding()

			Button {
				Task {
					user = try await loginAction()
				}
			} label: {
				Text(user == nil ? "Log in" : "Logged in: \(user!.name)")
			}
			.buttonStyle(.borderedProminent)

			TextEditor(text: $text)
				.padding()
				.font(.body.monospaced())
				.onReceive(logs) { newValue in
					text += "\n\(newValue)"
				}
		}
	}
}
