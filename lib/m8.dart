// ============================================================
// 第8课（第10周）：交互与状态管理 演示页
// 对应《Flutter实战·第二版》：8.2 手势识别 + 8.3 事件机制/HitTestBehavior
//                        + 8.6 通知Notification + 2.3 状态管理(Tapbox三兄弟)
//                        + 7.3 跨组件状态共享 Provider(购物车/Consumer/listen优化)
//                        + 表单校验(Form/validator)
// EX11~EX15 为扩展案例（含故意设计的缺陷，供学生修复练习）
//   症状复现口径：点不动/不刷新/不校验/不冒泡，详见讲义八 8A 节
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import 'main.dart' show Demo, sec;

// ============================================================
// 知识页 1：8.2 GestureDetector 三板斧（点击/双击/长按 + 拖动）
// ============================================================
Widget _d82Gesture(BuildContext context) {
  return const _GesturePage();
}

class _GesturePage extends StatefulWidget {
  const _GesturePage();
  @override
  State<_GesturePage> createState() => _GesturePageState();
}

class _GesturePageState extends State<_GesturePage> {
  String _op = 'No Gesture detected!';
  double _top = 40, _left = 20;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('8.2 GestureDetector：点击 / 双击 / 长按'),
        Container(
          alignment: Alignment.center,
          color: Colors.blue,
          height: 80,
          child: Text(_op, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
                onPressed: () => setState(() => _op = 'Tap（点击）'),
                child: const Text('模拟 Tap')),
            OutlinedButton(
                onPressed: () => setState(() => _op = 'DoubleTap（双击）'),
                child: const Text('模拟 DoubleTap')),
            OutlinedButton(
                onPressed: () => setState(() => _op = 'LongPress（长按）'),
                child: const Text('模拟 LongPress')),
          ],
        ),
        const Text(
          '书上注意点：同时监听 onTap 和 onDoubleTap 时，tap 会有约 200ms 延时'
          '——框架要等一等，看你会不会再点一下。只监听 onTap 则无延时。',
          style: TextStyle(fontSize: 12, color: Colors.indigo, height: 1.6),
        ),
        sec('拖动：onPanUpdate 的 delta 累加（书上字母A示例）'),
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              Positioned(
                top: _top,
                left: _left,
                child: GestureDetector(
                  onPanUpdate: (e) => setState(() {
                    _left += e.delta.dx;
                    _top += e.delta.dy;
                  }),
                  child: const CircleAvatar(child: Text('A')),
                ),
              ),
            ],
          ),
        ),
        const Text('DragUpdateDetails.delta = 本次滑动的增量；globalPosition = 按下点相对屏幕原点。拖我试试。',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

// ============================================================
// 知识页 2：8.2 缩放 + GestureRecognizer（TextSpan.recognizer 点我变色）
// ============================================================
Widget _d82Recognizer(BuildContext context) {
  return const _RecognizerPage();
}

class _RecognizerPage extends StatefulWidget {
  const _RecognizerPage();
  @override
  State<_RecognizerPage> createState() => _RecognizerPageState();
}

class _RecognizerPageState extends State<_RecognizerPage> {
  final TapGestureRecognizer _tapRecognizer = TapGestureRecognizer();
  bool _toggle = false;
  double _size = 60;

  @override
  void dispose() {
    _tapRecognizer.dispose(); // 书上强调：一定要 dispose 释放资源（内部计时器）
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('8.2.2 GestureRecognizer：富文本局部点击'),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '你好世界 你好世界 你好世界\n'),
            TextSpan(
              text: '点我变色',
              style: TextStyle(fontSize: 26, color: _toggle ? Colors.blue : Colors.red),
              recognizer: _tapRecognizer
                ..onTap = () => setState(() => _toggle = !_toggle),
            ),
            const TextSpan(text: ' 你好世界'),
          ]),
        ),
        const Text('TextSpan 不是 Widget，不能包 GestureDetector；recognizer 属性接 TapGestureRecognizer。',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        sec('onScaleUpdate 双指缩放（clamp 限 0.8~3 倍）'),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onScaleUpdate: (d) => setState(() => _size = 60 * d.scale.clamp(.8, 3.0)),
            child: Container(
              width: _size,
              height: _size,
              color: Colors.teal,
              alignment: Alignment.center,
              child: const Text('捏', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('手机上双指捏合可缩放；浏览器演示按住 Shift 拖模拟。ScaleUpdateDetails.scale 是缩放倍数。',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

// ============================================================
// 知识页 3：8.3 命中测试 + HitTestBehavior 三态
// ============================================================
Widget _d83HitTest(BuildContext context) {
  return const _HitTestPage();
}

class _HitTestPage extends StatefulWidget {
  const _HitTestPage();
  @override
  State<_HitTestPage> createState() => _HitTestPageState();
}

class _HitTestPageState extends State<_HitTestPage> {
  String _log = '';

  void log(String s) => setState(() => _log = '$s\n$_log');

  @override
  Widget build(BuildContext context) {
    Widget layer(String name, Color c) => Listener(
          behavior: HitTestBehavior.deferToChild, // 两层都 deferToChild，都可命中
          onPointerDown: (e) => log('[$name] 收到 PointerDown'),
          child: Container(width: 160, height: 120, color: c.withValues(alpha: 0.5)),
        );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('8.3 命中测试：深度优先、子先于父'),
        const Text(
          '书上结论：命中测试按渲染树深度优先进行，子组件先于父组件加入 HitTestResult，'
          '事件分发从前往后遍历——所以"父子同监听，子先响应"。',
          style: TextStyle(fontSize: 13, height: 1.6, color: Colors.indigo),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // 底层先放，上层后放：兄弟倒序遍历，上层先命中
            Align(alignment: Alignment.centerLeft, child: layer('底层·蓝', Colors.blue)),
            Align(
              alignment: Alignment.centerRight,
              child: Listener(
                onPointerDown: (e) => log('[上层·绿] 收到 PointerDown（叠了蓝的边也先我）'),
                child: Container(
                  width: 160,
                  height: 120,
                  color: Colors.green.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('点重叠区：只有上层绿响应——兄弟遍历倒序，命中即停。点日志区可多次观察。',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        sec('日志'),
        Container(
          height: 120,
          color: Colors.black87,
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: Text(_log.isEmpty ? '（点击上面的色块）' : _log,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace')),
          ),
        ),
        sec('HitTestBehavior 三态（书上表格）'),
        const Text(
          'deferToChild：子命中我才命中（默认）\n'
          'opaque：必然命中且 hitTest 返回 true（挡住下层）\n'
          'translucent：必然命中但放行下层（水印层就用它）',
          style: TextStyle(fontSize: 13, height: 1.8),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 4：8.6 通知 Notification 冒泡
// ============================================================
class _MyNotification extends Notification {
  _MyNotification(this.msg);
  final String msg;
}

Widget _d86Notification(BuildContext context) {
  return const _NotifyPage();
}

class _NotifyPage extends StatefulWidget {
  const _NotifyPage();
  @override
  State<_NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<_NotifyPage> {
  String _msg = '';
  int _scrollCount = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('8.6 自定义通知冒泡（书上 MyNotification 例子）'),
        const Text('点按钮 → 通知从按钮处沿树向上冒泡 → 根部 NotificationListener 接住显示。',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 8),
        NotificationListener<_MyNotification>(
          onNotification: (n) {
            setState(() => _msg += '${n.msg} ');
            return true; // true = 阻止继续冒泡
          },
          child: Builder(
            // 书上坑：必须用 Builder 拿按钮处的 context，根 context 分发不到子树
            builder: (ctx) => ElevatedButton(
              onPressed: () => _MyNotification('Hi').dispatch(ctx),
              child: const Text('Send Notification'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('收到：$_msg', style: const TextStyle(fontSize: 15)),
        sec('滚动通知：NotificationListener<ScrollNotification>'),
        const SizedBox(height: 4),
        Container(
          height: 160,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollUpdateNotification) {
                setState(() => _scrollCount++);
              }
              return false;
            },
            child: ListView.builder(
              itemCount: 50,
              itemBuilder: (_, i) => ListTile(dense: true, title: Text('第 $i 行')),
            ),
          ),
        ),
        Text('滚动通知触发次数：$_scrollCount（Scrollbar 就是这么监听滚动条位置的）',
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

// ============================================================
// 知识页 5：2.3 状态管理 Tapbox 三兄弟
// ============================================================
Widget _d23Tapbox(BuildContext context) {
  return const _TapboxPage();
}

class _TapboxPage extends StatelessWidget {
  const _TapboxPage();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        Text('书 2.3 节官方三原则：', style: TextStyle(fontSize: 13)),
        Text(
          '· 用户数据（选中态/滑块位置）→ 父 Widget 管\n'
          '· 界面外观（颜色/动画）→ Widget 自己管\n'
          '· 多 Widget 共享 → 公共父级管\n'
          '· 拿不准 → 首选父级管（灵活更重要）',
          style: TextStyle(fontSize: 13, height: 1.8, color: Colors.indigo),
        ),
        SizedBox(height: 12),
        _TapboxA(),
        SizedBox(height: 12),
        _ParentB(),
        SizedBox(height: 12),
        _ParentC(),
      ],
    );
  }
}

// A：自管状态
class _TapboxA extends StatefulWidget {
  const _TapboxA();
  @override
  State<_TapboxA> createState() => _TapboxAState();
}

class _TapboxAState extends State<_TapboxA> {
  bool _active = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _active = !_active),
      child: Container(
        height: 90,
        alignment: Alignment.center,
        color: _active ? Colors.lightGreen.shade700 : Colors.grey.shade600,
        child: Text('A·自管状态：${_active ? "Active" : "Inactive"}',
            style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }
}

// B：父管子状态（子是无状态，回调上报）
class _ParentB extends StatefulWidget {
  const _ParentB();
  @override
  State<_ParentB> createState() => _ParentBState();
}

class _ParentBState extends State<_ParentB> {
  bool _active = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _active = !_active),
      child: Container(
        height: 90,
        alignment: Alignment.center,
        color: _active ? Colors.lightGreen.shade700 : Colors.grey.shade600,
        child: Text('B·父管子状态：${_active ? "Active" : "Inactive"}（子Stateless+回调）',
            style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }
}

// C：混合管理（高亮 _highlight 自管、Active 父管）
class _ParentC extends StatefulWidget {
  const _ParentC();
  @override
  State<_ParentC> createState() => _ParentCState();
}

class _ParentCState extends State<_ParentC> {
  bool _active = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _active = !_active),
      child: Container(
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _active ? Colors.lightGreen.shade700 : Colors.grey.shade600,
          border: _active ? Border.all(color: Colors.teal.shade700, width: 6) : null,
        ),
        child: Text('C·混合：${_active ? "Active+高亮边框" : "Inactive"}（高亮自管/Active父管）',
            style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }
}

// ============================================================
// 知识页 6：7.3 Provider 购物车（书上 CartModel 完整版）
// ============================================================
class _Item {
  _Item(this.price, this.count);
  final double price;
  final int count;
}

class _CartModel extends ChangeNotifier {
  final List<_Item> _items = [];
  int get count => _items.length;
  double get totalPrice => _items.fold(0, (v, i) => v + i.count * i.price);
  void add(_Item item) {
    _items.add(item);
    notifyListeners(); // 书上：唯一能从外部改变购物车后通知订阅者重建的口子
  }
}

Widget _d73Cart(BuildContext context) {
  return ChangeNotifierProvider(
    create: (_) => _CartModel(),
    child: const _CartPage(),
  );
}

class _CartPage extends StatelessWidget {
  const _CartPage();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('7.3 Provider 购物车（书上原型）'),
        const Text('三件套：①Model 继承 ChangeNotifier，变化处 notifyListeners()；'
            '②顶层 ChangeNotifierProvider 注入；③消费端 watch（监听重建）/ read（只读调用）。',
            style: TextStyle(fontSize: 13, height: 1.6)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              // watch：依赖重建——总价每次 add 后刷新
              Text('总价：${context.watch<_CartModel>().totalPrice}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text('共 ${context.watch<_CartModel>().count} 件',
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 12),
              // read：事件回调里只读调用，不建立依赖
              ElevatedButton(
                onPressed: () => context.read<_CartModel>().add(_Item(20.0, 1)),
                child: const Text('添加商品（20元×1）'),
              ),
              const SizedBox(height: 8),
              const Text('口诀：界面 watch、动作 read。\n'
                  '书 7.3.3 性能优化讲的就是这个：listen:false 不建立依赖，按钮不重建。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 知识页 7：表单校验（Form + GlobalKey + validator）
// ============================================================
Widget _dForm(BuildContext context) {
  return const _FormPage();
}

class _FormPage extends StatefulWidget {
  const _FormPage();
  @override
  State<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<_FormPage> {
  final _formKey = GlobalKey<FormState>();
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          sec('表单校验三件套（讲义/书上同构）'),
          TextFormField(
            decoration: const InputDecoration(labelText: '学号', hintText: '10位数字'),
            validator: (v) => (v == null || v.length != 10) ? '学号应为10位' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码', hintText: '不少于6位'),
            validator: (v) => (v == null || v.length < 6) ? '密码不少于6位' : null,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                setState(() => _result = '校验通过 ✓ 可以提交');
              } else {
                setState(() => _result = '校验未通过 ✗ 错误见输入框下方');
              }
            },
            child: const Text('提交'),
          ),
          const SizedBox(height: 8),
          Text(_result, style: TextStyle(color: _result.contains('✓') ? Colors.green : Colors.red)),
          const Text('validator 返回 null = 通过；返回字符串 = errorText。validate() 只触发"已注册到 Form 的字段"。',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

// ============================================================
// EX11~EX15：第8课扩展案例（含故意缺陷，修复练习素材）
// ============================================================

// ---------- EX11 手势面板（缺陷：onTap+onDoubleTap 并存，点击有 200ms 延迟误以为卡） ----------
Widget _ex11Gesture(BuildContext context) {
  return const _Ex11Page();
}

class _Ex11Page extends StatefulWidget {
  const _Ex11Page();
  @override
  State<_Ex11Page> createState() => _Ex11PageState();
}

class _Ex11PageState extends State<_Ex11Page> {
  int _tapCount = 0;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX11 手势计数器'),
        const Text('任务：点一下计数 +1。可你每次点完都要愣一下才 +1，感觉"卡卡的"。',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 20),
        GestureDetector(
          // 缺陷：同时挂了 onTap 和 onDoubleTap，框架等 200ms 判断是否双击
          onTap: () => setState(() => _tapCount += 1),
          onDoubleTap: () => setState(() => _tapCount += 10),
          child: Container(
            height: 140,
            alignment: Alignment.center,
            color: Colors.orange.shade200,
            child: Text('点我 +1（双击+10）：$_tapCount',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        const Text('需求里根本不需要双击。病根提示：书上 8.2.1 开头那条"注意"。',
            style: TextStyle(fontSize: 12, color: Colors.black38)),
      ],
    );
  }
}

// ---------- EX12 图标按钮（缺陷：Icon 命中区域透明，点了没反应） ----------
Widget _ex12Icon(BuildContext context) {
  return const _Ex12Page();
}

class _Ex12Page extends StatefulWidget {
  const _Ex12Page();
  @override
  State<_Ex12Page> createState() => _Ex12PageState();
}

class _Ex12PageState extends State<_Ex12Page> {
  int _likes = 0;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX12 点赞图标'),
        const Text('任务：点星星点赞 +1。可星星四周"空气区"点了没反应，只有正正好好点中笔画才有反应。',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 20),
        GestureDetector(
          // 缺陷：默认 deferToChild，Icon 的绘制区域"镂空"，命中区域透明
          onTap: () => setState(() => _likes++),
          child: const Icon(Icons.star, size: 96, color: Colors.amber),
        ),
        const SizedBox(height: 12),
        Text('点赞：$_likes', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text('病根提示：题库第42题——HitTestBehavior.opaque。另：也可以换 InkWell 顺便要涟漪。',
            style: TextStyle(fontSize: 12, color: Colors.black38)),
      ],
    );
  }
}

// ---------- EX13 跨页角标（缺陷：notifyListeners 忘了调，界面不刷新） ----------
Widget _ex13Badge(BuildContext context) {
  return ChangeNotifierProvider(
    create: (_) => _Ex13Cart(),
    child: const _Ex13Page(),
  );
}

class _Ex13Cart extends ChangeNotifier {
  int count = 0;
  void add() {
    count++;
    // 缺陷：忘了 notifyListeners() —— 数据变了，没人知道
  }
}

class _Ex13Page extends StatelessWidget {
  const _Ex13Page();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX13 购物车角标'),
        const Text('任务：点"加入购物车"，顶部角标和总价都要刷新。可点了没任何变化——数字明明变了。',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🛒 角标'),
              Badge(
                label: Text('${context.watch<_Ex13Cart>().count}'),
                isLabelVisible: context.watch<_Ex13Cart>().count > 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.read<_Ex13Cart>().add(),
          child: const Text('加入购物车'),
        ),
        const SizedBox(height: 12),
        const Text('病根提示：题库第28题——CartModel.add 内未调用 notifyListeners，界面不动。watch 的人还在等通知。',
            style: TextStyle(fontSize: 12, color: Colors.black38)),
      ],
    );
  }
}

// ---------- EX14 表单（缺陷：TextField 没包进 Form/没用 TextFormField，校验不生效） ----------
Widget _ex14Form(BuildContext context) {
  return const _Ex14Page();
}

class _Ex14PageState extends State<_Ex14Page> {
  final _formKey = GlobalKey<FormState>();
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX14 注册表单'),
        const Text('任务：邮箱必填且带@。点提交明明空着也提示"提交成功"，校验形同虚设。',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        Form(
          key: _formKey,
          child: Column(
            children: [
              // 缺陷：用的是 TextField 而不是 TextFormField——根本没注册进 Form
              TextField(
                decoration: const InputDecoration(labelText: '邮箱', hintText: '含@的邮箱'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            final ok = _formKey.currentState!.validate();
            setState(() => _result = ok ? '提交成功' : '校验失败');
          },
          child: const Text('提交'),
        ),
        const SizedBox(height: 8),
        Text(_result, style: TextStyle(color: _result == '提交成功' ? Colors.green : Colors.red)),
        const Text('病根提示：validate() 只校验"注册进 Form 的 FormField"；TextField 不是 FormField。换 TextFormField 并补 validator。',
            style: TextStyle(fontSize: 12, color: Colors.black38)),
      ],
    );
  }
}

class _Ex14Page extends StatefulWidget {
  const _Ex14Page();
  @override
  State<_Ex14Page> createState() => _Ex14PageState();
}

// ---------- EX15 手势冲突（缺陷：拖动和点击同挂，点击常被拖动抢走） ----------
Widget _ex15Conflict(BuildContext context) {
  return const _Ex15Page();
}

class _Ex15PageState extends State<_Ex15Page> {
  double _top = 60;
  int _taps = 0;
  final String _hint = '点它 +1，或拖动它移动';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sec('EX15 拖拽小球'),
        const Text('任务：点小球计数 +1，也可以拖动小球。可点的时候小球总是"先不动再突然跳一下"，或者干脆被当成拖动。',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 8),
        Text('点击次数：$_taps', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: Stack(
            children: [
              Positioned(
                top: _top,
                left: 60,
                child: GestureDetector(
                  // 缺陷：onPanUpdate 与 onTap 同挂——pan 手势竞技场里太强势，
                  // 手指微动即被判为拖动，tap 频频落空（书上 8.4 手势冲突）
                  onPanUpdate: (e) => setState(() => _top += e.delta.dy),
                  onTap: () => setState(() => _taps++),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.pink.shade300,
                    child: const Text('🧶', style: TextStyle(fontSize: 26)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(_hint, style: const TextStyle(fontSize: 12, color: Colors.black38)),
        const Text('病根提示：书上 8.4 手势竞争——pan 与 tap 在手势竞技场里竞争，指针一动 pan 就占先。'
            '修复思路：单一方向 onVerticalDragUpdate 也要想清楚；或 tap 用 onTapUp 兜底；最稳是拆成"点按区+拖动手柄"两个区域。',
            style: TextStyle(fontSize: 12, color: Colors.black38, height: 1.6)),
      ],
    );
  }
}

class _Ex15Page extends StatefulWidget {
  const _Ex15Page();
  @override
  State<_Ex15Page> createState() => _Ex15PageState();
}

// ---------- 注册表 ----------
final m8Demos = <Demo>[
  Demo('8.2a', '手势三板斧', '8.2 点击/双击/长按 · 200ms延时 · 拖动delta', _d82Gesture),
  Demo('8.2b', 'Recognizer与缩放', '8.2.2 TextSpan.recognizer · dispose · onScaleUpdate', _d82Recognizer),
  Demo('8.3', '命中测试', '8.3 深度优先 · 子先于父 · HitTestBehavior三态', _d83HitTest),
  Demo('8.6', '通知冒泡', '8.6 MyNotification · Builder取context · 滚动通知', _d86Notification),
  Demo('2.3', 'Tapbox三兄弟', '2.3 自管/父管/混合 · 官方选型三原则', _d23Tapbox),
  Demo('7.3', 'Provider购物车', '7.3 CartModel · watch/read · notifyListeners', _d73Cart),
  Demo('FORM', '表单校验', 'Form+GlobalKey+validator · 学号/密码双校验', _dForm),
  Demo('EX11', '👆 手势计数器', '点了要愣一下？（200ms 延时之谜）', _ex11Gesture),
  Demo('EX12', '⭐ 点赞图标', '空气区点不动？（命中区域透明）', _ex12Icon),
  Demo('EX13', '🛒 购物车角标', '数据变了界面不动？（通知没发）', _ex13Badge),
  Demo('EX14', '📧 注册表单', '空着也提交成功？（校验没挂上）', _ex14Form),
  Demo('EX15', '🧶 拖拽小球', '点击老被拖动抢走？（手势竞技场）', _ex15Conflict),
];
