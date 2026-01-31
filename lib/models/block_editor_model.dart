import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/native_rich_text_editor.dart'; // For SegmentedTextEditingController


// Represents a single block in the editor (text, image, video, audio, latex)
class EditorBlock {
  final String type;
  String content;
  final FocusNode focusNode = FocusNode();
  // Controller is for text and latex blocks
  final TextEditingController? controller;
  
  // Layout properties
  double widthRatio; // 0.0 to 1.0, where 1.0 = full width
  int rowGroup; // Blocks with same rowGroup render on same row

  // Track previous content to detect actual text changes (not just selection changes)
  String _previousContent = '';

  EditorBlock({
    required this.type, 
    required this.content, 
    this.controller,
    this.widthRatio = 1.0,
    this.rowGroup = 0,
  }) {
    _previousContent = content;
  }

  // Helper to get clean content (without ZWSP if text/latex)
  String get cleanContent {
    if ((type == 'text' || type == 'latex') && controller != null) {
      // FIX: Use rich text JSON if available
      if (controller is SegmentedTextEditingController) {
          return (controller as SegmentedTextEditingController).toSegmentJson();
      }
      // Fallback for standard TextFields (shouldn't happen for text blocks now)
      return controller!.text;
    }
    return content;
  }

  Map<String, dynamic> toJson() => {
    'type': type, 
    'content': cleanContent,
    'widthRatio': widthRatio,
    'rowGroup': rowGroup,
  };
}

class BlockEditorController extends ChangeNotifier {
  final List<EditorBlock> blocks = [];
  // Callback when any block gains focus (useful for UI updates)
  VoidCallback? onFocusChange;

  // Track currently selected/resizing block
  EditorBlock? _selectedBlock;
  EditorBlock? get selectedBlock => _selectedBlock;

  // Track disposal state to prevent notifyListeners after dispose
  bool _disposed = false;

  void selectBlock(EditorBlock? block) {
    if (_selectedBlock != block) {
      _selectedBlock = block;
      // Unfocus currently focused text field when selecting a block
      if (block != null) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
      notifyListeners();
    }
  }

  void deselectBlock() {
    if (_selectedBlock != null) {
      _selectedBlock = null;
      notifyListeners();
    }
  }


  final TextEditingController Function(String text)? textControllerBuilder;

  BlockEditorController({
    String? initialJson,
    dynamic initialData,
    this.onFocusChange,
    this.textControllerBuilder,
  }) {
    if (initialData != null) {
      _loadFromData(initialData);
    } else {
      _loadFromJson(initialJson);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (var block in blocks) {
      block.focusNode.dispose();
      block.controller?.dispose();
    }
    super.dispose();
  }

  void _loadFromJson(String? jsonString) {
    if (jsonString != null && jsonString.isNotEmpty && jsonString.startsWith('[')) {
      try {
        final data = jsonDecode(jsonString);
        _loadFromData(data);
      } catch (e) {
        _addInitialTextBlock(text: jsonString);
      }
    } else if (jsonString != null && jsonString.isNotEmpty) {
      // Only add block if there's actual content
      _addInitialTextBlock(text: jsonString);
    } else {
      // If jsonString is null or empty, add an initial empty text block
      _addInitialTextBlock();
    }
  }

  void _loadFromData(dynamic data) {
    if (data is List) {
      if (data.isEmpty) {
        _addInitialTextBlock();
      } else {
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            _addBlockFromJson(item);
          }
        }
      }
    } else if (data is String) {
      _addInitialTextBlock(text: data);
    } else {
      _addInitialTextBlock();
    }
  }

  int get _nextRowGroup {
    if (blocks.isEmpty) return 0;
    int maxGroup = 0;
    for (var b in blocks) {
      if (b.rowGroup > maxGroup) maxGroup = b.rowGroup;
    }
    return maxGroup + 1;
  }

  void _addBlockFromJson(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final content = item['content'] as String;
    final widthRatio = (item['widthRatio'] as num?)?.toDouble() ?? 1.0;
    final rowGroup = (item['rowGroup'] as int?) ?? _nextRowGroup; // Auto-increment if missing
    
    if (type == 'text') {
      _addTextBlock(content, widthRatio: widthRatio, rowGroup: rowGroup);
    } else if (type == 'latex') {
      _addLatexBlock(content, widthRatio: widthRatio, rowGroup: rowGroup);
    } else {
      blocks.add(EditorBlock(
        type: type, 
        content: content,
        widthRatio: widthRatio,
        rowGroup: rowGroup,
      ));
    }
  }

  void _addInitialTextBlock({String? text}) {
    _addTextBlock(text ?? '');
  }

  void _addTextBlock(String text, {double widthRatio = 1.0, int? rowGroup}) {
    final fullText = text;
    final textController = textControllerBuilder?.call(fullText) ?? TextEditingController(text: fullText);
    final block = EditorBlock(
      type: 'text', 
      content: text, 
      controller: textController,
      widthRatio: widthRatio,
      rowGroup: rowGroup ?? _nextRowGroup,
    );

    _setupBlockListeners(block);
    blocks.add(block);
  }

  void _addLatexBlock(String text, {double widthRatio = 1.0, int? rowGroup}) {
    final fullText = text;
    final textController = textControllerBuilder?.call(fullText) ?? TextEditingController(text: fullText);
    final block = EditorBlock(
      type: 'latex', 
      content: text, 
      controller: textController,
      widthRatio: widthRatio,
      rowGroup: rowGroup ?? _nextRowGroup,
    );

    _setupBlockListeners(block);
    blocks.add(block);
  }

  void _setupBlockListeners(EditorBlock block) {
    block.focusNode.addListener(() {
      if (block.focusNode.hasFocus) {
        onFocusChange?.call();
        if (!_disposed) notifyListeners();
      }
    });

    if ((block.type == 'text' || block.type == 'latex') && block.controller != null) {
      block.controller!.addListener(() {
        final text = block.controller!.text;
        
        bool contentChanged = text != block._previousContent;
        if (contentChanged) {
          block._previousContent = text;
          block.content = text;
        }
        
        // Always notify on any change (including selection) to update toolbar
        if (!_disposed) {
          notifyListeners();
        }
      });
    }
  }

  void _removeBlockInternal(int index) {
    if (index < 0 || index >= blocks.length) return;
    final block = blocks[index];
    blocks.removeAt(index);

    // Defer disposal to allow current frame/notification to complete safely
    // This prevents "FocusNode used after being disposed" error when deleting from listener
    Future.microtask(() {
      block.focusNode.dispose();
      block.controller?.dispose();
    });
  }

  void removeBlock(EditorBlock block) {
    final index = blocks.indexOf(block);
    if (index != -1) {
      _removeBlockInternal(index);
      notifyListeners();
    }
  }

  // Insert media or other block at current cursor position (Split Insertion)
  void insertBlock(String type, String content) {
    int insertIndex = blocks.length;
    int focusedIndex = blocks.indexWhere((b) => b.focusNode.hasFocus);

    if (focusedIndex != -1) {
      final currentBlock = blocks[focusedIndex];
      // Fallback/Legacy logic for non-rich-text or if UI doesn't drive split
      if ((currentBlock.type == 'text' || currentBlock.type == 'latex') && currentBlock.controller != null) {
         insertIndex = focusedIndex + 1;
         int newRg1 = _nextRowGroup;
         blocks.insert(insertIndex, EditorBlock(type: type, content: content, rowGroup: newRg1));
         
         // Add empty text after
         final emptyFullText = '';
         final emptyController = textControllerBuilder?.call(emptyFullText) ?? TextEditingController(text: emptyFullText);
         int newRg2 = newRg1 + 1;
         final newTextBlock = EditorBlock(type: 'text', content: '', controller: emptyController, rowGroup: newRg2);
         _setupBlockListeners(newTextBlock);
         blocks.insert(insertIndex + 1, newTextBlock);
         
         newTextBlock.focusNode.requestFocus();
      } else {
         insertIndex = focusedIndex + 1;
         int newRg1 = _nextRowGroup;
         blocks.insert(insertIndex, EditorBlock(type: type, content: content, rowGroup: newRg1));
         // Add empty text
         final emptyFullText = '';
         final emptyController = textControllerBuilder?.call(emptyFullText) ?? TextEditingController(text: emptyFullText);
         int newRg2 = newRg1 + 1;
         final newTextBlock = EditorBlock(type: 'text', content: '', controller: emptyController, rowGroup: newRg2);
         _setupBlockListeners(newTextBlock);
         blocks.insert(insertIndex + 1, newTextBlock);
      }
    } else {
       int newRg1 = _nextRowGroup;
       blocks.add(EditorBlock(type: type, content: content, rowGroup: newRg1));
       int newRg2 = newRg1 + 1;
       final newTextBlock = EditorBlock(type: 'text', content: '', controller: TextEditingController(text: ''), rowGroup: newRg2);
       _setupBlockListeners(newTextBlock);
       blocks.add(newTextBlock);
    }
    notifyListeners();
  }

  // Precise split insertion driven by UI (NativeRichTextEditor)
  void insertBlockWithSplit({
      required int blockIndex, 
      required String leftJson, 
      required String rightJson, 
      required String mediaType, 
      required String mediaContent
  }) {
      if (blockIndex < 0 || blockIndex >= blocks.length) return;
      
      final currentBlock = blocks[blockIndex];
      
      // 1. Update Current (Left)
      currentBlock.controller!.text = leftJson;
      currentBlock.content = leftJson;
      
      // 2. Insert Media
      final insertIndex = blockIndex + 1;
      int newRg1 = _nextRowGroup;
      blocks.insert(insertIndex, EditorBlock(type: mediaType, content: mediaContent, rowGroup: newRg1));
      
      // 3. Insert Next (Right)
      final afterFullText = rightJson;
      final afterController = textControllerBuilder?.call(afterFullText) ?? TextEditingController(text: afterFullText);
      int newRg2 = newRg1 + 1;
      final newNextBlock = EditorBlock(type: 'text', content: rightJson, controller: afterController, rowGroup: newRg2);
      _setupBlockListeners(newNextBlock);
      blocks.insert(insertIndex + 1, newNextBlock);
      
      newNextBlock.focusNode.requestFocus();
      notifyListeners();
  }

  // New public method to insert an empty LaTeX block
  void insertLatexBlock() {
    int insertIndex = blocks.length;

    int focusedIndex = blocks.indexWhere((b) => b.focusNode.hasFocus);

    if (focusedIndex != -1) {
      final currentBlock = blocks[focusedIndex];
      // Works on text and latex blocks
      if ((currentBlock.type == 'text' || currentBlock.type == 'latex') && currentBlock.controller != null) {
        final text = currentBlock.cleanContent;
        final selection = currentBlock.controller!.selection;

        int cursorIndex = selection.baseOffset;
        // Safety checks
        if (cursorIndex < 0) cursorIndex = 0;
        if (cursorIndex > text.length) cursorIndex = text.length;

        final beforeText = text.substring(0, cursorIndex);
        final afterText = text.substring(cursorIndex);

        // Update current block
        currentBlock.controller!.text = beforeText;
        currentBlock.content = beforeText;

        insertIndex = focusedIndex + 1;

        // Insert new latex block
        final latexFullText = '';
        final latexController = textControllerBuilder?.call(latexFullText) ?? TextEditingController(text: latexFullText);
        int newRg1 = _nextRowGroup;
        final newLatexBlock = EditorBlock(type: 'latex', content: '', controller: latexController, rowGroup: newRg1);
        _setupBlockListeners(newLatexBlock);
        blocks.insert(insertIndex, newLatexBlock);

        // Insert remainder text block
        final afterFullText = afterText;
        final afterController = textControllerBuilder?.call(afterFullText) ?? TextEditingController(text: afterFullText);
        int newRg2 = newRg1 + 1;
        final newNextBlock = EditorBlock(type: 'text', content: afterText, controller: afterController, rowGroup: newRg2);
        _setupBlockListeners(newNextBlock);
        blocks.insert(insertIndex + 1, newNextBlock);

        // Focus the new latex block
        newLatexBlock.focusNode.requestFocus();
      } else {
        // Media focused? Insert after
        final latexFullText2 = '';
        final latexController2 = textControllerBuilder?.call(latexFullText2) ?? TextEditingController(text: latexFullText2);
        int newRg1 = _nextRowGroup;
        final newLatexBlock = EditorBlock(type: 'latex', content: '', controller: latexController2, rowGroup: newRg1);
        _setupBlockListeners(newLatexBlock);
        blocks.insert(insertIndex, newLatexBlock);

        // Also add a text block after it for good measure
        final textFullText = '';
        final textController = textControllerBuilder?.call(textFullText) ?? TextEditingController(text: textFullText);
        int newRg2 = newRg1 + 1;
        final newTextBlock = EditorBlock(type: 'text', content: '', controller: textController, rowGroup: newRg2);
        _setupBlockListeners(newTextBlock);
        blocks.insert(insertIndex + 1, newTextBlock);

        newLatexBlock.focusNode.requestFocus();
      }
    } else {
      // No focus, append to end
      _addLatexBlock('');
      _addTextBlock('');
    }

    notifyListeners();
  }

  void addTextBlock() {
    final fullText = '';
    final controller = textControllerBuilder?.call(fullText) ?? TextEditingController(text: fullText);
    final newTextBlock = EditorBlock(type: 'text', content: '', controller: controller, rowGroup: _nextRowGroup);
    _setupBlockListeners(newTextBlock);
    blocks.add(newTextBlock);
    notifyListeners();
  }

  String toJsonString() {
    // Update content from controllers before saving
    for (var block in blocks) {
      if (block.type == 'text' || block.type == 'latex') {
        block.content = block.cleanContent;
      }
    }
    return jsonEncode(blocks.map((b) => b.toJson()).toList());
  }
  
  void refresh() {
    notifyListeners();
  }

  // Layout manipulation methods
  void setBlockWidth(int blockIndex, double widthRatio) {
    if (blockIndex >= 0 && blockIndex < blocks.length) {
      blocks[blockIndex].widthRatio = widthRatio.clamp(0.2, 1.0);
      notifyListeners();
    }
  }

  void moveBlockToSameRow(int blockIndex, int targetRowGroup) {
    if (blockIndex >= 0 && blockIndex < blocks.length) {
      blocks[blockIndex].rowGroup = targetRowGroup;
      notifyListeners();
    }
  }

  void moveBlockToNewRow(int blockIndex) {
    if (blockIndex >= 0 && blockIndex < blocks.length) {
      // Find max rowGroup and increment
      final maxRow = blocks.map((b) => b.rowGroup).reduce((a, b) => a > b ? a : b);
      blocks[blockIndex].rowGroup = maxRow + 1;
      blocks[blockIndex].widthRatio = 1.0; // Reset to full width
      notifyListeners();
    }
  }

  SegmentedTextEditingController? get _currentEditorController {
    final focusedIndex = blocks.indexWhere((b) => b.focusNode.hasFocus);
    if (focusedIndex != -1) {
      final block = blocks[focusedIndex];
      if ((block.type == 'text' || block.type == 'latex') && 
          block.controller is SegmentedTextEditingController) {
        return block.controller as SegmentedTextEditingController;
      }
    }
    return null;
  }

  void toggleBold() => _currentEditorController?.toggleBold();
  void toggleItalic() => _currentEditorController?.toggleItalic();
  void toggleUnderline() => _currentEditorController?.toggleUnderline();
  void toggleStrikethrough() => _currentEditorController?.toggleStrikethrough();
  void setTextColor(Color? color) => _currentEditorController?.setTextColor(color);
  void setBackgroundColor(Color? color) => _currentEditorController?.setBackgroundColor(color);
  void setFontFamily(String? fontFamily) => _currentEditorController?.setFontFamily(fontFamily);
  
  bool get isBold => _currentEditorController?.isBold ?? false;
  bool get isItalic => _currentEditorController?.isItalic ?? false;
  bool get isUnderline => _currentEditorController?.isUnderline ?? false;
  bool get isStrikethrough => _currentEditorController?.isStrikethrough ?? false;
  Color? get currentColor => _currentEditorController?.currentColor;
  Color? get currentBackgroundColor => _currentEditorController?.currentBackgroundColor;
  String? get currentFontFamily => _currentEditorController?.currentFontFamily;

  void undo() => _currentEditorController?.undo();
  void redo() => _currentEditorController?.redo();

  void insertMedia(String type, String content) {
    try {
      final activeIndex = blocks.indexWhere((b) => b.focusNode.hasFocus);
      if (activeIndex != -1) {
        final activeBlock = blocks[activeIndex];
        if ((activeBlock.type == 'text' || activeBlock.type == 'latex') &&
            activeBlock.controller is SegmentedTextEditingController) {
          final state = activeBlock.controller as SegmentedTextEditingController;
          final splitMap = state.splitAtSelection();
          insertBlockWithSplit(
            blockIndex: activeIndex,
            leftJson: splitMap['left'] as String,
            rightJson: splitMap['right'] as String,
            mediaType: type,
            mediaContent: content,
          );
          return;
        }
      }
    } catch (_) {}
    
    // Fallback if no text block is focused or split fails
    insertBlock(type, content);
  }
}
