// ============================================================
// 第7课（第9周）：可滚动组件与多页面结构 演示页
// 对应《Flutter实战·第二版》：6.1/6.2/6.3/6.4/6.6 + 2.4 路由管理
// EX6~EX10 为扩展案例（含故意设计的缺陷，供学生修复练习）
//   症状复现口径：点按钮/滑动后表现与宣传不符，详见讲义七 7A 节
// ============================================================
import 'package:flutter/material.dart';

import 'main.dart' show Demo, sec;

// ---------- 数据模型 ----------
class _Book {
  final String title;
  final String category;
  final int borrowCount;
  final Color cover;
  const _Book(this.title, this.category, this.borrowCount, this.cover);
}

const _categories = ['前端', '后端', '移动', 'AI', '算法', '工程'];

final _allBooks = List.generate(
  40,
  (i) => _Book(
    '图书 ${i + 1}',
    _categories[i % _categories.length],
    (i * 37) % 90 + 10,
    Colors.primaries[i % Colors.primaries.length],
  ),
);

// ---------- 6.1 世界观：一次构建 vs 按需构建 ----------
Widget _d61World(BuildContext context) {
  Widget card(String t, String d, IconData i, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Icon(i, color: c, size: 30),
              const SizedBox(height: 6),
              Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      );
  return ListView(
    padding: const EdgeInsets.all(12),
    children: [
      sec('6.1 两种布局模型（书上原话）'),
      const Text(
        '"如果要一次性将子组件全部构建出将会非常昂贵！"\n'
        '"只有当 Sliver 出现在视口中时才会去构建它，这种模型称为按需加载模型。"',
        style: TextStyle(fontSize: 13, height: 1.6, color: Colors.indigo),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card('盒模型', 'RenderBox\n一次全构建\nColumn/Wrap', Icons.crop_square, Colors.grey),
          const SizedBox(width: 8),
          card('Sliver 模型', 'RenderSliver\n滚到才构建\nListView/GridView', Icons.view_agenda_outlined, Colors.indigo),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card('Scrollable', '处理手势\n算出偏移量', Icons.touch_app, Colors.blue),
          const SizedBox(width: 8),
          card('Viewport', '视窗：屏幕上\n那一格可见区', Icons.crop_din, Colors.teal),
          const SizedBox(width: 8),
          card('Sliver', '视窗里显示的\n一个个元素', Icons.layers, Colors.deepOrange),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text(
          'cacheExtent 默认 250 逻辑像素：可视区外再多渲染 250，滚进来"更丝滑"；\n'
          'physics 平台差异：iOS 弹性 Bouncing / Android 微光 Clamping。',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
      ),
    ],
  );
}

// ---------- 6.2 SingleChildScrollView：A-Z 字母表 ----------
Widget _d62Single(BuildContext context) {
  String letters = '';
  for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++) {
    letters += String.fromCharCode(c);
  }
  return Column(
    children: [
      sec('6.2 SingleChildScrollView（书上：A~Z）'),
      const Text('Scrollbar > SingleChildScrollView > Column\n内容"不会超过屏幕太多"才用它',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5)),
      const SizedBox(height: 8),
      Expanded(
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final l in letters.split(''))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(l,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Container(
                                height: 1, color: Colors.indigo.shade100)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// ---------- 6.3a ListView：children / separated ----------
Widget _d63Children(BuildContext context) => ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('6.3.1 默认构造：children 一次给全'),
        const Text('适合"子组件数量已知且比较少"。注意：Widget 全建，但布局绘制仍是按需的。',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 8),
        for (var i = 1; i <= 8; i++)
          ListTile(
            leading: CircleAvatar(child: Text('$i')),
            title: Text('静态条目 $i'),
            subtitle: const Text('children 版 · 拖动时不再新建 Widget'),
            dense: true,
          ),
        sec('6.3.2 ListView.separated 奇偶分割线'),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          separatorBuilder: (_, i) => Container(
            margin: EdgeInsets.only(left: i.isEven ? 56 : 16),
            height: .5,
            color: i.isEven ? Colors.redAccent : Colors.indigo,
          ),
          itemBuilder: (_, i) => ListTile(
            dense: true,
            leading: Icon(i.isEven ? Icons.looks_one : Icons.looks_two,
                color: i.isEven ? Colors.redAccent : Colors.indigo),
            title: Text('第 ${i + 1} 行（${i.isEven ? '奇数行红缩进线' : '偶数行蓝通栏线'}）'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
          child: const Text(
            '原理三句话：列表项是 RenderBox 不是 Sliver；一个 ListView 只有一个 Sliver；\n默认 SliverList → 指定 itemExtent 变 SliverFixedExtentList → 指定原型变 SliverPrototypeExtentList。',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ),
      ],
    );

// ---------- 6.3b ListView.builder：懒构建 + 无限加载 ----------
class _D63BuilderPage extends StatefulWidget {
  @override
  State<_D63BuilderPage> createState() => _D63BuilderState();
}

class _D63BuilderState extends State<_D63BuilderPage> {
  // 无限加载：表尾放 "##loading##" 标记项（书上无限加载实例）
  final _words = <String>['初始条目 1', '初始条目 2', '##loading##'];
  bool _loading = false;

  Future<void> _retrieve() async {
    await Future.delayed(const Duration(milliseconds: 600)); // 模拟网络
    if (!mounted) return;
    setState(() {
      _words.insertAll(
          _words.length - 1, [for (var i = 0; i < 20; i++) '追加条目 ${_words.length + i - 1}']);
      if (_words.length > 100) _words[_words.length - 1] = '没有更多了';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        sec('6.3.3 builder 懒构建 + 无限加载（书上实例）'),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
                'itemCount 为 null = 无限列表；滚到才调 itemBuilder。\n往下滚：表尾 ##loading## 标记 → 追加20条 → 满100条收口。',
                style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5))),
        Expanded(
          child: ListView.builder(
            itemExtent: 48, // 书上："指定 itemExtent 会有更好的性能"
            itemCount: _words.length,
            itemBuilder: (_, i) {
              if (_words[i] == '##loading##') {
                if (!_loading && _words.length <= 100) {
                  _loading = true;
                  _retrieve();
                }
                return const Center(
                    child: SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
              }
              return ListTile(
                dense: true,
                leading: const Icon(Icons.menu_book, size: 20),
                title: Text(_words[i], style: const TextStyle(fontSize: 14)),
                trailing: Text('$i', style: const TextStyle(fontSize: 11, color: Colors.black38)),
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _d63Builder(BuildContext context) => _D63BuilderPage();

// ---------- 6.4 ScrollController：返回顶部 ----------
class _D64Page extends StatefulWidget {
  @override
  State<_D64Page> createState() => _D64State();
}

class _D64State extends State<_D64Page> {
  final _controller = ScrollController();
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final s = _controller.offset >= 1000; // 书上经典阈值 1000
      if (s != _showTop) setState(() => _showTop = s);
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // 书上坑：忘记 dispose 内存泄漏
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        sec('6.4 ScrollController：offset≥1000 出现返回顶部'),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('addListener 读 controller.offset；点击 animateTo(0, 200ms, ease)。\n当前 offset 实时显示在底部。别忘了 dispose！',
                style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5))),
        Expanded(
          child: ListView.builder(
            controller: _controller,
            itemExtent: 44,
            itemCount: 80,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              title: Text('第 $i 行 · 滚到 1000 才见按钮', style: const TextStyle(fontSize: 13)),
              trailing: Text('${i * 44} px', style: const TextStyle(fontSize: 10, color: Colors.black38)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.indigo.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  'offset = ${_controller.hasClients && _controller.positions.length == 1 ? _controller.offset.toStringAsFixed(0) : '—'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
              _showTop
                  ? ElevatedButton.icon(
                      onPressed: () => _controller.animateTo(0,
                          duration: const Duration(milliseconds: 200), curve: Curves.ease),
                      icon: const Icon(Icons.arrow_upward, size: 16),
                      label: const Text('返回顶部', style: TextStyle(fontSize: 12)))
                  : const Text('（未到 1000，按钮还没出现）',
                      style: TextStyle(fontSize: 11, color: Colors.black38)),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _d64Controller(BuildContext context) => _D64Page();

// ---------- 6.6 GridView：count / extent ----------
Widget _d66Grid(BuildContext context) {
  Widget cell(Color c, String t) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
  return ListView(
    padding: const EdgeInsets.all(12),
    children: [
      sec('6.6.1 GridView.count 固定 3 列'),
      SizedBox(
        height: 320,
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.4, // 宽/高比，书上强调别让内容溢出格子
          children: [for (var i = 1; i <= 9; i++) cell(Colors.primaries[i % 18], '$i')],
        ),
      ),
      sec('6.6.2 GridView.extent 最大边 130 → 自动等分'),
      const Text('书上原话：横轴 450、maxCrossAxisExtent 落在 [450/4, 450/3) 内，子项实际都是 112.5。',
          style: TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 6),
      SizedBox(
        height: 260,
        child: GridView.extent(
          maxCrossAxisExtent: 130,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.2,
          children: [for (var i = 1; i <= 10; i++) cell(Colors.primaries[(i + 9) % 18], '图$i')],
        ),
      ),
      sec('SliverGridDelegate 两兄弟'),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text(
          'FixedCrossAxisCount：定列数，大小=列数+宽高比共同决定；\n'
          'MaxCrossAxisExtent：给单格最大宽度，仍等分取整；\n'
          '大量子项 → GridView.builder(gridDelegate + itemBuilder)。',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
      ),
    ],
  );
}

// ---------- 2.4 路由：演示页内嵌"迷你 App"（自建 MaterialApp+路由表） ----------
class _RouteRoot extends StatelessWidget {
  const _RouteRoot();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (_) => const _RHomePage(),
        '/list': (_) => const _RListPage(),
        '/detail': (_) => const _RDetailPage(),
      },
    );
  }
}

class _RHomePage extends StatelessWidget {
  const _RHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('迷你App · 首页（2.4 路由表）')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('MaterialApp routes 注册三条命名路由；\npushNamed 跳转，pop 返回。',
                style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                for (final c in _categories)
                  OutlinedButton(
                    onPressed: () async {
                      // 回程传值：await pushNamed 接住 pop 带回的字符串
                      final r = await Navigator.pushNamed(context, '/list', arguments: c);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                            content: Text('回传值：$r'), duration: const Duration(seconds: 2)));
                    },
                    child: Text(c, style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RListPage extends StatelessWidget {
  const _RListPage();

  @override
  Widget build(BuildContext context) {
    final cat = ModalRoute.of(context)?.settings.arguments as String? ?? '全部';
    final books =
        cat == '全部' ? _allBooks : _allBooks.where((b) => b.category == cat).toList();
    return Scaffold(
      appBar: AppBar(title: Text('列表页 · $cat')),
      body: ListView.builder(
        itemCount: books.length,
        itemBuilder: (_, i) => ListTile(
          leading: CircleAvatar(
              backgroundColor: books[i].cover.withValues(alpha: .7), child: Text('${i + 1}')),
          title: Text(books[i].title),
          subtitle: Text('${books[i].category} · 借阅 ${books[i].borrowCount} 次'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/detail', arguments: books[i]),
        ),
      ),
    );
  }
}

class _RDetailPage extends StatelessWidget {
  const _RDetailPage();

  @override
  Widget build(BuildContext context) {
    final b = ModalRoute.of(context)?.settings.arguments as _Book?;
    return Scaffold(
      appBar: AppBar(title: const Text('详情页')),
      body: b == null
          ? const Center(child: Text('没有收到参数！'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 110,
                    decoration: BoxDecoration(
                        color: b.cover.withValues(alpha: .8), borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(height: 12),
                  Text(b.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('分类：${b.category} · 借阅 ${b.borrowCount} 次',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    // 回程带值：pop(context, '...')
                    onPressed: () => Navigator.pop(context, '看完了《${b.title}》'),
                    child: const Text('返回并带值'),
                  ),
                ],
              ),
            ),
    );
  }
}

Widget _d24Routes(BuildContext context) => const _RouteRoot();

// ============================================================
// EX6~EX10：第7课扩展案例（含故意缺陷，修复练习素材）
// 症状与病根对照表见讲义七 7A 节
// ============================================================

// ---------- EX6 通讯录：字母索引条（缺陷：索引条点击无响应） ----------
class _Ex6Page extends StatefulWidget {
  @override
  State<_Ex6Page> createState() => _Ex6State();
}

class _Ex6State extends State<_Ex6Page> {
  final _controller = ScrollController();
  final _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
  final _contacts = <String, List<String>>{
    for (final l in ['A', 'B', 'C', 'D', 'E', 'F', 'G'])
      l: [for (var i = 1; i <= 4; i++) '${l}联系人$i'],
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 每组：1 个组头 + 4 个联系人
    final rows = <Widget>[
      for (final l in _letters) ...[
        Container(
          height: 28,
          color: Colors.indigo.shade50,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(l,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13)),
        ),
        for (final name in _contacts[l]!)
          ListTile(
              dense: true,
              leading: CircleAvatar(child: Text(name[0])),
              title: Text(name, style: const TextStyle(fontSize: 14))),
      ],
    ];
    return Stack(
      children: [
        ListView(controller: _controller, children: rows),
        // 右侧字母索引条 —— 缺陷：只是"看起来能点"，没挂任何点击事件
        Positioned(
          right: 4,
          top: 80,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .8), borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final l in _letters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(l, style: const TextStyle(fontSize: 12, color: Colors.indigo)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _ex6Contacts(BuildContext context) => _Ex6Page();

// ---------- EX7 商品瀑布墙（缺陷：childAspectRatio 不当，卡片被压扁） ----------
Widget _ex7Wall(BuildContext context) {
  final prices = [59.0, 129.0, 89.0, 199.0, 45.0, 76.0, 158.0, 32.0, 118.0];
  return GridView.builder(
    padding: const EdgeInsets.all(8),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 1.6, // 缺陷：比例给小了，卡片内容被压扁/溢出
    ),
    itemCount: prices.length,
    itemBuilder: (_, i) => Card(
      margin: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Container(color: Colors.primaries[i % 18].withValues(alpha: .6))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('商品 ${i + 1} · 精选好物限时特惠',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('已售 ${(i * 137) % 2000 + 100} 件 · 顺丰包邮 · 七天无理由退换',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 4),
                Text('¥${prices[i]}',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------- EX8 路由传参（缺陷：忘了传 arguments，详情收不到参数） ----------
class _Ex8Root extends StatelessWidget {
  const _Ex8Root();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      routes: {
        '/': (_) => _Ex8Home(),
        '/detail': (_) => _Ex8Detail(),
      },
    );
  }
}

class _Ex8Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EX8 传参演示')),
      body: ListView.builder(
        itemCount: _allBooks.length,
        itemBuilder: (_, i) => ListTile(
          leading:
              CircleAvatar(backgroundColor: _allBooks[i].cover.withValues(alpha: .7)),
          title: Text(_allBooks[i].title),
          subtitle: Text('${_allBooks[i].category} · 借阅 ${_allBooks[i].borrowCount} 次'),
          onTap: () {
            // 缺陷：忘了传 arguments，直接 pushNamed 裸跳
            Navigator.pushNamed(context, '/detail');
          },
        ),
      ),
    );
  }
}

class _Ex8Detail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 详情页只认 arguments，收不到就显示"未知书籍"占位
    final b = ModalRoute.of(context)?.settings.arguments as _Book?;
    return Scaffold(
      appBar: AppBar(title: const Text('详情')),
      body: Center(
        child: b == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.help_outline, size: 48, color: Colors.black26),
                  Text('未知书籍（参数没收到！）', style: TextStyle(color: Colors.black38)),
                ],
              )
            : Text('${b.title} · ${b.category}'),
      ),
    );
  }
}

Widget _ex8Args(BuildContext context) => const _Ex8Root();

// ---------- EX9 返回值回传（缺陷：跳过去选完却没接住返回值） ----------
class _Ex9Root extends StatelessWidget {
  const _Ex9Root();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      routes: {
        '/': (_) => _Ex9Home(),
        '/pick': (_) => _Ex9Pick(),
      },
    );
  }
}

class _Ex9Home extends StatefulWidget {
  @override
  State<_Ex9Home> createState() => _Ex9HomeState();
}

class _Ex9HomeState extends State<_Ex9Home> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EX9 选择收货地址')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_picked == null ? '当前：未选择' : '当前：$_picked',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                // 缺陷：跳过去了，但没有接返回值（缺 await 没用结果）
                Navigator.pushNamed(context, '/pick');
                setState(() {}); // 还立刻刷了个寂寞
              },
              child: const Text('去选择地址'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ex9Pick extends StatelessWidget {
  const _Ex9Pick();
  static const _addrs = ['东陆校区 · 翠湖北路2号', '呈贡校区 · 大学城东外环南路', '家里 · 老家地址'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选地址')),
      body: ListView(
        children: [
          for (final a in _addrs)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(a),
              onTap: () => Navigator.pop(context, a), // 这里明明带值 pop 了
            ),
        ],
      ),
    );
  }
}

Widget _ex9PopValue(BuildContext context) => const _Ex9Root();

// ---------- EX10 底部导航（缺陷：切页丢状态，没用 IndexedStack） ----------
class _Ex10Root extends StatelessWidget {
  const _Ex10Root();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.pink, useMaterial3: true),
      home: _Ex10Shell(),
    );
  }
}

class _Ex10Shell extends StatefulWidget {
  @override
  State<_Ex10Shell> createState() => _Ex10ShellState();
}

class _Ex10ShellState extends State<_Ex10Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    // 缺陷：每次切换 _body() 重新 new，计数器/输入内容全丢
    return Scaffold(
      body: _body(_tab),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(
              icon: Icon(Icons.star_border), selectedIcon: Icon(Icons.star), label: '收藏'),
        ],
      ),
    );
  }

  Widget _body(int i) => i == 0 ? _Ex10Counter() : _Ex10Form();
}

class _Ex10Counter extends StatefulWidget {
  @override
  State<_Ex10Counter> createState() => _Ex10CounterState();
}

class _Ex10CounterState extends State<_Ex10Counter> {
  int _n = 0;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('把计数器加到 5，再切到"收藏"再切回来 👀',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            Text('$_n', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            ElevatedButton(onPressed: () => setState(() => _n++), child: const Text('加一')),
          ],
        ),
      );
}

class _Ex10Form extends StatefulWidget {
  @override
  State<_Ex10Form> createState() => _Ex10FormState();
}

class _Ex10FormState extends State<_Ex10Form> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('输入点文字，切走再切回来 👀',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 8),
              TextField(
                  controller: _c,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: '随便写点什么')),
            ],
          ),
        ),
      );
}

Widget _ex10Tabs(BuildContext context) => const _Ex10Root();

// 本文件演示页注册表（由 main.dart 的 demos 列表引用）
final m7Demos = <Demo>[
  Demo('6.1', '滚动世界观', '6.1 盒模型 vs Sliver 按需加载 · 三角色', _d61World),
  Demo('6.2', 'SingleChildScrollView', '6.2 A~Z 字母表 · Scrollbar', _d62Single),
  Demo('6.3a', 'ListView children', '6.3 children/separated · 原理三句话', _d63Children),
  Demo('6.3b', 'ListView.builder', '6.3 无限加载 · itemExtent 性能', _d63Builder),
  Demo('6.4', 'ScrollController', '6.4 offset监听 · 返回顶部 · dispose', _d64Controller),
  Demo('6.6', 'GridView', '6.6 count/extent · 两个Delegate', _d66Grid),
  Demo('2.4', '命名路由迷你App', '2.4 路由表 · pushNamed传参 · pop回值', _d24Routes),
  Demo('EX6', '📖 通讯录索引', 'ListView分组 + 索引条（点了没反应？）', _ex6Contacts),
  Demo('EX7', '🛒 商品瀑布墙', 'GridView.builder（卡片被压扁？）', _ex7Wall),
  Demo('EX8', '📦 路由传参', '点击进详情（参数没收到？）', _ex8Args),
  Demo('EX9', '📮 返回值回传', '选完地址回来（没接住？）', _ex9PopValue),
  Demo('EX10', '📱 底部导航', 'NavigationBar 切页（状态丢了？）', _ex10Tabs),
];
