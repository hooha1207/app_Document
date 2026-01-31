import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../models/block_editor_model.dart';
import '../screens/rdkit_editor_screen.dart';
import 'media_widgets.dart';
import 'native_rich_text_editor.dart';

class CommonBlockEditor extends StatelessWidget {
  final BlockEditorController controller;
  final bool useNativeRichText;
  final VoidCallback? onInteraction;
  final EdgeInsetsGeometry? padding;

  const CommonBlockEditor({
    super.key,
    required this.controller,
    this.useNativeRichText = false,
    this.onInteraction,
    this.padding,
  });

  void _autoSizeRowWithPreservation(int targetRowGroup, EditorBlock preservedBlock) {
    List<EditorBlock> rowBlocks = controller.blocks.where((b) => b.rowGroup == targetRowGroup).toList();
    if (rowBlocks.length <= 1) return;

    // Calculate maximum fair share to prevent one block from crushing the others
    double maxFairShare = 1.0 / rowBlocks.length;

    // If the dropped block is entering a row, it shouldn't take up more than its fair share 
    // PLUS a small buffer, otherwise it squishes existing blocks too much.
    // Specially if it was 1.0 (coming from a new line), it must be scaled down.
    if (preservedBlock.widthRatio > maxFairShare * 1.5) {
       preservedBlock.widthRatio = maxFairShare;
    }

    double remainingWidth = 1.0 - preservedBlock.widthRatio;
    
    // Ensure remaining blocks always get at least a minimum viable width
    double minRequiredForOthers = 0.05 * (rowBlocks.length - 1);
    if (remainingWidth < minRequiredForOthers) {
       remainingWidth = minRequiredForOthers;
       preservedBlock.widthRatio = 1.0 - minRequiredForOthers;
    }

    List<EditorBlock> otherBlocks = rowBlocks.where((b) => b != preservedBlock).toList();
    if (otherBlocks.isEmpty) return;

    double otherSum = 0;
    for (var b in otherBlocks) {
      otherSum += b.widthRatio;
    }

    if (otherSum <= 0.001) {
      double split = remainingWidth / otherBlocks.length;
      for (var b in otherBlocks) {
        b.widthRatio = split;
      }
    } else {
      for (var b in otherBlocks) {
        double proportion = b.widthRatio / otherSum;
        b.widthRatio = remainingWidth * proportion;
      }
    }
  }

  int get _nextRowGroup {
    if (controller.blocks.isEmpty) return 0;
    int maxGroup = 0;
    for (var b in controller.blocks) {
      if (b.rowGroup > maxGroup) maxGroup = b.rowGroup;
    }
    return maxGroup + 1;
  }

  Widget _buildHorizontalSpacer(EditorBlock? insertBeforeBlock) {
    return DragTarget<_BlockDragData>(
      onWillAcceptWithDetails: (details) => details.data.block != insertBeforeBlock,
      onAcceptWithDetails: (details) {
        final draggedBlock = details.data.block;
        Future.microtask(() {
          if (controller.blocks.contains(draggedBlock)) {
            controller.blocks.remove(draggedBlock);
            
            int targetIndex = controller.blocks.length;
            if (insertBeforeBlock != null) {
               targetIndex = controller.blocks.indexOf(insertBeforeBlock);
               if (targetIndex == -1) targetIndex = controller.blocks.length; 
            }
            
            draggedBlock.rowGroup = _nextRowGroup;
            draggedBlock.widthRatio = 1.0;
            
            controller.blocks.insert(targetIndex, draggedBlock);
            controller.refresh();
          }
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isHovered ? 24.0 : 4.0, 
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 0),
          decoration: BoxDecoration(
            color: isHovered ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isHovered ? Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 2) : null,
          ),
          child: isHovered
              ? const Center(child: Icon(Icons.add, color: Colors.blue, size: 20))
              : null,
        );
      },
    );
  }

  Widget _buildRowEndDropZone(BuildContext context, int rowGroup) {
    return DragTarget<_BlockDragData>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final draggedBlock = details.data.block;
        Future.microtask(() {
          if (controller.blocks.contains(draggedBlock)) {
            controller.blocks.remove(draggedBlock);
            
            // Find the last block in this rowGroup
            int insertIndex = controller.blocks.length;
            for (int i = controller.blocks.length - 1; i >= 0; i--) {
              if (controller.blocks[i].rowGroup == rowGroup) {
                insertIndex = i + 1;
                break;
              }
            }
            
            controller.blocks.insert(insertIndex, draggedBlock);
            draggedBlock.rowGroup = rowGroup;
            _autoSizeRowWithPreservation(rowGroup, draggedBlock);
            controller.refresh();
          }
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovered ? Colors.blue.withValues(alpha: 0.05) : Colors.transparent,
            border: isHovered ? const Border(left: BorderSide(color: Colors.blue, width: 4)) : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {


        return ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final bool showAddTextButton = controller.blocks.isEmpty || 
                !controller.blocks.any((b) => b.type == 'text' || b.type == 'latex');

            final double minHeight = constraints.hasBoundedHeight ? constraints.maxHeight : 0;

            return Container(
              constraints: BoxConstraints(minHeight: minHeight),
              width: double.infinity,
              child: Builder(
                builder: (context) {
                  List<List<MapEntry<int, EditorBlock>>> rowGroups = [];
                  if (controller.blocks.isNotEmpty) {
                    List<MapEntry<int, EditorBlock>> currentRow = [];
                    int currentGroupId = controller.blocks.first.rowGroup;
                    for (int i = 0; i < controller.blocks.length; i++) {
                      final block = controller.blocks[i];
                      if (block.rowGroup == currentGroupId) {
                        currentRow.add(MapEntry(i, block));
                      } else {
                        rowGroups.add(currentRow);
                        currentRow = [MapEntry(i, block)];
                        currentGroupId = block.rowGroup;
                      }
                    }
                    if (currentRow.isNotEmpty) {
                      rowGroups.add(currentRow);
                    }
                  }

                  final sliverList = SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return LayoutBuilder(
                          builder: (context, rowConstraints) {
                            final double rowWidth = rowConstraints.maxWidth;

                            if (controller.blocks.isEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHorizontalSpacer(null),
                                ],
                              );
                            }
                            
                            if (index < rowGroups.length) {
                              final rowBlocks = rowGroups[index];
                              
                              double sumRatio = 0;
                              for (var entry in rowBlocks) {
                                sumRatio += entry.value.widthRatio;
                              }

                              Widget wrapWidget = Wrap(
                                spacing: 0,
                                runSpacing: 0,
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                children: rowBlocks.map((entry) {
                                  return _buildDraggableBlock(context, entry.value, entry.key, rowWidth);
                                }).toList(),
                              );

                              if (sumRatio < 0.95) {
                                double remainingRatio = 1.0 - sumRatio;
                                double remainingPx = rowWidth * remainingRatio;
                                if (remainingPx > 20) {
                                  wrapWidget = SizedBox(
                                    width: rowWidth,
                                    child: Stack(
                                      children: [
                                        wrapWidget,
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: remainingPx - 1,
                                          child: _buildRowEndDropZone(context, rowBlocks.first.value.rowGroup),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHorizontalSpacer(rowBlocks.first.value),
                                  wrapWidget,
                                ]
                              );
                            }
                            
                            // Last item
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHorizontalSpacer(null),
                                if (showAddTextButton)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: TextButton.icon(
                                      onPressed: () => controller.addTextBlock(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Text'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.tealAccent
                                            : Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }
                        );
                      },
                      childCount: controller.blocks.isEmpty ? 1 : rowGroups.length + 1,
                    ),
                  );

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller.deselectBlock();
                      // Also unfocus any active text field
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    child: CustomScrollView(
                      slivers: [
                        if (padding != null)
                          SliverPadding(
                            padding: padding!,
                            sliver: sliverList,
                          )
                        else
                          sliverList,
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDraggableBlock(BuildContext context, EditorBlock block, int index, double availableWidth) {
    // Subtract a tiny epsilon to prevent Wrap from wrapping due to sub-pixel rounding errors
    double displayWidth = (availableWidth * block.widthRatio) - 0.5;
    
    if (block.type == 'spacer' && displayWidth < 0) displayWidth = 0;
    if (displayWidth > availableWidth) displayWidth = availableWidth;

    final Widget blockWidget = Container(
      width: displayWidth,
      margin: const EdgeInsets.symmetric(horizontal: 0.1, vertical: 0.5),
      child: _buildBlockItem(context, block),
    );

    return _DraggableBlockWidget(
      key: ValueKey(block),
      block: block,
      availableWidth: availableWidth,
      displayWidth: displayWidth,
      controller: controller,
      blockWidget: blockWidget,
      onAutoSizeRowWithPreservation: _autoSizeRowWithPreservation,
      buildPreview: (ctx, blk) => _buildBlockPreview(ctx, blk),
    );
  }

  Widget _buildBlockItem(BuildContext context, EditorBlock block) {
    Widget contentWidget;
    switch (block.type) {
      case 'image':
        contentWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(block.content),
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => const Padding(
              padding: EdgeInsets.all(20),
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
        break;
      case 'image_url':
        contentWidget = GestureDetector(
          onTap: () async {
            final controller = TextEditingController(text: block.content);
            final url = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Edit Image URL'), 
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Enter Image URL'), 
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter Image URL',
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            );

            if (url != null && url != block.content) {
               block.content = url;
               this.controller.refresh(); 
            }
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  block.content,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                        const SizedBox(height: 8),
                        const Text('Failed to load', style: TextStyle(color: Colors.grey)),
                        Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                           child: Text(
                             block.content, 
                             maxLines: 2, 
                             overflow: TextOverflow.ellipsis,
                             textAlign: TextAlign.center,
                             style: const TextStyle(fontSize: 10, color: Colors.grey)
                           )
                        )
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                 bottom: 8, right: 8,
                 child: Container(
                   padding: const EdgeInsets.all(4),
                   decoration: BoxDecoration(
                     color: Colors.black.withValues(alpha: 0.6),
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.edit, color: Colors.white, size: 16),
                 ),
              ),
            ],
          ),
        );
        break;
      case 'video':
        contentWidget = VideoPlayerWidget(videoUrl: block.content);
        break;
      case 'audio':
        contentWidget = AudioPlayerWidget(audioUrl: block.content);
        break;
      case 'youtube':
        contentWidget = YouTubeBlockWidget(url: block.content);
        break;
      case 'rdkit':
        contentWidget = _buildRdkitBlock(context, block);
        break;
      case 'latex':
        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: block.controller,
              focusNode: block.focusNode,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                hintText: 'Enter LaTeX',
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey.shade50,
                filled: true,
              ),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
             Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
              color: Colors.transparent,
              child: ValueListenableBuilder<TextEditingValue>(
                 valueListenable: block.controller!,
                 builder: (context, value, child) {
                   return RichText(
                      text: TextSpan(
                        children: _buildRichTextWithLatex(context, value.text),
                        style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                   );
                 },
              ),
            ),
          ],
        );
        break;
      case 'spacer':
        contentWidget = Container(
           height: 48,
           color: Colors.transparent,
           child: Center(
              child: Icon(Icons.space_bar, color: Colors.grey.withAlpha(50), size: 24),
           ),
        );
        break;
      case 'text':
      default:
        contentWidget = useNativeRichText
              ? NativeRichTextEditor(
                key: GlobalObjectKey<NativeRichTextEditorState>(block),
                controller: block.controller!,
                focusNode: block.focusNode,
                hintText: 'Enter text...',
                onInteraction: onInteraction,
              )
            : TextField(
                controller: block.controller,
                focusNode: block.focusNode,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  hintText: 'Enter text...',
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
              );
        break;
    }

     return Container(
       decoration: BoxDecoration(
         border: Border.all(
           color: block.type == 'spacer' 
               ? Colors.transparent 
               : Theme.of(context).brightness == Brightness.dark
                   ? Colors.white.withValues(alpha: 0.2)
                   : Colors.black.withValues(alpha: 0.2),
           width: 1,
         ),
         borderRadius: BorderRadius.circular(8),
         color: block.type == 'spacer' ? Colors.transparent : Theme.of(context).cardColor,
       ),
       child: block.type == 'text' || block.type == 'spacer'
           ? contentWidget
           : ClipRRect(
               borderRadius: BorderRadius.circular(8),
               child: Column(children: [contentWidget]),
             ),
     );
  }

  // Helper for static preview during dragging (avoids GlobalKey duplication)
  Widget _buildBlockPreview(BuildContext context, EditorBlock block) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_getBlockIcon(block.type), color: Colors.blue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _getBlockSummary(block),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getBlockIcon(String type) {
    switch (type) {
      case 'image':
      case 'image_url':
        return Icons.image;
      case 'video':
      case 'youtube':
        return Icons.movie;
      case 'audio':
        return Icons.audiotrack;
      case 'spacer':
        return Icons.space_bar;
      case 'latex':
        return Icons.functions;
      case 'rdkit':
        return Icons.science;
      case 'text':
      default:
        return Icons.notes;
    }
  }

  String _getBlockSummary(EditorBlock block) {
    if (block.type == 'text' || block.type == 'latex') {
      final content = block.cleanContent;
      // If it's rich text JSON, try to extract some plain text
      if (content.startsWith('[')) {
        try {
          final List data = jsonDecode(content);
          final text = data.map((e) => e['text'] ?? '').join('');
          return text.isEmpty ? 'Empty ${block.type} block' : text;
        } catch (_) {
          return 'Rich ${block.type} block';
        }
      }
      return content.trim().isEmpty ? 'Empty ${block.type} block' : content.trim();
    } else if (block.type == 'spacer') {
      return 'Spacer Block';
    }
    return '${block.type.toUpperCase()} Block';
  }

  /// Builds the read-only display widget for an 'rdkit' block.
  /// Shows the captured PNG image with an edit overlay button.
  Widget _buildRdkitBlock(BuildContext context, EditorBlock block) {
    final decoded = decodeRdkitContent(block.content);
    final imagePath = decoded['imagePath'] ?? '';
    final smiles = decoded['smiles'] ?? '';

    Future<void> openEditor() async {
      final result = await Navigator.of(context).push<RdkitResult>(
        MaterialPageRoute(
          builder: (_) => RdkitEditorScreen(initialSmiles: smiles),
        ),
      );
      if (result != null) {
        block.content = encodeRdkitContent(result);
        controller.refresh();
      }
    }

    return GestureDetector(
      onDoubleTap: openEditor,
      child: Stack(
        children: [
          // Chemical structure image
          imagePath.isNotEmpty && File(imagePath).existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (e, o, s) => _rdkitPlaceholder(smiles),
                  ),
                )
              : _rdkitPlaceholder(smiles),

          // Edit button overlay
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: openEditor,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4)
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('편집',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rdkitPlaceholder(String smiles) {
    return Container(
      height: 200,
      width: double.infinity,
      color: const Color(0xFFF0F4FF),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.science, color: Color(0xFF1A73E8), size: 40),
          const SizedBox(height: 8),
          const Text(
            '화학식 이미지',
            style: TextStyle(
              color: Color(0xFF5f6368),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildRichTextWithLatex(BuildContext context, String text) {

    final List<InlineSpan> spans = [];
    final cleanText = text.replaceAll('\u200B', '');
    final parts = cleanText.split(r'$$');

    for (int i = 0; i < parts.length; i++) {
        if (i % 2 == 0) {
           if (parts[i].isNotEmpty) {
             spans.add(TextSpan(text: parts[i]));
           }
        } else {
           spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Math.tex(
                parts[i],
                textStyle: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                onErrorFallback: (err) => Text('\$\$${parts[i]}\$\$', style: const TextStyle(color: Colors.red)),
              ),
           ));
        }
    }
    return spans;
  }
}

class _ResizableBlock extends StatefulWidget {
  final EditorBlock block;
  final BlockEditorController controller;
  final double availableWidth;
  final Widget child;

  const _ResizableBlock({
    required this.block,
    required this.controller,
    required this.availableWidth,
    required this.child,
  });

  @override
  State<_ResizableBlock> createState() => _ResizableBlockState();
}

class _ResizableBlockState extends State<_ResizableBlock> {
  double? _resizeStartWidth;
  double? _resizeStartX;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.controller.selectedBlock == widget.block;

    return Stack(
      clipBehavior: Clip.none, 
      children: [
        widget.child,

        // Tap overlay to select this block
        // For text blocks: defer to child (TextField) to allow text selection
        // For media blocks: translucent to capture all taps
        if (!isSelected)
           Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.controller.selectBlock(widget.block);
                },
                child: Container(color: Colors.transparent),
              ),
           ),
        
        // Handles and selection border
        if (isSelected) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
              ),
            ),
          ),

          // Left resize handle
          Positioned(
            top: 0,
            bottom: 0,
            left: -15, 
            width: 40,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (_) {
                widget.controller.selectBlock(widget.block);
              },
              onPanStart: (details) {
                _resizeStartWidth = widget.block.widthRatio;
                _resizeStartX = details.globalPosition.dx;
              },
              onPanUpdate: (details) {
                if (_resizeStartWidth == null || _resizeStartX == null) return;
                
                final containerWidth = widget.availableWidth; 
                final deltaPx = _resizeStartX! - details.globalPosition.dx; // Reversed for left side
                final deltaRatio = deltaPx / containerWidth;

                _handleStrictResize(deltaRatio, isLeft: true);
              },
              onPanEnd: (_) {
                _resizeStartWidth = null;
                _resizeStartX = null;
              },
              child: Center(
                child: Container(
                  width: 6,
                  height: 40,
                  decoration: BoxDecoration(
                     color: Colors.blue,
                     borderRadius: BorderRadius.circular(3),
                     boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                  ),
                ),
              ),
            ),
          ),
          
          // Right resize handle
          Positioned(
            top: 0,
            bottom: 0,
            right: -15, // Pushed slightly right, but with enough width to overlap inside
            width: 40, // Increased width to 40px (at least half will be inside the 100% hit area)
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (_) {
                // Select immediately on touch to ensure visual response and gesture priority
                widget.controller.selectBlock(widget.block);
              },
              onPanStart: (details) {
                _resizeStartWidth = widget.block.widthRatio;
                _resizeStartX = details.globalPosition.dx;
              },
              onPanUpdate: (details) {
                if (_resizeStartWidth == null || _resizeStartX == null) return;
                
                final containerWidth = widget.availableWidth; 
                final deltaPx = details.globalPosition.dx - _resizeStartX!;
                final deltaRatio = deltaPx / containerWidth;

                // NEW: Strict row-based resizing distribution
                _handleStrictResize(deltaRatio, isLeft: false);
              },
              onPanEnd: (_) {
                _resizeStartWidth = null;
                _resizeStartX = null;
              },
              child: Center(
                child: Container(
                  width: 6,
                  height: 40,
                  decoration: BoxDecoration(
                     color: Colors.blue,
                     borderRadius: BorderRadius.circular(3),
                     boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                  ),
                ),
              ),
            ),
          ),
          
          // Delete button (moved to bottom of stack to render on top of resize handles)
          Positioned(
            top: 0, 
            right: 0,
            child: GestureDetector(
              onTap: () {
                widget.controller.removeBlock(widget.block);
                widget.controller.deselectBlock();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: const [
                     BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, color: Colors.black, size: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Calculate rows based on strictly defined rowGroup!
  List<List<int>> _calculateRows() {
    List<List<int>> rows = [];
    if (widget.controller.blocks.isEmpty) return rows;
    
    List<int> currentRow = [];
    int currentRowGroup = widget.controller.blocks.first.rowGroup;
    
    for (int i = 0; i < widget.controller.blocks.length; i++) {
        final block = widget.controller.blocks[i];
        if (block.rowGroup == currentRowGroup) {
            currentRow.add(i);
        } else {
            rows.add(currentRow);
            currentRow = [i];
            currentRowGroup = block.rowGroup;
        }
    }
    if (currentRow.isNotEmpty) rows.add(currentRow);
    return rows;
  }

  void _handleStrictResize(double deltaRatio, {bool isLeft = false}) {
    final rows = _calculateRows();
    final blockIndex = widget.controller.blocks.indexOf(widget.block);
    if (blockIndex == -1) return;

    List<int> currentRowIndices = [];
    for (final row in rows) {
      if (row.contains(blockIndex)) {
        currentRowIndices = row;
        break;
      }
    }

    if (currentRowIndices.isEmpty) return;
    
    final indexInRow = currentRowIndices.indexOf(blockIndex);
    final totalInRow = currentRowIndices.length;

    double newRatio = (_resizeStartWidth! + deltaRatio).clamp(0.05, 1.0);
    double actualDelta = newRatio - widget.block.widthRatio;
    
    if (actualDelta.abs() < 0.001) return;

    if (actualDelta < 0) {
      // Shrinking: free up space, potentially adding or expanding a spacer
      double spaceToFree = -actualDelta;
      if (isLeft) {
        if (indexInRow > 0) {
          final prevSibling = widget.controller.blocks[currentRowIndices[indexInRow - 1]];
          if (prevSibling.type == 'spacer') {
            prevSibling.widthRatio += spaceToFree;
            widget.block.widthRatio -= spaceToFree;
          } else {
            final spacer = EditorBlock(type: 'spacer', content: '', rowGroup: widget.block.rowGroup, widthRatio: spaceToFree);
            widget.controller.blocks.insert(blockIndex, spacer);
            widget.block.widthRatio -= spaceToFree;
          }
        } else {
          final spacer = EditorBlock(type: 'spacer', content: '', rowGroup: widget.block.rowGroup, widthRatio: spaceToFree);
          widget.controller.blocks.insert(blockIndex, spacer);
          widget.block.widthRatio -= spaceToFree;
        }
      } else {
        // Shrinking from the right
        if (indexInRow < totalInRow - 1) {
          final nextSibling = widget.controller.blocks[currentRowIndices[indexInRow + 1]];
          if (nextSibling.type == 'spacer') {
            nextSibling.widthRatio += spaceToFree;
            widget.block.widthRatio -= spaceToFree;
          } else {
            final spacer = EditorBlock(type: 'spacer', content: '', rowGroup: widget.block.rowGroup, widthRatio: spaceToFree);
            widget.controller.blocks.insert(blockIndex + 1, spacer);
            widget.block.widthRatio -= spaceToFree;
          }
        } else {
          // Shrinking the very last block on its right side just shrinks it.
          widget.block.widthRatio -= spaceToFree;
        }
      }
    } else if (actualDelta > 0) {
      // Expanding: consume space from adjacent blocks or spacers
      if (isLeft) {
        if (indexInRow > 0) {
          final prevSibling = widget.controller.blocks[currentRowIndices[indexInRow - 1]];
          if (prevSibling.type == 'spacer') {
            if (prevSibling.widthRatio - actualDelta > 0.01) {
              prevSibling.widthRatio -= actualDelta;
              widget.block.widthRatio += actualDelta;
            } else {
              double space = prevSibling.widthRatio;
              widget.block.widthRatio += space;
              widget.controller.removeBlock(prevSibling);
            }
          } else {
            if (prevSibling.widthRatio - actualDelta > 0.05) {
              prevSibling.widthRatio -= actualDelta;
              widget.block.widthRatio += actualDelta;
            } else {
              double space = prevSibling.widthRatio - 0.05;
              if (space > 0) {
                prevSibling.widthRatio -= space;
                widget.block.widthRatio += space;
              }
            }
          }
        }
      } else {
        // Expanding from the right
        if (indexInRow < totalInRow - 1) {
          final nextSibling = widget.controller.blocks[currentRowIndices[indexInRow + 1]];
          if (nextSibling.type == 'spacer') {
            if (nextSibling.widthRatio - actualDelta > 0.01) {
              nextSibling.widthRatio -= actualDelta;
              widget.block.widthRatio += actualDelta;
            } else {
              double space = nextSibling.widthRatio;
              widget.block.widthRatio += space;
              widget.controller.removeBlock(nextSibling);
            }
          } else {
            if (nextSibling.widthRatio - actualDelta > 0.05) {
              nextSibling.widthRatio -= actualDelta;
              widget.block.widthRatio += actualDelta;
            } else {
              double space = nextSibling.widthRatio - 0.05;
              if (space > 0) {
                nextSibling.widthRatio -= space;
                widget.block.widthRatio += space;
              }
            }
          }
        } else {
          // Expanding right on the last block
          double sumBefore = 0;
          for (int i = 0; i < totalInRow - 1; i++) {
            sumBefore += widget.controller.blocks[currentRowIndices[i]].widthRatio;
          }
           // Allow expanding up to the remaining space in the row
          double maxAllowedDelta = 1.0 - (sumBefore + widget.block.widthRatio);
        }
      }
    }

    // NORMALIZATION STEP: Ensure total width in row is exactly 1.0 to avoid overflow due to floating point precision
    // Re-fetch the row blocks since the controller's blocks list might have changed (inserted/removed spacers)
    final List<EditorBlock> updatedRowBlocks = widget.controller.blocks
        .where((b) => b.rowGroup == widget.block.rowGroup)
        .toList();

    final double rowSum = updatedRowBlocks.map((b) => b.widthRatio).fold(0, (a, b) => a + b);
    if ((rowSum - 1.0).abs() > 0.00001) {
       // Find the best block to adjust (preferably a spacer, otherwise the block we're currently resizing)
       EditorBlock? blockToAdjust;
       for (final b in updatedRowBlocks) {
         if (b.type == 'spacer') {
           blockToAdjust = b;
           break;
         }
       }
       blockToAdjust ??= widget.block;
       
       blockToAdjust.widthRatio += (1.0 - rowSum);
       // Safety clamp for adjustment
       if (blockToAdjust.widthRatio < 0.01) blockToAdjust.widthRatio = 0.01;
    }

    widget.controller.refresh();
  }
}

class _DraggableBlockWidget extends StatefulWidget {
  final EditorBlock block;
  final double availableWidth;
  final double displayWidth;
  final BlockEditorController controller;
  final Widget blockWidget;
  final Widget Function(BuildContext, EditorBlock) buildPreview;
  final void Function(int, EditorBlock) onAutoSizeRowWithPreservation;

  const _DraggableBlockWidget({
    super.key,
    required this.block,
    required this.availableWidth,
    required this.displayWidth,
    required this.controller,
    required this.blockWidget,
    required this.onAutoSizeRowWithPreservation,
    required this.buildPreview,
  });

  @override
  State<_DraggableBlockWidget> createState() => _DraggableBlockWidgetState();
}

class _DraggableBlockWidgetState extends State<_DraggableBlockWidget> {
  bool _isHovered = false;
  bool _isRightSide = false;
  final _DragOffsetProvider _dragOffsetProvider = _DragOffsetProvider();

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final controller = widget.controller;
    
    final delay = (block.type == 'text' || block.type == 'latex')
        ? const Duration(milliseconds: 800)
        : const Duration(milliseconds: 500);

    return DragTarget<_BlockDragData>(
      key: ValueKey(block),
      onWillAcceptWithDetails: (details) => details.data.block != block,
      onMove: (details) {
        final renderObject = context.findRenderObject();
        if (renderObject is RenderBox) {
          final pointerGlobalOffset = details.offset + details.data.tapLocalOffset;
          final localOffset = renderObject.globalToLocal(pointerGlobalOffset);
          // If the container is expanded, anything past the halfway point of the *actual block* is considered "right side"
          final rightSide = localOffset.dx > widget.displayWidth / 2;
          if (_isHovered != true || _isRightSide != rightSide) {
            setState(() {
              _isHovered = true;
              _isRightSide = rightSide;
            });
          }
        }
      },
      onLeave: (data) {
        setState(() {
          _isHovered = false;
        });
      },
      onAcceptWithDetails: (details) {
        setState(() {
          _isHovered = false;
        });
        final draggedBlock = details.data.block;
        if (draggedBlock == block) return;
        
        Future.microtask(() {
          if (controller.blocks.contains(draggedBlock)) {
            final targetRowGroup = block.rowGroup;
            controller.blocks.remove(draggedBlock);
            final updatedIndex = controller.blocks.indexOf(block);
            if (updatedIndex != -1) {
              final insertIndex = _isRightSide ? updatedIndex + 1 : updatedIndex;
              controller.blocks.insert(insertIndex, draggedBlock);
              draggedBlock.rowGroup = targetRowGroup;
              widget.onAutoSizeRowWithPreservation(targetRowGroup, draggedBlock);
              controller.refresh();
            }
          }
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isUnder = _isHovered && candidateData.isNotEmpty;
        
        final Widget contentStack = Stack(
          clipBehavior: Clip.none,
          children: [
            Listener(
              onPointerDown: (event) {
                _dragOffsetProvider.offset = event.localPosition;
              },
              child: LongPressDraggable<_BlockDragData>(
                key: ValueKey('drag_${block.hashCode}'),
                data: _BlockDragData(block, _dragOffsetProvider),
                delay: delay,
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: widget.availableWidth * 0.7),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: widget.buildPreview(context, block),
                  ),
                ),
                childWhenDragging: Container(
                  width: widget.displayWidth,
                  height: 48, 
                  margin: const EdgeInsets.symmetric(horizontal: 0.1, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _ResizableBlock(
                  block: block,
                  controller: controller,
                  availableWidth: widget.availableWidth,
                  child: widget.blockWidget,
                ),
              ),
            ),
            
            // Visual Edge Drop Zones
            if (isUnder)
              Positioned(
                top: 0, bottom: 0,
                // The visual indicator should stick exactly to the edge of the block
                left: _isRightSide ? widget.displayWidth - 2 : -2,
                width: 4,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            if (isUnder)
              Positioned(
                 left: 0, top: 0, bottom: 0,
                 width: widget.displayWidth,
                 child: IgnorePointer(
                   child: Container(
                     decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                     )
                   )
                 )
              )
          ],
        );

        return contentStack;
      },
    );
  }
}

class _DragOffsetProvider {
  Offset offset = Offset.zero;
}

class _BlockDragData {
  final EditorBlock block;
  final _DragOffsetProvider offsetProvider;

  _BlockDragData(this.block, this.offsetProvider);

  Offset get tapLocalOffset => offsetProvider.offset;
}
