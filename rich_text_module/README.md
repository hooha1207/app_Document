# Segment-based Rich Text Editor for Flutter

네이티브 TextField를 활용한 세그먼트 기반 Rich Text Editor입니다.

## 특징

- ✅ **완전한 네이티브 지원**: Flutter TextField 사용으로 모든 플랫폼 기능 지원
- ✅ **세그먼트 기반**: 각 텍스트 조각을 개별 스타일과 함께 관리
- ✅ **Diff 알고리즘**: 효율적인 O(n) 업데이트
- ✅ **Sticky Style**: MS Word처럼 스타일 버튼 클릭 후 입력 시 스타일 적용
- ✅ **JSON 직렬화**: 간단한 저장/불러오기
- ✅ **확장 가능**: 새로운 스타일 추가 용이

## 설치

이 파일을 프로젝트의 `lib/` 디렉토리에 복사하세요:

```
lib/
  widgets/
    rich_text_editor.dart
```

## 기본 사용법

### 1. Controller 생성

```dart
final controller = TextEditingController();
```

### 2. Widget 사용

```dart
RichTextEditor(
  controller: controller,
  hintText: 'Enter text...',
)
```

### 3. Toolbar 연결

```dart
final editorKey = GlobalKey<RichTextEditorState>();

// Widget
RichTextEditor(
  key: editorKey,
  controller: controller,
)

// Toolbar buttons
IconButton(
  icon: Icon(Icons.format_bold),
  onPressed: () => editorKey.currentState?.toggleBold(),
)
```

### 완전한 예제

```dart
import 'package:flutter/material.dart';
import 'rich_text_editor.dart';

class MyEditor extends StatefulWidget {
  @override
  State<MyEditor> createState() => _MyEditorState();
}

class _MyEditorState extends State<MyEditor> {
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
            IconButton(
              icon: Icon(Icons.format_italic),
              onPressed: () => _editorKey.currentState?.toggleItalic(),
            ),
            IconButton(
              icon: Icon(Icons.format_underline),
              onPressed: () => _editorKey.currentState?.toggleUnderline(),
            ),
          ],
        ),
        
        // Editor
        Expanded(
          child: RichTextEditor(
            key: _editorKey,
            controller: _controller,
            hintText: 'Enter text...',
          ),
        ),
      ],
    );
  }
}
```

## 저장 및 불러오기

### 저장

```dart
// SegmentedTextEditingController 접근
final internalController = _editorKey.currentState?.internalController;
final String jsonData = internalController?.toSegmentJson() ?? '[]';

// 파일이나 DB에 jsonData 저장
await saveToFile(jsonData);
```

### 불러오기

```dart
// 저장된 JSON 불러오기
final String jsonData = await loadFromFile();

// Controller에 설정
_controller.text = jsonData;
```

## API 문서

### RichTextEditor

**Properties:**
- `controller` (TextEditingController, required): 텍스트 컨트롤러
- `focusNode` (FocusNode?): 포커스 노드
- `hintText` (String): 힌트 텍스트
- `decoration` (InputDecoration?): 커스텀 데코레이션
- `style` (TextStyle?): 기본 텍스트 스타일
- `maxLines` (int?): 최대 라인 수

**Methods (via State):**
- `toggleBold()`: Bold 토글
- `toggleItalic()`: Italic 토글
- `toggleUnderline()`: Underline 토글

**Getters (via State):**
- `isBold` (bool): 현재 Bold 상태
- `isItalic` (bool): 현재 Italic 상태
- `isUnderline` (bool): 현재 Underline 상태

### TextSegment

```dart
class TextSegment {
  String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
}
```

**JSON 형식:**
```json
[
  {"text": "Hello ", "b": true, "i": false, "u": false},
  {"text": "World", "b": false, "i": true, "u": false}
]
```

## 커스터마이징

### 새로운 스타일 추가

`TextSegment` 클래스에 필드를 추가하고 관련 메서드를 구현하세요:

```dart
class TextSegment {
  String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final Color? color;  // 새로운 필드
  
  // toJson, fromJson, copyWith, style getter 업데이트
}
```

### 테마 적용

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
  ),
)
```

## 기술적 세부사항

### Diff 알고리즘

텍스트 변경 시:
1. 공통 접두사 계산
2. 공통 접미사 계산
3. 변경 영역만 추출
4. 세그먼트 업데이트
5. 동일 스타일 세그먼트 병합

복잡도: O(n), 대부분의 입력은 매우 빠름

### Sticky Style

- 스타일 버튼 클릭: 다음 입력에 적용될 스타일 설정
- 커서 이동: 커서 앞 글자의 스타일로 동기화
- 텍스트 선택 후 스타일 적용: 선택 영역의 스타일 즉시 변경

### 이중 컨트롤러 구조

```
External Controller (JSON) ←→ Internal Controller (Segments) ←→ TextField
```

- **External**: 상위 레벨에서 JSON 데이터 관리
- **Internal**: 세그먼트 로직 처리
- **양방향 동기화**: 무한 루프 방지

## 제한사항

- 현재 Bold, Italic, Underline만 지원
- 매우 긴 문서(10만자 이상)에서는 성능 최적화 필요
- Undo/Redo 기능 미포함

## 라이선스

MIT License - 자유롭게 사용하세요.

## 기여

이슈나 개선 사항은 GitHub에서 제안해주세요.
