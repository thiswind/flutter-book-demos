// ============================================================
// 第10课（第12周）：本地数据存储 演示页
// 对应《Flutter实战·第二版》11.1 文件操作
//          + shared_preferences / sqflite（pub.dev 官方包）
//          + 讲义十：存储选型矩阵 / 迁移通道 / local_store 案例
// EX21~EX25 为扩展案例（含故意设计的缺陷，供学生修复练习）
//   症状复现口径：永远默认/查了个寂寞/注入/新列失踪/密码裸奔，
//   对齐题库十 第39/40/25/38/10 题，详见讲义十 10A 节
//
// 平台说明：演示站部署在浏览器（GitHub Pages），dart:io 与原生
// sqflite 在 web 不可用。本文件用两个教学模拟器保持与教科书
// 完全一致的 API 签名：
//   MiniFs —— 模拟文件系统（临时/文档两目录、覆盖写/追加、异常）
//   MiniDb —— 模拟 sqflite（version/onCreate/onUpgrade 迁移通道、
//             全 Future CRUD、where/whereArgs 参数化）
// 数据落在浏览器 localStorage（经 shared_preferences），刷新不丢；
// 真机上这两层替换为 path_provider+dart:io 与 sqflite 即可。
// ============================================================
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show Demo, sec;

// ============================================================
// 教学模拟器一：MiniFs（文件系统）
// ============================================================
class FsException implements Exception {
  final String message;
  const FsException(this.message);
  @override
  String toString() => 'FsException: $message';
}

class MiniFs {
  /// 系统可随时清理的临时目录（放缓存；空间紧张时可能被清空）
  static const tmpDir = '/data/tmp（系统可清理）';

  /// 应用私有持久目录（放用户数据；卸载才删除）
  static const docDir = '/data/documents（应用私有·持久）';

  static Future<SharedPreferences> get _sp => SharedPreferences.getInstance();

  static String _k(String path) => 'minifs:$path';

  /// 写文件：默认整文件覆盖；append=true 追加到末尾
  static Future<void> write(
    String path,
    String content, {
    bool append = false,
  }) async {
    final sp = await _sp;
    final old = sp.getString(_k(path));
    await sp.setString(_k(path), append ? (old ?? '') + content : content);
  }

  /// 读文件：文件不存在抛 FsException（真机上对应 FileSystemException）
  static Future<String> read(String path) async {
    final sp = await _sp;
    final s = sp.getString(_k(path));
    if (s == null) throw const FsException('文件不存在（首次读取）');
    return s;
  }

  /// 安全读：不存在返回 null，不抛异常（讲义三、load() 的口径）
  static Future<String?> tryRead(String path) async {
    try {
      return await read(path);
    } on FsException {
      return null;
    }
  }

  static Future<void> remove(String path) async {
    final sp = await _sp;
    await sp.remove(_k(path));
  }
}

// ============================================================
// 教学模拟器二：MiniDb（sqflite 同签名教学引擎）
//   - openDatabase(path, version:, onCreate:, onUpgrade:)
//     首次打开 → onCreate；version 变大 → onUpgrade(old, new)
//   - insert/query/update/delete 全部返回 Future（忘 await 必翻车）
//   - query 支持 where/whereArgs/orderBy/limit/columns（仿 sqflite）
//   - execute 支持 CREATE TABLE / ALTER TABLE ADD COLUMN
//   - 表结构与数据序列化进 localStorage：刷新=真机重启进程后
//     重开已存在的库文件；version 判断与真机语义一致
// ============================================================
class MiniDbException implements Exception {
  final String message;
  const MiniDbException(this.message);
  @override
  String toString() => 'MiniDbException: $message';
}

typedef OnDbCreate = Future<void> Function(MiniDb db, int version);
typedef OnDbUpgrade = Future<void> Function(MiniDb db, int oldV, int newV);

class MiniDb {
  final String path;
  late final SharedPreferences _sp;
  final _tables = <String, _MiniTable>{};

  MiniDb._(this.path);

  static String _vk(String p) => 'minidb:$p:version';
  static String _tk(String p) => 'minidb:$p:tables';
  String _rk(String t) => 'minidb:$path:tbl:$t';

  /// 清库（重装演示用）：抹掉 version / 表清单 / 各表数据
  static Future<void> drop(String path) async {
    final sp = await SharedPreferences.getInstance();
    final tables = sp.getStringList(_tk(path)) ?? const [];
    await sp.remove(_vk(path));
    await sp.remove(_tk(path));
    for (final t in tables) {
      await sp.remove('minidb:$path:tbl:$t');
    }
  }

  static Future<MiniDb> openDatabase(
    String path, {
    required int version,
    OnDbCreate? onCreate,
    OnDbUpgrade? onUpgrade,
  }) async {
    final db = MiniDb._(path);
    db._sp = await SharedPreferences.getInstance();
    await db._loadTables();

    final stored = db._sp.getInt(_vk(path));
    if (stored == null) {
      // 首次建库：走 onCreate，落 version
      await onCreate?.call(db, version);
      await db._sp.setInt(_vk(path), version);
    } else if (version > stored) {
      // 代码版本更高：走 onUpgrade 迁移通道（oldVersion → newVersion）
      await onUpgrade?.call(db, stored, version);
      await db._sp.setInt(_vk(path), version);
    }
    // version 相同（或更低）：什么都不执行——这正是 EX24 的病根
    return db;
  }

  Future<int> get storedVersion async =>
      (await SharedPreferences.getInstance()).getInt(_vk(path)) ?? 0;

  // ---------- DDL ----------
  Future<void> execute(String sql) async {
    final s = sql.trim().replaceAll(RegExp(r'\s+'), ' ');
    var m = RegExp(
      r'CREATE TABLE (\w+)\s*\((.*)\)',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null) {
      final name = m.group(1)!;
      final cols = m
          .group(2)!
          .split(',')
          .map((c) => c.trim().split(RegExp(r'\s+')).first)
          .where((c) => c.isNotEmpty)
          .toList();
      _tables[name] = _MiniTable(name, cols);
      await _saveTable(name);
      return;
    }
    m = RegExp(
      r'ALTER TABLE (\w+) ADD COLUMN (\w+)',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null) {
      final name = m.group(1)!;
      final col = m.group(2)!;
      final t = _getTable(name);
      if (t.cols.contains(col)) {
        throw MiniDbException('duplicate column name: $col');
      }
      t.cols.add(col);
      for (final r in t.rows) {
        r[col] = null; // ALTER ADD COLUMN：老行新列补 NULL
      }
      await _saveTable(name);
      return;
    }
    throw MiniDbException('不支持的 SQL（教学引擎仅示范建表/加列）: $sql');
  }

  // ---------- DML（全部 Future，签名仿 sqflite） ----------
  Future<int> insert(String table, Map<String, Object?> values) async {
    final t = _getTable(table);
    final row = <String, Object?>{...values};
    row['id'] = t.nextId++;
    if (t.cols.contains('updatedAt') && row['updatedAt'] == null) {
      row['updatedAt'] = DateTime.now().toIso8601String();
    }
    t.rows.add(row);
    await _saveTable(table);
    return row['id'] as int;
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    List<String>? columns,
  }) async {
    final t = _getTable(table);
    if (columns != null) {
      for (final c in columns) {
        if (!t.cols.contains(c)) {
          throw MiniDbException('no such column: $c');
        }
      }
    }
    var rows = List<Map<String, Object?>>.from(t.rows);
    if (where != null) {
      rows = rows
          .where((r) => _match(r, where, whereArgs ?? const []))
          .toList();
    }
    if (orderBy != null) {
      final keys = orderBy
          .split(',')
          .map((k) => k.trim().split(RegExp(r'\s+')))
          .toList();
      rows.sort((a, b) {
        for (final k in keys) {
          final col = k[0];
          final desc = k.length > 1 && k[1].toUpperCase() == 'DESC';
          final c = _cmp(a[col], b[col]);
          if (c != 0) return desc ? -c : c;
        }
        return 0;
      });
    }
    if (limit != null) rows = rows.take(limit).toList();
    if (columns != null) {
      rows = rows.map((r) => {for (final c in columns) c: r[c]}).toList();
    }
    return rows;
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final t = _getTable(table);
    var n = 0;
    for (final r in t.rows) {
      if (where == null || _match(r, where, whereArgs ?? const [])) {
        r.addAll(values);
        if (t.cols.contains('updatedAt') && values.containsKey('updatedAt')) {
          // 保留调用方写入的 updatedAt
        }
        n++;
      }
    }
    await _saveTable(table);
    return n;
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final t = _getTable(table);
    final before = t.rows.length;
    t.rows.removeWhere(
      (r) => where == null || _match(r, where, whereArgs ?? const []),
    );
    await _saveTable(table);
    return before - t.rows.length;
  }

  Future<void> close() async {}

  // ---------- 内部 ----------
  _MiniTable _getTable(String name) {
    final t = _tables[name];
    if (t == null) throw MiniDbException('no such table: $name');
    return t;
  }

  /// where 支持 "col = ?" / "col LIKE ?"，多条件 AND 连接
  bool _match(Map<String, Object?> row, String where, List<Object?> args) {
    var i = 0; // 第几个 ?
    for (final part in where.split(
      RegExp(r'\s+AND\s+', caseSensitive: false),
    )) {
      final m = RegExp(r"(\w+)\s*(=|LIKE)\s*\?").firstMatch(part.trim());
      if (m == null) throw MiniDbException('不支持的条件: $part');
      final col = m.group(1)!;
      final op = m.group(2)!;
      final arg = args[i++].toString();
      final val = row[col]?.toString() ?? '';
      if (op == '=') {
        if (val != arg) return false;
      } else {
        // LIKE：仅支持 %kw% / kw% / %kw 三形（教学够用）
        if (!_like(val, arg)) return false;
      }
    }
    return true;
  }

  bool _like(String val, String pattern) {
    var p = pattern;
    final start = p.startsWith('%');
    final end = p.endsWith('%');
    if (start) p = p.substring(1);
    if (end) p = p.substring(0, p.length - 1);
    final v = val.toLowerCase(), q = p.toLowerCase();
    if (start && end) return v.contains(q);
    if (start) return v.endsWith(q);
    if (end) return v.startsWith(q);
    return v == q;
  }

  int _cmp(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    final x = num.tryParse(a.toString()), y = num.tryParse(b.toString());
    if (x != null && y != null) return x.compareTo(y);
    return a.toString().compareTo(b.toString());
  }

  Future<void> _loadTables() async {
    final names = _sp.getStringList(_tk(path)) ?? const [];
    for (final n in names) {
      final raw = _sp.getString(_rk(n));
      if (raw == null) continue;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _tables[n] =
          _MiniTable(
              n,
              (m['cols'] as List).cast<String>(),
              nextId: m['nextId'] as int,
            )
            ..rows = (m['rows'] as List)
                .map((r) => Map<String, Object?>.from(r as Map))
                .toList();
    }
  }

  Future<void> _saveTable(String name) async {
    final t = _tables[name]!;
    await _sp.setString(_rk(name), jsonEncode(t));
    final names = _sp.getStringList(_tk(path)) ?? <String>[];
    if (!names.contains(name)) {
      names.add(name);
      await _sp.setStringList(_tk(path), names);
    }
  }
}

class _MiniTable {
  final String name;
  final List<String> cols;
  List<Map<String, Object?>> rows = [];
  int nextId = 1;
  _MiniTable(this.name, this.cols, {this.nextId = 1});
  Map<String, dynamic> toJson() => {
    'cols': cols,
    'rows': rows,
    'nextId': nextId,
  };
}

// ---------- notes 表种子数据 ----------
const kNotesDdlV1 =
    'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'title TEXT NOT NULL, body TEXT, pinned INT DEFAULT 0, updatedAt TEXT)';

Future<void> _seedNotes(MiniDb db) async {
  final n = await db.query('notes');
  if (n.isNotEmpty) return;
  await db.insert('notes', {
    'title': '买《Flutter实战·第二版》',
    'body': '文件/网络/原理篇都要看',
    'pinned': 1,
  });
  await db.insert('notes', {
    'title': '周五前交课堂作业十',
    'body': 'lecture10 仓库 3 次提交',
    'pinned': 0,
  });
  await db.insert('notes', {
    'title': '周末跑 5 公里',
    'body': '久坐写代码要活动',
    'pinned': 0,
  });
}

// ============================================================
// 知识页 1：11.1 文件读写（教科书）
// ============================================================
Widget _d111File(BuildContext context) => const _FilePage();

class _FilePage extends StatefulWidget {
  const _FilePage();
  @override
  State<_FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<_FilePage> {
  static const _counterPath = '${MiniFs.docDir}/counter.json';
  int _count = 0;
  String _log = '（点按钮试试）';
  String? _appendDemo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 教科书计数器文件版：启动读文件，读不到给默认值
    final s = await MiniFs.tryRead(_counterPath);
    if (s != null) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      setState(() {
        _count = m['count'] as int? ?? 0;
        _log = '启动时从文件读回：count=$_count';
      });
    } else {
      setState(() => _log = '文件还不存在 → 默认值 0（不抛异常的写法）');
    }
  }

  Future<void> _inc() async {
    _count++;
    await MiniFs.write(_counterPath, jsonEncode({'count': _count}));
    setState(() => _log = '写入 $_counterPath → {"count":$_count}（整文件覆盖）');
  }

  Future<void> _readMissing() async {
    try {
      await MiniFs.read('${MiniFs.tmpDir}/不存在.json');
    } on FsException catch (e) {
      setState(() => _log = '捕获异常：$e → 返回 null 兜底');
    }
  }

  Future<void> _appendLog() async {
    const p = '${MiniFs.tmpDir}/log.txt';
    await MiniFs.write(p, '[${DateTime.now().second}s] 一行日志\n', append: true);
    final s = await MiniFs.tryRead(p);
    setState(() => _appendDemo = s);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 两个核心目录（path_provider）'),
        Row(
          children: const [
            Expanded(
              child: Card(
                color: Color(0xFFFFF3E0),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'getTemporaryDirectory()\n临时目录：系统可随时清理\n放缓存、日志',
                    style: TextStyle(fontSize: 12, height: 1.7),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Card(
                color: Color(0xFFE8F5E9),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'getApplicationDocumentsDirectory()\n文档目录：私有持久\n放用户数据',
                    style: TextStyle(fontSize: 12, height: 1.7),
                  ),
                ),
              ),
            ),
          ],
        ),
        sec('② 教科书计数器·文件版（重启保持）'),
        Container(
          padding: const EdgeInsets.all(14),
          color: Colors.indigo.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                '$_count',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton(
                onPressed: _inc,
                child: const Text('count+1 并写文件'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(_log, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _readMissing,
              child: const Text('读不存在的文件'),
            ),
            OutlinedButton(
              onPressed: _appendLog,
              child: const Text('append 追加写日志'),
            ),
          ],
        ),
        if (_appendDemo != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade200,
            child: Text(
              'log.txt（临时目录）：\n$_appendDemo',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.6,
              ),
            ),
          ),
        sec('③ 三条铁律'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '1. 文件 IO 全是异步 API：await 不能省\n'
            '2. writeAsString 默认整文件覆盖；追加要 FileMode.append\n'
            '3. readAsString 可能抛 FileSystemException——按第4课规范捕获兜底',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '平台说明：演示站跑在浏览器沙箱，文件内容落在 localStorage 模拟；'
          '\n真机上把 MiniFs 换成 path_provider + dart:io 的 File 即可，API 语义一致。',
          style: TextStyle(fontSize: 11, height: 1.6, color: Colors.black38),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 2：shared_preferences 键值存储（真实插件）
// ============================================================
Widget _dSp(BuildContext context) => const _SpPage();

class _SpPage extends StatefulWidget {
  const _SpPage();
  @override
  State<_SpPage> createState() => _SpPageState();
}

class _SpPageState extends State<_SpPage> {
  bool _dark = false;
  int _launches = 0;
  List<String> _history = const [];
  String? _missingKeyDemo;
  String _log = '加载中…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 正确姿势：initState 里异步加载，加载完 setState 再渲染
  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _dark = sp.getBool('demo.dark') ?? false; // ?? 默认值兜底
      _history = sp.getStringList('demo.history') ?? const [];
      _log = '已从 sp 加载（getInstance 异步完成）';
    });
    await sp.setInt('demo.launches', (sp.getInt('demo.launches') ?? 0) + 1);
    setState(() => _launches = sp.getInt('demo.launches')!);
  }

  Future<void> _toggleDark() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('demo.dark', !_dark); // 写后立即生效，落盘插件负责
    setState(() => _dark = !_dark);
  }

  Future<void> _addHistory(String s) async {
    if (s.trim().isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    _history = [s, ..._history].take(5).toList();
    await sp.setStringList('demo.history', _history);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 五种类型一次看全'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo.shade50,
          child: const Text(
            'String   sp.setString(\'name\', \'胡老师\')\n'
            'int      sp.setInt(\'launches\', 3)\n'
            'double   sp.setDouble(\'scale\', 1.25)\n'
            'bool     sp.setBool(\'darkMode\', true)\n'
            'List<String>  sp.setStringList(\'history\', [...])',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 2.0,
            ),
          ),
        ),
        sec('② 真持久化：开关与启动次数（刷新页面试试）'),
        Card(
          color: _dark ? Colors.grey.shade900 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Switch(value: _dark, onChanged: (_) => _toggleDark()),
                    const SizedBox(width: 8),
                    Text(
                      '深色模式（demo.dark）',
                      style: TextStyle(
                        color: _dark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Text(
                  '本页累计打开 $_launches 次（demo.launches，int）',
                  style: TextStyle(
                    color: _dark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _log,
                  style: TextStyle(
                    fontSize: 12,
                    color: _dark ? Colors.amber : Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
        sec('③ 上次输入记忆（List<String>，最多留 5 条）'),
        TextField(
          onSubmitted: _addHistory,
          decoration: const InputDecoration(
            labelText: '输入点什么回车——刷新后还在',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        if (_history.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final h in _history) Chip(label: Text(h))],
          ),
        sec('④ ?? 默认值兜底（读不存在的键）'),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () async {
                final sp = await SharedPreferences.getInstance();
                // 没写过的键 get 回 null——?? 给默认值是标准姿势
                final v = sp.getBool('demo.neverSet') ?? false;
                setState(
                  () => _missingKeyDemo =
                      'sp.getBool(neverSet) == null → ?? false → $v',
                );
              },
              child: const Text('读一个从没写过的键'),
            ),
          ],
        ),
        if (_missingKeyDemo != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _missingKeyDemo!,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        sec('⑤ 翻车警告'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            'getInstance() 是异步的——直接在 build 里同步取值必得 null：\n'
            '先在 initState 加载到成员变量，再 setState 渲染（EX21 病人）。\n'
            '它不是数据库：塞大 JSON 等于把数据库降级成文件还丢了查询。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 3：DB1 建库建表
// ============================================================
Widget _dDb1(BuildContext context) => const _Db1Page();

class _Db1Page extends StatefulWidget {
  const _Db1Page();
  @override
  State<_Db1Page> createState() => _Db1PageState();
}

class _Db1PageState extends State<_Db1Page> {
  int _storedV = 0;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final db = await MiniDb.openDatabase(
        'notes.db',
        version: 1,
        onCreate: (db, v) => db.execute(kNotesDdlV1),
      );
      await _seedNotes(db);
      final v = await db.storedVersion;
      setState(() {
        _storedV = v;
        _err = '';
      });
    } on MiniDbException catch (e) {
      setState(() => _err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① openDatabase 三件套'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo.shade50,
          child: const Text(
            "final db = await openDatabase(\n"
            "  join(await getDatabasesPath(), 'notes.db'),\n"
            "  version: 1,                       // 升它触发迁移\n"
            "  onCreate: (db, v) => db.execute(  // 首次建库走这里\n"
            "    'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, …)'),\n"
            ");",
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.9,
            ),
          ),
        ),
        sec('② notes 表结构'),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.indigo.shade100),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'id         INTEGER 主键自增',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
              Text(
                'title      TEXT 非空',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
              Text(
                'body       TEXT 正文',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
              Text(
                'pinned     INT 置顶标记（0/1）',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
              Text(
                'updatedAt  TEXT ISO 时间串',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _err.isEmpty
              ? '库已打开：notes.db · 当前 version=$_storedV · 刷新页面=重启进程重开同一个库'
              : '出错：$_err',
          style: TextStyle(
            fontSize: 12,
            color: _err.isEmpty ? Colors.black54 : Colors.red,
          ),
        ),
        sec('③ 建库语义（考试高频）'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '首次打开 → onCreate 执行 DDL，落 version；\n'
            '再次打开 → version 相同什么都不执行；\n'
            '代码 version 更大 → onUpgrade(db, 旧版, 新版) 迁移（见 MIG 页）。\n'
            'onCreate 只在"新用户"身上跑一次——这就是 EX24 的伏笔。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 4：DB2 增删改查四操作
// ============================================================
Widget _dDb2(BuildContext context) => const _Db2Page();

class _Db2Page extends StatefulWidget {
  const _Db2Page();
  @override
  State<_Db2Page> createState() => _Db2PageState();
}

class _Db2PageState extends State<_Db2Page> {
  MiniDb? _db;
  List<Map<String, Object?>> _rows = [];
  String _log = '';
  final _titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final db = await MiniDb.openDatabase(
      'notes.db',
      version: 1,
      onCreate: (db, v) => db.execute(kNotesDdlV1),
    );
    await _seedNotes(db);
    _db = db;
    await _refresh();
  }

  Future<void> _refresh() async {
    // 置顶优先，再按更新时间倒序——orderBy 一行搞定
    final rows = await _db!.query(
      'notes',
      orderBy: 'pinned DESC, updatedAt DESC',
    );
    setState(() => _rows = rows);
  }

  Future<void> _add() async {
    final t = _titleCtrl.text.trim();
    if (t.isEmpty) return;
    final id = await _db!.insert('notes', {
      'title': t,
      'body': '',
      'pinned': 0,
    });
    _titleCtrl.clear();
    setState(() => _log = 'insert → 新记录 id=$id（自增主键）');
    await _refresh();
  }

  Future<void> _togglePin(Map<String, Object?> r) async {
    final id = r['id'] as int;
    final pinned = (r['pinned'] as num? ?? 0) == 1 ? 0 : 1;
    final n = await _db!.update(
      'notes',
      {'pinned': pinned, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    setState(() => _log = 'update where id=$id → 影响 $n 行');
    await _refresh();
  }

  Future<void> _delete(Map<String, Object?> r) async {
    final id = r['id'] as int;
    final n = await _db!.delete('notes', where: 'id = ?', whereArgs: [id]);
    setState(() => _log = 'delete where id=$id → 删除 $n 行');
    await _refresh();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 新增（insert 返回自增 id）'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _titleCtrl,
                onSubmitted: (_) => _add(),
                decoration: const InputDecoration(
                  hintText: '新备忘标题',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _add, child: const Text('insert')),
          ],
        ),
        const SizedBox(height: 8),
        sec('② 列表（pinned DESC, updatedAt DESC · 刷新不丢）'),
        for (final r in _rows)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              dense: true,
              leading: Text(
                '#${r['id']}',
                style: const TextStyle(color: Colors.indigo, fontSize: 12),
              ),
              title: Text(
                '${r['title']}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: (r['pinned'] as num? ?? 0) == 1
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '${(r['pinned'] as num? ?? 0) == 1 ? "📌置顶 " : ""}'
                '${(r['updatedAt'] as String?)?.substring(5, 16) ?? ''}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '置顶/取消',
                    iconSize: 18,
                    onPressed: () => _togglePin(r),
                    icon: Icon(
                      (r['pinned'] as num? ?? 0) == 1
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: '删除',
                    iconSize: 18,
                    onPressed: () => _delete(r),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        if (_rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '（空表——先 insert 一条）',
              style: TextStyle(color: Colors.black38, fontSize: 12),
            ),
          ),
        const SizedBox(height: 4),
        Text(_log, style: const TextStyle(fontSize: 12, color: Colors.indigo)),
        sec('③ 四操作签名（全 Future，一个 await 都不能少）'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo.shade50,
          child: const Text(
            "await db.insert('notes', {'title':'买书','pinned':0});\n"
            "final all = await db.query('notes', orderBy:'pinned DESC');\n"
            "final n = await db.update('notes', {'pinned':1},\n"
            "              where:'id = ?', whereArgs:[3]);\n"
            "final m = await db.delete('notes', where:'id = ?', whereArgs:[3]);",
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.9,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 5：DB3 条件查询与防注入
// ============================================================
Widget _dDb3(BuildContext context) => const _Db3Page();

class _Db3PageState extends State<_Db3Page> {
  MiniDb? _db;
  final _kwCtrl = TextEditingController(text: '买');
  List<Map<String, Object?>> _hit = [];
  List<Map<String, Object?>> _limited = [];
  String _sql = '';

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final db = await MiniDb.openDatabase(
      'notes.db',
      version: 1,
      onCreate: (db, v) => db.execute(kNotesDdlV1),
    );
    await _seedNotes(db);
    _db = db;
    await _search();
  }

  Future<void> _search() async {
    // 参数化查询：? 占位，值走 whereArgs——用户输入永远只是"值"
    final kw = '%${_kwCtrl.text}%';
    _hit = await _db!.query('notes', where: 'title LIKE ?', whereArgs: [kw]);
    _limited = await _db!.query('notes', orderBy: 'updatedAt DESC', limit: 2);
    setState(() {
      _sql =
          "db.query('notes',\n  where: 'title LIKE ?',\n"
          "  whereArgs: ['$kw'])";
    });
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① LIKE 模糊搜索（参数化，安全）'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _kwCtrl,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  hintText: '关键词（试试：买 / 课 / 单引号\'）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _search, child: const Text('query')),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.indigo.shade50,
          child: Text(
            _sql,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_hit.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '0 条命中——空结果要给友好提示（作业评分点）',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        for (final r in _hit)
          ListTile(
            dense: true,
            leading: const Icon(Icons.check, size: 16, color: Colors.green),
            title: Text('${r['title']}', style: const TextStyle(fontSize: 14)),
          ),
        sec('② orderBy + limit'),
        for (final r in _limited)
          ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_right, size: 16),
            title: Text(
              '${r['title']}  （updatedAt 最新 2 条）',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        sec('③ 为什么必须参数化'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '字符串拼接：where: "title LIKE \'%\$kw%\'" ——\n'
            '用户输入 \' OR \'1\'=\'1 就能改写 SQL 结构（注入），见 EX23。\n'
            '参数化（? + whereArgs）：输入永远只是"值"，成不了"代码"。\n'
            '这就是题库第25题与作业评分点的出处。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

class _Db3Page extends StatefulWidget {
  const _Db3Page();
  @override
  State<_Db3Page> createState() => _Db3PageState();
}

// ============================================================
// 知识页 6：MIG 版本迁移通道
// ============================================================
Widget _dMig(BuildContext context) => const _MigPage();

class _MigPage extends StatefulWidget {
  const _MigPage();
  @override
  State<_MigPage> createState() => _MigPageState();
}

class _MigPageState extends State<_MigPage> {
  String _log = '点下面的按钮跑一遍 v1→v2 全流程';
  List<String> _cols = const [];
  List<Map<String, Object?>> _rows = const [];

  Future<void> _run() async {
    await MiniDb.drop('mig.db');
    final buf = StringBuffer();
    // 第一步：v1 上线，老用户建库存数据
    var db = await MiniDb.openDatabase(
      'mig.db',
      version: 1,
      onCreate: (d, v) async {
        await d.execute(
          'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, updatedAt TEXT)',
        );
        buf.writeln('① v1 onCreate：建表（还没有 color 列）');
      },
    );
    await db.insert('notes', {'title': '老用户的第一条'});
    buf.writeln('② 老用户写入 1 条数据');
    // 第二步：需求来了要加 color 列——version: 2 + onUpgrade
    db = await MiniDb.openDatabase(
      'mig.db',
      version: 2,
      onCreate: (d, v) => d.execute(
        'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, color TEXT, updatedAt TEXT)',
      ),
      onUpgrade: (d, oldV, newV) async {
        await d.execute('ALTER TABLE notes ADD COLUMN color TEXT');
        buf.writeln('③ 检测到 v$oldV → v$newV：onUpgrade 执行 ALTER 加列');
      },
    );
    final rows = await db.query('notes');
    setState(() {
      _log = buf.toString();
      _cols = rows.isEmpty ? const [] : rows.first.keys.toList();
      _rows = rows;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 迁移通道：version + onUpgrade'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo.shade50,
          child: const Text(
            "await openDatabase(path,\n"
            "  version: 2,                              // 升版本号\n"
            "  onCreate: …建新表DDL…,\n"
            "  onUpgrade: (db, oldV, newV) => db.execute(\n"
            "    'ALTER TABLE notes ADD COLUMN color TEXT'),\n"
            ");",
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.9,
            ),
          ),
        ),
        sec('② 全流程演示（老数据保留是验收标准）'),
        ElevatedButton(onPressed: _run, child: const Text('跑一遍 v1 → v2 迁移')),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.grey.shade100,
          child: Text(
            _log,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.8,
            ),
          ),
        ),
        if (_rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '迁移后表列：${_cols.join(', ')}',
            style: const TextStyle(fontSize: 12, color: Colors.indigo),
          ),
          Text(
            '老数据：${_rows.map((r) => r['title']).join(' / ')}（1 条没丢）',
            style: const TextStyle(fontSize: 12, color: Colors.green),
          ),
        ],
        sec('③ 双通道缺一不可'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            'onCreate 给新用户建最新结构的表；\n'
            'onUpgrade 给老用户把旧表补到最新结构。\n'
            '两处 DDL 都要写——只改 onCreate，老用户永远拿不到新列（EX24）。\n'
            '表结构一改，version 必须升——这是硬性纪律（作业独立研究1）。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 7：SEL 选型矩阵 + local_store 案例
// ============================================================
Widget _dSel(BuildContext context) {
  const rows = [
    ['方式', '适用', '不适用', '容量级'],
    ['文件 File', '整体读写：JSON快照/缓存/导出', '按条查询修改', 'KB~MB'],
    ['shared_preferences', '少量配置：主题/开关/上次输入', '结构化列表/大对象', '数十个键'],
    ['sqflite', '结构化记录：备忘/收藏/历史', '整体配置/极小数据', '无压力'],
  ];
  return ListView(
    padding: const EdgeInsets.all(12),
    children: [
      sec('① 选型三问（作业评分点要求写出答案）'),
      const Card(
        color: Color(0xFFE8EAF6),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            '问1：数据是"整体一份"还是"很多条"？\n'
            '      整体一份 → 文件；很多条 → 往下问\n'
            '问2：要不要按条件查（搜索/筛选/排序）？\n'
            '      要 → sqflite；不要 → 文件或 sp\n'
            '问3：是否敏感（密码/token）？\n'
            '      是 → 不得明文落盘（红线）→ flutter_secure_storage',
            style: TextStyle(fontSize: 13, height: 2.0),
          ),
        ),
      ),
      sec('② 选型矩阵'),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.indigo.shade100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                color: i == 0 ? Colors.indigo.shade50 : null,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        rows[i][0],
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: i == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(rows[i][1], style: TextStyle(fontSize: 11.5)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(rows[i][2], style: TextStyle(fontSize: 11.5)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        rows[i][3],
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      sec('③ 课堂案例 local_store：三步三提交'),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '步骤一 主题记忆',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '设置页切深浅色 → 写 sp → 重启保持',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              Text(
                'git commit -am "feat: theme persistence via shared_preferences"',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              SizedBox(height: 10),
              Text(
                '步骤二 备忘录 CRUD',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                'sqflite notes 表：新增/列表(置顶优先)/编辑/删除',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              Text(
                'git commit -am "feat: notes crud with sqflite"',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              SizedBox(height: 10),
              Text(
                '步骤三 搜索与导出',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                'LIKE 条件查询 + 全量导出 JSON 到文档目录（两方式同台）',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              Text(
                'git commit -am "feat: keyword search & json export"',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
      sec('④ 检查点与红线'),
      Container(
        padding: const EdgeInsets.all(12),
        color: Colors.red.shade50,
        child: const Text(
          '检查点：重启主题保持 · CRUD 全通 · 搜索生效 · 口头讲选型理由\n'
          '红线：密码/token 不得明文持久化（EX25）；作业禁用真实密码。',
          style: TextStyle(fontSize: 13, height: 1.9),
        ),
      ),
    ],
  );
}

// ============================================================
// EX21~EX25：第10课扩展案例（含故意缺陷，修复练习素材）
// ============================================================

// ---------- EX21 主题记忆（缺陷：getInstance 异步时机错位） ----------
Widget _ex21(BuildContext context) => const _Ex21Page();

class _Ex21Page extends StatefulWidget {
  const _Ex21Page();
  @override
  State<_Ex21Page> createState() => _Ex21PageState();
}

class _Ex21PageState extends State<_Ex21Page> {
  // 病号版：bool _broken = false 永远只吃默认值——
  // 模拟"在 build 里同步取 sp"必然拿到的初值（真实代码里是 null）
  bool _broken = false;
  // 正确版：异步加载完 setState 回填
  bool _fixed = false;
  String _hint = '两个开关都打开，然后刷新页面（F5）看谁记得住';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    // 正确版：加载到成员变量再 setState 渲染
    setState(() => _fixed = sp.getBool('ex21.dark') ?? false);
    // 病号版缺陷：加载结果永远没有写回 _broken（等价于在 build 同步取值的 null）
  }

  Future<void> _toggle() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('ex21.dark', true); // 两个版本都成功写盘
    setState(() {
      _broken = true;
      _fixed = true;
      _hint = '已写入 sp（ex21.dark=true）——现在刷新页面对比两边';
    });
  }

  Future<void> _clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('ex21.dark');
    setState(() {
      _broken = false;
      _fixed = false;
      _hint = '已清除，可重做实验';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX21 「记住我」总不记得？'),
        Card(
          color: Colors.red.shade50,
          child: SwitchListTile(
            title: const Text(
              '病号版：build 里同步取值',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              _broken ? 'true（内存里）' : 'false——永远是默认值',
              style: const TextStyle(fontSize: 12),
            ),
            value: _broken,
            onChanged: (_) => _toggle(),
          ),
        ),
        Card(
          color: Colors.green.shade50,
          child: SwitchListTile(
            title: const Text(
              '健康版：initState 异步加载 + setState',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              '$_fixed（从 sp 读回）',
              style: const TextStyle(fontSize: 12),
            ),
            value: _fixed,
            onChanged: (_) => _toggle(),
          ),
        ),
        Text(
          _hint,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _clear, child: const Text('清除实验数据')),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '病根提示：题库第39题——getInstance() 是异步的，\n'
            '写在 build 里同步取值只会拿到 null（渲染等不起）。\n'
            '修法：initState 里 await 加载到成员变量，加载完 setState 再渲染。\n'
            '写盘其实一直是成功的——坏的是"读"的时机。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ---------- EX22 查了个寂寞（缺陷：忘 await，拿 Future 当 List 用） ----------
Widget _ex22(BuildContext context) => const _Ex22Page();

class _Ex22Page extends StatefulWidget {
  const _Ex22Page();
  @override
  State<_Ex22Page> createState() => _Ex22PageState();
}

class _Ex22PageState extends State<_Ex22Page> {
  String _out = '（点上面的按钮对比）';
  MiniDb? _db;

  @override
  void initState() {
    super.initState();
    () async {
      final db = await MiniDb.openDatabase(
        'ex22.db',
        version: 1,
        onCreate: (d, v) async {
          await d.execute(kNotesDdlV1);
        },
      );
      await _seedNotes(db);
      setState(() => _db = db);
    }();
  }

  Future<void> _okVersion() async {
    if (_db == null) return;
    final rows = await _db!.query('notes', orderBy: 'pinned DESC');
    setState(
      () => _out =
          '✅ await 版：拿到 List，共 ${rows.length} 条\n'
          '   首条：${rows.first['title']}',
    );
  }

  Future<void> _badVersion() async {
    if (_db == null) return;
    // 缺陷：漏了 await——db.query 返回的是 Future，不是 List
    // ignore: avoid_print
    final future = _db!.query('notes', orderBy: 'pinned DESC');
    setState(
      () => _out =
          '❌ 忘 await：拿到的是 ${future.runtimeType}\n'
          '   它不是 List！拿它当查询结果用就是"查了个寂寞"',
    );
    // 再演示运行期炸法：dynamic 剥掉类型检查后 .length 直接 NoSuchMethodError
    try {
      // ignore: avoid_dynamic_calls
      final dynamic d = future;
      // ignore: avoid_dynamic_calls
      final n = d.length; // Future 没有 length
      setState(() => _out += '\n   强行 .length → 竟返回 $n？不会的，见下');
      // ignore: avoid_empty_catches
    } catch (e) {
      setState(() => _out += '\n   强行当 List 用 → 运行时炸：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX22 明明有数据，列表却是空/报错？'),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: _okVersion,
              child: const Text('✅ await 版查询'),
            ),
            ElevatedButton(
              onPressed: _badVersion,
              child: const Text('❌ 忘 await 版'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Text(
            _out,
            style: const TextStyle(
              fontSize: 13,
              height: 1.8,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '病根提示：题库第40题——sqflite 的 API 全是 Future，\n'
            '漏 await 拿到的是"取结果的凭证"而不是结果本身。\n'
            '强类型下 Future.length 直接编译报错；dynamic 绕过检查\n'
            '就在运行时炸 NoSuchMethodError。修法：await 一个都不能少。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ---------- EX23 搜索框注入（缺陷：SQL 字符串拼接） ----------
Widget _ex23(BuildContext context) => const _Ex23Page();

class _Ex23Page extends StatefulWidget {
  const _Ex23Page();
  @override
  State<_Ex23Page> createState() => _Ex23PageState();
}

class _Ex23PageState extends State<_Ex23Page> {
  MiniDb? _db;
  final _kwCtrl = TextEditingController(text: "' OR '1'='1");
  String _paramSql = '';
  String _concatSql = '';
  String _paramOut = '';
  String _concatOut = '';
  bool _injected = false;

  @override
  void initState() {
    super.initState();
    () async {
      final db = await MiniDb.openDatabase(
        'ex23.db',
        version: 1,
        onCreate: (d, v) async {
          await d.execute(kNotesDdlV1);
        },
      );
      await _seedNotes(db);
      setState(() => _db = db);
    }();
  }

  Future<void> _run() async {
    if (_db == null) return;
    final kw = _kwCtrl.text;
    // 健康版：参数化——kw 永远只是"值"
    final hit = await _db!.query(
      'notes',
      where: 'title LIKE ?',
      whereArgs: ['%$kw%'],
    );
    _paramSql = "SELECT * FROM notes WHERE title LIKE ?   -- args:['%$kw%']";
    _paramOut = '命中 ${hit.length} 条（输入被当作普通文本）';
    _injected = kw.contains("'");

    // 病号版：拼接——kw 直接长进 SQL 字符串里
    _concatSql = "SELECT * FROM notes WHERE title LIKE '%$kw%'";
    if (_injected) {
      // 教学模拟：注入改写了条件结构（OR '1'='1' 恒真）→ 全表返回
      final all = await _db!.query('notes');
      _concatOut = '命中 ${all.length} 条 ⚠️ 条件被改写成恒真，全表泄漏！';
    } else {
      _concatOut = '命中 ${hit.length} 条（这回侥幸没炸）';
    }
    setState(() {});
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX23 搜索框里打一个引号会怎样？'),
        TextField(
          controller: _kwCtrl,
          onSubmitted: (_) => _run(),
          decoration: const InputDecoration(
            labelText: "试试默认的  ' OR '1'='1  （经典注入串）",
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: _run, child: const Text('两种写法各查一次')),
        const SizedBox(height: 10),
        _row(
          '✅ 参数化（where + whereArgs）',
          _paramSql,
          _paramOut,
          Colors.green.shade50,
        ),
        _row(
          '❌ 字符串拼接',
          _concatSql,
          _concatOut,
          _injected ? Colors.red.shade50 : Colors.orange.shade50,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '病根提示：题库第25题——拼接把"用户输入"升级成了"SQL 代码"，\n'
            '引号闭合 + OR 恒真改写条件：查密码表能绕过登录、查笔记表全表泄漏。\n'
            "修法：永远 where: 'title LIKE ?' + whereArgs: ['%kw%']，\n"
            '输入永远只是参数值，成不了代码。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }

  Widget _row(String title, String sql, String out, Color c) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.all(10),
    color: c,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          sql,
          style: const TextStyle(
            fontSize: 11.5,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(out, style: const TextStyle(fontSize: 12.5)),
      ],
    ),
  );
}

// ---------- EX24 新列失踪（缺陷：改了 DDL 不升 version） ----------
Widget _ex24(BuildContext context) => const _Ex24Page();

class _Ex24Page extends StatefulWidget {
  const _Ex24Page();
  @override
  State<_Ex24Page> createState() => _Ex24PageState();
}

class _Ex24PageState extends State<_Ex24Page> {
  String _log = '按 ①→②→③ 顺序点，复现"新列失踪"';
  String _cols = '';
  int _rows = 0;
  String _err = '';

  static const _ddlV2 =
      'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, '
      'color TEXT, updatedAt TEXT)';

  Future<MiniDb> _open({
    required int version,
    OnDbCreate? onCreate,
    OnDbUpgrade? onUpgrade,
  }) => MiniDb.openDatabase(
    'ex24.db',
    version: version,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );

  // ① 模拟老用户：v1 装机（老 DDL，无 color 列）+ 存了数据
  Future<void> _step1() async {
    await MiniDb.drop('ex24.db');
    final db = await _open(
      version: 1,
      onCreate: (d, v) => d.execute(kNotesDdlV1),
    );
    await db.insert('notes', {'title': '老用户笔记 A'});
    await db.insert('notes', {'title': '老用户笔记 B'});
    final rows = await db.query('notes');
    setState(() {
      _log = '① 老用户以 v1 装机：建表无 color 列，存 2 条数据';
      _cols = rows.first.keys.join(', ');
      _rows = rows.length;
      _err = '';
    });
  }

  // ② 病号升级：DDL 加了 color 列，但 version 忘了升（还是 1）
  Future<void> _step2() async {
    final db = await _open(
      version: 1, // ← 缺陷：DDL 改了，version 没升
      onCreate: (d, v) => d.execute(_ddlV2),
    );
    try {
      await db.query('notes', columns: ['title', 'color']);
      setState(() => _err = '？竟然没报错——请先做 ① 再做 ②');
    } on MiniDbException catch (e) {
      setState(() {
        _log =
            '② 代码升级：onCreate 的 DDL 已含 color 列，但 version 仍=1\n'
            '   → 老库 version 相等 → onCreate/onUpgrade 一个都不执行\n'
            '   → 老用户的表还是旧结构';
        _err = '查询 color 列报错：$e';
      });
    }
  }

  // ③ 正确升级：version: 2 + onUpgrade ALTER
  Future<void> _step3() async {
    final db = await _open(
      version: 2,
      onCreate: (d, v) => d.execute(_ddlV2),
      onUpgrade: (d, oldV, newV) =>
          d.execute('ALTER TABLE notes ADD COLUMN color TEXT'),
    );
    final rows = await db.query('notes', columns: ['title', 'color']);
    setState(() {
      _log = '③ 正确姿势：version 1→2 触发 onUpgrade 执行 ALTER 加列';
      _cols = 'id, title, color, updatedAt（color 已补上，老行该列为 null）';
      _rows = rows.length;
      _err = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX24 加了新列，老用户却查不到？'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(onPressed: _step1, child: const Text('① 老用户装 v1')),
            ElevatedButton(
              onPressed: _step2,
              child: const Text('② 升级但忘升 version'),
            ),
            ElevatedButton(
              onPressed: _step3,
              child: const Text('③ version:2 + onUpgrade'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.grey.shade100,
          child: Text(
            _log,
            style: const TextStyle(
              fontSize: 12.5,
              fontFamily: 'monospace',
              height: 1.8,
            ),
          ),
        ),
        if (_cols.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '当前表列：$_cols · 数据 $_rows 条（迁移没丢数据）',
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
            ),
          ),
        if (_err.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            color: Colors.red.shade50,
            child: Text(
              _err,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.red,
                height: 1.6,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '病根提示：题库第38题——onCreate 只对新用户跑一次；\n'
            '老用户走的是 version 对比：相等=什么都不做。\n'
            '改表结构必须：①升 version ②写 onUpgrade 迁移 ③onCreate 同步新 DDL。\n'
            '三件事缺一，老用户就永远拿不到新列。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ---------- EX25 密码裸奔（缺陷：敏感信息明文落盘） ----------
Widget _ex25(BuildContext context) => const _Ex25Page();

class _Ex25Page extends StatefulWidget {
  const _Ex25Page();
  @override
  State<_Ex25Page> createState() => _Ex25PageState();
}

class _Ex25PageState extends State<_Ex25Page> {
  final _pwdCtrl = TextEditingController(text: 'Passw0rd!');
  bool _remember = true;
  String _peek = '';
  String _hint = '';

  Future<void> _login() async {
    final sp = await SharedPreferences.getInstance();
    if (_remember) {
      // 缺陷：密码明文直接写进持久化存储
      await sp.setString('ex25.pwd', _pwdCtrl.text);
      setState(() => _hint = '已"记住密码"——写进了 sp（localStorage）。\n点下面的按钮看看它躺得多明白。');
    } else {
      await sp.remove('ex25.pwd');
      setState(() => _hint = '未勾选记住：没有落盘（这是对的）');
    }
  }

  Future<void> _peekStorage() async {
    final sp = await SharedPreferences.getInstance();
    final pwd = sp.getString('ex25.pwd');
    setState(
      () => _peek = pwd == null
          ? '（存储里没有密码——干净）'
          : 'ex25.pwd = "$pwd"   ← 明文！导出/越狱/共享设备一眼看穿',
    );
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX25 「贴心」的记住密码？'),
        TextField(
          controller: _pwdCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '密码（页面上打码，存储里呢？）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        SwitchListTile(
          dense: true,
          title: const Text(
            '记住密码（病号逻辑：明文写 sp）',
            style: TextStyle(fontSize: 14),
          ),
          value: _remember,
          onChanged: (v) => setState(() => _remember = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(onPressed: _login, child: const Text('登录')),
            OutlinedButton(
              onPressed: _peekStorage,
              child: const Text('🔍 偷看存储'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_hint.isNotEmpty)
          Text(
            _hint,
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        if (_peek.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            color: _peek.contains('明文')
                ? Colors.red.shade50
                : Colors.green.shade50,
            child: Text(
              _peek,
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: 'monospace',
                height: 1.6,
                color: _peek.contains('明文') ? Colors.red : Colors.green,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.red.shade50,
          child: const Text(
            '病根提示：题库第10题+讲义红线——密码/token 不得明文持久化。\n'
            'sp/文件/未加密数据库都是明文本地存储：root/越狱/备份导出全可读。\n'
            '正确姿势：密码压根不落盘（每次登录）；token 用\n'
            'flutter_secure_storage（iOS Keychain / Android Keystore）。\n'
            '本课程作业不允许出现真实密码（独立研究2 调研加密存储）。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// m10 演示注册表
// ============================================================
final m10Demos = <Demo>[
  Demo('11.1', '文件读写', '教科书11.1 · 临时/文档目录 · 覆盖写/追加 · 异常捕获', _d111File),
  Demo('SP', '键值存储', 'shared_preferences 五类型 · ?? 兜底 · 刷新保持', _dSp),
  Demo('DB1', '建库建表', 'openDatabase version/onCreate · notes 表结构', _dDb1),
  Demo('DB2', '增删改查', 'insert/query/update/delete 全 Future · 置顶排序', _dDb2),
  Demo('DB3', '条件查询', 'where+whereArgs 参数化 · LIKE · orderBy/limit', _dDb3),
  Demo('MIG', '版本迁移', 'version+onUpgrade 通道 · v1→v2 老数据保留', _dMig),
  Demo('SEL', '选型矩阵', '选型三问 · 三方式对比 · local_store 三步三提交', _dSel),
  Demo('EX21', '🔘 总不记得我', 'getInstance 时机 · build 同步取值必 null（题39）', _ex21),
  Demo('EX22', '📭 查了个寂寞', '漏 await · 拿 Future 当 List 用（题40）', _ex22),
  Demo('EX23', '💉 搜索框注入', 'SQL 拼接 · 一个引号改写条件（题25）', _ex23),
  Demo('EX24', '🧱 新列失踪', 'version 不升 · DDL 对老用户不生效（题38）', _ex24),
  Demo('EX25', '🔓 密码裸奔', '明文持久化红线 · 偷看存储现原形（题10）', _ex25),
];
