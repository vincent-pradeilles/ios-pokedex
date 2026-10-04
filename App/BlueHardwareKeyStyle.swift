import SwiftUI

struct BlueHardwareKeyStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed && isEnabled
    configuration.label
      .background {
        RoundedRectangle(cornerRadius: 4)
          .fill(LinearGradient(
            colors: [Color(red: 0.40, green: 0.78, blue: 0.98),
                     Color(red: 0.20, green: 0.58, blue: 0.87),
                     Color(red: 0.12, green: 0.43, blue: 0.72)],
            startPoint: .topLeading, endPoint: .bottomTrailing
          ))
          .overlay {
            RoundedRectangle(cornerRadius: 3)
              .strokeBorder(LinearGradient(
                colors: [.white.opacity(0.65), .white.opacity(0.08), .black.opacity(0.3)],
                startPoint: .topLeading, endPoint: .bottomTrailing
              ), lineWidth: 1.5)
              .padding(1)
          }
          .overlay {
            RoundedRectangle(cornerRadius: 4)
              .strokeBorder(Color(red: 0.035, green: 0.19, blue: 0.32), lineWidth: 1)
          }
      }
      .offset(y: pressed ? 3 : 0)
      .padding(.bottom, 4)
      .background(alignment: .bottom) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color(red: 0.055, green: 0.25, blue: 0.43).gradient)
          .overlay {
            RoundedRectangle(cornerRadius: 4)
              .strokeBorder(.black.opacity(0.7), lineWidth: 1)
          }
          .padding(.top, 4)
      }
      .shadow(color: .black.opacity(pressed ? 0.15 : 0.55), radius: pressed ? 0 : 1, y: pressed ? 0 : 2)
      .contentShape(RoundedRectangle(cornerRadius: 4))
      .opacity(isEnabled ? 1 : 0.55)
      .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: pressed)
  }
}
