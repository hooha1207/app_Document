// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

/// Segment-based Native Rich Text Editor (Refactored)
/// 
/// Integrates Immutable Data Model and Undo/Redo

@immutable
class TextSegment {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final int? colorValue;
  final int? bgColorValue;
  final String? fontFamily;

  const TextSegment(
    this.text, {
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.colorValue,
    this.bgColorValue,
    this.fontFamily,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'b': isBold,
        'i': isItalic,
        'u': isUnderline,
        'st': isStrikethrough,
        if (colorValue != null) 'c': colorValue,
        if (bgColorValue != null) 'bc': bgColorValue,
        if (fontFamily != null) 'f': fontFamily,
      };

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      json['text'] as String? ?? '',
      isBold: json['b'] as bool? ?? false,
      isItalic: json['i'] as bool? ?? false,
      isUnderline: json['u'] as bool? ?? false,
      isStrikethrough: json['st'] as bool? ?? false,
      colorValue: json['c'] as int?,
      bgColorValue: json['bc'] as int?,
      fontFamily: json['f'] as String?,
    );
  }

  TextSegment copyWith({
    String? text,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    int? colorValue,
    int? bgColorValue,
    String? fontFamily,
  }) {
    return TextSegment(
      text ?? this.text,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      colorValue: colorValue ?? this.colorValue,
      bgColorValue: bgColorValue ?? this.bgColorValue,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  TextStyle get style {
    TextDecoration? decoration;
    if (isUnderline && isStrikethrough) {
      decoration = TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]);
    } else if (isUnderline) {
      decoration = TextDecoration.underline;
    } else if (isStrikethrough) {
      decoration = TextDecoration.lineThrough;
    } else {
      decoration = TextDecoration.none;
    }

    return TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: decoration,
      color: colorValue != null ? Color(colorValue!) : null,
      backgroundColor: bgColorValue != null ? Color(bgColorValue!) : null,
      fontFamily: fontFamily,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextSegment &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          isBold == other.isBold &&
          isItalic == other.isItalic &&
          isUnderline == other.isUnderline &&
          isStrikethrough == other.isStrikethrough &&
          colorValue == other.colorValue &&
          bgColorValue == other.bgColorValue &&
          fontFamily == other.fontFamily;

  @override
  int get hashCode =>
      Object.hash(text, isBold, isItalic, isUnderline, isStrikethrough, colorValue, bgColorValue, fontFamily);
}

class _HistoryManager {
  final List<List<TextSegment>> _undoStack = [];
  final List<List<TextSegment>> _redoStack = [];
  static const int _maxHistory = 50; 

  void record(List<TextSegment> segments) {
    _undoStack.add(List.from(segments));
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear(); 
  }

  List<TextSegment>? undo(List<TextSegment> currentSegments) {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(List.from(currentSegments));
    return _undoStack.removeLast();
  }

  List<TextSegment>? redo(List<TextSegment> currentSegments) {
    if (_redoStack.isEmpty) return null;
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

class SegmentedTextEditingController extends TextEditingController {
  List<TextSegment> _segments = [];
  final _HistoryManager _history = _HistoryManager();

  bool _pendingBold = false;
  bool _pendingItalic = false;
  bool _pendingUnderline = false;
  bool _pendingStrikethrough = false;
  int? _pendingColorValue;
  int? _pendingBgColorValue;
  String? _pendingFontFamily;

  bool _isInitializing = false;
  bool _isUndoRedoOperation = false;

  SegmentedTextEditingController({String? text}) : super(text: text == null ? '' : null);

  void initializeFromContext(String contextText) {
    if (contextText.isEmpty) {
      _segments = [];
      _isInitializing = true;
      text = '';
      _isInitializing = false;
      _history.clear();
      return;
    }

    try {
      final List<dynamic> jsonList = jsonDecode(contextText);
      _segments = jsonList.map((e) => TextSegment.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      if (contextText.isNotEmpty) {
         _segments = [TextSegment(contextText)];
      } else {
         _segments = [];
      }
    }
    
    String newText = _segments.map((e) => e.text).join('');
    _isInitializing = true;
    text = newText;
    if (newText.isNotEmpty) {
      selection = TextSelection.collapsed(offset: newText.length);
    }
    _isInitializing = false;
    _history.clear(); 
  }

  String toSegmentJson() {
    return jsonEncode(_segments.map((e) => e.toJson()).toList());
  }

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
    
    int newSelectionIndex = newText.length;
    if (selection.baseOffset >= 0 && selection.baseOffset <= newText.length) {
       newSelectionIndex = selection.baseOffset;
    }
    
    text = newText;
    selection = TextSelection.collapsed(offset: newSelectionIndex);
    
    _isUndoRedoOperation = false;
    notifyListeners();
  }

  void toggleBold() {
    if (value.selection.isValid && !value.selection.isCollapsed) {
      _recordHistory(); 
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

  void toggleStrikethrough() {
    if (value.selection.isValid && !value.selection.isCollapsed) {
       _recordHistory();
       _toggleSelectionStyle((s) => s.isStrikethrough, (s, v) => s.copyWith(isStrikethrough: v));
    } else {
      _pendingStrikethrough = !_pendingStrikethrough;
      notifyListeners();
    }
  }

  void setTextColor(Color? color) {
    if (value.selection.isValid && !value.selection.isCollapsed) {
       _recordHistory();
       _applyStyleToSelection((s) => s.copyWith(colorValue: color?.value));
    } else {
      _pendingColorValue = color?.value;
      notifyListeners();
    }
  }

  void setBackgroundColor(Color? color) {
    if (value.selection.isValid && !value.selection.isCollapsed) {
       _recordHistory();
       _applyStyleToSelection((s) => s.copyWith(bgColorValue: color?.value));
    } else {
      _pendingBgColorValue = color?.value;
      notifyListeners();
    }
  }

  void setFontFamily(String? fontFamily) {
    if (value.selection.isValid && !value.selection.isCollapsed) {
       _recordHistory();
       _applyStyleToSelection((s) => s.copyWith(fontFamily: fontFamily));
    } else {
      _pendingFontFamily = fontFamily;
      notifyListeners();
    }
  }

  void _applyStyleToSelection(TextSegment Function(TextSegment) updateSeg) {
    final start = min(value.selection.start, value.selection.end);
    final end = max(value.selection.start, value.selection.end);
    if (start == end) return;

    List<TextSegment> newSegments = [];
    int currentPos = 0;
    
    for (var seg in _segments) {
       int segStart = currentPos;
       int segEnd = currentPos + seg.text.length;
       
       if (segEnd <= start || segStart >= end) {
         newSegments.add(seg);
       } else {
         int overlapStart = max(start, segStart);
         int overlapEnd = min(end, segEnd);
         
         if (overlapStart > segStart) {
            newSegments.add(seg.copyWith(text: seg.text.substring(0, overlapStart - segStart)));
         }
         
         var middleText = seg.text.substring(overlapStart - segStart, overlapEnd - segStart);
         var styledSeg = updateSeg(seg.copyWith(text: middleText));
         newSegments.add(styledSeg);
         
         if (overlapEnd < segEnd) {
            newSegments.add(seg.copyWith(text: seg.text.substring(overlapEnd - segStart)));
         }
       }
       currentPos += seg.text.length;
    }
    
    _segments = _mergeSegmentsList(newSegments);
    notifyListeners();
  }

  void _toggleSelectionStyle(
      bool Function(TextSegment) getVal, TextSegment Function(TextSegment, bool) setVal) {
    final start = min(value.selection.start, value.selection.end);
    final end = max(value.selection.start, value.selection.end);
    if (start == end) return;

    bool hasFalse = false;
    _iterateSegmentsInRange(start, end, (seg) {
      if (!getVal(seg)) {
        hasFalse = true;
      }
    });
    bool targetValue = hasFalse; 

    List<TextSegment> newSegments = [];
    int currentPos = 0;
    
    for (var seg in _segments) {
       int segStart = currentPos;
       int segEnd = currentPos + seg.text.length;
       
       if (segEnd <= start || segStart >= end) {
         newSegments.add(seg);
       } else {
         int overlapStart = max(start, segStart);
         int overlapEnd = min(end, segEnd);
         
         if (overlapStart > segStart) {
            newSegments.add(seg.copyWith(text: seg.text.substring(0, overlapStart - segStart)));
         }
         
         var middleText = seg.text.substring(overlapStart - segStart, overlapEnd - segStart);
         var styledSeg = setVal(seg.copyWith(text: middleText), targetValue);
         newSegments.add(styledSeg);
         
         if (overlapEnd < segEnd) {
            newSegments.add(seg.copyWith(text: seg.text.substring(overlapEnd - segStart)));
         }
       }
       currentPos += seg.text.length;
    }
    
    _segments = _mergeSegmentsList(newSegments);
    notifyListeners();
  }
  
  // ADDED: splitAtSelection for compatibility with Block Editor
  Map<String, String> splitAtSelection() {
     if (!value.selection.isValid) {
        return {'left': toSegmentJson(), 'right': '[]'};
     }
     
     int splitIndex = value.selection.baseOffset;
     if (splitIndex < 0) splitIndex = 0;
     if (splitIndex > text.length) splitIndex = text.length;

     List<TextSegment> left = [];
     List<TextSegment> right = [];
     
     int currentPos = 0;
     for(var seg in _segments) {
       int segStart = currentPos;
       int segEnd = currentPos + seg.text.length;
       
       if (splitIndex <= segStart) {
         // Entirely right
         right.add(seg);
       } else if (splitIndex >= segEnd) {
         // Entirely left
         left.add(seg);
       } else {
         // Split
         int localSplit = splitIndex - segStart;
         left.add(seg.copyWith(text: seg.text.substring(0, localSplit)));
         right.add(seg.copyWith(text: seg.text.substring(localSplit)));
       }
       currentPos += seg.text.length;
     }

     return {
        'left': jsonEncode(left.map((e) => e.toJson()).toList()),
        'right': jsonEncode(right.map((e) => e.toJson()).toList()),
     };
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

  bool get isStrikethrough {
    if (value.selection.isValid && !value.selection.isCollapsed) {
      bool allTrue = true;
      _iterateSegmentsInRange(value.selection.start, value.selection.end, (seg) {
        if (!seg.isStrikethrough) allTrue = false;
      });
      return allTrue;
    }
    return _pendingStrikethrough;
  }

  Color? get currentColor {
    if (value.selection.isValid && !value.selection.isCollapsed) {
      Color? firstColor;
      bool first = true;
      _iterateSegmentsInRange(value.selection.start, value.selection.end, (seg) {
        if (first) {
          firstColor = seg.colorValue != null ? Color(seg.colorValue!) : null;
          first = false;
        }
      });
      return firstColor;
    }
    return _pendingColorValue != null ? Color(_pendingColorValue!) : null;
  }

  Color? get currentBackgroundColor {
    if (value.selection.isValid && !value.selection.isCollapsed) {
      Color? firstBgColor;
      bool first = true;
      _iterateSegmentsInRange(value.selection.start, value.selection.end, (seg) {
        if (first) {
          firstBgColor = seg.bgColorValue != null ? Color(seg.bgColorValue!) : null;
          first = false;
        }
      });
      return firstBgColor;
    }
    return _pendingBgColorValue != null ? Color(_pendingBgColorValue!) : null;
  }

  String? get currentFontFamily {
    if (value.selection.isValid && !value.selection.isCollapsed) {
      String? firstFont;
      bool first = true;
      _iterateSegmentsInRange(value.selection.start, value.selection.end, (seg) {
        if (first) {
          firstFont = seg.fontFamily;
          first = false;
        }
      });
      return firstFont;
    }
    return _pendingFontFamily;
  }

  @override
  set value(TextEditingValue newValue) {
    if (value.text != newValue.text) {
      if (!_isInitializing && !_isUndoRedoOperation) {
        _recordHistory();
        _updateSegmentsWithDiff(value.text, newValue.text);
      }
    } else {
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

  void _syncPendingStylesToSelection(TextSelection selection) {
    if (!selection.isValid || _segments.isEmpty) {
      _pendingBold = false;
      _pendingItalic = false;
      _pendingUnderline = false;
      _pendingStrikethrough = false;
      _pendingColorValue = null;
      _pendingBgColorValue = null;
      _pendingFontFamily = null;
      return;
    }

    int queryIndex = selection.baseOffset;
    if (queryIndex > 0) queryIndex--;

    TextSegment? seg = _getSegmentAt(queryIndex);
    if (seg != null) {
      _pendingBold = seg.isBold;
      _pendingItalic = seg.isItalic;
      _pendingUnderline = seg.isUnderline;
      _pendingStrikethrough = seg.isStrikethrough;
      _pendingColorValue = seg.colorValue;
      _pendingBgColorValue = seg.bgColorValue;
      _pendingFontFamily = seg.fontFamily;
    } else {
      _pendingBold = false;
      _pendingItalic = false;
      _pendingUnderline = false;
      _pendingStrikethrough = false;
      _pendingColorValue = null;
      _pendingBgColorValue = null;
      _pendingFontFamily = null;
    }
  }

  void _updateSegmentsWithDiff(String oldText, String newText) {
    int prefixLen = 0;
    int minLen = min(oldText.length, newText.length);
    while (prefixLen < minLen && oldText.codeUnitAt(prefixLen) == newText.codeUnitAt(prefixLen)) {
      prefixLen++;
    }

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

    int deleteStart = prefixLen;
    int deleteCount = oldText.length - suffixLen - prefixLen;
    int insertStart = prefixLen;
    String textToInsert = newText.substring(prefixLen, newText.length - suffixLen);

    List<TextSegment> nextSegments = _segments;
    
    if (deleteCount > 0) {
      nextSegments = _deleteRangeFromList(nextSegments, deleteStart, deleteCount);
    }

    if (textToInsert.isNotEmpty) {
      nextSegments = _insertTextIntoList(nextSegments, insertStart, textToInsert);
    }

    _segments = _mergeSegmentsList(nextSegments);
  }

  List<TextSegment> _deleteRangeFromList(List<TextSegment> source, int start, int count) {
    if (source.isEmpty || count <= 0) return source;

    List<TextSegment> result = [];
    int currentPos = 0;
    int deleteEnd = start + count;

    for (var seg in source) {
      int segStart = currentPos;
      int segEnd = currentPos + seg.text.length;

      int overlapStart = max(start, segStart);
      int overlapEnd = min(deleteEnd, segEnd);

      if (overlapStart < overlapEnd) {
        if (overlapStart > segStart) {
           result.add(seg.copyWith(text: seg.text.substring(0, overlapStart - segStart)));
        }
        if (overlapEnd < segEnd) {
           result.add(seg.copyWith(text: seg.text.substring(overlapEnd - segStart)));
        }
      } else {
        result.add(seg);
      }
      currentPos += seg.text.length;
    }
    return result;
  }

  List<TextSegment> _insertTextIntoList(List<TextSegment> source, int index, String text) {
    if (source.isEmpty) {
      return [TextSegment(
        text, 
        isBold: _pendingBold, 
        isItalic: _pendingItalic, 
        isUnderline: _pendingUnderline,
        isStrikethrough: _pendingStrikethrough,
        colorValue: _pendingColorValue,
        bgColorValue: _pendingBgColorValue,
        fontFamily: _pendingFontFamily,
      )];
    }

    List<TextSegment> result = [];
    int currentPos = 0;
    bool inserted = false;

    for (var seg in source) {
      int segStart = currentPos;
      int segEnd = currentPos + seg.text.length;

      if (!inserted && index >= segStart && index <= segEnd) {
         int localIndex = index - segStart;
         
         String pre = seg.text.substring(0, localIndex);
         String post = seg.text.substring(localIndex);
         
         final newSeg = TextSegment(
           text, 
           isBold: _pendingBold, 
           isItalic: _pendingItalic, 
           isUnderline: _pendingUnderline,
           isStrikethrough: _pendingStrikethrough,
           colorValue: _pendingColorValue,
           bgColorValue: _pendingBgColorValue,
           fontFamily: _pendingFontFamily,
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
    
    if (!inserted) {
       result.add(TextSegment(
        text, 
        isBold: _pendingBold, 
        isItalic: _pendingItalic, 
        isUnderline: _pendingUnderline,
        isStrikethrough: _pendingStrikethrough,
        colorValue: _pendingColorValue,
        bgColorValue: _pendingBgColorValue,
        fontFamily: _pendingFontFamily,
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
            pending.isUnderline == seg.isUnderline &&
            pending.isStrikethrough == seg.isStrikethrough &&
            pending.colorValue == seg.colorValue &&
            pending.bgColorValue == seg.bgColorValue &&
            pending.fontFamily == seg.fontFamily) {
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

/// Use NativeRichTextEditor name for compatibility
class NativeRichTextEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final VoidCallback? onInteraction;

  const NativeRichTextEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = '',
    this.onInteraction,
  });

  @override
  State<NativeRichTextEditor> createState() => NativeRichTextEditorState();
}

class NativeRichTextEditorState extends State<NativeRichTextEditor> {
  late SegmentedTextEditingController _internalController;
  late FocusNode _focusNode;
  bool _isSyncingToParent = false;
  bool _isUsingExternalController = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    
    _isUsingExternalController = widget.controller is SegmentedTextEditingController;
    if (_isUsingExternalController) {
      _internalController = widget.controller as SegmentedTextEditingController;
    } else {
      _internalController = SegmentedTextEditingController();
      _internalController.initializeFromContext(widget.controller.text);
      _internalController.addListener(_syncToParent);
      widget.controller.addListener(_onExternalChange);
    }
    _internalController.addListener(_notifyInteraction);
  }

  void _onExternalChange() {
    if (_isSyncingToParent || _isUsingExternalController) return;
    final internalJson = _internalController.toSegmentJson();
    if (widget.controller.text != internalJson) {
       _reloadInternalController();
    }
  }

  void _notifyInteraction() {
     if (mounted) widget.onInteraction?.call();
  }
  
  @override
  void didUpdateWidget(NativeRichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
       if (!_isUsingExternalController) {
         oldWidget.controller.removeListener(_onExternalChange);
         _internalController.removeListener(_syncToParent);
       }
       _internalController.removeListener(_notifyInteraction);

       _isUsingExternalController = widget.controller is SegmentedTextEditingController;
       if (_isUsingExternalController) {
         _internalController = widget.controller as SegmentedTextEditingController;
       } else {
         _internalController = SegmentedTextEditingController();
         _internalController.initializeFromContext(widget.controller.text);
         _internalController.addListener(_syncToParent);
         widget.controller.addListener(_onExternalChange);
       }
       _internalController.addListener(_notifyInteraction);
       
       if (mounted) setState(() {});
    }
  }

  void _reloadInternalController() {
    if (_isUsingExternalController) return;
    _internalController.removeListener(_syncToParent);
    _internalController.removeListener(_notifyInteraction);
    _internalController.dispose();

    _internalController = SegmentedTextEditingController();
    _internalController.initializeFromContext(widget.controller.text);
    _internalController.addListener(_syncToParent);
    _internalController.addListener(_notifyInteraction);
    
    if (mounted) setState(() {});
  }

  void _syncToParent() {
    if (_isUsingExternalController) return;
    _isSyncingToParent = true;
    try {
      final json = _internalController.toSegmentJson();
      if (widget.controller.text != json) {
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
    if (!_isUsingExternalController) {
      widget.controller.removeListener(_onExternalChange);
      _internalController.removeListener(_syncToParent);
      _internalController.dispose();
    }
    _internalController.removeListener(_notifyInteraction);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void toggleBold() { _internalController.toggleBold(); _focusNode.requestFocus(); }
  void toggleItalic() { _internalController.toggleItalic(); _focusNode.requestFocus(); }
  void toggleUnderline() { _internalController.toggleUnderline(); _focusNode.requestFocus(); }
  void toggleStrikethrough() { _internalController.toggleStrikethrough(); _focusNode.requestFocus(); }
  void setTextColor(Color? color) { _internalController.setTextColor(color); _focusNode.requestFocus(); }
  void setBackgroundColor(Color? color) { _internalController.setBackgroundColor(color); _focusNode.requestFocus(); }
  void setFontFamily(String? fontFamily) { _internalController.setFontFamily(fontFamily); _focusNode.requestFocus(); }
  
  void undo() { _internalController.undo(); _focusNode.requestFocus(); }
  void redo() { _internalController.redo(); _focusNode.requestFocus(); }

  bool get isBold => _internalController.isBold;
  bool get isItalic => _internalController.isItalic;
  bool get isUnderline => _internalController.isUnderline;
  bool get isStrikethrough => _internalController.isStrikethrough;
  Color? get currentColor => _internalController.currentColor;
  Color? get currentBackgroundColor => _internalController.currentBackgroundColor;
  String? get currentFontFamily => _internalController.currentFontFamily;
  
  Map<String, String> splitAtSelection() => _internalController.splitAtSelection();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _internalController, 
      builder: (context, child) {
         return TextField(
            controller: _internalController,
            focusNode: _focusNode,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.hintText,
              hintMaxLines: 1,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
          );
      }
    );
  }
}
