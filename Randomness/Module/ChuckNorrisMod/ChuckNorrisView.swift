//
//  ChuckNorrisView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI

struct ChuckNorrisView<ViewModel: ChuckNorrisViewModelProtocol>: View {
    @StateObject private var viewModel: ViewModel

    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ScrollView {
            if let joke = viewModel.joke {
                JokeCard(joke: joke)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.loadJoke() }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await viewModel.loadJoke() }
            } label: {
                Label("Another one", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
            .padding(16)
            .background(.clear)
            .tint(Color.pink.opacity(0.9))
        }
        .overlay {
            if viewModel.isLoading && viewModel.joke == nil {
                ProgressView()
            } else if let message = viewModel.errorMessage, viewModel.joke == nil {
                ContentUnavailableView {
                    Label("Couldn't load a joke", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { Task { await viewModel.loadJoke() } }
                }
            }
        }
        .navigationTitle("Chuck Norris")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
    }
}

private struct JokeCard: View {
    let joke: ChuckNorrisJoke

    var body: some View {
        VStack(spacing: 20) {
            RemoteImage(url: joke.iconURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Image(systemName: "person.fill.questionmark")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                }
            }
            .frame(width: 96, height: 96)
            .background(
                Color.gray.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(joke.value)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .italic()
                .kerning(0.5)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white
                )
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                .textCase(.none)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [Color.purple,Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ChuckNorrisView(viewModel: ChuckNorrisViewModel(service: MockChuckNorrisService()))
    }
}
