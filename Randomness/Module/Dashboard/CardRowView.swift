//
//  CardRowView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import SwiftUI

struct CardRowView: View {
    let title: String
    let subtitle: String
    let onTapped: CompletionHandler
    
    var body: some View {
        Button {
            onTapped()
        } label: {
            HStack(spacing: 20) {
                Image(systemName: "gamecontroller.fill")
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CardRowView(title: "Testing", subtitle: "This is a subtitle") { }
}
