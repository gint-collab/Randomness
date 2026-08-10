//
//  LandingView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import SwiftUI

struct LandingView<ViewModel: LandingViewModelProtocol>: View {
    @StateObject private var viewModel: ViewModel
    
    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.5), Color.white], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "dice.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .foregroundStyle(.pink, .black)
                        
                    Text("Randomness")
                        .font(.system(size: 40, weight: .bold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .accessibilityLabel("Randomness")
                        .accessibilityAddTraits(.isHeader)
                }
                
                Button {
                    viewModel.login()
                } label: {
                    Text("Get Started")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LandingView(viewModel: LandingViewModel(onLoginSuccess: {}))
    }
}
