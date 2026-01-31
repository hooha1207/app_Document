import 'package:flutter/material.dart';

class EditorToolbar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onStrikethrough;
  final VoidCallback onColor;
  final VoidCallback onBgColor;
  final VoidCallback onFontFamily;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertVideo;
  final VoidCallback onInsertYouTube;
  final VoidCallback onInsertAudio;
  final VoidCallback onInsertRdkit;
  final VoidCallback onInsertLatex;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;

  const EditorToolbar({
    super.key,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onStrikethrough,
    required this.onColor,
    required this.onBgColor,
    required this.onFontFamily,
    required this.onInsertImage,
    required this.onInsertVideo,
    required this.onInsertYouTube,
    required this.onInsertAudio,
    required this.onInsertRdkit,
    required this.onInsertLatex,
    required this.onUndo,
    required this.onRedo,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildToolbarButton(Icons.undo, onPressed: onUndo),
          _buildToolbarButton(Icons.redo, onPressed: onRedo),
          const VerticalDivider(width: 8, indent: 8, endIndent: 8),
          _buildToolbarButton(Icons.format_bold, onPressed: onBold, isActive: isBold),
          _buildToolbarButton(Icons.format_italic, onPressed: onItalic, isActive: isItalic),
          _buildToolbarButton(Icons.format_underline, onPressed: onUnderline, isActive: isUnderline),
          _buildToolbarButton(Icons.format_strikethrough, onPressed: onStrikethrough, isActive: isStrikethrough),
          _buildToolbarButton(Icons.format_color_text, onPressed: onColor),
          _buildToolbarButton(Icons.format_color_fill, onPressed: onBgColor),
          _buildToolbarButton(Icons.font_download, onPressed: onFontFamily),
          const VerticalDivider(width: 8, indent: 8, endIndent: 8),
          _buildToolbarButton(Icons.image, onPressed: onInsertImage),
          _buildToolbarButton(Icons.videocam, onPressed: onInsertVideo),
          _buildToolbarButton(Icons.smart_display, onPressed: onInsertYouTube),
          _buildToolbarButton(Icons.mic, onPressed: onInsertAudio),
          _buildToolbarButton(Icons.science, onPressed: onInsertRdkit, tooltip: '화학식 (RDKit)'),
          _buildToolbarButton(Icons.functions, onPressed: onInsertLatex, tooltip: '수식 (LaTeX)'),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(IconData icon, {required VoidCallback onPressed, String? tooltip, bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.deepPurple.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: isActive ? Colors.deepPurple : Colors.grey[700]),
        onPressed: onPressed,
        tooltip: tooltip ?? icon.toString(),
      ),
    );
  }
}
