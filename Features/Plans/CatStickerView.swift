import SwiftUI
import UIKit

enum CatStickerStyle {
    case head
    case peek
}

/// 各页面独立猫图资源名，可在 Assets 中分别替换
enum CatPageIcon {
    static let yearPlan = "CatYearPlan"   // 年度计划
    static let monthPlan = "CatMonthPlan" // 月度计划
    static let today = "CatToday"         // 今日
    static let stats = "CatStats"         // 统计
    static let settings = "CatSettings"   // 设置
}

struct CatStickerView: View {
    let style: CatStickerStyle
    let size: CGFloat
    let imageName: String?
    @State private var float = false
    @State private var bounce = false

    init(style: CatStickerStyle = .head, size: CGFloat = 44, imageName: String? = nil) {
        self.style = style
        self.size = size
        self.imageName = imageName
    }

    var body: some View {
        ZStack {
            let resolvedName = imageName ?? (style == .head ? "CatHead" : "CatPeek")
            if let image = catImage(named: resolvedName) {
                CatImageView(
                    image: image,
                    style: imageName != nil ? .head : style,
                    size: size,
                    isFloating: float
                )
            } else {
                if style == .peek && imageName == nil {
                    CatPaw()
                        .frame(width: size * 0.24, height: size * 0.18)
                        .offset(x: -size * 0.18, y: size * 0.28)
                    CatPaw()
                        .frame(width: size * 0.24, height: size * 0.18)
                        .offset(x: size * 0.18, y: size * 0.28)
                }

                CatHeadIllustration(eyeStyle: style == .head ? .smile : .dot)
                    .frame(width: size, height: size)
                    .offset(y: float ? -2 : 2)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: float)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(bounce ? 1.03 : 0.98)
        .onAppear {
            float.toggle()
            bounce.toggle()
        }
        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bounce)
    }

    private func catImage(named name: String) -> Image? {
        guard let uiImage = UIImage(named: name) else { return nil }
        return Image(uiImage: uiImage)
    }
}

struct CatStickerButton: View {
    let style: CatStickerStyle
    let size: CGFloat
    let imageName: String?
    let action: () -> Void

    init(style: CatStickerStyle = .head, size: CGFloat = 44, imageName: String? = nil, action: @escaping () -> Void) {
        self.style = style
        self.size = size
        self.imageName = imageName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            CatStickerView(style: style, size: size, imageName: imageName)
                .contentShape(Rectangle())
        }
        .buttonStyle(CatStickerPressStyle())
        .accessibilityLabel("AI 助手")
    }
}

struct CatStickerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .rotationEffect(.degrees(configuration.isPressed ? -4 : 0))
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.06 : 0.12),
                radius: configuration.isPressed ? 4 : 10,
                x: 0,
                y: configuration.isPressed ? 2 : 6
            )
            .overlay(
                Circle()
                    .stroke(Color.orange.opacity(configuration.isPressed ? 0.35 : 0), lineWidth: 3)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct CatHeadIllustration: View {
    enum EyeStyle {
        case smile
        case dot
    }

    let eyeStyle: EyeStyle

    private let strokeColor = Color.black.opacity(0.85)
    private let furColor = Color(red: 0.9, green: 0.9, blue: 0.9)
    private let bellyColor = Color(red: 0.98, green: 0.98, blue: 0.98)
    private let stripeColor = Color.gray.opacity(0.35)

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let line = max(1.5, size * 0.05)

            ZStack {
                CatEarShape()
                    .fill(furColor)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .offset(x: -size * 0.22, y: -size * 0.38)
                CatEarShape()
                    .fill(furColor)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .offset(x: size * 0.22, y: -size * 0.38)

                CatEarShape()
                    .stroke(strokeColor, lineWidth: line)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .offset(x: -size * 0.22, y: -size * 0.38)
                CatEarShape()
                    .stroke(strokeColor, lineWidth: line)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .offset(x: size * 0.22, y: -size * 0.38)

                Ellipse()
                    .fill(furColor)
                    .frame(width: size * 0.9, height: size * 0.82)

                Circle()
                    .fill(bellyColor)
                    .frame(width: size * 0.78, height: size * 0.62)
                    .offset(y: size * 0.18)

                Ellipse()
                    .stroke(strokeColor, lineWidth: line)
                    .frame(width: size * 0.9, height: size * 0.82)

                HStack(spacing: size * 0.06) {
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(stripeColor)
                        .frame(width: size * 0.08, height: size * 0.2)
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(stripeColor)
                        .frame(width: size * 0.1, height: size * 0.24)
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(stripeColor)
                        .frame(width: size * 0.08, height: size * 0.2)
                }
                .offset(y: -size * 0.18)

                CatWhiskers()
                    .stroke(strokeColor, lineWidth: line * 0.7)
                    .frame(width: size, height: size)

                if eyeStyle == .smile {
                    CatEyeSmile()
                        .stroke(strokeColor, lineWidth: line * 0.75)
                        .frame(width: size, height: size)
                } else {
                    Circle()
                        .fill(strokeColor)
                        .frame(width: size * 0.06, height: size * 0.06)
                        .offset(x: -size * 0.16, y: -size * 0.02)
                    Circle()
                        .fill(strokeColor)
                        .frame(width: size * 0.06, height: size * 0.06)
                        .offset(x: size * 0.16, y: -size * 0.02)
                }

                CatNose()
                    .fill(strokeColor)
                    .frame(width: size * 0.08, height: size * 0.06)
                    .offset(y: size * 0.1)

                CatMouth()
                    .stroke(strokeColor, lineWidth: line * 0.65)
                    .frame(width: size, height: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct CatTailWiggle: View {
    var body: some View {
        Capsule()
            .fill(Color.gray.opacity(0.4))
    }
}

private struct CatImageView: View {
    let image: Image
    let style: CatStickerStyle
    let size: CGFloat
    let isFloating: Bool

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .offset(y: isFloating ? -2 : 2)
            .rotationEffect(.degrees(isFloating ? 1.2 : -1.2))
            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: isFloating)
    }
}

private struct CatPaw: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 0.98, green: 0.98, blue: 0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.7), lineWidth: 2)
            )
    }
}

private struct CatEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CatWhiskers: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerY = rect.midY + rect.height * 0.05
        let offsetX = rect.width * 0.2
        let whiskerLength = rect.width * 0.18

        for index in [-1, 0, 1] {
            let y = centerY + CGFloat(index) * rect.height * 0.06
            path.move(to: CGPoint(x: rect.midX - offsetX, y: y))
            path.addLine(to: CGPoint(x: rect.midX - offsetX - whiskerLength, y: y + CGFloat(index) * 2))
            path.move(to: CGPoint(x: rect.midX + offsetX, y: y))
            path.addLine(to: CGPoint(x: rect.midX + offsetX + whiskerLength, y: y + CGFloat(index) * 2))
        }

        return path
    }
}

private struct CatEyeSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        let leftEyeCenter = CGPoint(x: rect.midX - width * 0.16, y: rect.midY - height * 0.06)
        let rightEyeCenter = CGPoint(x: rect.midX + width * 0.16, y: rect.midY - height * 0.06)
        let eyeWidth = width * 0.16
        let eyeHeight = height * 0.08

        path.addQuadCurve(
            to: CGPoint(x: leftEyeCenter.x + eyeWidth / 2, y: leftEyeCenter.y),
            control: CGPoint(x: leftEyeCenter.x, y: leftEyeCenter.y + eyeHeight)
        )
        path.move(to: CGPoint(x: rightEyeCenter.x - eyeWidth / 2, y: rightEyeCenter.y))
        path.addQuadCurve(
            to: CGPoint(x: rightEyeCenter.x + eyeWidth / 2, y: rightEyeCenter.y),
            control: CGPoint(x: rightEyeCenter.x, y: rightEyeCenter.y + eyeHeight)
        )

        return path
    }
}

private struct CatNose: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CatMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.12)
        let mouthWidth = rect.width * 0.12
        let mouthHeight = rect.height * 0.06

        path.move(to: CGPoint(x: center.x, y: center.y))
        path.addQuadCurve(
            to: CGPoint(x: center.x - mouthWidth, y: center.y + mouthHeight),
            control: CGPoint(x: center.x - mouthWidth * 0.6, y: center.y + mouthHeight * 0.1)
        )
        path.move(to: CGPoint(x: center.x, y: center.y))
        path.addQuadCurve(
            to: CGPoint(x: center.x + mouthWidth, y: center.y + mouthHeight),
            control: CGPoint(x: center.x + mouthWidth * 0.6, y: center.y + mouthHeight * 0.1)
        )

        return path
    }
}
