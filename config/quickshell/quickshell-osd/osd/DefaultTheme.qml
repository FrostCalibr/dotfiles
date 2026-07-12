import QtQuick
import ".." as LocalColors

QtObject {
  id: themeRoot
  
  // Instantiates the MatugenColors generated in the parent config folder
  readonly property var colors: LocalColors.MatugenColors {}

  readonly property color bgBase: colors.surfaceContainer
  readonly property color bgSurface: colors.surfaceContainerHigh
  readonly property color bgOverlay: "#88000000"
  readonly property color bgHover: colors.surfaceBright
  readonly property color bgSelected: colors.surfaceVariant
  readonly property color bgBorder: colors.outline
  
  readonly property color textPrimary: colors.on_surface
  readonly property color textSecondary: colors.on_surface_variant
  readonly property color textMuted: colors.outlineVariant
  
  readonly property color accentPrimary: colors.primary
  readonly property color accentCyan: colors.secondary
  readonly property color accentGreen: colors.primaryContainer
  readonly property color accentOrange: colors.secondaryContainer
  readonly property color accentRed: colors.error
}
