import SwiftUI

/// 左侧导航页面枚举
enum Page: String, CaseIterable, Identifiable {
    case keyMapping = "keyMapping"
    case keyDetection = "keyDetection"
    case setupGuide = "setupGuide"
    case settings = "settings"

    var id: String { rawValue }

    /// 菜单项图标
    var icon: String {
        switch self {
        case .keyMapping:    return "gamecontroller.fill"
        case .keyDetection:  return "keyboard"
        case .setupGuide:    return "book.fill"
        case .settings:      return "gearshape.fill"
        }
    }

    /// 是否位于侧边栏底部（Settings）
    var isBottom: Bool {
        self == .settings
    }
}

/// 左侧导航侧边栏
struct SidebarView: View {
    @Binding var selectedPage: Page
    @ObservedObject var monitor: ControllerMonitor

    var body: some View {
        VStack(spacing: 0) {
            // ─── 顶部：应用标识 ───
            appHeader
                .padding(.top, 20)
                .padding(.bottom, 16)
                .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 12)

            // ─── 中部：主要导航项 ───
            VStack(spacing: 2) {
                ForEach(Page.allCases.filter { !$0.isBottom }) { page in
                    SidebarItem(
                        page: page,
                        isSelected: selectedPage == page,
                        action: { selectedPage = page }
                    )
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 8)

            Spacer()

            Divider()
                .padding(.horizontal, 12)

            // ─── 底部：系统设置 ───
            VStack(spacing: 2) {
                ForEach(Page.allCases.filter { $0.isBottom }) { page in
                    SidebarItem(
                        page: page,
                        isSelected: selectedPage == page,
                        action: { selectedPage = page }
                    )
                }
            }
            .padding(.bottom, 12)
            .padding(.horizontal, 8)
        }
        .frame(width: 200)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: monitor.isControllerConnected ? "gamecontroller.fill" : "gamecontroller")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Paddle Mapper")
                    .font(.headline)
                if monitor.isControllerConnected {
                    Text(monitor.controllerName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// 单个侧边栏菜单项
private struct SidebarItem: View {
    let page: Page
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.icon)
                    .font(.body)
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Text(titleForPage(page))
                    .font(.body)
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func titleForPage(_ page: Page) -> String {
        switch page {
        case .keyMapping:    return NSLocalizedString("SIDEBAR_KEY_MAPPING", comment: "Key Mapping menu item")
        case .keyDetection:  return NSLocalizedString("SIDEBAR_KEY_DETECTION", comment: "Key Detection menu item")
        case .setupGuide:    return NSLocalizedString("SIDEBAR_SETUP_GUIDE", comment: "Setup Guide menu item")
        case .settings:      return NSLocalizedString("SIDEBAR_SETTINGS", comment: "Settings menu item")
        }
    }
}
