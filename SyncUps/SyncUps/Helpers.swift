import Sharing
import SwiftUI

// NB: This is only used for previews.
struct Preview<Content: View>: View {
  let content: Content
  let message: String
  init(
    message: String,
    @ViewBuilder content: () -> Content
  ) {
    self.content = content()
    self.message = message
  }

  var body: some View {
    VStack {
      DisclosureGroup {
        Text(message)
          .frame(maxWidth: .infinity)
      } label: {
        HStack {
          Image(systemName: "info.circle.fill")
            .font(.title3)
          Text("About this preview")
        }
      }
      .padding()

      content
    }
  }
}

#Preview {
  Preview(
    message:
      """
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt \
      ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation \
      ullamco laboris nisi ut aliquip ex ea commodo consequat.
      """
  ) {
    SyncUpDetailView(model: SyncUpDetailModel(syncUp: Shared(.mock)))
  }
}
