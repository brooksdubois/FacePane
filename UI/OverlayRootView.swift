import SwiftUI

struct OverlayRootView: View {
    var body: some View {
        ZStack {
            WindowPaneBackground()

            PlaceholderCameraContent()
        }
        .frame(minWidth: 260, minHeight: 160)
        .background(Color.clear)
    }
}

private struct WindowPaneBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.86))

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.35), lineWidth: 2)
                .blur(radius: 0.5)
                .offset(y: 1)
        }
    }
}

private struct PlaceholderCameraContent: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.fill")
                .font(.system(size: 54, weight: .semibold))

            Text("Windowpane")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Camera preview goes here")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.56))
        }
        .foregroundStyle(Color.white)
        .padding(32)
    }
}
