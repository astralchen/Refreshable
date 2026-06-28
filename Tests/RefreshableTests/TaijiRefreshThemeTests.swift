import Testing
@testable import Refreshable
import UIKit

@Suite("TaijiRefreshTheme")
@MainActor
struct TaijiRefreshThemeTests {

    @Test("system theme resolves different light and dark palettes")
    func systemThemeResolvesTraits() {
        let light = TaijiRefreshTheme.system.resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .light)
        )
        let dark = TaijiRefreshTheme.system.resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .dark)
        )

        #expect(light != dark)
        #expect(!light.backgroundTint.isEqual(dark.backgroundTint))
        #expect(!light.shadowCore.isEqual(dark.shadowCore))
    }

    @Test("explicit themes ignore current trait style")
    func explicitThemesIgnoreTraits() {
        let lightInDarkTraits = TaijiRefreshTheme.light.resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .dark)
        )
        let darkInLightTraits = TaijiRefreshTheme.dark.resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .light)
        )

        #expect(lightInDarkTraits == .light)
        #expect(darkInLightTraits == .dark)
    }

    @Test("custom theme returns the supplied palette")
    func customThemeReturnsPalette() {
        let palette = TaijiRefreshPalette(
            backgroundTint: .red,
            primaryGlow: .green,
            secondaryGlow: .blue,
            glassHighlight: .white,
            shadowCore: .black,
            particle: .yellow
        )

        let resolved = TaijiRefreshTheme.custom(palette).resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .dark)
        )

        #expect(resolved == palette)
    }
}
