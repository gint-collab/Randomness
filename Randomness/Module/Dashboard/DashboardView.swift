//
//  DashboardView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import SwiftUI

struct DashboardView<ViewModel: DashboardViewModelProtocol>: View {
    @StateObject private var viewModel: ViewModel

    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        List {
            ForEach(viewModel.items) { item in
                Button {
                    viewModel.didSelect(item)
                } label: {
                    HStack {
                        Text(item.rawValue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    // Makes the whole row (including the empty Spacer area) tappable.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.didTapLogout()
                } label: {
                    Text("Logout")
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear { viewModel.onAppear() }
        .navigationTitle("Randomness")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    DashboardView(viewModel: DashboardViewModel(onLogout: {}))
}
