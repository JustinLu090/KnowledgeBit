import SwiftUI

struct CompactPageHeader<Trailing: View>: View {
  let title: String
  @ViewBuilder var trailing: Trailing

  init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
    self.title = title
    self.trailing = trailing()
  }

  init(_ title: String) where Trailing == EmptyView {
    self.title = title
    self.trailing = EmptyView()
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title)
        .font(.system(size: 34, weight: .bold))
        .foregroundStyle(.primary)

      Spacer(minLength: 0)

      trailing
    }
    .padding(.top, 10)
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
  }
}

