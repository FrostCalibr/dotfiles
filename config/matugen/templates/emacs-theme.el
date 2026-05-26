;;; matugen-theme.el --- Dynamically compiled Material Design 3 theme -*- lexical-binding: t; -*-

(deftheme matugen
  "A dynamic theme generated from wallpaper assets via the Matugen engine.")

(let ((background "{{ colors.background.default.hex }}")
      (foreground "{{ colors.on_background.default.hex }}")
      (primary "{{ colors.primary.default.hex }}")
      (on-primary "{{ colors.on_primary.default.hex }}")
      (primary-container "{{ colors.primary_container.default.hex }}")
      (on-primary-container "{{ colors.on_primary_container.default.hex }}")
      (secondary "{{ colors.secondary.default.hex }}")
      (tertiary "{{ colors.tertiary.default.hex }}")
      (surface "{{ colors.surface.default.hex }}")
      (surface-dim "{{ colors.surface_dim.default.hex }}")
      (outline "{{ colors.outline.default.hex }}")
      (error-color "{{ colors.error.default.hex }}"))

  (custom-theme-set-faces
   'matugen
   `(default ((t (:background ,background :foreground ,foreground))))
   `(cursor ((t (:background ,primary))))
   `(fringe ((t (:background ,background))))
   `(mode-line ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(mode-line-inactive ((t (:background ,surface-dim :foreground ,outline))))
   `(region ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(minibuffer-prompt ((t (:foreground ,primary :weight bold))))
   `(font-lock-comment-face ((t (:foreground ,outline :slant italic))))
   `(font-lock-keyword-face ((t (:foreground ,primary :weight bold))))
   `(font-lock-string-face ((t (:foreground ,secondary))))
   `(font-lock-function-name-face ((t (:foreground ,tertiary :weight bold))))
   `(font-lock-variable-name-face ((t (:foreground ,foreground))))
   `(font-lock-type-face ((t (:foreground ,primary))))
   `(font-lock-constant-face ((t (:foreground ,tertiary))))
   `(font-lock-warning-face ((t (:foreground ,error-color :weight bold))))
   `(line-number ((t (:foreground ,outline :background ,nil))))
   `(line-number-current-line ((t (:foreground ,primary :background ,surface :weight bold))))))

(provide-theme 'matugen)
