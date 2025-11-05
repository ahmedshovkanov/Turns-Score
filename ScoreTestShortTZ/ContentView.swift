//
//  ContentView.swift
//  ScoreTestShortTZ
//
//  Created by John Sorren on 01.11.2025.
//

import SwiftUI
import Combine
import AudioToolbox
import UIKit

private enum NavigationTab: Hashable {
	case sessions
	case settings
	case statistics
}

struct ContentView: View {
	@EnvironmentObject private var appState: AppState
	@State private var selectedTab: NavigationTab = .sessions

	var body: some View {
		TabView(selection: $selectedTab) {
			SessionListView()
				.tabItem {
					Label("Sessions", systemImage: "list.bullet.rectangle")
				}
				.tag(NavigationTab.sessions)

			SettingsView()
				.tabItem {
					Label("Settings", systemImage: "gearshape")
				}
				.tag(NavigationTab.settings)

			StatisticsView()
				.tabItem {
					Label("Statistics", systemImage: "chart.bar")
				}
				.tag(NavigationTab.statistics)
		}
	}
}

private struct SessionListView: View {
	@EnvironmentObject private var appState: AppState
	@State private var showingNewSession = false

	var body: some View {
		NavigationStack {
			Group {
				if appState.sessions.isEmpty {
					EmptyStateView {
						showingNewSession = true
					}
				} else {
					List {
						ForEach(appState.sessions) { session in
							NavigationLink {
								SessionDetailView(session: session)
							} label: {
								SessionRow(session: session)
							}
						}
						.onDelete { appState.deleteSessions(at: $0) }
					}
					.listStyle(.insetGrouped)
				}
			}
			.navigationTitle("Game Sessions")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						showingNewSession = true
					} label: {
						Label("New Session", systemImage: "plus")
					}
				}
			}
			.sheet(isPresented: $showingNewSession) {
				NewSessionView(presets: appState.presets) { session in
					appState.addSession(session)
				}
			}
		}
	}
}

private struct EmptyStateView: View {
	var onCreate: () -> Void

	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: "list.clipboard")
				.font(.system(size: 48))
				.foregroundStyle(.secondary)
			Text("No sessions yet")
				.font(.title3)
			Text("Create your first session to start tracking scores.")
				.font(.body)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
			Button {
				onCreate()
			} label: {
				Label("Create Session", systemImage: "plus")
			}
			.buttonStyle(.borderedProminent)
		}
		.padding()
	}
}

private struct SessionRow: View {
	@ObservedObject var session: GameSession

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(spacing: 12) {
				Image(systemName: session.preset.systemImageName)
					.font(.title3)
					.foregroundStyle(Color.accentColor)
				Text(session.preset.name)
					.font(.headline)
				Spacer()
				Text(session.roundStatusBadgeText)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Text(session.playerSummary)
				.font(.subheadline)
				.foregroundStyle(.primary)
				.lineLimit(1)
			Text(session.leaderSummary)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.padding(.vertical, 6)
	}
}

private struct SessionDetailView: View {
	@EnvironmentObject private var appState: AppState
	@ObservedObject var session: GameSession
	@State private var showingResetConfirmation = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				SessionInfoCard(session: session)
				RoundControl(session: session)
				VStack(alignment: .leading, spacing: 16) {
					ForEach(session.players) { player in
						PlayerScoreCard(session: session, player: player)
					}
					if session.canAddPlayer {
						Button {
							session.addPlayer()
							appState.registerPlayerAdded()
						} label: {
							Label("Add Player", systemImage: "person.badge.plus")
						}
						.buttonStyle(.bordered)
					}
				}
				SessionSummary(session: session)
			}
			.padding(.horizontal)
			.padding(.bottom, 24)
		}
		.navigationTitle(session.preset.name)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					showingResetConfirmation = true
				} label: {
					Label("Reset scores", systemImage: "arrow.counterclockwise")
				}
				.disabled(session.isPristine)
			}
		}
		.confirmationDialog("Reset all scores for \(session.preset.name)?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
			Button("Reset Scores", role: .destructive) {
				session.resetScores()
			}
			Button("Cancel", role: .cancel) { }
		}
	}
}

private struct SessionInfoCard: View {
	@ObservedObject var session: GameSession

	var body: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 8) {
				Text(session.preset.description)
					.font(.body)
				if !session.preset.notes.isEmpty {
					Divider()
					Text(session.preset.notes)
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
		} label: {
			Label("Preset", systemImage: "bookmark")
		}
	}
}

private struct RoundControl: View {
	@ObservedObject var session: GameSession

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Label(session.roundStatusHeadline, systemImage: "clock")
					.font(.headline)
				Spacer()
				Text(session.roundStatusDetail)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			ProgressView(value: session.progress)
				.tint(Color.accentColor)
			HStack {
				Button {
					session.previousRound()
				} label: {
					Label("Previous", systemImage: "chevron.left")
				}
				.disabled(!session.canRewindRound)
				Spacer()
				Button {
					session.nextRound()
				} label: {
					Label("Next", systemImage: "chevron.right")
				}
				.disabled(!session.canAdvanceRound)
			}
		}
		.padding()
		.background(
			RoundedRectangle(cornerRadius: 16)
				.fill(Color.gray.opacity(0.08))
		)
	}
}

private struct PlayerScoreCard: View {
	@EnvironmentObject private var appState: AppState
	@ObservedObject var session: GameSession
	@ObservedObject var player: PlayerScore
	@State private var showingRemovalConfirmation = false

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .center, spacing: 12) {
				TextField("Player name", text: Binding(
					get: { player.name },
					set: { player.name = $0 }
				))
				.textFieldStyle(.roundedBorder)
				Spacer()
				Text(session.formattedScore(player.totalScore))
					.font(.title3)
					.monospacedDigit()
				if session.canRemovePlayer {
					Menu {
						Button("Remove Player", role: .destructive) {
							showingRemovalConfirmation = true
						}
					} label: {
						Image(systemName: "ellipsis.circle")
							.foregroundStyle(.secondary)
					}
				}
			}
			RoundBreakdown(session: session, player: player)
			ScoreControls(session: session, player: player)
			if !session.preset.scoringHint.isEmpty {
				Text(session.preset.scoringHint)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.padding()
		.background(
			RoundedRectangle(cornerRadius: 16)
				.strokeBorder(Color.gray.opacity(0.15))
				.background(
					RoundedRectangle(cornerRadius: 16)
						.fill(Color.gray.opacity(0.05))
				)
		)
		.confirmationDialog("Remove \(player.name)?", isPresented: $showingRemovalConfirmation, titleVisibility: .visible) {
			Button("Remove Player", role: .destructive) {
				session.removePlayer(player)
			}
			Button("Cancel", role: .cancel) { }
		}
	}
}

private struct RoundBreakdown: View {
	@ObservedObject var session: GameSession
	@ObservedObject var player: PlayerScore

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 12) {
				ForEach(Array(player.roundScores.enumerated()), id: \.offset) { index, value in
					VStack(alignment: .leading, spacing: 6) {
						Text(session.roundTitle(for: index))
							.font(.caption)
							.foregroundStyle(index == session.currentRoundIndex ? .primary : .secondary)
						Text(session.formattedScore(value))
							.font(.headline)
							.monospacedDigit()
						if let target = session.preset.targetPerRound, value >= target {
							Text("Target reached")
								.font(.caption2)
								.foregroundStyle(.green)
						}
					}
					.padding(10)
					.background(
						RoundedRectangle(cornerRadius: 12)
							.fill(index == session.currentRoundIndex ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.05))
					)
				}
			}
		}
	}
}

private struct ScoreControls: View {
	@EnvironmentObject private var appState: AppState
	@ObservedObject var session: GameSession
	@ObservedObject var player: PlayerScore

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(session.preset.scoringOptions) { option in
					Button {
						session.apply(option, to: player)
						appState.registerScoreChange(delta: option.delta)
					} label: {
						Label(option.label, systemImage: option.iconSystemName)
							.font(.subheadline)
							.padding(.vertical, 6)
							.padding(.horizontal, 12)
							.background(option.color.opacity(0.15))
							.foregroundStyle(option.color)
							.clipShape(Capsule())
					}
				}
			}
		}
	}
}

private struct SessionSummary: View {
	@ObservedObject var session: GameSession

	var body: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 10) {
				ForEach(session.standings) { player in
					HStack {
						Text(player.name)
						Spacer()
						Text(session.formattedScore(player.totalScore))
							.monospacedDigit()
					}
				}
				if let target = session.preset.targetPerRound {
					Divider()
					Text("Target: first to \(session.formattedScore(target)) each \(session.preset.roundLabel.lowercased()).")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		} label: {
			Label("Leaderboard", systemImage: "rosette")
		}
	}
}

private struct SettingsView: View {
	@EnvironmentObject private var appState: AppState
	@State private var showingResetStatistics = false
	@State private var showingClearSessions = false

	var body: some View {
		NavigationStack {
			Form {
				Section("Feedback") {
					Toggle("Sound", isOn: $appState.settings.soundEnabled)
					Toggle("Vibration", isOn: $appState.settings.vibrationEnabled)
				}

				Section("Data") {
					Button("Reset Statistics", role: .destructive) {
						showingResetStatistics = true
					}
					.confirmationDialog("Reset lifetime statistics?", isPresented: $showingResetStatistics, titleVisibility: .visible) {
						Button("Reset", role: .destructive) {
							appState.resetStatistics()
						}
						Button("Cancel", role: .cancel) { }
					}

					Button("Clear Saved Sessions", role: .destructive) {
						showingClearSessions = true
					}
					.disabled(appState.sessions.isEmpty)
					.confirmationDialog("Remove all sessions?", isPresented: $showingClearSessions, titleVisibility: .visible) {
						Button("Remove All", role: .destructive) {
							appState.clearSessions()
						}
						Button("Cancel", role: .cancel) { }
					}
				}
			}
			.navigationTitle("Settings")
		}
	}
}

private struct StatisticsView: View {
	@EnvironmentObject private var appState: AppState

	private var derived: DerivedStatistics { appState.derivedMetrics }
	private var lifetime: AppStatistics { appState.statistics }

	var body: some View {
		NavigationStack {
			List {
				Section("Overview") {
					StatRow(title: "Active Sessions", value: "\(derived.activeSessions)")
					StatRow(title: "Active Players", value: "\(derived.activePlayers)")
					StatRow(title: "Points Tracked", value: formatted(derived.totalActivePoints))
					StatRow(title: "Avg. Points / Session", value: formatted(derived.averagePointsPerActiveSession))
					if let favorite = derived.favoritePresetName {
						StatRow(title: "Most Popular Preset", value: favorite)
					}
				}

				Section("Lifetime Totals") {
					StatRow(title: "Sessions Created", value: "\(lifetime.totalSessionsCreated)")
					StatRow(title: "Score Events", value: "\(lifetime.totalScoreEvents)")
					StatRow(title: "Points Awarded", value: formatted(lifetime.totalPointsAwarded))
					StatRow(title: "Players Tracked", value: "\(lifetime.totalPlayersTracked)")
					StatRow(title: "Avg. Points / Session", value: formatted(lifetime.averagePointsPerSession))
					StatRow(title: "Last Updated", value: lifetime.lastUpdated.formatted(date: .abbreviated, time: .shortened))
				}
			}
			.listStyle(.insetGrouped)
			.navigationTitle("Statistics")
		}
	}

	private func formatted(_ value: Double) -> String {
		if value.isNaN || value.isInfinite {
			return "0"
		}
		if abs(value.rounded() - value) < 0.0001 {
			return String(Int(value.rounded()))
		}
		return String(format: "%.1f", value)
	}
}

private struct StatRow: View {
	let title: String
	let value: String

	var body: some View {
		HStack {
			Text(title)
			Spacer()
			Text(value)
				.foregroundStyle(.secondary)
		}
	}
}

private struct NewSessionView: View {
	@Environment(\.dismiss) private var dismiss
	let presets: [GamePreset]
	var onCreate: (GameSession) -> Void

	@State private var selectedPreset: GamePreset
	@State private var players: [PlayerDraft]
	@State private var validationMessage: ValidationMessage?

	init(presets: [GamePreset], onCreate: @escaping (GameSession) -> Void) {
		self.presets = presets
		self.onCreate = onCreate
		let initialPreset = presets.first ?? GamePreset.placeholder
		_selectedPreset = State(initialValue: initialPreset)
		_players = State(initialValue: initialPreset.defaultPlayerNames.enumerated().map { index, name in
			PlayerDraft(name: name.isEmpty ? "Player \(index + 1)" : name)
		})
	}

	var body: some View {
		NavigationStack {
			Form {
				Section("Preset") {
					Picker("Game", selection: $selectedPreset) {
						ForEach(presets) { preset in
							HStack {
								Image(systemName: preset.systemImageName)
								VStack(alignment: .leading) {
									Text(preset.name)
									Text(preset.description)
										.font(.caption)
										.foregroundStyle(.secondary)
								}
							}
							.tag(preset)
						}
					}
				}

				Section("Players") {
					ForEach(players) { player in
						TextField("Player", text: binding(for: player))
							.textInputAutocapitalization(.words)
							.disableAutocorrection(true)
							.swipeActions {
								if players.count > selectedPreset.minPlayers {
									Button(role: .destructive) {
										remove(player)
									} label: {
										Label("Remove", systemImage: "trash")
									}
								}
							}
					}
					Button {
						addPlayer()
					} label: {
						Label("Add Player", systemImage: "plus")
					}
					.disabled(!canAddPlayer)
				}

				Section("Overview") {
					Text(selectedPreset.notes)
						.font(.footnote)
					if !selectedPreset.scoringHint.isEmpty {
						Text(selectedPreset.scoringHint)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			}
			.navigationTitle("New Session")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Create") {
						createSession()
					}
				}
			}
			.onChange(of: selectedPreset) { newValue in
				players = newValue.defaultPlayerNames.enumerated().map { index, name in
					PlayerDraft(name: name.isEmpty ? "Player \(index + 1)" : name)
				}
				syncPlayersWithPreset()
			}
			.onAppear {
				syncPlayersWithPreset()
			}
			.alert(item: $validationMessage) { message in
				Alert(
					title: Text("Can't Create Session"),
					message: Text(message.text),
					dismissButton: .default(Text("OK"))
				)
			}
		}
	}

	private var canAddPlayer: Bool {
		guard let max = selectedPreset.maxPlayers else { return true }
		return players.count < max
	}

	private func binding(for draft: PlayerDraft) -> Binding<String> {
		guard let index = players.firstIndex(where: { $0.id == draft.id }) else {
			return .constant("")
		}
		return Binding(
			get: { players[index].name },
			set: { players[index].name = $0 }
		)
	}

	private func addPlayer() {
		guard canAddPlayer else { return }
		let nextIndex = players.count
		players.append(PlayerDraft(name: selectedPreset.suggestedName(for: nextIndex)))
	}

	private func remove(_ draft: PlayerDraft) {
		players.removeAll { $0.id == draft.id }
		syncPlayersWithPreset()
	}

	private func syncPlayersWithPreset() {
		while players.count < selectedPreset.minPlayers {
			let nextIndex = players.count
			players.append(PlayerDraft(name: selectedPreset.suggestedName(for: nextIndex)))
		}
		if let max = selectedPreset.maxPlayers, players.count > max {
			players = Array(players.prefix(max))
		}
	}

	private func createSession() {
		let cleanNames = players
			.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }

		if cleanNames.count < selectedPreset.minPlayers {
			validationMessage = ValidationMessage(text: "This preset requires at least \(selectedPreset.minPlayers) player(s).")
			return
		}

		if let max = selectedPreset.maxPlayers, cleanNames.count > max {
			validationMessage = ValidationMessage(text: "This preset supports up to \(max) player(s).")
			return
		}

		let roundCount = max(selectedPreset.roundCount, 1)
		let sessionPlayers = cleanNames.map { PlayerScore(name: $0, roundCount: roundCount) }
		let session = GameSession(preset: selectedPreset, players: sessionPlayers)
		onCreate(session)
		dismiss()
	}
}

private struct PlayerDraft: Identifiable {
	let id = UUID()
	var name: String
}

private struct ValidationMessage: Identifiable {
	let id = UUID()
	let text: String
}

struct ScoreOption: Identifiable {
	let id = UUID()
	let label: String
	let delta: Double
	let iconSystemName: String
	let color: Color
}

struct GamePreset: Identifiable, Hashable {
	let id: String
	let name: String
	let systemImageName: String
	let description: String
	let roundCount: Int
	let roundLabel: String
	let scoringOptions: [ScoreOption]
	let minPlayers: Int
	let maxPlayers: Int?
	let defaultPlayerNames: [String]
	let notes: String
	let scoreFloor: Double
	let targetPerRound: Double?
	let scoringHint: String

	func suggestedName(for index: Int) -> String {
		if index < defaultPlayerNames.count {
			let candidate = defaultPlayerNames[index]
			return candidate.isEmpty ? "Player \(index + 1)" : candidate
		}
		return "Player \(index + 1)"
	}

	static func == (lhs: GamePreset, rhs: GamePreset) -> Bool {
		lhs.id == rhs.id
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	static var placeholder: GamePreset {
		GamePreset(
			id: "generic",
			name: "Generic",
			systemImageName: "sportscourt",
			description: "Configure players and keep score.",
			roundCount: 1,
			roundLabel: "Round",
			scoringOptions: [
				ScoreOption(label: "+1", delta: 1, iconSystemName: "plus", color: .accentColor)
			],
			minPlayers: 2,
			maxPlayers: nil,
			defaultPlayerNames: ["Player 1", "Player 2"],
			notes: "Generic preset placeholder.",
			scoreFloor: 0,
			targetPerRound: nil,
			scoringHint: ""
		)
	}
}

extension GamePreset {
	static let library: [GamePreset] = {
		[
			GamePreset(
				id: "football",
				name: "Football",
				systemImageName: "soccerball",
				description: "Two halves, standard match scoring.",
				roundCount: 2,
				roundLabel: "Half",
				scoringOptions: [
					ScoreOption(label: "Goal", delta: 1, iconSystemName: "sportscourt", color: .green),
					ScoreOption(label: "Penalty", delta: 1, iconSystemName: "bolt.circle", color: .blue),
					ScoreOption(label: "Undo", delta: -1, iconSystemName: "arrow.uturn.backward", color: .orange)
				],
				minPlayers: 2,
				maxPlayers: 2,
				defaultPlayerNames: ["Home", "Away"],
				notes: "Track total goals across two halves. Use undo to revert mistakes; scores never drop below zero.",
				scoreFloor: 0,
				targetPerRound: nil,
				scoringHint: "Each button updates the current half's tally."
			),
			GamePreset(
				id: "basketball",
				name: "Basketball",
				systemImageName: "basketball",
				description: "Four quarters with standard point values.",
				roundCount: 4,
				roundLabel: "Quarter",
				scoringOptions: [
					ScoreOption(label: "+1", delta: 1, iconSystemName: "1.circle", color: .purple),
					ScoreOption(label: "+2", delta: 2, iconSystemName: "2.circle", color: .blue),
					ScoreOption(label: "+3", delta: 3, iconSystemName: "3.circle", color: .green),
					ScoreOption(label: "Undo", delta: -1, iconSystemName: "arrow.uturn.backward", color: .orange)
				],
				minPlayers: 2,
				maxPlayers: 2,
				defaultPlayerNames: ["Home", "Away"],
				notes: "Four quarters mirror regulation play. Quarter totals sum to the game score.",
				scoreFloor: 0,
				targetPerRound: nil,
				scoringHint: "Use +1 for free throws, +2 for field goals, +3 for long-range shots."
			),
			GamePreset(
				id: "table-tennis",
				name: "Table Tennis",
				systemImageName: "figure.table.tennis",
				description: "Best of five games to eleven points.",
				roundCount: 5,
				roundLabel: "Game",
				scoringOptions: [
					ScoreOption(label: "Point", delta: 1, iconSystemName: "figure.table.tennis", color: .green),
					ScoreOption(label: "Undo", delta: -1, iconSystemName: "arrow.uturn.backward", color: .orange)
				],
				minPlayers: 2,
				maxPlayers: 2,
				defaultPlayerNames: ["Player A", "Player B"],
				notes: "Track up to five games. A game is typically won at 11 points with a two-point margin.",
				scoreFloor: 0,
				targetPerRound: 11,
				scoringHint: "Mark each rally won. Stop scoring once a player reaches 11 with a two-point lead."
			),
			GamePreset(
				id: "chess",
				name: "Chess",
				systemImageName: "checkerboard.rectangle",
				description: "Single game with classic result scoring.",
				roundCount: 1,
				roundLabel: "Game",
				scoringOptions: [
					ScoreOption(label: "Win", delta: 1, iconSystemName: "crown", color: .green),
					ScoreOption(label: "Draw", delta: 0.5, iconSystemName: "scalemass", color: .blue),
					ScoreOption(label: "Undo", delta: -0.5, iconSystemName: "arrow.uturn.backward", color: .orange)
				],
				minPlayers: 2,
				maxPlayers: nil,
				defaultPlayerNames: ["White", "Black", "Challenger 1", "Challenger 2"],
				notes: "Track head-to-head games or round-robin results across multiple players.",
				scoreFloor: 0,
				targetPerRound: nil,
				scoringHint: "Record wins as 1.0, draws as 0.5, and losses as 0."
			),
			GamePreset(
				id: "volleyball",
				name: "Volleyball",
				systemImageName: "volleyball",
				description: "Five sets to twenty-five points.",
				roundCount: 5,
				roundLabel: "Set",
				scoringOptions: [
					ScoreOption(label: "+1", delta: 1, iconSystemName: "plus", color: .green),
					ScoreOption(label: "Undo", delta: -1, iconSystemName: "arrow.uturn.backward", color: .orange)
				],
				minPlayers: 2,
				maxPlayers: 2,
				defaultPlayerNames: ["Team A", "Team B"],
				notes: "Race to 25 points per set with a two-point lead. Track up to five sets.",
				scoreFloor: 0,
				targetPerRound: 25,
				scoringHint: "Log points rally-by-rally. A team must lead by two to close a set."
			),
			GamePreset(
				id: "hockey",
				name: "Hockey",
				systemImageName: "hockey.puck",
				description: "Three periods with goal-based scoring.",
				roundCount: 3,
				roundLabel: "Period",
				scoringOptions: [
					ScoreOption(label: "Goal", delta: 1, iconSystemName: "sportscourt", color: .green),
					ScoreOption(label: "Empty Net", delta: 1, iconSystemName: "target", color: .blue),
					ScoreOption(label: "Undo", delta: -1, iconSystemName: "arrow.uturn.backward", color: .orange)
				],
				minPlayers: 2,
				maxPlayers: 2,
				defaultPlayerNames: ["Home", "Away"],
				notes: "Standard three-period structure. Use scoring buttons for each goal event.",
				scoreFloor: 0,
				targetPerRound: nil,
				scoringHint: "Undo reverses the last goal if added by mistake."
			)
		]
	}()
}

struct AppSettings: Codable {
	var soundEnabled: Bool = true
	var vibrationEnabled: Bool = true
}

struct AppStatistics: Codable {
	var totalSessionsCreated: Int = 0
	var totalScoreEvents: Int = 0
	var totalPointsAwarded: Double = 0
	var totalPlayersTracked: Int = 0
	var lastUpdated: Date = Date()

	var averagePointsPerSession: Double {
		guard totalSessionsCreated > 0 else { return 0 }
		return totalPointsAwarded / Double(totalSessionsCreated)
	}
}

struct DerivedStatistics {
	let activeSessions: Int
	let activePlayers: Int
	let totalActivePoints: Double
	let averagePointsPerActiveSession: Double
	let favoritePresetName: String?
}

final class AppState: ObservableObject {
	@Published var sessions: [GameSession] {
		didSet {
			watchSessions()
			persist()
		}
	}

	@Published var settings: AppSettings {
		didSet { persist() }
	}

	@Published var statistics: AppStatistics {
		didSet { persist() }
	}

	let presets: [GamePreset]

	private let persistence = PersistenceController()
	private var sessionCancellables: Set<AnyCancellable> = []

	init(presets: [GamePreset] = GamePreset.library) {
		self.presets = presets
		let bundle = persistence.load() ?? PersistedBundle.defaultValue
		let decodedSessions = bundle.sessions.compactMap { GameSession(snapshot: $0, presets: presets) }
		self.sessions = decodedSessions
		self.settings = bundle.settings
		self.statistics = bundle.statistics
		watchSessions()
	}

	func addSession(_ session: GameSession) {
		sessions.append(session)
		statistics.totalSessionsCreated += 1
		statistics.totalPlayersTracked += session.players.count
		statistics.lastUpdated = Date()
	}

	func deleteSessions(at offsets: IndexSet) {
		sessions.remove(atOffsets: offsets)
		statistics.lastUpdated = Date()
	}

	func clearSessions() {
		sessions.removeAll()
		statistics.lastUpdated = Date()
	}

	func resetStatistics() {
		statistics = AppStatistics()
	}

	func registerPlayerAdded() {
		statistics.totalPlayersTracked += 1
		statistics.lastUpdated = Date()
	}

	func registerScoreChange(delta: Double) {
		guard delta != 0 else { return }
		statistics.totalScoreEvents += 1
		if delta > 0 {
			statistics.totalPointsAwarded += delta
		} else {
			statistics.totalPointsAwarded = max(0, statistics.totalPointsAwarded + delta)
		}
		statistics.lastUpdated = Date()
		FeedbackManager.shared.play(delta: delta, settings: settings)
	}

	var derivedMetrics: DerivedStatistics {
		let activeSessions = sessions.count
		let activePlayers = sessions.reduce(0) { result, session in
			result + session.players.count
		}
		let totalActivePoints = sessions.reduce(0.0) { partial, session in
			partial + session.players.reduce(0.0) { $0 + $1.totalScore }
		}
		let averagePointsPerSession = activeSessions > 0 ? totalActivePoints / Double(activeSessions) : 0
		let counts = sessions.reduce(into: [String: Int]()) { partial, session in
			partial[session.preset.id, default: 0] += 1
		}
		let favoritePresetName = counts.max(by: { $0.value < $1.value }).flatMap { key, _ in
			presets.first(where: { $0.id == key })?.name
		}

		return DerivedStatistics(
			activeSessions: activeSessions,
			activePlayers: activePlayers,
			totalActivePoints: totalActivePoints,
			averagePointsPerActiveSession: averagePointsPerSession,
			favoritePresetName: favoritePresetName
		)
	}

	private func watchSessions() {
		sessionCancellables = []
		for session in sessions {
			session.objectWillChange
				.sink { [weak self] _ in
					guard let self else { return }
					DispatchQueue.main.async {
						self.persist()
					}
				}
				.store(in: &sessionCancellables)
		}
	}

	private func persist() {
		let snapshots = sessions.map { $0.snapshot }
		let bundle = PersistedBundle(sessions: snapshots, settings: settings, statistics: statistics)
		persistence.save(bundle)
	}
}

private final class FeedbackManager {
	static let shared = FeedbackManager()

	func play(delta: Double, settings: AppSettings) {
		guard settings.soundEnabled || settings.vibrationEnabled else { return }
		DispatchQueue.main.async {
			if settings.soundEnabled {
				AudioServicesPlaySystemSound(1104)
			}
			if settings.vibrationEnabled {
				let generator = UINotificationFeedbackGenerator()
				generator.prepare()
				let type: UINotificationFeedbackGenerator.FeedbackType = delta >= 0 ? .success : .warning
				generator.notificationOccurred(type)
			}
		}
	}
}

final class PersistenceController {
	private let url: URL

	init(filename: String = "appstate.json") {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		if !FileManager.default.fileExists(atPath: base.path) {
			try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
		}
		url = base.appendingPathComponent(filename)
	}

	func load() -> PersistedBundle? {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		do {
			let data = try Data(contentsOf: url)
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			return try decoder.decode(PersistedBundle.self, from: data)
		} catch {
			return nil
		}
	}

	func save(_ bundle: PersistedBundle) {
		do {
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(bundle)
			try data.write(to: url, options: .atomic)
		} catch {
			// Swallow errors to avoid interrupting the UI; consider logging in production.
		}
	}
}

struct PersistedBundle: Codable {
	var sessions: [GameSessionSnapshot]
	var settings: AppSettings
	var statistics: AppStatistics

	static let defaultValue = PersistedBundle(sessions: [], settings: AppSettings(), statistics: AppStatistics())
}

struct GameSessionSnapshot: Codable {
	let id: UUID
	let presetID: String
	let currentRoundIndex: Int
	let players: [PlayerSnapshot]
}

struct PlayerSnapshot: Codable {
	let id: UUID
	let name: String
	let scores: [Double]
}

final class PlayerScore: ObservableObject, Identifiable {
	let id: UUID
	@Published var name: String
	@Published var roundScores: [Double]

	init(id: UUID = UUID(), name: String, roundCount: Int, scores: [Double]? = nil) {
		self.id = id
		self.name = name
		let rounds = max(roundCount, 1)
		if let scores, !scores.isEmpty {
			if scores.count == rounds {
				self.roundScores = scores
			} else if scores.count < rounds {
				self.roundScores = scores + Array(repeating: 0, count: rounds - scores.count)
			} else {
				self.roundScores = Array(scores.prefix(rounds))
			}
		} else {
			self.roundScores = Array(repeating: 0, count: rounds)
		}
	}

	var totalScore: Double {
		roundScores.reduce(0, +)
	}

	func reset(roundCount: Int) {
		roundScores = Array(repeating: 0, count: max(roundCount, 1))
	}
}

final class GameSession: ObservableObject, Identifiable {
	let id: UUID
	let preset: GamePreset
	@Published var players: [PlayerScore] {
		didSet {
			observePlayers()
			normalizePlayers()
		}
	}
	@Published private(set) var currentRoundIndex: Int

	private var cancellables: Set<AnyCancellable> = []

	init(id: UUID = UUID(), preset: GamePreset, players: [PlayerScore], currentRoundIndex: Int = 0) {
		self.id = id
		self.preset = preset
		self.players = players
		self.currentRoundIndex = min(max(currentRoundIndex, 0), max(preset.roundCount - 1, 0))
		observePlayers()
		normalizePlayers()
	}

	var totalRounds: Int {
		max(preset.roundCount, 1)
	}

	var currentRoundNumber: Int {
		min(currentRoundIndex, totalRounds - 1) + 1
	}

	var progress: Double {
		guard totalRounds > 0 else { return 0 }
		return Double(currentRoundNumber) / Double(totalRounds)
	}

	var canAdvanceRound: Bool {
		currentRoundIndex < totalRounds - 1
	}

	var canRewindRound: Bool {
		currentRoundIndex > 0
	}

	var isPristine: Bool {
		players.allSatisfy { $0.totalScore == 0 }
	}

	var roundStatusHeadline: String {
		"\(preset.roundLabel) \(currentRoundNumber) of \(totalRounds)"
	}

	var roundStatusDetail: String {
		canAdvanceRound ? "In progress" : "Final \(preset.roundLabel.lowercased())"
	}

	var roundStatusBadgeText: String {
		"\(currentRoundNumber)/\(totalRounds) \(preset.roundLabel.lowercased())"
	}

	var playerSummary: String {
		switch players.count {
		case 0:
			return "No players yet"
		case 1:
			return players.first?.name ?? "Player"
		case 2:
			return "\(players[0].name) vs \(players[1].name)"
		case 3...4:
			return players.map { $0.name }.joined(separator: ", ")
		default:
			let prefix = players.prefix(3).map { $0.name }.joined(separator: ", ")
			return "\(prefix) +\(players.count - 3) more"
		}
	}

	var standings: [PlayerScore] {
		players.sorted { $0.totalScore > $1.totalScore }
	}

	func roundTitle(for index: Int) -> String {
		"\(preset.roundLabel) \(index + 1)"
	}

	func formattedScore(_ value: Double) -> String {
		if value.isNaN || value.isInfinite {
			return "0"
		}
		if abs(value.rounded() - value) < 0.0001 {
			return String(Int(value.rounded()))
		}
		return String(format: "%.1f", value)
	}

	func apply(_ option: ScoreOption, to player: PlayerScore) {
		guard let index = players.firstIndex(where: { $0.id == player.id }) else { return }
		let roundIndex = min(currentRoundIndex, totalRounds - 1)
		let target = players[index]
		var updatedScores = target.roundScores
		var newValue = updatedScores[roundIndex] + option.delta
		newValue = max(preset.scoreFloor, newValue)
		updatedScores[roundIndex] = newValue
		target.roundScores = updatedScores
	}

	func nextRound() {
		guard canAdvanceRound else { return }
		currentRoundIndex += 1
	}

	func previousRound() {
		guard canRewindRound else { return }
		currentRoundIndex -= 1
	}

	func resetScores() {
		currentRoundIndex = 0
		players.forEach { $0.reset(roundCount: totalRounds) }
	}

	var canAddPlayer: Bool {
		guard let max = preset.maxPlayers else { return true }
		return players.count < max
	}

	var canRemovePlayer: Bool {
		players.count > preset.minPlayers
	}

	func addPlayer() {
		guard canAddPlayer else { return }
		let newName = preset.suggestedName(for: players.count)
		let newPlayer = PlayerScore(name: newName, roundCount: totalRounds)
		players.append(newPlayer)
	}

	func removePlayer(_ player: PlayerScore) {
		guard canRemovePlayer else { return }
		players.removeAll { $0.id == player.id }
	}

	fileprivate var snapshot: GameSessionSnapshot {
		GameSessionSnapshot(
			id: id,
			presetID: preset.id,
			currentRoundIndex: currentRoundIndex,
			players: players.map { PlayerSnapshot(id: $0.id, name: $0.name, scores: $0.roundScores) }
		)
	}

	fileprivate convenience init?(snapshot: GameSessionSnapshot, presets: [GamePreset]) {
		guard let preset = presets.first(where: { $0.id == snapshot.presetID }) else {
			return nil
		}
		let players = snapshot.players.map { PlayerScore(id: $0.id, name: $0.name, roundCount: preset.roundCount, scores: $0.scores) }
		self.init(id: snapshot.id, preset: preset, players: players, currentRoundIndex: snapshot.currentRoundIndex)
	}

	private func observePlayers() {
		cancellables = []
		for player in players {
			player.objectWillChange
				.sink { [weak self] _ in
					self?.objectWillChange.send()
				}
				.store(in: &cancellables)
		}
	}

	private func normalizePlayers() {
		let rounds = totalRounds
		for player in players {
			if player.roundScores.count != rounds {
				var scores = player.roundScores
				if scores.count < rounds {
					scores.append(contentsOf: Array(repeating: 0, count: rounds - scores.count))
				} else if scores.count > rounds {
					scores = Array(scores.prefix(rounds))
				}
				player.roundScores = scores
			}
		}
	}

	var leaderSummary: String {
		guard let topScore = standings.first?.totalScore else { return "" }
		let leaders = standings.filter { abs($0.totalScore - topScore) < 0.0001 }
		let formatted = formattedScore(topScore)
		if leaders.count == 1, let leader = leaders.first {
			return "Leader: \(leader.name) (\(formatted))"
		}
		let names = leaders.map { $0.name }.joined(separator: ", ")
		return "Tied: \(names) (\(formatted))"
	}
}

#Preview {
	ContentView()
		.environmentObject(AppState())
}
