import UIKit

/// 默认刷新样式的文字、字体和无障碍行为配置。
public struct DefaultRefreshStyleConfiguration {
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

    /// 创建默认刷新样式配置。
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

/// 默认顶部下拉刷新样式的可见文案和 VoiceOver 文案。
public struct DefaultTopRefreshTexts {
    public var idle: String
    public var pulling: String
    public var triggered: String
    public var refreshing: String
    public var ending: String
    public var accessibilityLabel: String
    public var idleAccessibilityValue: String
    public var pullingAccessibilityValue: String
    public var triggeredAccessibilityValue: String
    public var refreshingAccessibilityValue: String
    public var endingAccessibilityValue: String

    /// 创建顶部下拉刷新默认文案。
    public init(
        idle: String = "下拉刷新",
        pulling: String = "下拉刷新",
        triggered: String = "释放刷新",
        refreshing: String = "正在刷新...",
        ending: String = "刷新完成",
        accessibilityLabel: String = "刷新",
        idleAccessibilityValue: String = "未刷新",
        pullingAccessibilityValue: String = "下拉中",
        triggeredAccessibilityValue: String = "释放刷新",
        refreshingAccessibilityValue: String = "正在刷新",
        endingAccessibilityValue: String = "刷新完成"
    ) {
        self.idle = idle
        self.pulling = pulling
        self.triggered = triggered
        self.refreshing = refreshing
        self.ending = ending
        self.accessibilityLabel = accessibilityLabel
        self.idleAccessibilityValue = idleAccessibilityValue
        self.pullingAccessibilityValue = pullingAccessibilityValue
        self.triggeredAccessibilityValue = triggeredAccessibilityValue
        self.refreshingAccessibilityValue = refreshingAccessibilityValue
        self.endingAccessibilityValue = endingAccessibilityValue
    }
}

/// 默认底部上拉加载更多样式的可见文案和 VoiceOver 文案。
public struct DefaultBottomLoadMoreTexts {
    public var idle: String
    public var pulling: String
    public var triggered: String
    public var refreshing: String
    public var ending: String
    public var noMoreData: String
    public var accessibilityLabel: String
    public var idleAccessibilityValue: String
    public var pullingAccessibilityValue: String
    public var triggeredAccessibilityValue: String
    public var refreshingAccessibilityValue: String
    public var endingAccessibilityValue: String
    public var noMoreDataAccessibilityValue: String

    /// 创建底部上拉加载更多默认文案。
    public init(
        idle: String = "上拉加载更多",
        pulling: String = "上拉加载更多",
        triggered: String = "释放加载",
        refreshing: String = "正在加载...",
        ending: String = "加载完成",
        noMoreData: String = "没有更多数据",
        accessibilityLabel: String = "加载更多",
        idleAccessibilityValue: String = "未加载",
        pullingAccessibilityValue: String = "上拉中",
        triggeredAccessibilityValue: String = "释放加载",
        refreshingAccessibilityValue: String = "正在加载",
        endingAccessibilityValue: String = "加载完成",
        noMoreDataAccessibilityValue: String = "没有更多数据"
    ) {
        self.idle = idle
        self.pulling = pulling
        self.triggered = triggered
        self.refreshing = refreshing
        self.ending = ending
        self.noMoreData = noMoreData
        self.accessibilityLabel = accessibilityLabel
        self.idleAccessibilityValue = idleAccessibilityValue
        self.pullingAccessibilityValue = pullingAccessibilityValue
        self.triggeredAccessibilityValue = triggeredAccessibilityValue
        self.refreshingAccessibilityValue = refreshingAccessibilityValue
        self.endingAccessibilityValue = endingAccessibilityValue
        self.noMoreDataAccessibilityValue = noMoreDataAccessibilityValue
    }
}

struct DefaultRefreshStyleAccessibilityEnvironment {
    var isReduceMotionEnabled: Bool
    var isReduceTransparencyEnabled: Bool

    @MainActor
    static var current: DefaultRefreshStyleAccessibilityEnvironment {
        DefaultRefreshStyleAccessibilityEnvironment(
            isReduceMotionEnabled: UIAccessibility.isReduceMotionEnabled,
            isReduceTransparencyEnabled: UIAccessibility.isReduceTransparencyEnabled
        )
    }
}
