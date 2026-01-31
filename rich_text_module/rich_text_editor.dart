import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

/// Segment-based Rich Text Editor
///
/// This module provides a native Flutter TextField with rich text editing capabilities.
/// It uses a segment-based approach where each text piece maintains its own styling.
/// The data model is immutable to support robust undo/redo operations.

/// IMMUTABLE Data model representing a styled text segment
@immutable
class TextSegment {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  const TextSegment(
    this.text, {
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'b': isBold,
        'i': isItalic,
        'u': isUnderline,
      };

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      json['text'] as String? ?? '',
      isBold: json['b'] as bool? ?? false,
      isItalic: json['i'] as bool? ?? false,
      isUnderline: json['u'] as bool? ?? false,
    );
  }

  TextSegment copyWith({
    String? text,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
  }) {
    return TextSegment(
      text ?? this.text,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
    );
  }

  TextStyle get style => TextStyle(
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextSegment &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          isBold == other.isBold &&
          isItalic == other.isItalic &&
          isUnderline == other.isUnderline;

  @override
  int get hashCode =>
      text.hashCode ^ isBold.hashCode ^ isItalic.hashCode ^ isUnderline.hashCode;
}

/// History Manager for Undo/Redo
class _HistoryManager {
  final List<List<TextSegment>> _undoStack = [];
  final List<List<TextSegment>> _redoStack = [];
  static const int _maxHistory = 50; // Limit history size

  void record(List<TextSegment> segments) {
    // Deep copy not strictly needed since TextSegment is immutable,
    // but the List itself is mutable, so we copy the List.
    _undoStack.add(List.from(segments));
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear(); // New action clears redo stack
  }

  List<TextSegment>? undo(List<TextSegment> currentSegments) {
    if (_undoStack.isEmpty) return null;
    
    // Save current state to redo stack
    _redoStack.add(List.from(currentSegments));
    
    return _undoStack.removeLast();
  }

  List<TextSegment>? redo(List<TextSegment> currentSegments) {
    if (_redoStack.isEmpty) return null;

    // Save current state to undo stack (but don't clear redo)
    _undoStack.add(List.from(currentSegments));
    
    return _redoStack.removeLast();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}

/// Custom controller that manages text segments and rich text styling
class SegmentedTextEditingController extends TextEditingController {
  List<TextSegment> _segments = [];
  final _HistoryManager _history = _HistoryManager();

  // Pending styles for the next inserted character (sticky style)
  bool _pendingBold = false;
  bool _pendingItalic = false;
  bool _pendingUnderline = false;

  // Initialization flag to bypass diff logic during initial load
  bool _isInitializing = false;
  // Flag to prevent recording history during internal updates
  bool _isUndoRedoOperation = false;

  SegmentedTextEditingController({String? text}) : super(text: text == null ? '' : null);

  /// Initialize from JSON or plain text
  void initializeFromContext(String contextText) {
    if (contextText.isEmpty) {
      _replaceSegmentsAndNotify([]);
      _isInitializing = true;
      text = '';
      _isInitializing = false;
      _history.clear();
      return;
    }

    List<TextSegment> initialSegments;
    try {
      final List<dynamic> jsonList = jsonDecode(contextText);
      initialSegments = jsonList.map((e) => TextSegment.fromJson(e)).toList();
    } on FormatException catch (e) {
      debugPrint('RichTextEditor: Invalid JSON format, falling back to plain text. Error: $e');
      initialSegments = [TextSegment(contextText)];
    } catch (e) {
      debugPrint('RichTextEditor: Unexpected error during initialization: $e');
      initialSegments = [];
    }

    _segments = initialSegments;
    
    // Set text to match segments without triggering diff
    String newText = _segments.map((e) => e.text).join('');
    _isInitializing = true;
    text = newText;
    if (newText.isNotEmpty) {
      selection = TextSelection.collapsed(offset: newText.length);
    }
    _isInitializing = false;
    _history.clear(); // Clear history after init
  }

  /// Serialize segments to JSON
  String toSegmentJson() {
    return jsonEncode(_segments.map((e) => e.toJson()).toList());
  }

  // Helper to update segments safely
  void _replaceSegmentsAndNotify(List<TextSegment> newSegments) {
    _segments = newSegments;
    // merge is called during diff/operations, so _segments itself is usually merged.
    notifyListeners();
  }
  
  // Undo/Redo Public API
  void undo() {
    final prev = _history.undo(_segments);
    if (prev != null) {
      _applyHistoryState(prev);
    }
  }

  void redo() {
    final next = _history.redo(_segments);
    if (next != null) {
      _applyHistoryState(next);
    }
  }
  
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void _applyHistoryState(List<TextSegment> state) {
    _isUndoRedoOperation = true;
    _segments = state;
    String newText = _segments.map((e) => e.text).join('');
    
    // Attempt to restore cursor safely
    int newSelectionIndex = newText.length;
    // If we had a selection, we might want to map it, but simplest is end or keep relative index
    // Let's safe guard against index out of bounds
    if (selection.baseOffset > newText.length) {
       newSelectionIndex = newText.length;
    } else {
       newSelectionIndex = selection.baseOffset; // Keep roughly same position
    }
    
    text = newText;
    selection = TextSelection.collapsed(offset: newSelectionIndex);
    
    _isUndoRedoOperation = false;
    notifyListeners();
  }

  // Toggle styles
  void toggleBold() {
    if (value.selection.isValid && !value.selection.isCollapsed) {
      _recordHistory(); // Record before change
      _toggleSelectionStyle((s) => s.isBold, (s, v) => s.copyWith(isBold: v));
    } else {
      _pendingBold = !_pendingBold;
      notifyListeners();
    }
  }

  void toggleItalic() {
    if (value.selection.isValid && !value.selection.isCollapsed) {
       _recordHistory();
       _toggleSelectionStyle((s) => s.isItalic, (s, v) => s.copyWith(isItalic: v));
    } else {
      _pendingItalic = !_pendingItalic;
      notifyListeners();
    }
  }

  void toggleUnderline() {
    if (value.selection.isValid && !value.selection.isCollapsed) {
       _recordHistory();
       _toggleSelectionStyle((s) => s.isUnderline, (s, v) => s.copyWith(isUnderline: v));
    } else {
      _pendingUnderline = !_pendingUnderline;
      notifyListeners();
    }
  }

  void _toggleSelectionStyle(
      bool Function(TextSegment) getVal, TextSegment Function(TextSegment, bool) setVal) {
    final start = min(value.selection.start, value.selection.end);
    final end = max(value.selection.start, value.selection.end);
    if (start == end) return;

    // Determine target value
    bool hasFalse = false;
    _iterateSegmentsInRange(start, end, (seg) {
      if (!getVal(seg)) {
        hasFalse = true;
      }
    });
    bool targetValue = hasFalse; // If mixed or all false, make true.

    // Immutable transformation
    List<TextSegment> newSegments = [];
    int currentPos = 0;
    
    for (var seg in _segments) {
       int segStart = currentPos;
       int segEnd = currentPos + seg.text.length;
       
       // Completely outside
       if (segEnd <= start || segStart >= end) {
         newSegments.add(seg);
       } else {
         // Intersection: Split and Apply
         int overlapStart = max(start, segStart);
         int overlapEnd = min(end, segEnd);
         
         // Part Before
         if (overlapStart > segStart) {
            newSegments.add(seg.copyWith(text: seg.text.substring(0, overlapStart - segStart)));
         }
         
         // Part Inside (Apply Style)
         var middleText = seg.text.substring(overlapStart - segStart, overlapEnd - segStart);
         var styledSeg = setVal(seg.copyWith(text: middleText), targetValue);
         newSegments.add(styledSeg);
         
         // Part After
         if (overlapEnd < segEnd) {
            newSegments.add(seg.copyWith(text: seg.text.substring(overlapEnd - segStart)));
         }
       }
       currentPos += seg.text.length;
    }
    
    _segments = _mergeSegmentsList(newSegments);
    notifyListeners();
  }

  void _iterateSegmentsInRange(int start, int end, void Function(TextSegment) callback) {
    int currentPos = 0;
    for (var seg in _segments) {
      final segStart = currentPos;
      final segEnd = currentPos + seg.text.length;

      if (start < segEnd && end > segStart) {
        callback(seg);
      }
      currentPos += seg.text.length;
    }
  }
  
  // No longer needed specifically as we use generalized immutable split logic in loop,
  // but kept if specific single split is needed. But _toggleSelectionStyle now handles split inline.

  // Public state getters for toolbar
  bool get isBold {
    if (value.selection.isValid && !value.selection.isCollapsed) {
      bool allTrue = true;
      _iterateSegmentsInRange(value.selection.start, value.selection.end, (seg) {
        if (!seg.isBold) allTrue = false;
      });
      return allTrue;
    }
    return _pendingBold;
  }

  bool get isItalic {
    if (value.selection.isValid && !value.selection.isCollapsed) {
      bool allTrue = true;
      _iterateSegmentsInRange(value.selection.start, value.selection.end, (seg) {
        if (!seg.isItalic) allTrue = false;
      });
      return allTrue;
    }
    return _pendingItalic;
  }

  bool get isUnderline {
    if (value.selection.isValid && !value.selection.isCollapsed) {
      bool allTrue = true;
      _iterateSegmentsInRange(value.selection.start, value.selection.end, (seg) {
        if (!seg.isUnderline) allTrue = false;
      });
      return allTrue;
    }
    return _pendingUnderline;
  }

  @override
  set value(TextEditingValue newValue) {
    if (value.text != newValue.text) {
      if (!_isInitializing && !_isUndoRedoOperation) {
        _recordHistory();
        _updateSegmentsWithDiff(value.text, newValue.text);
      }
    } else {
      if (!newValue.selection.isCollapsed && value.selection.isCollapsed && !_isInitializing) {
           // Selection expanded - no history needed yet
      }
      
      if (newValue.selection != value.selection) {
        _syncPendingStylesToSelection(newValue.selection);
        notifyListeners();
      }
    }
    super.value = newValue;
  }
  
  void _recordHistory() {
     _history.record(_segments);
  }

  // Sync pending styles based on cursor position (sticky style)
  void _syncPendingStylesToSelection(TextSelection selection) {
    if (!selection.isValid || _segments.isEmpty) {
      _pendingBold = false;
      _pendingItalic = false;
      _pendingUnderline = false;
      return;
    }

    // Get style from character before cursor
    int queryIndex = selection.baseOffset;
    if (queryIndex > 0) queryIndex--;

    TextSegment? seg = _getSegmentAt(queryIndex);
    if (seg != null) {
      _pendingBold = seg.isBold;
      _pendingItalic = seg.isItalic;
      _pendingUnderline = seg.isUnderline;
    } else {
      _pendingBold = false;
      _pendingItalic = false;
      _pendingUnderline = false;
    }
  }

  // Diff algorithm: calculate changes and update segments
  void _updateSegmentsWithDiff(String oldText, String newText) {
    // Calculate common prefix
    int prefixLen = 0;
    int minLen = min(oldText.length, newText.length);
    while (prefixLen < minLen && oldText.codeUnitAt(prefixLen) == newText.codeUnitAt(prefixLen)) {
      prefixLen++;
    }

    // Calculate common suffix
    int suffixLen = 0;
    int oldRemaining = oldText.length - prefixLen;
    int newRemaining = newText.length - prefixLen;
    int maxSuffix = min(oldRemaining, newRemaining);

    while (suffixLen < maxSuffix) {
      if (oldText.codeUnitAt(oldText.length - 1 - suffixLen) ==
          newText.codeUnitAt(newText.length - 1 - suffixLen)) {
        suffixLen++;
      } else {
        break;
      }
    }

    // Define changed ranges (Relative to Old Text)
    int deleteStart = prefixLen;
    int deleteCount = oldText.length - suffixLen - prefixLen;
    // (Relative to New Text)
    int insertStart = prefixLen;
    String textToInsert = newText.substring(prefixLen, newText.length - suffixLen);

    // Apply updates (Immutable pipeline)
    List<TextSegment> nextSegments = _segments;
    
    if (deleteCount > 0) {
      nextSegments = _deleteRangeFromList(nextSegments, deleteStart, deleteCount);
    }

    if (textToInsert.isNotEmpty) {
      nextSegments = _insertTextIntoList(nextSegments, insertStart, textToInsert);
    }

    _segments = _mergeSegmentsList(nextSegments);
  }

  // Immutable Delete Range
  List<TextSegment> _deleteRangeFromList(List<TextSegment> source, int start, int count) {
    if (source.isEmpty || count <= 0) return source;

    List<TextSegment> result = [];
    int currentPos = 0;
    int deleteEnd = start + count;

    for (var seg in source) {
      int segStart = currentPos;
      int segEnd = currentPos + seg.text.length;

      // Check overlap
      int overlapStart = max(start, segStart);
      int overlapEnd = min(deleteEnd, segEnd);

      if (overlapStart < overlapEnd) {
        // Deletion overlaps this segment
        // We keep parts OUTSIDE the deletion range
        
        // Pre-deletion part
        if (overlapStart > segStart) {
           result.add(seg.copyWith(text: seg.text.substring(0, overlapStart - segStart)));
        }
        
        // Post-deletion part
        if (overlapEnd < segEnd) {
           result.add(seg.copyWith(text: seg.text.substring(overlapEnd - segStart)));
        }
        
        // The middle part is skipped (deleted)
      } else {
        // No overlap, keep entire segment
        result.add(seg);
      }
      currentPos += seg.text.length;
    }
    
    return result;
  }

  // Immutable Insert Text
  List<TextSegment> _insertTextIntoList(List<TextSegment> source, int index, String text) {
    if (source.isEmpty) {
      return [TextSegment(
        text, 
        isBold: _pendingBold, 
        isItalic: _pendingItalic, 
        isUnderline: _pendingUnderline
      )];
    }

    List<TextSegment> result = [];
    int currentPos = 0;
    bool inserted = false;

    for (var seg in source) {
      int segStart = currentPos;
      int segEnd = currentPos + seg.text.length;

      // Insertion point falls within this segment (or at start boundary)
      if (!inserted && index >= segStart && index <= segEnd) {
         int localIndex = index - segStart;
         
         String pre = seg.text.substring(0, localIndex);
         String post = seg.text.substring(localIndex);
         
         // New Segment
         final newSeg = TextSegment(
           text, 
           isBold: _pendingBold, 
           isItalic: _pendingItalic, 
           isUnderline: _pendingUnderline
         );
         
         if (pre.isNotEmpty) result.add(seg.copyWith(text: pre));
         result.add(newSeg);
         if (post.isNotEmpty) result.add(seg.copyWith(text: post));
         
         inserted = true;
      } else {
         result.add(seg);
      }
      currentPos += seg.text.length;
    }
    
    // Append at end if not inserted yet (e.g., text length matches total length)
    if (!inserted) {
       result.add(TextSegment(
        text, 
        isBold: _pendingBold, 
        isItalic: _pendingItalic, 
        isUnderline: _pendingUnderline
      ));
    }

    return result;
  }

  TextSegment? _getSegmentAt(int globalIndex) {
    int scan = 0;
    for (var seg in _segments) {
      if (globalIndex >= scan && globalIndex < scan + seg.text.length) return seg;
      scan += seg.text.length;
    }
    return null;
  }

  // Immutable Merge
  List<TextSegment> _mergeSegmentsList(List<TextSegment> input) {
    if (input.isEmpty) return [];
    
    List<TextSegment> merged = [];
    TextSegment? pending;

    for (var seg in input) {
      if (seg.text.isEmpty) continue;

      if (pending == null) {
        pending = seg;
      } else {
        if (pending.isBold == seg.isBold &&
            pending.isItalic == seg.isItalic &&
            pending.isUnderline == seg.isUnderline) {
          // Merge: create NEW segment with combined text
          pending = pending.copyWith(text: pending.text + seg.text);
        } else {
          merged.add(pending);
          pending = seg;
        }
      }
    }
    if (pending != null) merged.add(pending);
    return merged;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (_segments.isEmpty) return TextSpan(style: style, text: text);

    return TextSpan(
      style: style,
      children: _segments.map((seg) => TextSpan(
            text: seg.text,
            style: seg.style,
          )).toList(),
    );
  }
}

/// Rich Text Editor Widget
class RichTextEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;

  const RichTextEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = '',
    this.decoration,
    this.style,
    this.maxLines,
  });

  @override
  State<RichTextEditor> createState() => RichTextEditorState();
}

class RichTextEditorState extends State<RichTextEditor> {
  late SegmentedTextEditingController _internalController;
  late FocusNode _focusNode;
  bool _isSyncingToParent = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();

    _internalController = SegmentedTextEditingController();
    _internalController.initializeFromContext(widget.controller.text);
    _internalController.addListener(_syncToParent);

    widget.controller.addListener(_onExternalChange);
  }

  void _onExternalChange() {
    if (_isSyncingToParent) return;

    final internalJson = _internalController.toSegmentJson();

    if (widget.controller.text != internalJson) {
      _reloadInternalController();
    }
  }

  @override
  void didUpdateWidget(RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onExternalChange);
      widget.controller.addListener(_onExternalChange);
      _reloadInternalController();
    }
  }

  void _reloadInternalController() {
    _internalController.removeListener(_syncToParent);
    _internalController.dispose();

    _internalController = SegmentedTextEditingController();
    _internalController.initializeFromContext(widget.controller.text);
    _internalController.addListener(_syncToParent);

    if (mounted) setState(() {});
  }

  void _syncToParent() {
    _isSyncingToParent = true;
    try {
      final json = _internalController.toSegmentJson();

      if (widget.controller.text != json) {
        // Smart Cursor Mapping:
        // Try to keep the relative cursor, but clamping is necessary as length might differ
        // (Though length should be same ideally if ZWSP not used)
        final int currentSelection = _internalController.selection.baseOffset;
        final int clampedSelection = max(0, min(currentSelection, json.length));
        
        widget.controller.value = widget.controller.value.copyWith(
          text: json,
          selection: TextSelection.collapsed(offset: clampedSelection),
          composing: TextRange.empty,
        );
      }
    } finally {
      _isSyncingToParent = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalChange);
    if (widget.focusNode == null) _focusNode.dispose();
    _internalController.removeListener(_syncToParent);
    _internalController.dispose();
    super.dispose();
  }

  // Public API for toolbar
  void toggleBold() {
    _internalController.toggleBold();
    _focusNode.requestFocus();
  }

  void toggleItalic() {
    _internalController.toggleItalic();
    _focusNode.requestFocus();
  }

  void toggleUnderline() {
    _internalController.toggleUnderline();
    _focusNode.requestFocus();
  }
  
  void undo() {
    _internalController.undo();
    _focusNode.requestFocus();
  }
  
  void redo() {
    _internalController.redo();
    _focusNode.requestFocus();
  }

  // State API
  bool get isBold => _internalController.isBold;
  bool get isItalic => _internalController.isItalic;
  bool get isUnderline => _internalController.isUnderline;
  
  bool get canUndo => _internalController.canUndo;
  bool get canRedo => _internalController.canRedo;
  
  // Expose internal controller safely
  SegmentedTextEditingController get internalController => _internalController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: _internalController,
        builder: (context, child) {
          return TextField(
            controller: _internalController,
            focusNode: _focusNode,
            maxLines: widget.maxLines,
            keyboardType: TextInputType.multiline,
            style: widget.style,
            decoration: widget.decoration ??
                InputDecoration(
                  border: InputBorder.none,
                  hintText: widget.hintText,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                ),
          );
        });
  }
}
