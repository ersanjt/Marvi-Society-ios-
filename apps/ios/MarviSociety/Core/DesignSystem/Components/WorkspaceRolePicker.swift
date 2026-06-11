import SwiftUI

struct WorkspaceRolePicker: View {
    let roles: [UserRole]
    @Binding var selected: UserRole

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(roles) { role in
                    Button {
                        selected = role
                    } label: {
                        Label(role.rawValue, systemImage: role.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected == role ? .white : MarviColor.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                selected == role
                                    ? AnyShapeStyle(MarviGradient.brand)
                                    : AnyShapeStyle(MarviColor.panelElevated)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(MarviColor.border, lineWidth: selected == role ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
