// ============================================================
// 第9课（第11周）：动画、调试与质量 演示页
// 对应《Flutter实战·第二版》第9章：9.1 动画四角色
//                        + 9.2 动画基本结构三写法
//                        + 9.4 Hero 动画
//                        + 9.6 AnimatedSwitcher
//                        + 9.7 隐式动画过渡组件家族
//                        + DevTools/异常捕获/analyze（讲义三节）
// EX16~EX20 为扩展案例（含故意设计的缺陷，供学生修复练习）
//   症状复现口径：不动/泄漏/错飞/闪烁/静默白屏，详见讲义九 9A 节
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'main.dart' show Demo, sec;

// ============================================================
// 知识页 1：9.1 动画四角色（Animation/Curve/Controller/Tween）
// ============================================================
Widget _d91FourRoles(BuildContext context) {
  return const _FourRolesPage();
}

class _FourRolesPage extends StatefulWidget {
  const _FourRolesPage();
  @override
  State<_FourRolesPage> createState() => _FourRolesPageState();
}

class _FourRolesPageState extends State<_FourRolesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    // 链式组装：Controller(时钟) -> CurvedAnimation(节奏) -> Tween(值域)
    _anim = Tween(begin: 0.0, end: 200.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _anim.addListener(() => setState(() {}));
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed) _c.reverse();
      if (s == AnimationStatus.dismissed) _c.forward();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose(); // 书上原话：路由销毁时必须释放动画资源
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('9.1 四角色：Animation 状态 / Curve 节奏 / Controller 时钟 / Tween 值域'),
        Container(
          height: 220,
          alignment: Alignment.center,
          color: Colors.indigo.shade50,
          child: Container(
            width: _anim.value,
            height: _anim.value,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(_anim.value / 4),
            ),
            child: Text(
              _anim.value.toStringAsFixed(0),
              style: const TextStyle(color: Colors.white, fontSize: 28),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            'Animation<double>：只存值和状态，不管渲染\n'
            'Controller：0.0→1.0 的时钟，forward/reverse/stop；必须 vsync + dispose\n'
            'CurvedAnimation：给时钟套节奏（easeIn 先慢后快 / easeOut 先快后慢）\n'
            'Tween：值域映射 [0,1]→[0,200]，animate(controller) 才能用',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
        sec('lerp 线性插值：动画的数学底座'),
        const Text(
          '返回值 = a + (b-a) × t；Color.lerp/Rect.lerp/Offset.lerp 全是这个套路。\n'
          'Curve 本质就是把 t 换个映射公式（如弹性 bounceIn 会超出 [0,1]）。',
          style: TextStyle(fontSize: 13, height: 1.8, color: Colors.black54),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 2：9.2 三写法（裸写/AnimatedWidget/AnimatedBuilder）+ 状态监听
// ============================================================
Widget _d92ThreeWays(BuildContext context) {
  return const _ThreeWaysPage();
}

class _ThreeWaysPage extends StatefulWidget {
  const _ThreeWaysPage();
  @override
  State<_ThreeWaysPage> createState() => _ThreeWaysPageState();
}

class _ThreeWaysPageState extends State<_ThreeWaysPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _anim;
  String _status = '未启动';

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween(begin: 20.0, end: 160.0).animate(_anim0());
    // 写法一：addListener 里手动 setState
    _anim.addListener(() => setState(() {}));
    // 状态监听：四种 AnimationStatus
    _anim.addStatusListener((s) {
      setState(() {
        _status = {
          AnimationStatus.dismissed: 'dismissed（回到起点）',
          AnimationStatus.forward: 'forward（正向跑）',
          AnimationStatus.reverse: 'reverse（反向跑）',
          AnimationStatus.completed: 'completed（到达终点）',
        }[s]!;
      });
    });
    _c.forward();
  }

  // 帮手：把 curve 组装抽出来
  Animation<double> _anim0() =>
      CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('写法一：addListener + setState（书上图片放大示例）'),
        Container(
          height: 190,
          color: Colors.indigo.shade50,
          alignment: Alignment.center,
          child: Container(
            width: _anim.value,
            height: _anim.value,
            decoration: const BoxDecoration(
              color: Colors.indigo,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
                onPressed: () => _c.forward(), child: const Text('forward')),
            const SizedBox(width: 8),
            ElevatedButton(
                onPressed: () => _c.reverse(), child: const Text('reverse')),
            const SizedBox(width: 8),
            ElevatedButton(
                onPressed: () => _c.stop(), child: const Text('stop')),
            const SizedBox(width: 12),
            Text('状态：$_status', style: const TextStyle(fontSize: 13)),
          ],
        ),
        sec('写法二：AnimatedWidget —— 把 setState 封进组件'),
        const Text(
          'class AnimatedImage extends AnimatedWidget {\n'
          '  build => Image.asset(width: (listenable as Animation).value)\n'
          '}\n'
          'listen 动画帧自动触发自身重建，不再手写 addListener。',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.7),
        ),
        sec('写法三：AnimatedBuilder —— 连渲染都分离（书上最推荐）'),
        const Text(
          'AnimatedBuilder(animation:, child:, builder:(ctx, child){...})\n'
          '三大好处：①不用手动 setState ②重建范围缩到 builder 内，性能更好\n'
          '③可封装复用（FadeTransition/ScaleTransition 就是这么造的）。',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.8),
        ),
        sec('循环动画套路（状态监听实战）'),
        const Text(
          'addStatusListener：completed 时 reverse()，dismissed 时 forward()，\n'
          '一推一拉就成永动机 —— 书上"先放大再缩小再放大"示例。',
          style: TextStyle(fontSize: 13, height: 1.8, color: Colors.black54),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 3：9.4 Hero 共享元素转场
// ============================================================
Widget _d94Hero(BuildContext context) {
  return const _HeroPage();
}

class _HeroPage extends StatelessWidget {
  const _HeroPage();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('9.4 Hero：两页同 tag，元素自己飞过去'),
        const Text(
          '列表页 Hero(tag:"b1", child: 封面) + 详情页同 tag →'
          '\npush/pop 时封面连续过渡（共享元素转场）。',
          style: TextStyle(fontSize: 13, height: 1.8),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: .8,
          children: [
            for (var i = 1; i <= 6; i++)
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _HeroDetail(i),
                    fullscreenDialog: false,
                  ),
                ),
                child: Column(
                  children: [
                    // tag 必须按条目唯一：'b$i'
                    Hero(
                      tag: 'b$i',
                      child: Container(
                        width: 70,
                        height: 90,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.primaries[i % Colors.primaries.length],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('书$i',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('点看大图', style: TextStyle(
                        fontSize: 11, color: Colors.indigo.shade300)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            'tag 配对规则：前后路由 tag 必须相同且唯一。\n'
            '写成固定字符串（如全部 "avatar"）→ 多个 Hero 同屏撞车报错。\n'
            r'套路：tag: "book-$id"（题库第37题考点）。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

class _HeroDetail extends StatelessWidget {
  final int i;
  const _HeroDetail(this.i);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('书$i 详情')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Hero(
            tag: 'b$i',
            child: Container(
              width: 200,
              height: 260,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.primaries[i % Colors.primaries.length],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('书$i 原图',
                  style: const TextStyle(color: Colors.white, fontSize: 24)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('pop 返回时大图飞回小图（Hero 双向生效）',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

// ============================================================
// 知识页 4：9.6 AnimatedSwitcher 新旧切换
// ============================================================
Widget _d96Switcher(BuildContext context) {
  return const _SwitcherPage();
}

class _SwitcherPage extends StatefulWidget {
  const _SwitcherPage();
  @override
  State<_SwitcherPage> createState() => _SwitcherPageState();
}

class _SwitcherPageState extends State<_SwitcherPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('9.6 AnimatedSwitcher：child 变化（类型或 key 不同）→ 新旧同时动画'),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Text(
            '$_count',
            key: ValueKey<int>(_count), // 必须！同类型 child 靠 key 区分新旧
            style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => setState(() => _count++),
          child: const Text('+1（旧数字缩小退场，新数字放大进场）'),
        ),
        sec('原理'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '新 child 播正向动画（forward），旧 child 播反向动画（reverse）\n'
            '→ 默认 FadeTransition：旧的渐隐、新的渐显。\n'
            '因为正反对称，"左出右入"做不到 → 定制 MySlideTransition\n'
            '在 reverse 分支翻转偏移（书上 9.6.2 打破对称性）。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
        sec('AnimatedCrossFade 的区别'),
        const Text('两个子元素间切换 vs AnimatedSwitcher 一个子元素新旧值切换',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
      ],
    );
  }
}

// ============================================================
// 知识页 5：9.7 隐式动画家族（一行换一个过渡）
// ============================================================
Widget _d97Implicit(BuildContext context) {
  return const _ImplicitPage();
}

class _ImplicitPage extends StatefulWidget {
  const _ImplicitPage();
  @override
  State<_ImplicitPage> createState() => _ImplicitPageState();
}

class _ImplicitPageState extends State<_ImplicitPage> {
  bool _big = false;
  bool _show = true;
  double _pad = 8;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('9.7 隐式动画：内部自管 Controller，你只管 setState 换属性'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _big = !_big),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: _big ? 220 : 90,
              height: _big ? 140 : 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _big ? Colors.indigo : Colors.grey,
                borderRadius: BorderRadius.circular(_big ? 24 : 12),
              ),
              child: Text(
                _big ? '再点收回' : '点我展开',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => setState(() => _show = !_show),
              child: const Text('AnimatedOpacity'),
            ),
            const SizedBox(width: 24),
            AnimatedOpacity(
              opacity: _show ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(Icons.star, color: Colors.amber, size: 48),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => setState(() => _pad = _pad == 8 ? 28 : 8),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 400),
            padding: EdgeInsets.all(_pad),
            child: const Text('AnimatedPadding（点我改 padding）'),
          ),
        ),
        sec('家族成员表'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            'AnimatedPadding / AnimatedPositioned(配合Stack) / AnimatedOpacity\n'
            '/ AnimatedAlign / AnimatedContainer / AnimatedDefaultTextStyle\n\n'
            '适用：状态驱动的属性过渡（展开收起、选中高亮）。\n'
            '限制：不能编排多段/循环 → 那是显式动画（Controller+Tween）的事。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 6：DevTools 两板斧 + 性能反例（讲义 3.1/四节）
// ============================================================
Widget _dDevTools(BuildContext context) {
  return const _DevToolsPage();
}

class _DevToolsPage extends StatefulWidget {
  const _DevToolsPage();
  @override
  State<_DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<_DevToolsPage> {
  int _rebuilds = 0;

  @override
  Widget build(BuildContext context) {
    _rebuilds++;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('DevTools 两板斧（讲义 3.1）'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo.shade50,
          child: Text(
            '① Widget Inspector：看真实 Widget 树 + RenderObject 尺寸约束\n'
            '   "撑不满/溢出/对不齐"的终极定位器（第6课已用）\n'
            '② Highlight rebuilds：可视化谁在频繁重建（本页 build 已跑 '
            '$_rebuilds 次）\n'
            '日志：debugPrint 代替 print（长文本自动分行）',
            style: const TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => setState(() {}), // 空刷新，触发整页重建
          child: const Text('点我触发整页 setState（rebuild +1）'),
        ),
        const Text('开着 Highlight rebuilds 点它：整页黄块闪 —— 这就是大范围 setState 的代价',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        sec('讲义四节：三大性能反例'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '反例一：itemBuilder 里 new ScrollController/动画对象 → 每帧新建，上提 State\n'
            '反例二：大范围 setState 整页重建 → 缩小状态粒度 / const 构造\n'
            '反例三：列表大图没设 cacheWidth → 解码原始尺寸占内存\n\n'
            '修复路径：先量化（rebuild 高亮/帧率图），再动手，不凭感觉优化。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 7：异常捕获 + analyze/format（讲义 3.2/3.3）
// ============================================================
Widget _dErrCatch(BuildContext context) {
  return const _ErrCatchPage();
}

class _ErrCatchPage extends StatefulWidget {
  const _ErrCatchPage();
  @override
  State<_ErrCatchPage> createState() => _ErrCatchPageState();
}

class _ErrCatchPageState extends State<_ErrCatchPage> {
  final List<String> _log = [];

  void _demo() {
    setState(() => _log.clear());
    // ① 同步框架异常：FlutterError.onError
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      _log.add('FlutterError 接住：${details.exception.toString().characters.take(40)}');
      original?.call(details); // 交回框架继续处理（控制台仍打印）
    };
    // ② 异步/平台异常：PlatformDispatcher.instance.onError（此处只演示挂载点）
    _log.add('PlatformDispatcher.instance.onError：应用启动时挂一次');
    _log.add('runZonedGuarded：包住 runApp 统一上报');
    // ③ 制造一个真实的异步异常
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      throw Exception('模拟：网络请求超时');
    }).catchError((e) {
      setState(() => _log.add('catchError 接住异步异常：$e'));
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('3.2 异常捕获三层（讲义）'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo.shade50,
          child: const Text(
            '① FlutterError.onError —— 框架同步异常（build 抛错）\n'
            '② PlatformDispatcher.instance.onError —— 未捕获异步/平台异常\n'
            '③ runZonedGuarded —— 自定义 zone 内兜底，统一上报\n'
            '本课先"接住并打印"，第11课升级为"错误分类上报"。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _demo,
          child: const Text('演示：抛一个异步异常并接住'),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.black87, borderRadius: BorderRadius.circular(8)),
          child: ListView(
            children: [
              for (final l in _log)
                Text(l,
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontFamily: 'monospace')),
            ],
          ),
        ),
        sec('3.3 提交两件套（红线）'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            'flutter analyze —— error 必须清零（warning/info 尽量清）\n'
            'dart format . —— 一键统一格式\n'
            '从本课起所有代码作业硬性检查；期末验收列入检查清单。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// EX16~EX20：第9课扩展案例（含故意缺陷，修复练习素材）
// ============================================================

// ---------- EX16 隐式动画（缺陷：FadeTransition 永远不出现——controller 忘了 forward） ----------
Widget _ex16Fade(BuildContext context) {
  return const _Ex16Page();
}

class _Ex16Page extends StatefulWidget {
  const _Ex16Page();
  @override
  State<_Ex16Page> createState() => _Ex16PageState();
}

class _Ex16PageState extends State<_Ex16Page>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  String _hint = '点按钮让星星出来';

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    // 缺陷：只创建了 controller，忘了 forward() —— value 恒 0，星星永远透明
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX16 渐显星星：点了按钮星星也不出来？'),
        Container(
          height: 200,
          color: Colors.indigo.shade50,
          alignment: Alignment.center,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _c, curve: Curves.easeIn),
            child: const Icon(Icons.star,
                color: Colors.amber, size: 96),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => setState(() => _hint = '按了，但还是没有星星…（为什么？）'),
              child: const Text('点我让星星渐显'),
            ),
          ],
        ),
        Text(_hint, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '病根提示：题库第40题——FadeTransition 不透明度恒 0，\n'
            '首查 controller 是否 forward() 启动。创建了时钟不等于按了开关。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ---------- EX17 控制器泄漏（缺陷：dispose 漏掉 controller.dispose） ----------
Widget _ex17Leak(BuildContext context) {
  return const _Ex17Page();
}

class _Ex17Page extends StatefulWidget {
  const _Ex17Page();
  @override
  State<_Ex17Page> createState() => _Ex17PageState();
}

class _Ex17PageState extends State<_Ex17Page>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _c.addListener(() {
      if (_c.value > .98 && _ticks < 1) setState(() => _ticks = 1);
    });
    _c.forward();
  }

  // 缺陷：没有重写 dispose 释放 _c —— 离开页面后 controller 还在 ticking
  // （故意不写 dispose 方法体，供学生补上 _c.dispose()）

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX17 心跳小球：切走再切回来，控制台骂人？'),
        Container(
          height: 180,
          color: Colors.indigo.shade50,
          alignment: Alignment.center,
          child: ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.2)
                .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
            child: const Icon(Icons.favorite,
                color: Colors.redAccent, size: 80),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _c.forward();
                setState(() {});
              },
              child: const Text('再跳一次'),
            ),
          ],
        ),
        const Text('用上一页/下一页切走再切回，反复几次',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '病根提示：题库第32题——dispose 漏掉 c.dispose()，\n'
            '"AnimationController is still ticking after dispose" 警告 + 内存泄漏。\n'
            'Controller 是资源，谁创建谁释放。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ---------- EX18 Hero 撞车（缺陷：所有条目用同一个固定 tag） ----------
Widget _ex18HeroCrash(BuildContext context) {
  return const _Ex18Page();
}

class _Ex18Page extends StatelessWidget {
  const _Ex18Page();

  static const _colors = [
    Color(0xFFEF9A9A), Color(0xFFA5D6A7), Color(0xFF90CAF9),
    Color(0xFFCE93D8), Color(0xFFFFCC80), Color(0xFF80DEEA),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX18 商品墙：点任意卡片，飞出来的总是错的？'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: .8,
          children: [
            for (var i = 0; i < 6; i++)
              InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _Ex18Detail(i))),
                child: Column(
                  children: [
                    // 缺陷：所有条目共用固定 tag 'p' —— 同屏多个同 tag Hero
                    Hero(
                      tag: 'p',
                      child: Container(
                        width: 70,
                        height: 90,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _colors[i],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('商品${i + 1}',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('点我', style: TextStyle(
                        fontSize: 11, color: Colors.indigo.shade300)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            r'病根提示：题库第37题——tag 必须按条目唯一（"book-$id"）。' '\n'
            '同屏出现两个相同 tag 的 Hero，框架没法配对：\n'
            '轻则飞错目标（点的 A 飞出 B），重则直接抛异常。\n'
            '修法：tag 里带上条目编号，详情页用同一个值。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

class _Ex18Detail extends StatelessWidget {
  final int i;
  const _Ex18Detail(this.i);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('商品${i + 1} 详情')),
      body: Center(
        child: Hero(
          tag: 'p',
          child: Container(
            width: 200,
            height: 260,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _Ex18Page._colors[i],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('原图', style: TextStyle(color: Colors.white, fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

// ---------- EX19 列表闪烁（缺陷：itemBuilder 里每次 new AnimationController） ----------
Widget _ex19Flicker(BuildContext context) {
  return const _Ex19Page();
}

class _Ex19Page extends StatefulWidget {
  const _Ex19Page();
  @override
  State<_Ex19Page> createState() => _Ex19PageState();
}

class _Ex19PageState extends State<_Ex19Page> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX19 骨架屏列表：滚一下就闪烁 + 越用越卡？'),
        const Text(
            '症状：上下滚动列表，灰色的"骨架"条忽明忽暗闪；'
            '滚得越久越卡，像滚雪球。',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 30,
          itemBuilder: (_, i) => _Ex19Item(index: i),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '病根提示：题库第31题——itemBuilder 每帧 new AnimationController，\n'
            '闪烁与泄漏，应上提到 State。\n'
            'itemBuilder 是"滚到才建、滚出就丢"的工厂，重对象放里面=灾难。\n'
            '修法：controller/animation 声明为 State 成员，initState 建一次。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ---------- EX19 的 item：缺陷本体在这里 ----------
// 缺陷：controller 声明在 State 里没错，但每个 item 都是独立 StatefulWidget，
// 30 个 item = 30 个 controller 常驻 + itemBuilder 每次滚回来重建 State 再建一个 ——
// 滚动时反复创建/丢弃动画对象，闪烁 + 泄漏 + 卡顿（题库第31题的活体标本）
class _Ex19Item extends StatefulWidget {
  final int index;
  const _Ex19Item({required this.index});
  @override
  State<_Ex19Item> createState() => _Ex19ItemState();
}

class _Ex19ItemState extends State<_Ex19Item>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // 每建一个 item 就 new 一个 controller —— 正确做法是整页共享一个
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          FadeTransition(
            opacity: _c,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeTransition(
                  opacity: _c,
                  child: Container(
                    height: 14,
                    width: 160 + (i % 4) * 40.0,
                    color: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: _c,
                  child: Container(
                    height: 12,
                    width: 100 + (i % 3) * 30.0,
                    color: Colors.grey.shade200,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- EX20 静默白屏（缺陷：全局异常只 print 不处理，用户看到白屏） ----------
Widget _ex20White(BuildContext context) {
  return const _Ex20Page();
}

class _Ex20Page extends StatefulWidget {
  const _Ex20Page();
  @override
  State<_Ex20Page> createState() => _Ex20PageState();
}

class _Ex20PageState extends State<_Ex20Page> {
  String _state = 'loading';
  Widget? _body;

  Future<void> _load() async {
    setState(() { _state = 'loading'; _body = null; });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      // 模拟断网抛异常
      await Future<void>.delayed(const Duration(milliseconds: 200));
      throw Exception('SocketException: Failed host lookup: api.demo');
    } on Exception catch (e) {
      // 缺陷：异常只 print，界面没有任何反馈 —— 用户盯着转圈/白屏干等
      // ignore: avoid_print
      print('load failed: $e');
      // 忘了 setState，也忘了把错误显示到界面上
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX20 断网测试：接口挂了，页面就永远转圈？'),
        Container(
          height: 220,
          color: Colors.indigo.shade50,
          alignment: Alignment.center,
          child: _body ??
              (_state == 'loading'
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('加载中…（断网时将永远停在这）',
                            style: TextStyle(color: Colors.black54)),
                      ],
                    )
                  : const SizedBox.shrink()),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _load,
              child: const Text('模拟断网加载'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: const Text(
            '病根提示：题库第43题——全局异常接住后只 print 不处理，\n'
            '问题被掩盖。正确姿势：接住 → setState 切到错误态 →\n'
            '界面内错误条 + 重试按钮；为第11课"错误分类上报"埋点。\n'
            '四段式记录：现象（永远转圈）→ 工具（日志/断点）→\n'
            '原因（catch 里没反馈）→ 修复（错误态 UI + 重试）。',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 注册表
// ============================================================
final m9Demos = <Demo>[
  Demo('9.1', '动画四角色', '9.1 Animation/Curve/Controller/Tween + lerp', _d91FourRoles),
  Demo('9.2', '动画三写法', '9.2 裸写/AnimatedWidget/AnimatedBuilder + 状态监听', _d92ThreeWays),
  Demo('9.4', 'Hero 转场', '9.4 两页同 tag 元素飞越 · tag 唯一性', _d94Hero),
  Demo('9.6', 'AnimatedSwitcher', '9.6 新旧切换 · 正反对称 · key 缺一不可', _d96Switcher),
  Demo('9.7', '隐式动画家族', '9.7 AnimatedContainer/Opacity/Padding 一行过渡', _d97Implicit),
  Demo('DEV', 'DevTools 两板斧', '3.1 Inspector · rebuild 高亮 · 三大性能反例', _dDevTools),
  Demo('ERR', '异常捕获', '3.2 FlutterError/PlatformDispatcher · 3.3 analyze 两件套', _dErrCatch),
  Demo('EX16', '⭐ 渐显星星', '点了星星也不出来？（时钟没按开关）', _ex16Fade),
  Demo('EX17', '❤️ 心跳小球', '切走切回控制台骂人？（资源没释放）', _ex17Leak),
  Demo('EX18', '🛍️ 商品墙', '飞出来的总是错的？（tag 撞车）', _ex18HeroCrash),
  Demo('EX19', '💀 骨架屏', '滚一下就闪越滚越卡？（工厂里造重物）', _ex19Flicker),
  Demo('EX20', '⚪ 断网白屏', '接口挂了永远转圈？（异常只 print）', _ex20White),
];
