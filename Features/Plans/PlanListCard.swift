import SwiftUI

struct PlanListCard: View {
    let title: String
    let emptyHint: String
    let addButtonLabel: String
    let maxCollapsedItems: Int?
    @Binding var items: [String]
    @Binding var isExpanded: Bool

    private var visibleIndices: [Int] {
        let indices = Array(items.indices)
        guard let max = maxCollapsedItems, !isExpanded else { return indices }
        return Array(indices.prefix(max))
    }

    private var hasOverflow: Bool {
        guard let max = maxCollapsedItems else { return false }
        return items.count > max
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .accessibilityLabel(addButtonLabel)
            }

            Group {
                if items.isEmpty {
                    Button(action: addItem) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                            Text(emptyHint)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                    }
                    .padding(.horizontal, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(visibleIndices, id: \.self) { index in
                            PlanListRow(text: binding(for: index), onDelete: {
                                removeItem(at: index)
                            })
                            if index != visibleIndices.last {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.leading, 18)
                    .padding(.trailing, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PlanListPaperBackground())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if hasOverflow {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(isExpanded ? "收起" : "展开 \(items.count - visibleIndices.count) 条")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(red: 0.99, green: 0.96, blue: 0.92))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func addItem() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            items.append("")
            if maxCollapsedItems != nil {
                isExpanded = true
            }
        }
    }

    private func removeItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            items.remove(at: index)
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { items.indices.contains(index) ? items[index] : "" },
            set: { newValue in
                if items.indices.contains(index) {
                    items[index] = newValue
                }
            }
        )
    }
}

private struct PlanListRow: View {
    @Binding var text: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.blue.opacity(0.7))
                .frame(width: 6, height: 6)

            TextField("写一条目标...", text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct PlanListPaperBackground: View {
    private let lineSpacing: CGFloat = 26

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color(red: 1.0, green: 0.985, blue: 0.95)

                Path { path in
                    let lineCount = Int(proxy.size.height / lineSpacing)
                    for index in 1...lineCount {
                        let y = CGFloat(index) * lineSpacing
                        path.move(to: CGPoint(x: 12, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width - 12, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)

                Rectangle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 2)
                    .padding(.leading, 10)
            }
        }
    }
}
