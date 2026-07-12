import QtQuick

QtObject {
    property color windowBgColor: "{{colors.surface.default.hex}}"
    
    // Core accents
    property color primary: "{{colors.primary.default.hex}}"
    property color on_primary: "{{colors.on_primary.default.hex}}"
    property color primaryContainer: "{{colors.primary_container.default.hex}}"
    property color on_primary_container: "{{colors.on_primary_container.default.hex}}"
    
    property color secondary: "{{colors.secondary.default.hex}}"
    property color on_secondary: "{{colors.on_secondary.default.hex}}"
    property color secondaryContainer: "{{colors.secondary_container.default.hex}}"
    property color on_secondary_container: "{{colors.on_secondary_container.default.hex}}"
    
    property color tertiary: "{{colors.tertiary.default.hex}}"
    property color on_tertiary: "{{colors.on_tertiary.default.hex}}"
    property color tertiaryContainer: "{{colors.tertiary_container.default.hex}}"
    property color on_tertiary_container: "{{colors.on_tertiary_container.default.hex}}"
    
    property color error: "{{colors.error.default.hex}}"
    property color on_error: "{{colors.on_error.default.hex}}"
    property color errorContainer: "{{colors.error_container.default.hex}}"
    property color on_error_container: "{{colors.on_error_container.default.hex}}"
    
    // Surfaces
    property color surface: "{{colors.surface.default.hex}}"
    property color on_surface: "{{colors.on_surface.default.hex}}"
    property color surfaceVariant: "{{colors.surface_variant.default.hex}}"
    property color on_surface_variant: "{{colors.on_surface_variant.default.hex}}"
    
    property color surfaceBright: "{{colors.surface_bright.default.hex}}"
    property color surfaceDim: "{{colors.surface_dim.default.hex}}"
    property color surfaceContainer: "{{colors.surface_container.default.hex}}"
    property color surfaceContainerLow: "{{colors.surface_container_low.default.hex}}"
    property color surfaceContainerHigh: "{{colors.surface_container_high.default.hex}}"
    property color surfaceContainerHighest: "{{colors.surface_container_highest.default.hex}}"
    
    // Borders & shadows
    property color outline: "{{colors.outline.default.hex}}"
    property color outlineVariant: "{{colors.outline_variant.default.hex}}"
    property color shadow: "{{colors.shadow.default.hex}}"
}
