//
//  AvatarView.swift
//  MedJourney
//
//  Components — Circle avatar with initials or image
//

import SwiftUI

/// A circular avatar displaying initials or an image.
struct AvatarView: View {

    enum Size: CGFloat {
        case small = 32
        case medium = 40
        case large = 56
    }

    let name: String
    let size: Size
    let backgroundColor: Color

    init(name: String, size: Size = .medium, backgroundColor: Color = AppColors.brandPale) {
        self.name = name
        self.size = size
        self.backgroundColor = backgroundColor
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size.rawValue * 0.38, weight: .semibold))
            .foregroundStyle(AppColors.brandDark)
            .frame(width: size.rawValue, height: size.rawValue)
            .background(backgroundColor)
            .clipShape(Circle())
    }
}

#Preview {
    HStack(spacing: 12) {
        AvatarView(name: "Ada Smith", size: .small)
        AvatarView(name: "Ada Smith", size: .medium)
        AvatarView(name: "Ada Smith", size: .large)
    }
}
