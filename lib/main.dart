import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'models/block_editor_model.dart';
import 'models/document.dart';
import 'screens/document_list_screen.dart';
import 'screens/rdkit_editor_screen.dart';
import 'services/document_service.dart';
import 'widgets/common_block_editor.dart';
import 'widgets/editor_toolbar.dart';
import 'widgets/native_rich_text_editor.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DocumentService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DocumentListScreen(),
        ),
        GoRoute(
          path: '/editor/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DocumentEditorScreen(documentId: id);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Rich Text Editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class DocumentEditorScreen extends StatefulWidget {
  final String documentId;

  const DocumentEditorScreen({super.key, required this.documentId});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late BlockEditorController _controller;
  late Document _document;
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  void _loadDocument() {
    final doc = DocumentService.getDocument(widget.documentId);
    if (doc == null) {
      // Document not found, navigate back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return;
    }

    _document = doc;
    _titleController.text = _document.title;

    _controller = BlockEditorController(
      initialJson: _document.content,
      onFocusChange: () {
        setState(() {});
      },
      textControllerBuilder: (text) => SegmentedTextEditingController()..initializeFromContext(text),
    );

    // Auto-save on content change
    _controller.addListener(_autoSave);
    _titleController.addListener(_autoSave);
  }

  void _autoSave() {
    _document.title = _titleController.text;
    _document.content = _controller.toJsonString();
    DocumentService.updateDocument(_document);
  }

  @override
  void dispose() {
    _controller.removeListener(_autoSave);
    _titleController.removeListener(_autoSave);
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _handleBold() => _controller.toggleBold();
  void _handleItalic() => _controller.toggleItalic();
  void _handleUnderline() => _controller.toggleUnderline();
  void _handleStrikethrough() => _controller.toggleStrikethrough();

  void _handlePickColor(bool isBackground) async {
    final colors = [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.transparent];
    final names = ['Black', 'Red', 'Blue', 'Green', 'Yellow', 'Clear'];
    
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(isBackground ? 'Select Background Color' : 'Select Text Color'),
        children: List.generate(colors.length, (index) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, colors[index]),
          child: Row(
            children: [
              Container(
                width: 24, 
                height: 24, 
                color: colors[index] == Colors.transparent ? null : colors[index], 
                decoration: colors[index] == Colors.transparent ? BoxDecoration(border: Border.all()) : null,
              ),
              const SizedBox(width: 12),
              Text(names[index]),
            ],
          ),
        )),
      )
    );
    
    if (selectedColor != null) {
      if (isBackground) {
        _controller.setBackgroundColor(selectedColor == Colors.transparent ? null : selectedColor);
      } else {
        _controller.setTextColor(selectedColor == Colors.transparent ? null : selectedColor);
      }
    }
  }

  void _handlePickFont() async {
    final fonts = ['Default', 'Serif', 'Sans-serif', 'Monospace'];
    
    final selectedFont = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Font'),
        children: List.generate(fonts.length, (index) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, fonts[index]),
          child: Text(fonts[index]),
        )),
      )
    );
    
    if (selectedFont != null) {
      _controller.setFontFamily(selectedFont == 'Default' ? null : selectedFont);
    }
  }

  Future<void> _addMediaBlock(String type) async {

    FilePickerResult? result;

    if (type == 'audio') {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg', 'wma', 'opus'],
      );
    } else {
      final fileType = (type == 'image') ? FileType.image : FileType.video;
      result = await FilePicker.platform.pickFiles(type: fileType);
    }

    if (result == null || result.files.single.path == null) return;

    final sourcePath = result.files.single.path!;
    final appDir = await getApplicationDocumentsDirectory();
    final newFileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final newFilePath = p.join(appDir.path, newFileName);

    await File(sourcePath).copy(newFilePath);

    _controller.insertMedia(type, newFilePath);
  }

  Future<void> _addYouTubeBlock() async {

    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert YouTube URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the URL of the YouTube video:'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://youtu.be/...',
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

    if (url != null && url.isNotEmpty) {
      _controller.insertMedia('youtube', url);
    }
  }

  Future<void> _addImageUrlBlock() async {

    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Image URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the URL of the image:'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://...',
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

    if (url != null && url.isNotEmpty) {
      _controller.insertMedia('image_url', url);
    }
  }


  void _handleInsertImage() {
    showDialog(
        context: context,
        builder: (context) => SimpleDialog(
              title: const Text('Select Image Type'),
              children: [
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    _addMediaBlock('image');
                  },
                  child: const Text('Pick from Gallery'),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    _addImageUrlBlock();
                  },
                  child: const Text('From URL'),
                )
              ],
            ));
  }

  Future<void> _addRdkitBlock() async {
    final result = await Navigator.of(context).push<RdkitResult>(
      MaterialPageRoute(
        builder: (_) => const RdkitEditorScreen(),
      ),
    );
    if (result != null) {
      _controller.insertMedia('rdkit', encodeRdkitContent(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Document Title',
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            EditorToolbar(
              onBold: _handleBold,
              onItalic: _handleItalic,
              onUnderline: _handleUnderline,
              onStrikethrough: _handleStrikethrough,
              onColor: () => _handlePickColor(false),
              onBgColor: () => _handlePickColor(true),
              onFontFamily: _handlePickFont,
              onInsertImage: _handleInsertImage,
              onInsertVideo: () => _addMediaBlock('video'),
              onInsertYouTube: _addYouTubeBlock,
              onInsertAudio: () => _addMediaBlock('audio'),
              onInsertRdkit: _addRdkitBlock,
              onInsertLatex: () => _controller.insertLatexBlock(),
              onUndo: () => _controller.undo(),
              onRedo: () => _controller.redo(),
              isBold: _controller.isBold,
              isItalic: _controller.isItalic,
              isUnderline: _controller.isUnderline,
              isStrikethrough: _controller.isStrikethrough,
            ),
            Expanded(
              child: CommonBlockEditor(
                padding: const EdgeInsets.all(16),
                controller: _controller,
                useNativeRichText: true,
                onInteraction: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
