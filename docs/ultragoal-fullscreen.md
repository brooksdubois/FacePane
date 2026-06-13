Now add double-click fullscreen behavior to the Windowpane macOS app.

Current architecture:
- SwiftUI OverlayRootView is hosted inside an AppKit OverlayWindow
- WindowController creates the window
- The app shows a live camera preview

Goal:
Double-clicking the camera pane should toggle between the normal floating window size and a fullscreen-style presentation.

Requirements:
1. A double-click anywhere on the camera preview/root pane toggles fullscreen mode.
2. Preserve the previous window frame before entering fullscreen.
3. On fullscreen enter:
   - Move the window to the visible frame of the current screen.
   - Remove or visually hide normal titlebar chrome if needed.
   - Keep the camera preview aspect-fill.
   - Keep the window above normal windows.
4. On fullscreen exit:
   - Restore the exact previous frame.
   - Restore floating overlay behavior.
5. Do not use native macOS fullscreen spaces mode if it creates a separate fullscreen Space. We want instant overlay-style fullscreen on the current screen with no animation.
6. Alt+shift+f should trigger the fullscreen mode. Escape key should exit fullscreen if active.
7. Keep the code clean: WindowController should own window frame/fullscreen state.
8. SwiftUI should only send intent/events upward, not directly mutate AppKit window geometry if avoidable.
9. Do not break dragging/resizing in normal mode.

Output policy:
- Do not dump full source files into the TUI.
- Edit files directly.
- After editing, summarize:
  1. files changed
  2. behavior implemented
  3. commands to build/test
  4. any known limitations