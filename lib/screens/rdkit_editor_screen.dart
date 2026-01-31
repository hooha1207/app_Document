import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'smiles_search_screen.dart';

/// Result returned when the user finishes editing in RdkitEditorScreen
class RdkitResult {
  final String smiles;
  final String imagePath;

  const RdkitResult({required this.smiles, required this.imagePath});
}

/// Standalone screen for editing / creating a chemical formula block using RDKit JS.
/// Returns a [RdkitResult] via Navigator.pop when the user taps "편집 완료".
class RdkitEditorScreen extends StatefulWidget {
  /// Pre-existing SMILES to edit (null / empty for a new block)
  final String? initialSmiles;

  const RdkitEditorScreen({super.key, this.initialSmiles});

  @override
  State<RdkitEditorScreen> createState() => _RdkitEditorScreenState();
}

class _RdkitEditorScreenState extends State<RdkitEditorScreen> {
  late final TextEditingController _smilesController;
  WebViewController? _webController;

  bool _rdkitReady = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _smilesController = TextEditingController(text: widget.initialSmiles ?? '');
    _initWebView();
  }

  Future<void> _initWebView() async {
    final controller = WebViewController();

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.white);

    // Register channel: Flutter receives 'ready' from JS
    await controller.addJavaScriptChannel(
      'RdkitReady',
      onMessageReceived: (_) {
        if (!mounted) return;
        setState(() {
          _rdkitReady = true;
        });
        // Auto-render initial smiles if editing
        final initial = widget.initialSmiles ?? '';
        if (initial.isNotEmpty) {
          _renderSmiles(initial);
        }
      },
    );

    // Load the local HTML from assets as a data URL
    final htmlContent = await rootBundle.loadString('assets/rdkit/rdkit_editor.html');
    await controller.loadHtmlString(htmlContent, baseUrl: 'https://rdkit.org');

    if (mounted) {
      setState(() {
        _webController = controller;
      });
    }
  }

  /// Tells the WebView JS layer to draw the current SMILES
  void _renderSmiles(String smiles) {
    if (!_rdkitReady || _webController == null) return;
    final escaped = smiles
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '');
    _webController!.runJavaScript("drawMolecule('$escaped');");
  }

  /// Captures the preview widget area directly from JS Canvas as base64 PNG
  Future<void> _onFinishEditing() async {
    if (_isSaving || _webController == null) return;
    setState(() {
      _isSaving = true;
    });

    try {
      // Small delay to ensure render is complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      final Object resultObj = await _webController!.runJavaScriptReturningResult('getBase64Image();');
      final String base64Url = resultObj.toString().replaceAll('"', '');

      if (base64Url.isEmpty || !base64Url.startsWith('data:image/png;base64,')) {
        _showError('유효한 화학식을 렌더링한 후 캡쳐해주세요.');
        return;
      }

      final String base64Data = base64Url.substring('data:image/png;base64,'.length);
      final Uint8List imageBytes = base64Decode(base64Data);

      // Save PNG to local app documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory rdkitDir = Directory(p.join(appDir.path, 'rdkit_cache'));
      if (!await rdkitDir.exists()) {
        await rdkitDir.create(recursive: true);
      }

      final String fileName =
          'rdkit_${DateTime.now().millisecondsSinceEpoch}.png';
      final File imageFile = File(p.join(rdkitDir.path, fileName));
      await imageFile.writeAsBytes(imageBytes);

      final result = RdkitResult(
        smiles: _smilesController.text.trim(),
        imagePath: imageFile.path,
      );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      _showError('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _smilesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          '화학식 편집기',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton.icon(
              onPressed: _rdkitReady ? _onFinishEditing : null,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                '편집 완료',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── SMILES input ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _smilesController,
              decoration: InputDecoration(
                labelText: 'SMILES 수식',
                hintText: '예) c1ccccc1 (벤젠)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                prefixIcon:
                    const Icon(Icons.science, color: Color(0xFF1A73E8)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF1A73E8)),
                  tooltip: '렌더링',
                  onPressed: () =>
                      _renderSmiles(_smilesController.text.trim()),
                ),
              ),
              onSubmitted: (v) => _renderSmiles(v.trim()),
              style:
                  const TextStyle(fontFamily: 'monospace', fontSize: 15),
            ),
          ),

          // ─ Search Button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (context) => const SmilesSearchScreen()),
                  );
                  if (result != null && result.isNotEmpty) {
                    _smilesController.text = result;
                    _renderSmiles(result);
                  }
                },
                icon: const Icon(Icons.search),
                label: const Text('화학식 사전에서 검색하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // ── Preview area ──────────────────────────────────────────
          Expanded(
            child: Container(
              color: Colors.white,
              child: _webController == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('WebView 초기화 중...',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        WebViewWidget(controller: _webController!),
                        if (!_rdkitReady)
                          Container(
                            color: Colors.white.withValues(alpha: 0.9),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('RDKit 라이브러리 로딩 중...',
                                      style: TextStyle(color: Colors.grey)),
                                  SizedBox(height: 8),
                                  Text('(인터넷 연결이 필요합니다)',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encodes a [RdkitResult] to a JSON string for storing in EditorBlock.content
String encodeRdkitContent(RdkitResult result) {
  return jsonEncode({'smiles': result.smiles, 'imagePath': result.imagePath});
}

/// Decodes stored EditorBlock.content JSON back to smiles + imagePath
Map<String, String> decodeRdkitContent(String content) {
  try {
    final map = jsonDecode(content) as Map<String, dynamic>;
    return {
      'smiles': map['smiles'] as String? ?? '',
      'imagePath': map['imagePath'] as String? ?? '',
    };
  } catch (_) {
    return {'smiles': '', 'imagePath': content};
  }
}
