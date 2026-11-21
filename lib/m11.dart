// ============================================================
// 第11课（第13周）：网络访问与异步交互 演示页
// 对应《Flutter实战·第二版》第11章网络部分（教科书收官课）：
//   11.2 HttpClient 五步 / 11.3 dio / 11.5 WebSocket /
//   11.7 Json转Dart Model类（11.4 分块下载、11.6 Socket 带过）
//   + 讲义十一：错误三分类 / FutureBuilder三态 / 刷新分页 /
//     先旧后新缓存 / data_app 案例
// EX26~EX30 为扩展案例（故意设计的缺陷，供学生修复练习）：
//   请求风暴 / 空态装死 / 404装成功 / 静音错误 / 来历不明，
//   对齐题库十一 第31/37/40/42/1 题，详见讲义十一 6A 节。
//
// 平台说明：本课全部是真网络请求——演示站跑在浏览器里，
// http 包在 web 平台走 XhrHttpClient（XMLHttpRequest）。
// 数据源：本站 dataset/ 目录托管的课程统一数据集（同源，无
// CORS 问题）——落实讲义"课程统一数据集仓库托管地址为唯一
// 基准"。真机上把 base 换成教师发布的地址即可，代码不变。
// ============================================================
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'main.dart' show Demo, sec;

/// 统一数据集基地址：本站 dataset/ 目录（与课堂发布的仓库托管地址同内容）。
/// 注意必须用 Uri.base.resolve 相对解析：本站 GitHub Pages 配置了自定义
/// 域（github.io 会 301 到 myblog.thiswind.work），写死 github.io 绝对
/// 地址会变成跨源请求被 CORS 拦截；相对解析则无论从哪个域访问都同源。
Uri datasetUri(String file) => Uri.base.resolve('dataset/$file');

// ============================================================
// Book 模型（11.7 手工模型化 + 讲义 fromJsonSafe 缺字段兜底）
// ============================================================
class Book {
  final String id;
  final String title;
  final String category;
  final String author;
  final int rating;
  final int borrowCount;
  final String month;
  const Book({
    required this.id,
    required this.title,
    required this.category,
    required this.author,
    required this.rating,
    required this.borrowCount,
    required this.month,
  });

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        category: j['category'] as String,
        author: j['author'] as String,
        rating: (j['rating'] as num).toInt(),
        borrowCount: (j['borrowCount'] as num).toInt(),
        month: j['month'] as String,
      );

  /// 讲义约定：缺字段/空值兜底（empty.json 与裁剪数据测试用）
  factory Book.fromJsonSafe(Map<String, dynamic> j) => Book(
        id: j['id'] as String? ?? '未知',
        title: j['title'] as String? ?? '（无书名）',
        category: j['category'] as String? ?? '未分类',
        author: j['author'] as String? ?? '佚名',
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        borrowCount: (j['borrowCount'] as num?)?.toInt() ?? 0,
        month: j['month'] as String? ?? '—',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'author': author,
        'rating': rating,
        'borrowCount': borrowCount,
        'month': month,
      };
}

// ---------- 请求层：三分类错误 + 两个真实端点 ----------
class AppException implements Exception {
  final String userMsg; // 给用户看的话
  final String kind; // socket / timeout / http / parse
  AppException(this.kind, this.userMsg);
  @override
  String toString() => '[$kind] $userMsg';
}

/// http 包版 fetchBooks：get + 8 秒超时 + 三分类（讲义二）
Future<List<Book>> fetchBooks(String file) async {
  try {
    final resp = await http
        .get(datasetUri(file))
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return [for (final j in list) Book.fromJson(j as Map<String, dynamic>)];
    }
    throw AppException('http', '服务异常：HTTP ${resp.statusCode}');
  } on SocketLikeException {
    throw AppException('socket', '网络不可用，请检查网络连接');
  } on TimeoutException {
    throw AppException('timeout', '请求超时，请稍后再试');
  }
}

/// 演示用的"把 SocketException 一并归到网络层"的哨兵类型
///（http 包在 web 上抛的异常类型与 VM 不完全一致，统一归类
///  本课知识点：按语义分类，而不是按异常类型穷举）
class SocketLikeException implements Exception {}

/// errText：三分类错误 → 用户可读提示（题35 考点）
String errText(Object e) {
  if (e is AppException) return e.userMsg;
  final s = e.toString();
  if (s.contains('Socket') || s.contains('Failed to fetch') ||
      s.contains('Network') || s.contains('XMLHttpRequest')) {
    return '请检查网络连接';
  }
  if (s.contains('Timeout')) return '请求超时，请稍后再试';
  return '服务异常，请稍后再试';
}

// ============================================================
// 知识页 1：NET1 真请求入门（get+超时+状态码+三分类）
// ============================================================
Widget _dNet1(BuildContext context) => const _Net1Page();

class _Net1Page extends StatefulWidget {
  const _Net1Page();
  @override
  State<_Net1Page> createState() => _Net1PageState();
}

class _Net1PageState extends State<_Net1Page> {
  String _log = '点下面的按钮，发出这门课的第一个真网络请求';
  bool _busy = false;

  Future<void> _go(String file, String label) async {
    setState(() {
      _busy = true;
      _log = '$label 请求中…（最多等 8 秒）';
    });
    final sw = Stopwatch()..start();
    try {
      final books = await fetchBooks(file);
      setState(() {
        _busy = false;
        _log = '$label 成功：HTTP 200，耗时 ${sw.elapsedMilliseconds}ms，'
            '解析出 ${books.length} 本《${books.first.title}》等';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _log = '$label 失败 → ${errText(e)}（${e.runtimeType}）';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 请求五要素（讲义二）'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo.shade50,
          child: const Text(
            'http.get(Uri.parse(url))\n'
            '  .timeout(Duration(seconds: 8))   ← 超时\n'
            'if (resp.statusCode == 200)        ← 判状态码\n'
            '  jsonDecode(resp.body) as List    ← 解析\n'
            'throw AppException(...)            ← 业务层错误',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.9),
          ),
        ),
        sec('② 三个真实端点（课程统一数据集，本站托管）'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: _busy ? null : () => _go('books.json', 'books.json(36条)'),
              child: const Text('GET books.json'),
            ),
            ElevatedButton(
              onPressed: _busy ? null : () => _go('books_page1.json', 'page1(18条)'),
              child: const Text('GET page1'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _go('empty.json', 'empty.json(空[])'),
              child: const Text('GET empty.json'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _go('no_such_file.json', '不存在的文件'),
              child: const Text('GET 404'),
            ),
          ],
        ),
        sec('③ 错误三分类（题库 2/3/4/25 题）'),
        const RowOf3(),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.amber.shade50,
          child: Text(
            _log,
            style: const TextStyle(fontSize: 13, height: 1.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.green.shade50,
          child: const Text(
            '注意 404 那个按钮：请求"成功到达"但状态码非 200 → 走业务层'
            '分类。statusCode==200 才碰 body（题40），这就是错误分界的\n'
            '第一道闸门。empty.json 返回 [] 是"成功但空"——第 4 节讲空态。',
            style: TextStyle(fontSize: 12.5, height: 1.8),
          ),
        ),
      ],
    );
  }
}

class RowOf3 extends StatelessWidget {
  const RowOf3();
  @override
  Widget build(BuildContext context) {
    Widget cell(String t, String d, Color c) => Expanded(
          child: Card(
            color: c,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('$t\n$d',
                  style: const TextStyle(fontSize: 11.5, height: 1.6)),
            ),
          ),
        );
    return Row(children: [
      cell('网络层', 'SocketException\n→「检查网络」', Colors.red.shade50),
      cell('超时', 'TimeoutException\n→「稍后再试」', Colors.orange.shade50),
      cell('业务层', '非200状态码\n→「服务异常」', Colors.blue.shade50),
    ]);
  }
}

// ============================================================
// 知识页 2：NET2 教科书 11.2 HttpClient 五步走读
// ============================================================
Widget _dNet2(BuildContext context) => const _Net2Page();

class _Net2PageState extends State<_Net2Page> {
  String _log = 'HttpClient 是 dart:io 的"原生五步舞"——教科书用它讲清'
      'HTTP 请求的本质；日常开发用 http 包/dio（下一页）。';
  bool _busy = false;

  Future<void> _run5Steps() async {
    setState(() {
      _busy = true;
      _log = '① HttpClient() 已创建…（web 沙箱下五步由模拟器演示，'
          '语义与真机 dart:io 完全一致）';
    });
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() => _log += '\n② getUrl(uri) 打开连接（Request 对象，可设请求头）');
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() => _log += '\n③ await request.close() 请求发出，等 Response');
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() => _log += '\n④ response.transform(utf8.decoder).join() 读响应流');
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _busy = false;
      _log += '\n⑤ httpClient.close() 收尾（会终止该 client 的所有请求）\n'
          '→ 完成：这就是教科书 11.2 的五步。麻烦但透明——'
          '连接、请求头、响应流全在你手里。http 包/dio 把这五步'
          '封装成了一行 http.get()。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 教科书 11.2：HttpClient 五步（dart:io）'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo.shade50,
          child: const Text(
            '1. HttpClient client = HttpClient();\n'
            '2. HttpClientRequest req = await client.getUrl(uri);\n'
            '   req.headers.add("user-agent", "test");   // 可设请求头\n'
            '3. HttpClientResponse resp = await req.close();\n'
            '4. String body = await resp.transform(utf8.decoder).join();\n'
            '5. client.close();',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.9),
          ),
        ),
        sec('② 逐步演示（语义演示）'),
        ElevatedButton(
          onPressed: _busy ? null : _run5Steps,
          child: const Text('▶ 五步走一遍'),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.amber.shade50,
          child: Text(
            _log,
            style: const TextStyle(fontSize: 12.5, height: 1.8),
          ),
        ),
        sec('③ 为什么课本先讲它（考试口径）'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.green.shade50,
          child: const Text(
            '· HttpClient 能力最全：连接超时(connectionTimeout)、认证'
            '(addCredentials)、代理(findProxy)、证书校验'
            '(badCertificateCallback)——教科书 11.2.2~11.2.5 四节都在讲它\n'
            '· 五步太啰嗦 → 社区封装出 http 包（一行 get）和 dio'
            '（拦截器/取消/上传下载）\n'
            '· 题库考"五步的顺序"和"response 是响应流要 transform 读取"',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
      ],
    );
  }
}

class _Net2Page extends StatefulWidget {
  const _Net2Page();
  @override
  State<_Net2Page> createState() => _Net2PageState();
}

// ============================================================
// 知识页 3：NET3 教科书 11.3 dio（第三方库的封装价值）
// ============================================================
Widget _dNet3(BuildContext context) => const _Net3Page();

class _Net3Page extends StatefulWidget {
  const _Net3Page();
  @override
  State<_Net3Page> createState() => _Net3PageState();
}

class _Net3PageState extends State<_Net3Page> {
  String _log = '（待请求）';
  final _dio = Dio(BaseOptions(
    baseUrl: Uri.base.resolve('dataset/').toString(), // 相对解析：见 datasetUri 说明
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  Future<void> _byDio(String path) async {
    setState(() => _log = 'dio.get("$path") 请求中…');
    final sw = Stopwatch()..start();
    try {
      final resp = await _dio.get<List<dynamic>>(path);
      final list = resp.data!;
      setState(() {
        _log = '成功：${resp.statusCode}，${list.length} 条，'
            '${sw.elapsedMilliseconds}ms\n'
            '注意：dio 自动 jsonDecode 了——resp.data 已经是 List，'
            '不需要再 jsonDecode(resp.body)';
      });
    } on DioException catch (e) {
      setState(() {
        _log = '失败：DioException.type = ${e.type}\n'
            '（连接超时/响应超时/取消/坏响应…dio 把异常也分类好了）';
      });
    }
  }

  Future<void> _cancelDemo() async {
    final cancel = CancelToken();
    setState(() => _log = '请求已发出，200ms 后主动取消…');
    final f = _dio
        .get<List<dynamic>>('/books.json', cancelToken: cancel)
        .then((r) {
      setState(() => _log = '请求已完成（太快没来得及取消）：${r.data!.length} 条');
      return r;
    }).catchError((Object e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        setState(() => _log = '已取消：CancelToken.cancel() 生效，'
            '在途请求被终止——独立研究任务1 的官方姿势');
      }
      throw e;
    });
    await Future.delayed(const Duration(milliseconds: 200), cancel.cancel);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 教科书 11.3：dio——把 HttpClient 封装成"一行"'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo.shade50,
          child: const Text(
            'final dio = Dio(BaseOptions(baseUrl: 相对地址,\n'
            '    connectTimeout: Duration(seconds: 8)));\n'
            'final resp = await dio.get<List<dynamic>>("/books.json");\n'
            '// 自动 jsonDecode：resp.data 直接是 List\n'
            '// 还自带：拦截器 / 请求取消(CancelToken) / 上传下载 / Cookie',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.9),
          ),
        ),
        sec('② 对比实验：同一个数据源，两套客户端'),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: () => _byDio('/books.json'),
              child: const Text('dio GET books.json'),
            ),
            OutlinedButton(
              onPressed: _cancelDemo,
              child: const Text('CancelToken 取消演示'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.amber.shade50,
          child: Text(_log, style: const TextStyle(fontSize: 12.5, height: 1.8)),
        ),
        sec('③ 选型口径（考"什么时候用哪个"）'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.green.shade50,
          child: const Text(
            '· http 包：官方、轻量、够用——本课作业用它\n'
            '· dio：拦截器/取消/重试/上传下载等企业需求\n'
            '· 两者都在底层走 HttpClient（web 平台走 XHR）——'
            '教科书 11.3 结尾原话：dio 内部仍然使用 HttpClient',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 4：NET4 FutureBuilder 三态渲染（+请求风暴对照）
// ============================================================
Widget _dNet4(BuildContext context) => const _Net4Page();

class _Net4Page extends StatefulWidget {
  const _Net4Page();
  @override
  State<_Net4Page> createState() => _Net4PageState();
}

class _Net4PageState extends State<_Net4Page> {
  Future<List<Book>>? _future;
  String _file = 'books.json';

  @override
  void initState() {
    super.initState();
    _future = fetchBooks('books.json');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 三态口诀：没好 / 坏了 / 空了（题库 5/6/27/28/37）'),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('36 条(正常)'),
              selected: _file == 'books.json',
              onSelected: (_) => setState(() {
                _file = 'books.json';
                _future = fetchBooks('books.json');
              }),
            ),
            ChoiceChip(
              label: const Text('empty.json(空态)'),
              selected: _file == 'empty.json',
              onSelected: (_) => setState(() {
                _file = 'empty.json';
                _future = fetchBooks('empty.json');
              }),
            ),
            ChoiceChip(
              label: const Text('no_such(错误态)'),
              selected: _file == 'no_such.json',
              onSelected: (_) => setState(() {
                _file = 'no_such.json';
                _future = fetchBooks('no_such.json');
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          child: Card(
            margin: EdgeInsets.zero,
            child: FutureBuilder<List<Book>>(
              key: ValueKey(_file),
              future: _future, // 必须是成员变量！build 里现场调函数=请求风暴
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErrorView(
                    msg: errText(snap.error!),
                    onRetry: () => setState(() => _future = fetchBooks(_file)),
                  );
                }
                final books = snap.data!;
                if (books.isEmpty) return const EmptyView();
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: books.length,
                  itemBuilder: (_, i) {
                    final b = books[i];
                    return ListTile(
                      dense: true,
                      leading: Text(b.id,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.indigo)),
                      title: Text(b.title,
                          style: const TextStyle(fontSize: 13.5)),
                      subtitle: Text('${b.author} · ${b.category} · ${b.month}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${'★' * b.rating}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.orange)),
                          const SizedBox(width: 6),
                          Text('${b.borrowCount}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        sec('② future 为什么必须是成员变量（题31/39）'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.red.shade50,
          child: const Text(
            '✗ future: fetchBooks()  ← 在 build 里现场调用\n'
            '  每次 setState/滚动/键盘弹出都会重建 → 每次都发新请求 → 请求风暴\n'
            '✓ initState 里 _future = fetchBooks()；重试 = setState 换新 future\n'
            '（EX26 病号就是反例，第 4 节验伤）',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.9),
          ),
        ),
      ],
    );
  }
}

/// 错误态视图：可读提示 + 重试入口（题库 20/34/42 题）
class ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 44, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 空态视图：不是错误，是"成功但没数据"（题库 9/37 题）
class EmptyView extends StatelessWidget {
  const EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.inbox_outlined, size: 44, color: Colors.black26),
          SizedBox(height: 8),
          Text('暂时没有数据（HTTP 200，但列表为空）',
              style: TextStyle(fontSize: 13, color: Colors.black45)),
        ],
      ),
    );
  }
}

// ============================================================
// 知识页 5：NET5 模型化 11.7（fromJson / fromJsonSafe / 生成方案）
// ============================================================
Widget _dNet5(BuildContext context) => const _Net5Page();

class _Net5Page extends StatefulWidget {
  const _Net5Page();
  @override
  State<_Net5Page> createState() => _Net5PageState();
}

class _Net5PageState extends State<_Net5Page> {
  String _log = '（点按钮验证）';
  bool _useSafe = false;

  void _parse({required bool broken}) {
    final good = <String, dynamic>{
      'id': 'b01', 'title': '跨平台之路', 'category': '计算机技术',
      'author': '张承志', 'rating': 5, 'borrowCount': 9, 'month': '1月',
    };
    final miss = <String, dynamic>{
      'id': 'b02', 'title': '山河故人',
      // 故意缺 category/author/rating/borrowCount/month（服务端字段裁剪）
    };
    final j = broken ? miss : good;
    try {
      final b = _useSafe ? Book.fromJsonSafe(j) : Book.fromJson(j);
      setState(() => _log = '${_useSafe ? 'fromJsonSafe' : 'fromJson'} 解析成功：\n'
          '${b.id}《${b.title}》${b.author} ${b.category} '
          '${'★' * b.rating} 借${b.borrowCount}次 ${b.month}');
    } catch (e) {
      setState(() => _log = '${_useSafe ? 'fromJsonSafe' : 'fromJson'} 崩溃：'
          '${e.runtimeType}\n'
          '类型断言 as String? 遇到 null 直接炸（题41：字段 null 必须'
          '兜底默认值）');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 教科书 11.7：为什么不用 Map 裸奔'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.indigo.shade50,
          child: const Text(
            'jsonDecode 的产物是 Map<String, dynamic>：\n'
            '· 字段名打错（titel）编译器不管 → 运行时才 null\n'
            '· 类型全丢失 → 拼写/类型错误全推迟到线上\n'
            'Model 化（Book.fromJson）→ 类型安全 + 自动补全 + 编译期报错',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
        sec('② fromJson vs fromJsonSafe（缺字段实验）'),
        SwitchListTile(
          dense: true,
          title: Text(_useSafe ? '用 fromJsonSafe（兜底版）' : '用 fromJson（严格版）'),
          value: _useSafe,
          onChanged: (v) => setState(() => _useSafe = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: () => _parse(broken: false),
              child: const Text('完整数据'),
            ),
            OutlinedButton(
              onPressed: () => _parse(broken: true),
              child: const Text('缺 5 个字段的数据'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.amber.shade50,
          child: Text(_log, style: const TextStyle(fontSize: 12.5, height: 1.8)),
        ),
        sec('③ 生成方案（教科书 11.7 的三档）'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.green.shade50,
          child: const Text(
            '1. 手写 fromJson/toJson —— 本课要求（作业评分点：全字段+兜底）\n'
            '2. json_serializable + build_runner —— 注解生成 .g.dart\n'
            '3. IDE 插件 / Json_model 包 —— JSON 贴进去直接出类\n'
            '口径：字段少手写最透明；字段多上百就用工具，别当人肉打字机',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 6：NET6 下拉刷新 + 上拉分页（ScrollController 触底）
// ============================================================
Widget _dNet6(BuildContext context) => const _Net6Page();

class _Net6Page extends StatefulWidget {
  const _Net6Page();
  @override
  State<_Net6Page> createState() => _Net6PageState();
}

class _Net6PageState extends State<_Net6Page> {
  final _ctrl = ScrollController();
  List<Book> _all = [];
  int _shown = 0;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _status = '';

  static const _pageSize = 6;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    try {
      final books = await fetchBooks('books.json');
      setState(() {
        _all = books;
        _shown = _pageSize;
        _status = '已加载第 1 页（$_shown/${_all.length} 条）';
      });
    } catch (e) {
      setState(() => _status = '加载失败：${errText(e)}');
    }
  }

  void _onScroll() {
    // 题库 19：pixels == maxScrollExtent 即触底
    if (_ctrl.position.pixels >= _ctrl.position.maxScrollExtent - 24 &&
        !_loadingMore &&
        _hasMore &&
        _all.isNotEmpty) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _status = '触底 → 加载更多…（模拟网络 600ms）';
    });
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _shown = (_shown + _pageSize).clamp(0, _all.length);
      _hasMore = _shown < _all.length;
      _loadingMore = false;
      _status = '已加载 $_shown/${_all.length} 条'
          '${_hasMore ? '' : '（全部加载完）'}';
    });
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _init();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _all.take(_shown).toList();
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: Colors.indigo.shade50,
          child: Text(
            'RefreshIndicator 下拉刷新 · ScrollController 触底分页\n$_status',
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _all.isEmpty && _status.contains('失败')
                ? ListView(children: [
                    SizedBox(
                      height: 300,
                      child: Center(child: Text(_status,
                          style: const TextStyle(fontSize: 13))),
                    ),
                  ])
                : ListView.builder(
                    controller: _ctrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final b = items[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 11)),
                        ),
                        title: Text(b.title,
                            style: const TextStyle(fontSize: 13.5)),
                        subtitle: Text('${b.category} · 借阅 ${b.borrowCount} 次',
                            style: const TextStyle(fontSize: 11)),
                        trailing: Text(b.month,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black38)),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 7：NET7 本地缓存·先旧后新（第10课文件通道复用）
// ============================================================
Widget _dNet7(BuildContext context) => const _Net7Page();

class _Net7PageState extends State<_Net7Page> {
  String _log = '';
  List<Book> _books = [];
  bool _fromCache = false;
  Stopwatch _sw = Stopwatch();

  Future<SharedPreferences> get _sp => SharedPreferences.getInstance();
  static const _cacheKey = 'm11:cache:books';

  Future<void> _coldStart() async {
    _sw..reset()..start();
    final sp = await _sp;
    final cached = sp.getString(_cacheKey);
    if (cached != null) {
      final list = jsonDecode(cached) as List;
      setState(() {
        _books = [
          for (final j in list) Book.fromJson(j as Map<String, dynamic>)
        ];
        _fromCache = true;
        _log = '冷启动 ${_sw.elapsedMilliseconds}ms：先渲染缓存'
            '${_books.length} 条（秒开！）→ 后台再刷新';
      });
      // 后台刷新（先旧后新的"后新"半步）
      await _refresh(silent: true);
    } else {
      setState(() {
        _fromCache = false;
        _log = '首次使用：没有缓存，只能等网络…';
      });
      await _refresh(silent: false);
    }
  }

  Future<void> _refresh({required bool silent}) async {
    try {
      final books = await fetchBooks('books.json');
      final sp = await _sp;
      await sp.setString(_cacheKey, jsonEncode(books)); // 成功才写缓存
      setState(() {
        _books = books;
        _fromCache = false;
        _log = silent
            ? '$_log\n后台刷新完成：仍是 ${books.length} 条'
                '（若服务端更新过，此刻已换新）'
            : '网络刷新 ${_sw.elapsedMilliseconds}ms：拿到 ${books.length} 条'
                '并写入缓存';
      });
    } catch (e) {
      if (!silent) {
        setState(() => _log = '刷新失败：${errText(e)}\n（缓存还在：'
            '断网也不白屏——这就是先旧后新的价值）');
      }
    }
  }

  Future<void> _clear() async {
    final sp = await _sp;
    await sp.remove(_cacheKey);
    setState(() {
      _books = [];
      _log = '缓存已清空 → 再点「模拟冷启动」就是首次体验';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 先旧后新（题库 22/32/49）'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.indigo.shade50,
          child: const Text(
            '成功响应 → writeAsString/写 sp 落缓存（第 10 课通道复用）\n'
            '下次进入 → 先渲染缓存（秒开）→ 再尝试刷新\n'
            '刷新失败 → 缓存顶着，不白屏',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: _coldStart,
              child: const Text('模拟冷启动'),
            ),
            OutlinedButton(
              onPressed: () => _refresh(silent: false),
              child: const Text('仅刷新'),
            ),
            OutlinedButton(
              onPressed: _clear,
              child: const Text('清空缓存'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.amber.shade50,
          child: Text(
            _log.isEmpty ? '（先点「模拟冷启动」）' : _log,
            style: const TextStyle(fontSize: 12.5, height: 1.8),
          ),
        ),
        sec('② 缓存的内容${_fromCache ? '（当前显示：缓存）' : '（当前显示：网络）'}'),
        if (_books.isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final b in _books.take(5))
                  ListTile(
                    dense: true,
                    title: Text(b.title, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${b.id} · ${b.author}',
                        style: const TextStyle(fontSize: 11)),
                    trailing: _fromCache
                        ? const Icon(Icons.save_outlined,
                            size: 16, color: Colors.brown)
                        : const Icon(Icons.cloud_done,
                            size: 16, color: Colors.green),
                  ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('…（仅示前 5 条）',
                      style: TextStyle(fontSize: 11, color: Colors.black38)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Net7Page extends StatefulWidget {
  const _Net7Page();
  @override
  State<_Net7Page> createState() => _Net7PageState();
}

// ============================================================
// 知识页 8：NET8 教科书 11.5 WebSocket + 教科书收官地图
// ============================================================
Widget _dNet8(BuildContext context) => const _Net8Page();

class _Net8PageState extends State<_Net8Page> {
  WebSocketChannel? _channel;
  final _msgs = <String>[];
  final _ctrl = TextEditingController();
  bool _connected = false;

  static const _url = 'wss://echo.websocket.events';

  Future<void> _connect() async {
    setState(() => _msgs.add('正在连接 $_url …'));
    try {
      final ch = WebSocketChannel.connect(Uri.parse(_url));
      await ch.ready;
      setState(() {
        _channel = ch;
        _connected = true;
        _msgs.add('已连接：这是长连接，服务器可以主动推消息给你');
      });
      ch.stream.listen(
        (msg) => setState(() => _msgs.add('⇠ 回显：$msg')),
        onError: (e) => setState(() {
          _connected = false;
          _msgs.add('连接出错：$e');
        }),
        onDone: () => setState(() {
          _connected = false;
          _msgs.add('连接已关闭');
        }),
      );
    } catch (e) {
      setState(() => _msgs.add('连接失败：$e（测试服务偶发不可用，'
          '属正常现象——教科书 11.5 也有此提示）'));
    }
  }

  void _send() {
    if (_ctrl.text.isEmpty || _channel == null) return;
    _channel!.sink.add(_ctrl.text);
    setState(() => _msgs.add('⇢ 发送：${_ctrl.text}'));
    _ctrl.clear();
  }

  void _close() {
    _channel?.sink.close();
    setState(() {
      _connected = false;
      _msgs.add('已主动关闭（sink.close）');
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('① 教科书 11.5：WebSocket——HTTP 的"对讲机"'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.indigo.shade50,
          child: const Text(
            'HTTP：客户端问一句 → 服务器答一句 → 断开（无状态、单向）\n'
            'WebSocket：HTTP 握手升级为长连接 → 双方随时互发（实时通信）\n'
            '四步：connect → 监听 stream → sink.add 发送 → close 收尾',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
        sec('② 回显服务器实验（echo.websocket.events）'),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: _connected ? null : _connect,
              child: const Text('连接'),
            ),
            OutlinedButton(
              onPressed: _connected ? _close : null,
              child: const Text('关闭'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                enabled: _connected,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '输入消息，回车发送',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _connected ? _send : null,
              child: const Icon(Icons.send, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_msgs.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(10),
            color: Colors.amber.shade50,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in _msgs)
                  Text(m, style: const TextStyle(fontSize: 12, height: 1.7)),
              ],
            ),
          ),
        sec('③ 教科书收官地图：第 11 章（本课讲完，全书教学线结束）'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.green.shade50,
          child: const Text(
            '✓ 11.1 文件操作（第 10 课）\n'
            '✓ 11.2 HttpClient（本课 NET2）\n'
            '✓ 11.3 dio（本课 NET3）\n'
            '○ 11.4 分块下载（自学选读：大文件下载的实现思路）\n'
            '✓ 11.5 WebSocket（本页）\n'
            '○ 11.6 Socket API（自学选读：更底层的 TCP 通信）\n'
            '✓ 11.7 JSON 转 Dart Model（本课 NET5）\n'
            '至此教科书教学线全部讲完——第 12 周课不再是新知识，'
            '是期末验收：纸质设计方案上交 + 一致性核对 + 逐人检查。',
            style: TextStyle(fontSize: 12.5, height: 1.95),
          ),
        ),
      ],
    );
  }
}

class _Net8Page extends StatefulWidget {
  const _Net8Page();
  @override
  State<_Net8Page> createState() => _Net8PageState();
}

// ============================================================
// 病号 EX26：请求风暴（future 没缓存，build 里现场请求）
// ============================================================
Widget _ex26(BuildContext context) => const _Ex26Page();

class _Ex26Page extends StatefulWidget {
  const _Ex26Page();
  @override
  State<_Ex26Page> createState() => _Ex26PageState();
}

class _Ex26PageState extends State<_Ex26Page> {
  int _reqCount = 0;
  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX26 症状：列表闪个不停，网络面板请求狂飙'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.red.shade50,
          child: Text(
            'build 已执行 $_buildCount 次；已发出请求 $_reqCount 次\n'
            '（每敲一个字/每滚动一下，build 就重跑一次，请求就再发一次）',
            style: const TextStyle(fontSize: 14, height: 1.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: '随便输入几个字，看着请求数暴涨（搜索框挡板）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: Card(
            margin: EdgeInsets.zero,
            // 病号代码：future 参数在 build 里现场调用 fetchBooks()
            child: FutureBuilder<List<Book>>(
              future: _fetch(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: snap.data!.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(snap.data![i].title,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(snap.data![i].author,
                        style: const TextStyle(fontSize: 11)),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.blue.shade50,
          child: const Text(
            '病根提示：题库第 31/39 题——future 未缓存到成员变量，'
            'build 里每次重建都创建新请求（请求风暴）。\n'
            '修复方向：initState 里 _future = fetchBooks()，build 只读'
            '成员变量；重试用 setState 换新 future。\n'
            '进阶（独立研究任务1）：搜索场景加 300ms 防抖 + 页面离开取消'
            '在途请求。',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
      ],
    );
  }

  Future<List<Book>> _fetch() {
    _reqCount++;
    return fetchBooks('books.json');
  }
}

// ============================================================
// 病号 EX27：空态装死（成功但空数据时一片空白）
// ============================================================
Widget _ex27(BuildContext context) => const _Ex27Page();

class _Ex27PageState extends State<_Ex27Page> {
  Future<List<Book>>? _f;

  @override
  void initState() {
    super.initState();
    _f = fetchBooks('empty.json');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX27 症状：页面空白，用户以为卡死/坏了'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.red.shade50,
          child: const Text(
            '数据源是 empty.json（HTTP 200、返回 []）——请求成功了，'
            '但页面什么都没有。没有报错、没有提示、没有重试，'
            '只有一片"装死"的白。',
            style: TextStyle(fontSize: 13, height: 1.8),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: Card(
            margin: EdgeInsets.zero,
            // 病号代码：只处理了 loading 和 error，漏了 empty
            child: FutureBuilder<List<Book>>(
              future: _f,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return const Center(child: Text('出错了'));
                }
                final books = snap.data!;
                return ListView.builder(
                  itemCount: books.length, // 0 条 → 什么都不渲染
                  itemBuilder: (_, i) => ListTile(
                    title: Text(books[i].title),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: Card(
            margin: EdgeInsets.zero,
            color: Colors.green.shade50,
            child: const Center(
              child: Text(
                '健康版：三态齐全\n\n'
                '没好 → loading 转圈\n'
                '坏了 → 错误视图 + 重试\n'
                '空了 → EmptyView（"暂时没有数据"）\n'
                '—— empty.json 就是专门考空态的（题库 9/37 题）',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 2.0),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          color: Colors.blue.shade50,
          child: const Text(
            '病根提示：三态缺角——"任何一态缺失都是扣分点"（讲义原话）。\n'
            '修复：books.isEmpty 时返回空状态视图；区分"错"与"空"：'
            '错是 hasError，空是 done 且 data 为空列表。',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
      ],
    );
  }
}

class _Ex27Page extends StatefulWidget {
  const _Ex27Page();
  @override
  State<_Ex27Page> createState() => _Ex27PageState();
}

// ============================================================
// 病号 EX28：404 装成功（不判状态码就解析 body）
// ============================================================
Widget _ex28(BuildContext context) => const _Ex28Page();

class _Ex28PageState extends State<_Ex28Page> {
  String _log = '（点按钮）';

  Future<void> _bad() async {
    final resp = await http.get(datasetUri('no_such_file.json'));
    // 病号代码：没判 statusCode，直接 jsonDecode
    try {
      final data = jsonDecode(resp.body);
      setState(() => _log = '解析"成功"了？？拿到了：'
          '${data.runtimeType}\n'
          '——404 页面返回的是 GitHub Pages 的 HTML 错误页，'
          'jsonDecode 碰巧没炸 / 或炸得莫名其妙。\n'
          '真实世界：状态码是服务器的"第一句话"，不先听它说话就'
          '拆包裹，迟早出事。');
    } catch (e) {
      setState(() => _log = '当场崩溃：${e.runtimeType}\n'
          '——404 的 body 是 HTML 错误页，根本不是 JSON。\n'
          '这就是不判状态码的下场（题库 40 题）。');
    }
  }

  Future<void> _good() async {
    final resp = await http.get(datasetUri('no_such_file.json'));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      setState(() => _log = '正常路径：${list.length} 条');
    } else {
      // 健康版：先判状态码，非 200 走业务层错误
      setState(() => _log = '健康版：HTTP ${resp.statusCode} → '
          'throw AppException(\'http\', \'服务异常\')\n'
          '给用户看"服务异常"，错误可分类上报（题库 25 题）。');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX28 症状：页面 404 了，App 却"若无其事"'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.red.shade50,
          child: const Text(
            '病号代码：final resp = await http.get(url);\n'
            '          final data = jsonDecode(resp.body);  ← 直接拆包裹\n'
            '没有 if (resp.statusCode == 200) 这道闸门。',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.9),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: _bad,
              child: const Text('▶ 病号版请求 404'),
            ),
            OutlinedButton(
              onPressed: _good,
              child: const Text('▶ 健康版请求 404'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.amber.shade50,
          child: Text(_log, style: const TextStyle(fontSize: 12.5, height: 1.8)),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          color: Colors.blue.shade50,
          child: const Text(
            '病根提示：题库 40 题——非 200 也当成功解析 body。\n'
            '修复：先判状态码；2xx 才解析，其余 throw 业务层异常。\n'
            '顺带记住三个常见状态码：200 成功 / 404 资源不存在 / '
            '500 服务器内部错误（题库 2 题）。',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
      ],
    );
  }
}

class _Ex28Page extends StatefulWidget {
  const _Ex28Page();
  @override
  State<_Ex28Page> createState() => _Ex28PageState();
}

// ============================================================
// 病号 EX29：静音错误（catch 里只 print，用户无感知）
// ============================================================
Widget _ex29(BuildContext context) => const _Ex29Page();

class _Ex29PageState extends State<_Ex29Page> {
  String _log = '（点加载）';

  Future<void> _silent() async {
    setState(() => _log = '加载中…');
    try {
      final books = await fetchBooks('no_such_file.json');
      setState(() {
        _log = '成功 ${books.length} 条';
      });
    } catch (e) {
      // 病号代码：吞掉异常，只在控制台 print
      // ignore: avoid_print
      print('load error: $e');
      setState(() => _log = '加载完成(?)'); // ← 用户看到这句，以为一切正常
    }
  }

  Future<void> _loud() async {
    setState(() => _log = '加载中…');
    try {
      await fetchBooks('no_such_file.json');
    } catch (e) {
      setState(() => _log = '错误态：${errText(e)}\n'
          '—— hasError 分支渲染 ErrorView + 重试按钮，'
          '用户知道发生了什么、知道该怎么办（题库 20/42 题）。');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX29 症状：断网/出错后页面永远"加载完成"，什么也没有'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.red.shade50,
          child: const Text(
            '病号代码：} catch (e) {\n'
            '            print(e);            ← 只打在控制台\n'
            '            setState(() => _log = \'加载完成\');\n'
            '          }\n'
            '开发者看得到 print，用户看不到——错误被"静音"了。',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.9),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: _silent,
              child: const Text('▶ 病号版加载（必 404）'),
            ),
            OutlinedButton(
              onPressed: _loud,
              child: const Text('▶ 健康版加载'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.amber.shade50,
          child: Text(_log, style: const TextStyle(fontSize: 12.5, height: 1.8)),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          color: Colors.blue.shade50,
          child: const Text(
            '病根提示：题库 42 题——hasError 时只 print，用户无感知。\n'
            '修复：错误要"说人话 + 给出路"——可读提示 + 重试入口；\n'
            '分类上报（独立研究任务3）：三类错误接入全局通道落本地日志。\n'
            '顺带一句：真机上"开飞行模式再刷新"就能亲手触发这条路径，'
            '错误处理是本课评分重头。',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
      ],
    );
  }
}

class _Ex29Page extends StatefulWidget {
  const _Ex29Page();
  @override
  State<_Ex29Page> createState() => _Ex29PageState();
}

// ============================================================
// 病号 EX30：来历不明（数据合规红线：来源不标注）
// ============================================================
Widget _ex30(BuildContext context) => const _Ex30Page();

class _Ex30Page extends StatefulWidget {
  const _Ex30Page();
  @override
  State<_Ex30Page> createState() => _Ex30PageState();
}

class _Ex30PageState extends State<_Ex30Page> {
  String _log = '（点加载）';
  List<Book> _shownBooks = const [];

  Future<void> _load() async {
    try {
      final books = await fetchBooks('books.json');
      setState(() {
        _shownBooks = books.take(4).toList();
        _log = '加载 ${books.length} 条成功——但这个 App 的"关于"页'
            '什么都没写：数据从哪来？能不能商用？谁维护？一概不知。';
      });
    } catch (e) {
      setState(() => _log = '加载失败：${errText(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX30 症状：一个"什么都没说"的数据应用'),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.red.shade50,
          child: const Text(
            '列表很漂亮，功能很正常——但整个 App 找不到一行字说明'
            '数据来源。这在课程里是合规红线，在真实世界里是法律风险'
            '（数据从哪来、有没有授权、用户协议怎么说）。',
            style: TextStyle(fontSize: 13, height: 1.8),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: _load, child: const Text('加载数据')),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.amber.shade50,
          child: Text(_log, style: const TextStyle(fontSize: 12.5, height: 1.8)),
        ),
        if (_shownBooks.isNotEmpty) ...[
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                for (final b in _shownBooks)
                  ListTile(
                    dense: true,
                    title: Text(b.title, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${b.author} · ${b.category}',
                        style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          color: Colors.green.shade50,
          child: const Text(
            '健康版"关于"页应写：\n'
            '· 数据来源：课程统一数据集（教师发布地址）\n'
            '· 声明：教学演示虚构数据，非真实统计\n'
            '· 本课程红线（题库 1/10/48 题）：网络访问仅允许统一数据集'
            '与课堂发布接口；访问其他公网 API 须教师确认。\n'
            '病根不在代码在意识：EX30 没有崩、没有错——它缺的是"出处"。',
            style: TextStyle(fontSize: 12.5, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// m11 演示注册表
// ============================================================
final m11Demos = <Demo>[
  Demo('NET1', '网络请求入门', 'http.get+超时+状态码 · 错误三分类 · 真实端点', _dNet1),
  Demo('11.2', 'HttpClient 五步', '教科书11.2 · 原生请求 · 认证/代理/证书带读', _dNet2),
  Demo('11.3', 'dio', '教科书11.3 · 自动jsonDecode · CancelToken取消', _dNet3),
  Demo('FB', '三态渲染', 'FutureBuilder · 没好/坏了/空了 · 重试', _dNet4),
  Demo('11.7', '模型化', 'fromJson/fromJsonSafe · 生成方案三档', _dNet5),
  Demo('PG', '刷新与分页', 'RefreshIndicator · ScrollController触底', _dNet6),
  Demo('CACHE', '先旧后新', '缓存秒开 · 后台刷新 · 断网不白屏', _dNet7),
  Demo('11.5', 'WebSocket', '教科书11.5 · 长连接回显 · 教科书收官地图', _dNet8),
  Demo('EX26', '🌀 请求风暴', 'future未缓存 · build里现场请求（题31/39）', _ex26),
  Demo('EX27', '⬜ 空态装死', '三态缺角 · 空列表渲染成白页（题37）', _ex27),
  Demo('EX28', '🎭 404装成功', '不判状态码就解析body（题40）', _ex28),
  Demo('EX29', '🔇 静音错误', 'catch里只print · 用户无感知（题42）', _ex29),
  Demo('EX30', '❓ 来历不明', '来源不标注 · 数据合规红线（题1/10/48）', _ex30),
];
