# 다른 프로젝트에 Rich Text Editor 이식하기

이 가이드는 세그먼트 기반 Rich Text Editor를 다른 Flutter 프로젝트에 통합하는 방법을 설명합니다.

## 빠른 시작 (5분)

### 1단계: 파일 복사

`rich_text_editor.dart` 파일을 프로젝트에 복사:

```
your_project/
  lib/
    widgets/
      rich_text_editor.dart  ← 여기에 복사
```

### 2단계: 사용

```dart
import 'package:flutter/material.dart';
import 'widgets/rich_text_editor.dart';

class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final _controller = TextEditingController();
  final _editorKey = GlobalKey<RichTextEditorState>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.format_bold),
              onPressed: () => _editorKey.currentState?.toggleBold(),
            ),
          ],
        ),
        
        // Editor
        RichTextEditor(
          key: _editorKey,
          controller: _controller,
        ),
      ],
    );
  }
}
```

### 3단계: 실행

```bash
flutter run
```

끝! 이제 작동하는 Rich Text Editor가 있습니다.

---

## 상세 가이드

### 의존성

이 모듈은 **Flutter 기본 패키지만** 사용합니다:
- `dart:convert` (JSON 직렬화)
- `dart:math` (min/max)
- `package:flutter/material.dart` (UI)

**외부 패키지 불필요!**

### 저장 및 불러오기 통합

#### 로컬 저장소 (SharedPreferences)

```dart
import 'package:shared_preferences/shared_preferences.dart';

// 저장
Future<void> saveDocument() async {
  final prefs = await SharedPreferences.getInstance();
  final state = _editorKey.currentState;
  final json = state?._internalController.toSegmentJson() ?? '[]';
  await prefs.setString('my_document', json);
}

// 불러오기
Future<void> loadDocument() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString('my_document') ?? '[]';
  setState(() {
    _controller.text = json;
  });
}
```

#### 파일 저장소

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// 저장
Future<void> saveToFile(String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  
  final state = _editorKey.currentState;
  final json = state?._internalController.toSegmentJson() ?? '[]';
  await file.writeAsString(json);
}

// 불러오기
Future<void> loadFromFile(String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  
  if (await file.exists()) {
    final json = await file.readAsString();
    setState(() {
      _controller.text = json;
    });
  }
}
```

#### 데이터베이스 (SQLite)

```dart
import 'package:sqflite/sqflite.dart';

// 테이블 생성
await db.execute('''
  CREATE TABLE documents (
    id INTEGER PRIMARY KEY,
    title TEXT,
    content TEXT
  )
''');

// 저장
Future<void> saveToDb(int id, String title) async {
  final state = _editorKey.currentState;
  final json = state?._internalController.toSegmentJson() ?? '[]';
  
  await db.insert('documents', {
    'id': id,
    'title': title,
    'content': json,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

// 불러오기
Future<void> loadFromDb(int id) async {
  final results = await db.query('documents', where: 'id = ?', whereArgs: [id]);
  if (results.isNotEmpty) {
    final json = results.first['content'] as String;
    setState(() {
      _controller.text = json;
    });
  }
}
```

### Toolbar 커스터마이징

#### 동적 버튼 상태

```dart
class _MyScreenState extends State<MyScreen> {
  @override
  Widget build(BuildContext context) {
    final state = _editorKey.currentState;
    
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.format_bold),
          color: state?.isBold == true ? Colors.blue : Colors.grey,
          onPressed: () {
            state?.toggleBold();
            setState(() {}); // UI 업데이트
          },
        ),
      ],
    );
  }
}
```

#### ListenableBuilder로 자동 업데이트

```dart
class _MyScreenState extends State<MyScreen> {
  late final SegmentedTextEditingController _internalController;
  
  @override
  void initState() {
    super.initState();
    // 내부 컨트롤러 접근 (고급 기능)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _internalController = _editorKey.currentState!._internalController;
      setState(() {});
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _internalController,
      builder: (context, child) {
        return Row(
          children: [
            IconButton(
              icon: Icon(Icons.format_bold),
              color: _internalController.isBold ? Colors.blue : Colors.grey,
              onPressed: () => _editorKey.currentState?.toggleBold(),
            ),
          ],
        );
      },
    );
  }
}
```

### 스타일 커스터마이징

#### 다크 모드 지원

```dart
RichTextEditor(
  controller: _controller,
  style: TextStyle(
    fontSize: 16,
    color: Theme.of(context).textTheme.bodyLarge?.color,
  ),
  decoration: InputDecoration(
    border: OutlineInputBorder(),
    fillColor: Theme.of(context).cardColor,
    filled: true,
    hintText: 'Enter text...',
  ),
)
```

#### 패딩 조정

```dart
RichTextEditor(
  controller: _controller,
  decoration: InputDecoration(
    border: InputBorder.none,
    contentPadding: EdgeInsets.all(20), // 커스텀 패딩
  ),
)
```

### 기존 코드와 통합

#### 기존 문서 편집 앱

```dart
class DocumentEditor extends StatefulWidget {
  final String documentId;
  
  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  late TextEditingController _controller;
  final _editorKey = GlobalKey<RichTextEditorState>();
  
  @override
  void initState() {
    super.initState();
    _loadDocument();
  }
  
  Future<void> _loadDocument() async {
    final doc = await myDatabase.getDocument(widget.documentId);
    _controller = TextEditingController(text: doc.content);
    setState(() {});
  }
  
  Future<void> _saveDocument() async {
    final state = _editorKey.currentState;
    final json = state?._internalController.toSegmentJson() ?? '[]';
    await myDatabase.updateDocument(widget.documentId, json);
  }
}
```

## 문제 해결

### Q: 저장한 데이터를 불러왔는데 스타일이 안 보여요

A: `_controller.text`에 JSON 문자열을 설정했는지 확인하세요:

```dart
// ❌ 잘못된 방법
_controller.text = plainText;

// ✅ 올바른 방법
_controller.text = jsonString; // JSON 형식의 문자열
```

### Q: 커서가 이상한 곳으로 이동해요

A: 현재 알려진 이슈입니다. `_syncToParent()` 메서드의 selection mapping을 개선 중입니다.

### Q: 성능이 느려요

A: 문서가 매우 긴 경우 (10만 자 이상) 성능 문제가 있을 수 있습니다. code_analysis.md의 성능 최적화 섹션을 참조하세요.

### Q: 새로운 스타일을 추가하고 싶어요

A: `TextSegment` 클래스를 수정하면 됩니다:

```dart
class TextSegment {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final Color? textColor;  // 추가!
  
  // toJson, fromJson, copyWith, style getter 수정 필요
}
```

## 다음 단계

1. **테스트**: 앱에서 충분히 테스트
2. **피드백**: 문제점 발견 시 개선
3. **확장**: 필요한 스타일 추가
4. **최적화**: 성능 모니터링

## 추가 리소스

- `README.md`: 기본 사용법
- `example.dart`: 완전한 예제 앱
- `code_analysis.md`: 코드 품질 및 개선 사항
