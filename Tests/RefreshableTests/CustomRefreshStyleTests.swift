import Testing
@testable import Refreshable
import UIKit

@Suite("Custom Refresh Styles", .tags(.ui))
@MainActor
struct CustomRefreshStyleTests {

    @Test("VideoTopRefreshStyle exposes reusable video refresh UI")
    func videoTopRefreshStyleStateText() throws {
        let style = VideoTopRefreshStyle()
        let label = try #require(style.view.firstSubview(of: UILabel.self))

        #expect(style.extent == 44)
        #expect(style.view.isAccessibilityElement)
        #expect(style.view.firstSubview(of: UIVisualEffectView.self) != nil)

        style.update(state: .pulling(0.5), progress: 0.5)
        #expect(label.text == "继续下拉刷新视频")
        #expect(style.view.accessibilityValue == "下拉中")

        style.update(state: .triggered, progress: 1)
        #expect(label.text == "释放刷新视频")
        #expect(style.view.accessibilityValue == "释放刷新")

        style.update(state: .refreshing, progress: 0)
        #expect(label.text == "正在刷新视频")
        #expect(style.view.accessibilityValue == "正在刷新")
        let indicator = try #require(style.view.firstSubview(of: UIActivityIndicatorView.self))
        #expect(indicator.isAnimating)

        style.update(state: .ending, progress: 0)
        #expect(label.text == "视频已刷新")
        #expect(style.view.accessibilityValue == "刷新完成")
    }

    @Test("VideoBottomLoadMoreStyle exposes reusable video load-more UI")
    func videoBottomLoadMoreStyleStateText() throws {
        let style = VideoBottomLoadMoreStyle(extent: 76)
        let label = try #require(style.view.firstSubview(of: UILabel.self))

        #expect(style.extent == 76)
        #expect(style.view.isAccessibilityElement)
        #expect(style.view.firstSubview(of: UIVisualEffectView.self) != nil)

        style.update(state: .pulling(0.5), progress: 0.5)
        #expect(label.text == "继续上拉加载视频")
        #expect(style.view.accessibilityValue == "上拉中")

        style.update(state: .triggered, progress: 1)
        #expect(label.text == "释放加载视频")
        #expect(style.view.accessibilityValue == "释放加载")

        style.update(state: .refreshing, progress: 0)
        #expect(label.text == "正在加载视频")
        #expect(style.view.accessibilityValue == "正在加载")
        let indicator = try #require(style.view.firstSubview(of: UIActivityIndicatorView.self))
        #expect(indicator.isAnimating)

        style.update(state: .noMoreData, progress: 0)
        #expect(label.text == "没有更多视频")
        #expect(style.view.accessibilityValue == "没有更多视频")
        #expect(indicator.isAnimating == false)
    }

    @Test("Video overlay styles allow custom text and extent")
    func videoOverlayStylesAllowCustomTextAndExtent() throws {
        let topStyle = VideoTopRefreshStyle(
            extent: 52,
            texts: VideoTopRefreshTexts(
                idle: "Pull video",
                pulling: "Keep pulling video",
                triggered: "Release video",
                refreshing: "Refreshing video",
                ending: "Video refreshed",
                accessibilityLabel: "Video refresh",
                idleAccessibilityValue: "Idle",
                pullingAccessibilityValue: "Pulling",
                triggeredAccessibilityValue: "Ready",
                refreshingAccessibilityValue: "Refreshing",
                endingAccessibilityValue: "Done"
            )
        )
        let topLabel = try #require(topStyle.view.firstSubview(of: UILabel.self))
        topStyle.update(state: .triggered, progress: 1)

        #expect(topStyle.extent == 52)
        #expect(topLabel.text == "Release video")
        #expect(topStyle.view.accessibilityLabel == "Video refresh")
        #expect(topStyle.view.accessibilityValue == "Ready")

        let bottomStyle = VideoBottomLoadMoreStyle(
            extent: 68,
            texts: VideoBottomLoadMoreTexts(
                idle: "Pull more video",
                pulling: "Keep pulling more video",
                triggered: "Release more video",
                refreshing: "Loading video",
                ending: "Loaded video",
                noMoreData: "No more video",
                accessibilityLabel: "Video load more",
                idleAccessibilityValue: "Idle",
                pullingAccessibilityValue: "Pulling",
                triggeredAccessibilityValue: "Ready",
                refreshingAccessibilityValue: "Loading",
                endingAccessibilityValue: "Done",
                noMoreDataAccessibilityValue: "Complete"
            )
        )
        let bottomLabel = try #require(bottomStyle.view.firstSubview(of: UILabel.self))
        bottomStyle.update(state: .noMoreData, progress: 0)

        #expect(bottomStyle.extent == 68)
        #expect(bottomLabel.text == "No more video")
        #expect(bottomStyle.view.accessibilityLabel == "Video load more")
        #expect(bottomStyle.view.accessibilityValue == "Complete")
    }

    @Test("SystemNativeRefreshStyle exposes compact native state text")
    func systemNativeStateText() {
        let style = SystemNativeRefreshStyle()

        #expect(style.extent == 64)
        #expect(style.view.isAccessibilityElement)

        style.update(state: .idle, progress: 0)
        #expect(style.view.accessibilityValue == "未刷新")

        style.update(state: .pulling(0.5), progress: 0.5)
        #expect(style.view.accessibilityValue == "下拉中")
        #expect(style.view.containsVisibleLabel(text: "下拉刷新"))

        style.update(state: .triggered, progress: 1)
        #expect(style.view.accessibilityValue == "释放刷新")
        #expect(style.view.containsVisibleLabel(text: "释放刷新"))

        style.update(state: .refreshing, progress: 0)
        #expect(style.view.accessibilityValue == "正在刷新")
        #expect(style.view.containsVisibleLabel(text: "正在刷新..."))
    }

    @Test("SystemNativeRefreshStyle shows last updated subtitle")
    func systemNativeShowsLastUpdatedSubtitle() {
        let style = SystemNativeRefreshStyle()

        style.update(state: .refreshing, progress: 0)

        #expect(style.view.containsLabel(text: "上次更新：刚刚"))
    }

    @Test("SystemNativeRefreshStyle uses design structure when triggered")
    func systemNativeUsesDesignStructureWhenTriggered() throws {
        let style = SystemNativeRefreshStyle()

        style.update(state: .triggered, progress: 1)

        #expect(style.view.accessibilityValue == "释放刷新")
        #expect(style.view.containsVisibleLabel(text: "释放刷新"))
        #expect(style.view.containsVisibleLabel(text: "正在刷新...") == false)
        #expect(style.view.containsVisibleLabel(text: "上次更新：刚刚") == false)

        let iconArrow = try #require(style.view.systemNativeIconArrow())
        #expect(iconArrow.isHidden)

        let spinner = try #require(style.view.firstSubview(className: "SystemNativeSpinnerView"))
        let segments = try #require(spinner.layer.sublayers as? [CAShapeLayer])
        let alphas = Set(segments.map { round(($0.fillColor?.alpha ?? 0) * 100) / 100 })
        #expect(alphas.count >= 4)
    }

    @Test("SystemNativeRefreshStyle keeps the pull hint arrow pointing down")
    func systemNativeHintArrowPointsDown() throws {
        let style = SystemNativeRefreshStyle()
        let hintArrow = try #require(style.view.systemNativeHintArrow())
        let actualImage = try #require(hintArrow.image)
        let expectedImage = try #require(UIImage(
            systemName: "arrow.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        ))

        #expect(
            actualImage.renderedSymbolData(size: CGSize(width: 24, height: 14))
                == expectedImage.renderedSymbolData(size: CGSize(width: 24, height: 14))
        )
    }

    @Test("SystemNativeRefreshStyle rotates the pull hint arrow with pull progress")
    func systemNativeHintArrowRotatesWithPullProgress() throws {
        let style = SystemNativeRefreshStyle()
        let hintArrow = try #require(style.view.systemNativeHintArrow())

        style.update(state: .pulling(0.5), progress: 0.5)
        #expect(hintArrow.transform.rotationAngle.isApproximately(.pi / 2))

        style.update(state: .pulling(1.2), progress: 1.2)
        #expect(hintArrow.transform.rotationAngle.isApproximately(.pi))

        style.update(state: .triggered, progress: 1)
        #expect(hintArrow.transform.rotationAngle.isApproximately(.pi))

        style.update(state: .idle, progress: 0)
        #expect(hintArrow.transform.rotationAngle.isApproximately(0))
    }

    @Test("SystemNativeRefreshStyle uses custom spinner while refreshing")
    func systemNativeUsesCustomSpinnerWhileRefreshing() throws {
        let style = SystemNativeRefreshStyle()

        style.update(state: .refreshing, progress: 0)

        #expect(style.view.firstSubview(of: UIActivityIndicatorView.self) == nil)
        let spinner = try #require(style.view.firstSubview(className: "SystemNativeSpinnerView"))
        #expect(spinner.isHidden == false)
        #expect(spinner.layer.animation(forKey: "systemNativeSpin") != nil)
    }

    @Test("SystemNativeRefreshStyle visibly rebuilds spinner with pull progress")
    func systemNativeVisiblyRebuildsSpinnerWithPullProgress() throws {
        let style = SystemNativeRefreshStyle()
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)
        style.view.layoutIfNeeded()

        let spinner = try #require(style.view.firstSubview(className: "SystemNativeSpinnerView"))

        style.update(state: .pulling(0.2), progress: 0.2)
        spinner.layoutIfNeeded()
        let iconArrow = try #require(style.view.systemNativeIconArrow())
        #expect(iconArrow.isHidden)
        let lowSegments = try #require(spinner.layer.sublayers as? [CAShapeLayer])
        let lowMaxArea = lowSegments.map { $0.bounds.width * $0.bounds.height }.max() ?? 0
        let lowVisibleCount = lowSegments.filter { ($0.fillColor?.alpha ?? 0) > 0.08 }.count

        style.update(state: .pulling(0.9), progress: 0.9)
        spinner.layoutIfNeeded()
        let highSegments = try #require(spinner.layer.sublayers as? [CAShapeLayer])
        let highMaxArea = highSegments.map { $0.bounds.width * $0.bounds.height }.max() ?? 0
        let highVisibleCount = highSegments.filter { ($0.fillColor?.alpha ?? 0) > 0.08 }.count

        #expect(lowVisibleCount <= 4)
        #expect(highVisibleCount >= 10)
        #expect(highMaxArea > lowMaxArea * 3)
    }

    @Test("SystemNativeRefreshStyle keeps expanding spinner while triggered pull continues")
    func systemNativeKeepsExpandingSpinnerWhileTriggeredPullContinues() throws {
        let style = SystemNativeRefreshStyle()
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)
        style.view.layoutIfNeeded()

        let spinner = try #require(style.view.firstSubview(className: "SystemNativeSpinnerView"))

        style.update(state: .triggered, progress: 1)
        spinner.layoutIfNeeded()
        let triggeredSegments = try #require(spinner.layer.sublayers as? [CAShapeLayer])
        let triggeredMaxArea = triggeredSegments.map { $0.bounds.width * $0.bounds.height }.max() ?? 0

        style.update(state: .triggered, progress: 1.7)
        spinner.layoutIfNeeded()
        let continuedPullSegments = try #require(spinner.layer.sublayers as? [CAShapeLayer])
        let continuedPullMaxArea = continuedPullSegments.map { $0.bounds.width * $0.bounds.height }.max() ?? 0

        #expect(continuedPullMaxArea > triggeredMaxArea * 1.2)
    }

    @Test("TaijiRefreshStyle maps refresh states without visible text")
    func taijiStateMapping() {
        let style = TaijiRefreshStyle()

        #expect(style.extent == 92)
        #expect(style.view.isAccessibilityElement)
        #expect(style.view.subviews.isEmpty == false)

        style.update(state: .pulling(0.5), progress: 0.5)
        #expect(style.view.accessibilityValue == "下拉中")

        style.update(state: .refreshing, progress: 0)
        #expect(style.view.accessibilityValue == "正在刷新")

        style.update(state: .ending, progress: 0)
        #expect(style.view.accessibilityValue == "刷新完成")
    }

    @Test("TaijiRefreshStyle supports runtime theme switching")
    func taijiThemeSwitching() {
        let style = TaijiRefreshStyle(theme: .dark)

        style.setTheme(.light, animated: false)

        #expect(style.theme == .light)
    }

    @Test("TaijiRefreshStyle keeps glass atmosphere compact")
    func taijiUsesCompactGlassAtmosphere() throws {
        let style = TaijiRefreshStyle(theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)
        style.view.layoutIfNeeded()

        style.update(state: .refreshing, progress: 1)
        style.view.layoutIfNeeded()

        let symbol = try #require(style.view.firstSubview(className: "TaijiSymbolView"))
        #expect(symbol.bounds.width <= 56)
        #expect(symbol.bounds.width >= 44)

        let gradients = style.view.layer.allSublayers(of: CAGradientLayer.self)
        #expect(gradients.isEmpty == false)
        #expect(gradients.allSatisfy { $0.frame.width <= 260 })
        #expect(gradients.allSatisfy { $0.frame.width < style.view.bounds.width * 0.75 })
    }

    @Test("TaijiRefreshStyle avoids a solid platform under the symbol")
    func taijiAvoidsSolidPlatform() throws {
        let style = TaijiRefreshStyle(theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)
        style.view.layoutIfNeeded()

        style.update(state: .refreshing, progress: 1)
        style.view.layoutIfNeeded()

        let baseLayer = try #require(style.view.layer.sublayers?.first as? CAShapeLayer)
        #expect(baseLayer.fillColor?.alpha ?? 0 <= 0.12)
        #expect(baseLayer.opacity <= 0.42)
        #expect(baseLayer.shadowOpacity <= 0.24)
    }

    @Test("TaijiRefreshStyle communicates pull progress through body energy")
    func taijiCommunicatesPullProgressThroughBodyEnergy() throws {
        let style = TaijiRefreshStyle(theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)
        style.view.layoutIfNeeded()

        let symbol = try #require(style.view.firstSubview(className: "TaijiSymbolView"))
        let patternLayer = try #require(symbol.layer.sublayers?.first { $0.name == "taijiPatternLayer" })
        let rimLayer = try #require(symbol.layer.allSublayers(of: CAShapeLayer.self).first { $0.name == "taijiRimLayer" })
        let lowerGlowLayer = try #require(symbol.layer.allSublayers(of: CAShapeLayer.self).first { $0.name == "taijiLowerGlowLayer" })
        let mistLayer = try #require(style.view.layer.allSublayers(of: CAGradientLayer.self).first)

        style.update(state: .pulling(0.2), progress: 0.2)
        style.view.layoutIfNeeded()
        let lowScale = symbol.transform.a
        let lowPatternRotation = abs(atan2(patternLayer.affineTransform().b, patternLayer.affineTransform().a))
        let lowRimWidth = rimLayer.lineWidth
        let lowGlowOpacity = lowerGlowLayer.opacity
        let lowMistOpacity = mistLayer.opacity
        let lowParticleCount = style.view.visibleTaijiParticleLayers().count

        style.update(state: .pulling(0.9), progress: 0.9)
        style.view.layoutIfNeeded()
        let highScale = symbol.transform.a
        let highPatternRotation = abs(atan2(patternLayer.affineTransform().b, patternLayer.affineTransform().a))
        let highRimWidth = rimLayer.lineWidth
        let highGlowOpacity = lowerGlowLayer.opacity
        let highMistOpacity = mistLayer.opacity
        let highParticleCount = style.view.visibleTaijiParticleLayers().count

        #expect(highScale > lowScale)
        #expect(highPatternRotation > lowPatternRotation + 0.18)
        #expect(highRimWidth > lowRimWidth)
        #expect(highGlowOpacity > lowGlowOpacity)
        #expect(highMistOpacity > lowMistOpacity)
        #expect(highParticleCount > lowParticleCount)
    }

    @Test("TaijiRefreshStyle keeps the glass body as the visual focal point")
    func taijiKeepsGlassBodyAsFocalPoint() throws {
        let style = TaijiRefreshStyle(theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)
        style.view.layoutIfNeeded()

        style.update(state: .refreshing, progress: 1)
        style.view.layoutIfNeeded()

        let symbol = try #require(style.view.firstSubview(className: "TaijiSymbolView"))
        let shellLayers = symbol.layer.sublayers?.compactMap { $0 as? CAShapeLayer } ?? []
        #expect(shellLayers.count >= 3)
        #expect(shellLayers.contains { $0.lineWidth >= 2.4 && ($0.strokeColor?.alpha ?? 0) >= 0.35 })
        #expect(shellLayers.contains { ($0.fillColor?.alpha ?? 0) > 0.08 && ($0.fillColor?.alpha ?? 0) <= 0.28 })

        let activeOrbitLayers = (style.view.layer.sublayers ?? [])
            .compactMap { $0 as? CAShapeLayer }
            .filter { ["taijiBackOrbitLayer", "taijiFrontOrbitLayer"].contains($0.name) }
            .filter { $0.path != nil || $0.opacity > 0 || $0.strokeEnd > 0 }
        #expect(activeOrbitLayers.isEmpty)
    }

    @Test("TaijiRefreshStyle spins the inner taiji while keeping the body front facing")
    func taijiSpinsInnerArtworkWhileKeepingBodyFrontFacing() throws {
        let style = TaijiRefreshStyle(theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)
        style.view.layoutIfNeeded()

        style.update(state: .pulling(0.9), progress: 0.9)
        style.view.layoutIfNeeded()

        let symbol = try #require(style.view.firstSubview(className: "TaijiSymbolView"))
        let coreLayer = try #require(symbol.layer.sublayers?.first { $0.name == "taijiCoreLayer" })
        let patternLayer = try #require(symbol.layer.sublayers?.first { $0.name == "taijiPatternLayer" })
        #expect(abs(symbol.transform.b) < 0.001)
        #expect(abs(symbol.transform.c) < 0.001)
        #expect(abs(coreLayer.affineTransform().b) < 0.001)
        #expect(abs(coreLayer.affineTransform().c) < 0.001)

        style.update(state: .triggered, progress: 1)
        #expect(abs(symbol.transform.b) < 0.001)
        #expect(abs(symbol.transform.c) < 0.001)
        #expect(abs(coreLayer.affineTransform().b) < 0.001)
        #expect(abs(coreLayer.affineTransform().c) < 0.001)

        style.update(state: .refreshing, progress: 1)
        #expect(symbol.layer.animation(forKey: "taijiSpin") == nil)

        #expect(coreLayer.animation(forKey: "taijiCoreSpin") == nil)
        #expect(patternLayer.animation(forKey: "taijiPatternSpin") != nil)

        #expect(style.view.visibleTaijiOrbitLayers().isEmpty)
    }

    @Test("TaijiRefreshStyle removes orbit arcs from every visible state")
    func taijiRemovesOrbitArcsFromEveryVisibleState() {
        let style = TaijiRefreshStyle(theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)
        style.view.layoutIfNeeded()

        style.update(state: .pulling(0.9), progress: 0.9)
        style.view.layoutIfNeeded()
        #expect(style.view.visibleTaijiOrbitLayers().isEmpty)

        style.update(state: .triggered, progress: 1)
        style.view.layoutIfNeeded()
        #expect(style.view.visibleTaijiOrbitLayers().isEmpty)

        style.update(state: .refreshing, progress: 1)
        style.view.layoutIfNeeded()
        #expect(style.view.visibleTaijiOrbitLayers().isEmpty)

        style.update(state: .ending, progress: 1)
        style.view.layoutIfNeeded()
        #expect(style.view.visibleTaijiOrbitLayers().isEmpty)
    }

    @Test("KineticRefreshStyle exposes playful state text")
    func kineticStateText() {
        let style = KineticRefreshStyle()

        #expect(style.extent == 82)
        #expect(style.view.isAccessibilityElement)

        style.update(state: .triggered, progress: 1)
        #expect(style.view.accessibilityValue == "释放刷新")

        style.update(state: .refreshing, progress: 0)
        #expect(style.view.accessibilityValue == "正在更新")
    }

    @Test("KineticRefreshStyle uses faded ribbon and full particle set")
    func kineticUsesFadedRibbonAndFullParticleSet() throws {
        let style = KineticRefreshStyle()

        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)
        style.view.layoutIfNeeded()
        style.update(state: .refreshing, progress: 1)

        let gradient = try #require(style.view.layer.firstSublayer(of: CAGradientLayer.self))
        let colors = try #require(gradient.colors as? [CGColor])
        #expect(UIColor(cgColor: colors.first!).cgColor.alpha < 0.2)
        #expect(UIColor(cgColor: colors.last!).cgColor.alpha < 0.2)

        let shapeLayers = style.view.layer.allSublayers(of: CAShapeLayer.self)
        let ribbonLayers = shapeLayers.filter { abs($0.lineWidth - 3.5) < 0.01 }
        let particleLayers = shapeLayers.filter { $0.fillColor != nil && $0.bounds.width <= 12 && $0.bounds.height <= 36 }

        #expect(ribbonLayers.count >= 2)
        #expect(particleLayers.count == 11)
    }
}

private extension UIView {
    func containsLabel(text: String) -> Bool {
        if let label = self as? UILabel, label.text == text {
            return true
        }

        return subviews.contains { $0.containsLabel(text: text) }
    }

    func containsVisibleLabel(text: String) -> Bool {
        if let label = self as? UILabel, label.text == text, label.isEffectivelyVisible {
            return true
        }

        return subviews.contains { $0.containsVisibleLabel(text: text) }
    }

    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }

        for subview in subviews {
            if let match = subview.firstSubview(of: type) {
                return match
            }
        }

        return nil
    }

    func firstSubview(className: String) -> UIView? {
        if String(describing: type(of: self)) == className {
            return self
        }

        for subview in subviews {
            if let match = subview.firstSubview(className: className) {
                return match
            }
        }

        return nil
    }

    func allSubviews<T: UIView>(of type: T.Type) -> [T] {
        var matches: [T] = []
        if let view = self as? T {
            matches.append(view)
        }

        for subview in subviews {
            matches.append(contentsOf: subview.allSubviews(of: type))
        }

        return matches
    }

    func systemNativeIconArrow() -> UIImageView? {
        allSubviews(of: UIImageView.self).first { imageView in
            imageView.superview?.firstSubview(className: "SystemNativeSpinnerView") != nil
        }
    }

    func systemNativeHintArrow() -> UIImageView? {
        let iconArrow = systemNativeIconArrow()
        return allSubviews(of: UIImageView.self).first { imageView in
            imageView !== iconArrow
        }
    }

    func visibleTaijiOrbitLayers() -> [CAShapeLayer] {
        layer.allSublayers(of: CAShapeLayer.self).filter { shapeLayer in
            guard ["taijiBackOrbitLayer", "taijiFrontOrbitLayer"].contains(shapeLayer.name) else {
                return false
            }

            return shapeLayer.path != nil || shapeLayer.opacity > 0 || shapeLayer.strokeEnd > 0
        }
    }

    func visibleTaijiParticleLayers() -> [CAShapeLayer] {
        layer.allSublayers(of: CAShapeLayer.self).filter { shapeLayer in
            shapeLayer.name == "taijiParticleLayer" && shapeLayer.opacity > 0.05
        }
    }

    private var isEffectivelyVisible: Bool {
        guard !isHidden, alpha > 0.01 else { return false }
        var ancestor = superview
        while let currentAncestor = ancestor {
            guard !currentAncestor.isHidden, currentAncestor.alpha > 0.01 else { return false }
            ancestor = currentAncestor.superview
        }
        return true
    }
}

private extension UIImage {
    func renderedSymbolData(size: CGSize) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
            withTintColor(.black, renderingMode: .alwaysOriginal).draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension CGAffineTransform {
    var rotationAngle: CGFloat {
        atan2(b, a)
    }
}

private extension CGFloat {
    func isApproximately(_ other: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
        abs(self - other) <= tolerance
    }
}

private extension CALayer {
    func firstSublayer<T: CALayer>(of type: T.Type) -> T? {
        if let layer = self as? T {
            return layer
        }

        if let match = mask?.firstSublayer(of: type) {
            return match
        }

        for sublayer in sublayers ?? [] {
            if let match = sublayer.firstSublayer(of: type) {
                return match
            }
        }

        return nil
    }

    func allSublayers<T: CALayer>(of type: T.Type) -> [T] {
        var matches: [T] = []
        if let layer = self as? T {
            matches.append(layer)
        }

        if let mask {
            matches.append(contentsOf: mask.allSublayers(of: type))
        }

        for sublayer in sublayers ?? [] {
            matches.append(contentsOf: sublayer.allSublayers(of: type))
        }

        return matches
    }
}
