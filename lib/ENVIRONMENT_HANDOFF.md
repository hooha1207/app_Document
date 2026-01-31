# Project Environment & Technical Handoff

## Core Environment
- **Flutter Version**: 3.38.3 (Stable)
- **Dart Version**: 3.10.1
- **Target SDK Constraint**: `sdk: ^3.10.1`

## Critical Dependencies
- **Navigation**: `go_router: ^17.0.1`
- **LaTeX Rendering**: `flutter_math_fork: ^0.7.4`
- **Media**: `video_player`, `audioplayers`, `youtube_player_flutter`
- **Storage**: `hive`, `hive_flutter`

## Development Guidelines (Anti-Patterns to Avoid)

### 1. API Compatibility
- **DO NOT USE `withValues`**: While newer Flutter versions support it, the project setup prefers stability. Use `.withOpacity(alpha)` or legacy `.withOpacity()` to ensure compatibility.
- **DO NOT USE `dashStyle` in `Border.all`**: This parameter does not exist in the Flutter framework. For dashed borders, use a custom painter or the `dotted_border` package (not currently in pubspec).

### 2. Layout & Side-by-Side (Wrap)
- **Sub-pixel Epsilon**: When placing two 50% width blocks side-by-side in a `Wrap` widget, subtract a small epsilon (e.g., `0.5` or `1.0`) from the calculated width to prevent wrapping due to floating-point rounding errors on different screen densities.
- **Cross-axis Alignment**: Ensure `Wrap` has `crossAxisAlignment: WrapCrossAlignment.start` to prevent blocks of different heights from causing large layout gaps.

### 3. Drag-and-Drop Stability
- **Nested DragTargets**: Avoid wrapping the entire editor in a `DragTarget` while child blocks also have `DragTargets`. This causes "Cannot hit test a render box that has never been laid out" errors.
- **APPEND ZONE**: Use a dedicated, non-overlapping `DragTarget` at the bottom of the document for appending blocks to the end.
- **Reordering Logic**: Perform list mutations in `onAcceptWithDetails` rather than `onWillAccept` to ensure the layout is stable before the tree is mutated.
- **Feedback Duplication**: Avoid using `GlobalKey`s inside the `feedback` widget of a `Draggable` if that key is already present in the source tree. Use static "Preview" widgets instead.

### 4. Special Features Implementation
- **Snap-to-Grid Resizing**: Blocks snap to specific ratios (`0.25`, `0.33`, `0.48`, `0.5`, `0.66`, `0.75`, `1.0`) during manual resizing for easier side-by-side layout. (Note: `0.48` is used as a safe alternative to `0.5` in some cases).
- **Side-Aware DragTarget**: The `DragTarget` on each block detects if a drop occurs on the left or right half using `RenderBox.globalToLocal`. This determines whether to insert the dragged block before or after the target.
- **Epsilon Adjustment**: Sub-pixel widths in `Wrap` are reduced by `0.5` pixels to prevent wrapping on high-DPI displays where `50% + 50%` might slightly exceed the container width due to rounding.

## Key Files
- `lib/widgets/common_block_editor.dart`: Main editor implementation (Contains DragTarget and Snap logic).
- `lib/models/block_editor_model.dart`: Block structure and controller logic.
- `lib/widgets/media_widgets.dart`: Specific handlers for images, video, and audio.
- `rich_text_module/`: Business logic for the multi-block rich text system.
