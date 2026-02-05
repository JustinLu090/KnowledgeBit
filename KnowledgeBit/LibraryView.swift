// LibraryView.swift
// Library tab view for word sets management

import SwiftUI

struct LibraryView: View {
  var body: some View {
    NavigationStack {
      WordSetListView()
        .navigationTitle("單字集")
        .navigationBarTitleDisplayMode(.large)
    }
  }
}
