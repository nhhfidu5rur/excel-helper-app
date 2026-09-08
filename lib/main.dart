import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مساعد الاكسل',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _passwordController = TextEditingController();
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('اكتب كلمة المرور لفتح البرنامج', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'كلمة المرور'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (_passwordController.text.trim() == '000') {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
                } else {
                  setState(() {
                    _error = 'كلمة المرور غير صحيحة';
                  });
                }
              },
              child: const Text('فتح'),
            ),
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FileModel> files = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('data');
    if (s != null) {
      final decoded = jsonDecode(s) as List;
      setState(() {
        files = decoded.map((e) => FileModel.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final list = files.map((e) => e.toJson()).toList();
    await prefs.setString('data', jsonEncode(list));
  }

  void _addFile() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة ملف Excel جديد'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الملف')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  files.add(FileModel(name: name, lists: []));
                });
                _saveData();
                Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _openFile(FileModel file) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FilePage(file: file, onUpdate: (updated) {
          setState(() {});
          _saveData();
        })));
  }

  void _deleteFile(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف الملف؟ ستفقد كل القوائم والبيانات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  files.removeAt(index);
                });
                _saveData();
                Navigator.pop(context);
              },
              child: const Text('حذف')),
        ],
      ),
    );
  }

  Future<void> _exportAll() async {
    // Create a workbook and sheets for each file
    final excel = Excel.createExcel();
    // Remove default sheet
    excel.delete('Sheet1');

    for (var f in files) {
      final sheetName = f.name;
      for (var lst in f.lists) {
        final sheetTitle = '${sheetName}-${lst.name}';
        final sheet = excel[sheetTitle];
        sheet.appendRow(['التاريخ', 'النص']);
        for (var entry in lst.entries) {
          sheet.appendRow([entry.date, entry.text]);
        }
      }
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    // Share the file so the user can save it
    await Share.shareXFiles([XFile(file.path)], text: 'ملف تصدير من مساعد الاكسل');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفاتي'),
        actions: [
          IconButton(onPressed: _exportAll, icon: const Icon(Icons.download)),
        ],
      ),
      body: files.isEmpty
          ? const Center(child: Text('لا توجد ملفات. أضف ملفاً جديداً.'))
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (_, i) {
                final f = files[i];
                return ListTile(
                  title: Text(f.name),
                  subtitle: Text('${f.lists.length} قوائم'),
                  onTap: () => _openFile(f),
                  trailing: IconButton(onPressed: () => _deleteFile(i), icon: const Icon(Icons.delete, color: Colors.red)),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFile,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class FilePage extends StatefulWidget {
  final FileModel file;
  final void Function(FileModel) onUpdate;
  const FilePage({required this.file, required this.onUpdate, super.key});

  @override
  State<FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<FilePage> {
  void _addList() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة قائمة جديدة'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم القائمة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    widget.file.lists.add(ListModel(name: name, entries: []));
                  });
                  widget.onUpdate(widget.file);
                  Navigator.pop(context);
                }
              },
              child: const Text('إضافة')),
        ],
      ),
    );
  }

  void _openList(ListModel lst) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListPage(list: lst, onUpdate: () {
          setState(() {});
          widget.onUpdate(widget.file);
        })));
  }

  void _deleteList(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذه القائمة مع كل محتواها؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.file.lists.removeAt(index);
                });
                widget.onUpdate(widget.file);
                Navigator.pop(context);
              },
              child: const Text('حذف')),
        ],
      ),
    );
  }

  Future<void> _exportFile(FileModel file) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    for (var lst in file.lists) {
      final sheet = excel[lst.name];
      sheet.appendRow(['التاريخ', 'النص']);
      for (var e in lst.entries) {
        sheet.appendRow([e.date, e.text]);
      }
    }
    final bytes = excel.encode();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${file.name}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await f.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(f.path)], text: 'تصدير ${file.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.file.name), actions: [IconButton(onPressed: () => _exportFile(widget.file), icon: const Icon(Icons.download))]),
      body: widget.file.lists.isEmpty
          ? const Center(child: Text('لا توجد قوائم. أضف قائمة جديدة.'))
          : ListView.builder(
              itemCount: widget.file.lists.length,
              itemBuilder: (_, i) {
                final lst = widget.file.lists[i];
                return ListTile(
                  title: Text(lst.name),
                  subtitle: Text('${lst.entries.length} إدخالات'),
                  onTap: () => _openList(lst),
                  trailing: IconButton(onPressed: () => _deleteList(i), icon: const Icon(Icons.delete, color: Colors.red)),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(onPressed: _addList, child: const Icon(Icons.add)),
    );
  }
}

class ListPage extends StatefulWidget {
  final ListModel list;
  final VoidCallback onUpdate;
  const ListPage({required this.list, required this.onUpdate, super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final TextEditingController _textController = TextEditingController();

  void _addEntry() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final formatted = DateFormat('yyyy/M/d').format(now);
    setState(() {
      widget.list.entries.insert(0, EntryModel(date: formatted, text: text));
      _textController.clear();
    });
    widget.onUpdate();
  }

  void _deleteEntry(int index) {
    setState(() {
      widget.list.entries.removeAt(index);
    });
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.list.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _textController, decoration: const InputDecoration(labelText: 'نص الإدخال'))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addEntry, child: const Text('إضافة'))
              ],
            ),
          ),
          Expanded(
            child: widget.list.entries.isEmpty
                ? const Center(child: Text('لا توجد إدخالات بعد.'))
                : ListView.builder(
                    itemCount: widget.list.entries.length,
                    itemBuilder: (_, i) {
                      final e = widget.list.entries[i];
                      return ListTile(
                        title: Text(e.text),
                        subtitle: Text(e.date),
                        trailing: IconButton(onPressed: () => _deleteEntry(i), icon: const Icon(Icons.delete, color: Colors.red)),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}

// Models
class FileModel {
  String name;
  List<ListModel> lists;
  FileModel({required this.name, required this.lists});

  factory FileModel.fromJson(Map<String, dynamic> j) => FileModel(
        name: j['name'],
        lists: (j['lists'] as List).map((e) => ListModel.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {'name': name, 'lists': lists.map((e) => e.toJson()).toList()};
}

class ListModel {
  String name;
  List<EntryModel> entries;
  ListModel({required this.name, required this.entries});

  factory ListModel.fromJson(Map<String, dynamic> j) => ListModel(
        name: j['name'],
        entries: (j['entries'] as List).map((e) => EntryModel.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {'name': name, 'entries': entries.map((e) => e.toJson()).toList()};
}

class EntryModel {
  String date;
  String text;
  EntryModel({required this.date, required this.text});

  factory EntryModel.fromJson(Map<String, dynamic> j) => EntryModel(date: j['date'], text: j['text']);
  Map<String, dynamic> toJson() => {'date': date, 'text': text};
}
