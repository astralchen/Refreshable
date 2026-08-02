import UIKit

/// 带文案刷新样式共享的字体、颜色和无障碍行为配置。
public struct RefreshLabelStyleConfiguration {
    /// 标签使用的基础字体。
    public var font: UIFont

    /// 用于 Dynamic Type 缩放的文字样式。
    public var fontTextStyle: UIFont.TextStyle

    /// 默认文字颜色。
    public var textColor: UIColor

    /// 开启“降低透明度”辅助功能时使用的高对比文字颜色。
    public var reducedTransparencyTextColor: UIColor

    /// 标签是否跟随系统内容字号变化。
    public var adjustsFontForContentSizeCategory: Bool

    /// 是否响应“减弱动态效果”辅助功能设置。
    public var honorsReduceMotion: Bool

    /// 是否响应“降低透明度”辅助功能设置。
    public var honorsReduceTransparency: Bool

    /// 创建刷新文案样式配置。
    ///
    /// - Parameters:
    ///   - font: 标签使用的基础字体。
    ///   - fontTextStyle: 用于 Dynamic Type 缩放的文字样式。
    ///   - textColor: 默认文字颜色。
    ///   - reducedTransparencyTextColor: 开启“降低透明度”辅助功能时使用的高对比文字颜色。
    ///   - adjustsFontForContentSizeCategory: 标签是否跟随系统内容字号变化。
    ///   - honorsReduceMotion: 是否响应“减弱动态效果”辅助功能设置。
    ///   - honorsReduceTransparency: 是否响应“降低透明度”辅助功能设置。
    public init(
        font: UIFont = .systemFont(ofSize: 14),
        fontTextStyle: UIFont.TextStyle = .body,
        textColor: UIColor = .secondaryLabel,
        reducedTransparencyTextColor: UIColor = .label,
        adjustsFontForContentSizeCategory: Bool = true,
        honorsReduceMotion: Bool = true,
        honorsReduceTransparency: Bool = true
    ) {
        self.font = font
        self.fontTextStyle = fontTextStyle
        self.textColor = textColor
        self.reducedTransparencyTextColor = reducedTransparencyTextColor
        self.adjustsFontForContentSizeCategory = adjustsFontForContentSizeCategory
        self.honorsReduceMotion = honorsReduceMotion
        self.honorsReduceTransparency = honorsReduceTransparency
    }
}

/// 顶部下拉刷新样式的可见文案和 VoiceOver 文案。
public struct TopRefreshTexts {
    /// 空闲状态显示的文案。
    public var idle: String

    /// 用户下拉但尚未达到触发距离时显示的文案。
    public var pulling: String

    /// 已达到触发距离、等待用户松手时显示的文案。
    public var triggered: String

    /// 刷新动作执行中显示的文案。
    public var active: String

    /// 刷新动作结束并开始收起时显示的文案。
    public var ending: String

    /// 顶部刷新视图的无障碍标签。
    public var accessibilityLabel: String

    /// 空闲状态的无障碍值。
    public var idleAccessibilityValue: String

    /// 下拉状态的无障碍值。
    public var pullingAccessibilityValue: String

    /// 已触发状态的无障碍值。
    public var triggeredAccessibilityValue: String

    /// 刷新中状态的无障碍值。
    public var activeAccessibilityValue: String

    /// 结束状态的无障碍值。
    public var endingAccessibilityValue: String

    /// 创建顶部下拉刷新文案。
    ///
    /// - Parameters:
    ///   - idle: 空闲状态显示的文案。
    ///   - pulling: 用户下拉但尚未达到触发距离时显示的文案。
    ///   - triggered: 已达到触发距离、等待用户松手时显示的文案。
    ///   - active: 刷新动作执行中显示的文案。
    ///   - ending: 刷新动作结束并开始收起时显示的文案。
    ///   - accessibilityLabel: 顶部刷新视图的无障碍标签。
    ///   - idleAccessibilityValue: 空闲状态的无障碍值。
    ///   - pullingAccessibilityValue: 下拉状态的无障碍值。
    ///   - triggeredAccessibilityValue: 已触发状态的无障碍值。
    ///   - activeAccessibilityValue: 刷新中状态的无障碍值。
    ///   - endingAccessibilityValue: 结束状态的无障碍值。
    public init(
        idle: String = "下拉刷新",
        pulling: String = "下拉刷新",
        triggered: String = "释放刷新",
        active: String = "正在刷新...",
        ending: String = "刷新完成",
        accessibilityLabel: String = "刷新",
        idleAccessibilityValue: String = "未刷新",
        pullingAccessibilityValue: String = "下拉中",
        triggeredAccessibilityValue: String = "释放刷新",
        activeAccessibilityValue: String = "正在刷新",
        endingAccessibilityValue: String = "刷新完成"
    ) {
        self.idle = idle
        self.pulling = pulling
        self.triggered = triggered
        self.active = active
        self.ending = ending
        self.accessibilityLabel = accessibilityLabel
        self.idleAccessibilityValue = idleAccessibilityValue
        self.pullingAccessibilityValue = pullingAccessibilityValue
        self.triggeredAccessibilityValue = triggeredAccessibilityValue
        self.activeAccessibilityValue = activeAccessibilityValue
        self.endingAccessibilityValue = endingAccessibilityValue
    }
}

/// 底部上拉加载更多样式的可见文案和 VoiceOver 文案。
public struct BottomLoadMoreTexts {
    /// 空闲状态显示的文案。
    public var idle: String

    /// 用户上拉但尚未达到触发距离时显示的文案。
    public var pulling: String

    /// 已达到触发距离、等待用户松手时显示的文案。
    public var triggered: String

    /// 加载动作执行中显示的文案。
    public var active: String

    /// 加载动作结束并开始收起时显示的文案。
    public var ending: String

    /// 没有更多数据状态显示的文案。
    public var noMoreData: String

    /// 底部加载更多视图的无障碍标签。
    public var accessibilityLabel: String

    /// 空闲状态的无障碍值。
    public var idleAccessibilityValue: String

    /// 上拉状态的无障碍值。
    public var pullingAccessibilityValue: String

    /// 已触发状态的无障碍值。
    public var triggeredAccessibilityValue: String

    /// 加载中状态的无障碍值。
    public var activeAccessibilityValue: String

    /// 结束状态的无障碍值。
    public var endingAccessibilityValue: String

    /// 没有更多数据状态的无障碍值。
    public var noMoreDataAccessibilityValue: String

    /// 创建底部上拉加载更多文案。
    ///
    /// - Parameters:
    ///   - idle: 空闲状态显示的文案。
    ///   - pulling: 用户上拉但尚未达到触发距离时显示的文案。
    ///   - triggered: 已达到触发距离、等待用户松手时显示的文案。
    ///   - active: 加载动作执行中显示的文案。
    ///   - ending: 加载动作结束并开始收起时显示的文案。
    ///   - noMoreData: 没有更多数据状态显示的文案。
    ///   - accessibilityLabel: 底部加载更多视图的无障碍标签。
    ///   - idleAccessibilityValue: 空闲状态的无障碍值。
    ///   - pullingAccessibilityValue: 上拉状态的无障碍值。
    ///   - triggeredAccessibilityValue: 已触发状态的无障碍值。
    ///   - activeAccessibilityValue: 加载中状态的无障碍值。
    ///   - endingAccessibilityValue: 结束状态的无障碍值。
    ///   - noMoreDataAccessibilityValue: 没有更多数据状态的无障碍值。
    public init(
        idle: String = "上拉加载更多",
        pulling: String = "上拉加载更多",
        triggered: String = "释放加载",
        active: String = "正在加载...",
        ending: String = "加载完成",
        noMoreData: String = "没有更多数据",
        accessibilityLabel: String = "加载更多",
        idleAccessibilityValue: String = "未加载",
        pullingAccessibilityValue: String = "上拉中",
        triggeredAccessibilityValue: String = "释放加载",
        activeAccessibilityValue: String = "正在加载",
        endingAccessibilityValue: String = "加载完成",
        noMoreDataAccessibilityValue: String = "没有更多数据"
    ) {
        self.idle = idle
        self.pulling = pulling
        self.triggered = triggered
        self.active = active
        self.ending = ending
        self.noMoreData = noMoreData
        self.accessibilityLabel = accessibilityLabel
        self.idleAccessibilityValue = idleAccessibilityValue
        self.pullingAccessibilityValue = pullingAccessibilityValue
        self.triggeredAccessibilityValue = triggeredAccessibilityValue
        self.activeAccessibilityValue = activeAccessibilityValue
        self.endingAccessibilityValue = endingAccessibilityValue
        self.noMoreDataAccessibilityValue = noMoreDataAccessibilityValue
    }
}

struct RefreshStyleAccessibilityEnvironment {
    var isReduceMotionEnabled: Bool
    var isReduceTransparencyEnabled: Bool

    @MainActor
    static var current: RefreshStyleAccessibilityEnvironment {
        RefreshStyleAccessibilityEnvironment(
            isReduceMotionEnabled: UIAccessibility.isReduceMotionEnabled,
            isReduceTransparencyEnabled: UIAccessibility.isReduceTransparencyEnabled
        )
    }
}
