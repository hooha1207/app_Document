import 'package:hive_flutter/hive_flutter.dart';
import '../models/document.dart';

class DocumentService {
  static const String _boxName = 'documents';
  static Box<Document>? _box;
  static Box<String>? _memoBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DocumentAdapter());
    _box = await Hive.openBox<Document>(_boxName);
    _memoBox = await Hive.openBox<String>('smiles_memos');
  }

  static Box<String> get memoBox {
    if (_memoBox == null) {
      throw Exception('Memo Box not initialized.');
    }
    return _memoBox!;
  }

  static Box<Document> get box {
    if (_box == null) {
      throw Exception('DocumentService not initialized. Call init() first.');
    }
    return _box!;
  }

  static Future<Document> createDocument(String title) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final document = Document(
      id: id,
      title: title,
      content: '[{"type":"text","content":""}]', // Empty initial content
      createdAt: now,
      updatedAt: now,
    );
    await box.put(id, document);
    return document;
  }

  static Document? getDocument(String id) {
    return box.get(id);
  }

  static List<Document> getAllDocuments() {
    return box.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // Most recent first
  }

  static Future<void> updateDocument(Document document) async {
    document.updatedAt = DateTime.now();
    await document.save();
  }

  static Future<void> deleteDocument(String id) async {
    await box.delete(id);
  }
}
