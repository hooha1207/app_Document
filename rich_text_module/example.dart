import 'package:flutter/material.dart';
import 'rich_text_editor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rich Text Editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const EditorExample(),
    );
  }
}

class EditorExample extends StatefulWidget {
  const EditorExample({super.key});

  @override
  State<EditorExample> createState() => _EditorExampleState();
}

class _EditorExampleState extends State<EditorExample> {
  final _controller = TextEditingController();
  final _editorKey = GlobalKey<RichTextEditorState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSaveDialog() {
    final state = _editorKey.currentState;
    if (state == null) return;

    final json = state.internalController.toSegmentJson();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved JSON'),
        content: SingleChildScrollView(
          child: SelectableText(json),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _loadSample() {
    // Sample JSON with various styles
    const sampleJson = '''[
  {"text": "Refactored ", "b": false, "i": false, "u": false},
  {"text": "Rich Text Editor", "b": true, "i": false, "u": false},
  {"text": " supports ", "b": false, "i": false, "u": false},
  {"text": "Immutable Data", "b": true, "i": true, "u": false},
  {"text": " and ", "b": false, "i": false, "u": false},
  {"text": "Robust Undo/Redo", "b": false, "i": false, "u": true},
  {"text": ".", "b": false, "i": false, "u": false}
]''';
    
    setState(() {
      _controller.text = sampleJson;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _editorKey.currentState;
    
    // Listen for state changes (e.g. undo/redo availability)
    return ListenableBuilder(
      listenable: state?.internalController ?? ChangeNotifier(),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Rich Text Editor V2'),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download),
                onPressed: _loadSample,
                tooltip: 'Load Sample',
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _showSaveDialog,
                tooltip: 'Show JSON',
              ),
            ],
          ),
          body: Column(
            children: [
              // Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: state?.canUndo == true ? () => state?.undo() : null,
                      tooltip: 'Undo',
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo),
                      onPressed: state?.canRedo == true ? () => state?.redo() : null,
                      tooltip: 'Redo',
                    ),
                    const VerticalDivider(width: 20, indent: 8, endIndent: 8),
                    IconButton(
                      icon: const Icon(Icons.format_bold),
                      onPressed: () => state?.toggleBold(),
                      color: state?.isBold == true 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                      tooltip: 'Bold',
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_italic),
                      onPressed: () => state?.toggleItalic(),
                      color: state?.isItalic == true 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                      tooltip: 'Italic',
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_underline),
                      onPressed: () => state?.toggleUnderline(),
                      color: state?.isUnderline == true 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                      tooltip: 'Underline',
                    ),
                  ],
                ),
              ),
              
              // Editor
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: RichTextEditor(
                    key: _editorKey,
                    controller: _controller,
                    hintText: 'Start typing to test Undo/Redo...',
                    maxLines: null,
                    style: const TextStyle(fontSize: 18, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
