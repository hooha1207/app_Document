import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/smiles_model.dart';
import '../services/document_service.dart';

class SmilesSearchScreen extends StatefulWidget {
  const SmilesSearchScreen({super.key});

  @override
  State<SmilesSearchScreen> createState() => _SmilesSearchScreenState();
}

class _SmilesSearchScreenState extends State<SmilesSearchScreen> {
  List<SmilesData> _allData = [];
  List<SmilesData> _filteredData = [];
  bool _isLoading = true;
  String _sortOrder = 'koName'; // 'koName', 'enName', 'hasMemo'
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/smiles_db.json');
      final List<dynamic> data = json.decode(response);
      _allData = data.map((e) => SmilesData.fromJson(e)).toList();
      _filteredData = List.from(_allData);
      _sortData();
    } catch (e) {
      debugPrint('Error loading SMILES data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performAsyncSearch(query);
    });
  }

  Future<void> _performAsyncSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    // 필터링 알고리즘: 비동기 처리를 위해 compute 사용 가능하나 데이터가 적을땐 직접 비동기처럼 처리
    // 대용량 데이터 대응을 위한 비동기 연산 시뮬레이션
    final results = await compute(_filterDataTask, {
      'data': _allData.map((e) => e.toJson()).toList(),
      'query': query.toLowerCase(),
      'memos': DocumentService.memoBox.toMap(),
    });

    if (mounted) {
      setState(() {
        _filteredData = results.map((e) => SmilesData.fromJson(e)).toList();
        _sortData();
        _isLoading = false;
      });
    }
  }

  static List<Map<String, dynamic>> _filterDataTask(Map<String, dynamic> params) {
    final List<dynamic> data = params['data'];
    final String query = params['query'];
    final Map<dynamic, dynamic> memos = params['memos'];

    if (query.isEmpty) return List<Map<String, dynamic>>.from(data);

    return data.where((item) {
      final String ko = (item['koName'] ?? '').toLowerCase();
      final String en = (item['enName'] ?? '').toLowerCase();
      final String sm = (item['smiles'] ?? '').toLowerCase();
      final String memo = (memos[item['smiles']] ?? '').toLowerCase();

      return ko.contains(query) || en.contains(query) || sm.contains(query) || memo.contains(query);
    }).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _sortData() {
    setState(() {
      if (_sortOrder == 'koName') {
        _filteredData.sort((a, b) => a.koName.compareTo(b.koName));
      } else if (_sortOrder == 'enName') {
        _filteredData.sort((a, b) => a.enName.compareTo(b.enName));
      } else if (_sortOrder == 'hasMemo') {
        _filteredData.sort((a, b) {
          final hasA = DocumentService.memoBox.containsKey(a.smiles);
          final hasB = DocumentService.memoBox.containsKey(b.smiles);
          if (hasA && !hasB) return -1;
          if (!hasA && hasB) return 1;
          return a.koName.compareTo(b.koName);
        });
      }
    });
  }

  Future<void> _editMemo(SmilesData item) async {
    final existingMemo = DocumentService.memoBox.get(item.smiles) ?? '';
    final controller = TextEditingController(text: existingMemo);

    final newMemo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.koName} 메모'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '메모를 입력하세요...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (newMemo != null) {
      if (newMemo.isEmpty) {
        await DocumentService.memoBox.delete(item.smiles);
      } else {
        await DocumentService.memoBox.put(item.smiles, newMemo);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('화학식 사전 검색'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              _sortOrder = value;
              _sortData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'koName', child: Text('이름순 (한글)')),
              const PopupMenuItem(value: 'enName', child: Text('이름순 (영어)')),
              const PopupMenuItem(value: 'hasMemo', child: Text('메모 있는 항목 우선')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '이름, 수식, 또는 메모 검색...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _filteredData.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.builder(
                      itemCount: _filteredData.length,
                      itemBuilder: (context, index) {
                        final item = _filteredData[index];
                        final memo = DocumentService.memoBox.get(item.smiles);
                        return ListTile(
                          title: Text('${item.koName} (${item.enName})'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.formula, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(item.smiles, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (memo != null && memo.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[50],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.amber[200]!),
                                  ),
                                  child: Text('📝 $memo', style: const TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.edit_note, color: memo != null ? Colors.blue : Colors.grey),
                            onPressed: () => _editMemo(item),
                          ),
                          onTap: () => Navigator.pop(context, item.smiles),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
