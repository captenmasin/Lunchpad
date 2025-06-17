//
//  SpotlightSearchField.swift
//  Lunchpad
//
//  Created by Mason Day on 12/06/2025.
//


import SwiftUI

struct SpotlightSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .resizable()
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)

            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .font(.system(size: 18))
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 15)
        .background(
            RoundedRectangle(cornerRadius: 100)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 100)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

#Preview {
    SpotlightSearchField(
        text: .constant("test"),
        placeholder: "Placeholder"
    )
}
