import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'm10.dart';
import 'm7.dart';
import 'm8.dart';
import 'm9.dart';

void main() {
  // 支持 ?d=3.1.1 直达指定演示页（截图、逐字稿嵌链接都靠它）
  runApp(FlutterBookDemosApp(initialDemoId: Uri.base.queryParameters['d']));
}

/// 教科书《Flutter实战》第3/4/5章示例演示集
/// 每个演示页对应书上一个小节，按今天第6课讲课顺序排列
class FlutterBookDemosApp extends StatelessWidget {
  final String? initialDemoId;
  const FlutterBookDemosApp({super.key, this.initialDemoId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '教科书示例演示 · 第6课',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: DemoHome(initialDemoId: initialDemoId),
    );
  }
}

class Demo {
  final String id;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
  const Demo(this.id, this.title, this.subtitle, this.builder);
}

class DemoHome extends StatefulWidget {
  final String? initialDemoId;
  const DemoHome({super.key, this.initialDemoId});
  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // ?d=3.1.1 直达指定页；找不到就落回第 0 页
    final i = demos.indexWhere((d) => d.id == widget.initialDemoId);
    if (i >= 0) _index = i;
  }

  static final demos = [
    Demo('3.1.1', 'Text 基础', '3.1.1 textAlign / maxLines / overflow', _d31Text),
    Demo('3.1.2', 'TextStyle', '3.1.2 颜色/字号/行高/装饰线', _d312Style),
    Demo('3.1.3', 'TextSpan 富文本', '3.1.3 Text.rich 一段文字多种样式', _d313Span),
    Demo(
      '3.1.4',
      'DefaultTextStyle',
      '3.1.4 样式继承与 inherit:false',
      _d314Default,
    ),
    Demo('3.2', '按钮家族', '3.2 四种按钮 + .icon 构造 + 禁用态', _d32Buttons),
    Demo('3.3.1', '图片 fit 七种', '3.3.1 BoxFit 全家福对比', _d331ImageFit),
    Demo(
      '3.3.1b',
      '图片混合与平铺',
      '3.3.1 color+blendMode / repeat',
      _d331bImageBlend,
    ),
    Demo('3.3.2', 'Icon 字体图标', '3.3.2 MaterialIcons 与图标本质', _d332Icon),
    Demo('3.5.1', 'TextField', '3.5.1 controller取值/密码框/焦点控制', _d351Input),
    Demo('3.6', '进度指示器', '3.6 模糊/精确 × 线/圆 + 自定义尺寸', _d36Progress),
    Demo(
      '4.2.3',
      'ConstrainedBox/SizedBox',
      '4.2.3 最小高度强制/固定宽高',
      _d423Constraints,
    ),
    Demo('4.2.5', '多重限制', '4.2.5 父子ConstrainedBox谁说了算', _d425Multi),
    Demo(
      '4.2.6',
      'UnconstrainedBox',
      '4.2.6 "去除"父约束+AppBar实例',
      _d426Unconstrained,
    ),
    Demo(
      '4.3',
      'Row/Column',
      '4.3 主轴交叉轴 + textDirection + 特殊情况',
      _d43RowColumn,
    ),
    Demo('4.4', 'Flex/Expanded/Spacer', '4.4 1:2 与 2:1:1 + Spacer原理', _d44Flex),
    Demo('4.5', 'Wrap 流式', '4.5.1 Chip标签云自动折行', _d45Wrap),
    Demo('4.6', 'Stack/Positioned', '4.6 层叠+定位+fit+绘制顺序', _d46Stack),
    Demo(
      '5.4',
      'Container 卡片',
      '5.4.2 渐变/阴影/transform + padding vs margin',
      _d54Container,
    ),
    Demo(
      'EX1',
      '🎯 热区彩蛋 · 点击爆炸',
      'Stack+Positioned 散落 Icon · GestureDetector 点中触发',
      _ex1Boom,
    ),
    Demo(
      'EX2',
      '💰 迷你记账本',
      'Wrap 标签云 + TextSpan 富文本 + Stack 浮动按钮 + Expanded',
      _ex2Ledger,
    ),
    Demo(
      'EX3',
      '📅 打卡日历',
      'Wrap 31 格 Container · GestureDetector setState 切换红蓝',
      _ex3Calendar,
    ),
    Demo(
      'EX4',
      '🎰 抽奖转盘',
      'Stack 多层 Positioned · SweepGradient · AnimatedContainer 旋转',
      _ex4Wheel,
    ),
    Demo(
      'EX5',
      '🔥 朋友圈卡片',
      'Container 卡片 + Wrap 九宫格图 + Text.rich 点赞列表',
      _ex5Moments,
    ),
    ...m7Demos, // 第7课：可滚动组件与多页面结构（6.x + 2.4 路由 + EX6~EX10）
    ...m8Demos, // 第8课：交互与状态管理（8.x 手势/命中/通知 + 2.3 + 7.3 Provider + EX11~EX15）
    ...m9Demos, // 第9课：动画、调试与质量（9.x 动画四角色/三写法/Hero/Switcher/隐式 + DevTools/异常 + EX16~EX20）
    ...m10Demos, // 第10课：本地数据存储（11.1 文件/sp/建库/CRUD/条件查询/迁移/选型 + EX21~EX25）
  ];

  @override
  Widget build(BuildContext context) {
    final demo = demos[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text('${demo.id} ${demo.title}'),
        actions: [
          IconButton(
            tooltip: '上一个',
            onPressed: _index == 0 ? null : () => setState(() => _index--),
            icon: const Icon(Icons.arrow_back),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(child: Text('${_index + 1}/${demos.length}')),
          ),
          IconButton(
            tooltip: '下一个',
            onPressed: _index == demos.length - 1
                ? null
                : () => setState(() => _index++),
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView.builder(
          itemCount: demos.length,
          itemBuilder: (_, i) => ListTile(
            selected: i == _index,
            leading: Text(
              demos[i].id,
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
            ),
            title: Text(demos[i].title, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              demos[i].subtitle,
              style: const TextStyle(fontSize: 11),
            ),
            dense: true,
            onTap: () {
              setState(() => _index = i);
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: demo.builder(context),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                demo.subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 3.1.1 Text 基础 ==========
class _D311Text extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① textAlign 对齐参考系是 Text 自身'),
        Container(
          color: Colors.amber[100],
          width: double.infinity,
          child: const Text(
            'Hello world',
            textAlign: TextAlign.center,
          ), // 内容不足一行时对齐无意义
        ),
        const SizedBox(height: 8),
        Container(
          color: Colors.amber[100],
          width: double.infinity,
          child: Text(
            'Hello world ' * 6,
            textAlign: TextAlign.center,
          ), // 换行后第二行居中
        ),
        sec('② maxLines + overflow 截断'),
        Container(
          color: Colors.amber[100],
          width: double.infinity,
          child: Text(
            'Hello world! I am Jack. ' * 4,
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // 换成 clip 看硬截断
          ),
        ),
        sec('③ textScaleFactor 缩放因子（对照系 fontSize）'),
        Row(
          children: const [
            Text('正常', style: TextStyle(fontSize: 16)),
            SizedBox(width: 12),
            Text(
              '放大',
              textScaler: TextScaler.linear(1.5),
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _d31Text(BuildContext context) => _D311Text();

// ========== 3.1.2 TextStyle ==========
class _D312Style extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 书上完整示例：黄底蓝字下划虚线'),
        Text(
          'Hello world',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 18.0,
            height: 1.2,
            fontFamily: 'Courier',
            background: Paint()..color = Colors.yellow,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dashed,
          ),
        ),
        sec('② height 是因子：行高 = fontSize × height'),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('height=1.0', style: TextStyle(fontSize: 20, height: 1.0)),
            Text('height=2.0', style: TextStyle(fontSize: 20, height: 2.0)),
          ],
        ),
        sec('③ fontSize 与 textScaleFactor 的分工'),
        const Text(
          'fontSize 精确字号（不随系统字体设置变）；\n'
          'textScaleFactor 跟随系统无障碍字体缩放。',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
      ],
    );
  }
}

Widget _d312Style(BuildContext context) => _D312Style();

// ========== 3.1.3 TextSpan ==========
class _D313Span extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 书上示例：一段话里嵌蓝色可点击链接'),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Home: '),
              TextSpan(
                text: 'https://flutterchina.club',
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer(),
              ),
            ],
          ),
        ),
        sec('② TextSpan 可嵌套 children'),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 18, color: Colors.black87),
            children: [
              const TextSpan(text: '移动应用'),
              TextSpan(
                text: '软件开发',
                style: TextStyle(
                  color: Colors.indigo[700],
                  fontWeight: FontWeight.bold,
                ),
                children: const [
                  TextSpan(
                    text: '实训',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ],
          ),
        ),
        sec('③ 本质：Text 是 RichText 的包装'),
        const Text(
          '普通 Text 所有文字只能一种样式；\n'
          '要"一段话多种样式"就必须 Text.rich + TextSpan。',
          style: TextStyle(fontSize: 14, height: 1.6, color: Colors.black54),
        ),
      ],
    );
  }
}

Widget _d313Span(BuildContext context) => _D313Span();

// ========== 3.1.4 DefaultTextStyle ==========
class _D314Default extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 子树默认继承，inherit:false 脱离'),
        DefaultTextStyle(
          style: const TextStyle(color: Colors.red, fontSize: 20.0),
          textAlign: TextAlign.start,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('hello world'),
              const Text('I am Jack'),
              Text(
                'I am Jack',
                style: const TextStyle(inherit: false, color: Colors.grey),
              ),
            ],
          ),
        ),
        sec('② 用途：给一块区域定统一文字基调'),
        const Text(
          'DefaultTextStyle 一处设置、整棵子树生效；\n'
          '主题里的文字样式就是靠它层层下发。',
          style: TextStyle(fontSize: 14, height: 1.6, color: Colors.black54),
        ),
      ],
    );
  }
}

Widget _d314Default(BuildContext context) => _D314Default();

// ========== 3.2 按钮 ==========
class _D32Buttons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 三兄弟默认外观（Material 3 下 Elevated 无灰底）'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(onPressed: () {}, child: const Text('Elevated 漂浮')),
            TextButton(onPressed: () {}, child: const Text('Text 文本')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined 描边')),
          ],
        ),
        sec('② IconButton 与涟漪'),
        Row(
          children: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.thumb_up)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.favorite)),
            const SizedBox(width: 8),
            const Text('按下有水波动画（涟漪）', style: TextStyle(color: Colors.black54)),
          ],
        ),
        sec('③ .icon 构造：带图标的按钮'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.send),
              label: const Text('发送'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('添加'),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.info),
              label: const Text('详情'),
            ),
          ],
        ),
        sec('④ onPressed: null = 禁用置灰'),
        Wrap(
          spacing: 12,
          children: [
            ElevatedButton(onPressed: null, child: const Text('禁用中')),
            OutlinedButton(onPressed: null, child: const Text('禁用中')),
          ],
        ),
        const Text(
          '第8课表单"校验没过→提交按钮置灰"就是它',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

Widget _d32Buttons(BuildContext context) => _D32Buttons();

// ========== 3.3.1 Image fit ==========
class _D331ImageFit extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const fits = [
      BoxFit.fill,
      BoxFit.contain,
      BoxFit.cover,
      BoxFit.fitWidth,
      BoxFit.fitHeight,
      BoxFit.scaleDown,
      BoxFit.none,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('同一张图 × 同一显示框(100×50) × 七种 fit'),
        ...fits.map(
          (f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 50,
                  child: Image.asset('assets/avatar.png', fit: f),
                ),
                const SizedBox(width: 16),
                Text(f.name, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ),
        const Text(
          'fill 拉伸变形 / contain 保比缩进 / cover 保比裁满 /'
          '\nfitWidth 按宽缩 / fitHeight 按高缩 / scaleDown 只缩不放 / none 原图居中',
          style: TextStyle(fontSize: 12, height: 1.8, color: Colors.black54),
        ),
      ],
    );
  }
}

Widget _d331ImageFit(BuildContext context) => _D331ImageFit();

// ========== 3.3.1b 图片混合与平铺 ==========
class _D331bImageBlend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① color + colorBlendMode 像素级混合'),
        Row(
          children: [
            Image.asset(
              'assets/avatar.png',
              width: 100,
              color: Colors.blue,
              colorBlendMode: BlendMode.difference,
              fit: BoxFit.fill,
            ),
            const SizedBox(width: 16),
            Image.asset(
              'assets/avatar.png',
              width: 100,
              color: Colors.red,
              colorBlendMode: BlendMode.multiply,
              fit: BoxFit.fill,
            ),
          ],
        ),
        sec('② repeat 平铺（图小于显示框时）'),
        Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
          child: Image.asset(
            'assets/avatar.png',
            width: 100,
            fit: BoxFit.none,
            repeat: ImageRepeat.repeat,
          ),
        ),
        const Text(
          'ImageRepeat.repeatY 只纵向平铺；默认 noRepeat',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

Widget _d331bImageBlend(BuildContext context) => _D331bImageBlend();

// ========== 3.3.2 Icon ==========
class _D332Icon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 图标本质是字体：码点直接写进 Text'),
        const Text(
          '\uE03E \uE237 \uE287',
          style: TextStyle(
            fontFamily: 'MaterialIcons',
            fontSize: 32,
            color: Colors.green,
          ),
        ),
        const Text(
          '码点：accessible / error / fingerprint',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        sec('② Icon 组件 = 码点的友好封装'),
        const Row(
          children: [
            Icon(Icons.accessible, color: Colors.green),
            SizedBox(width: 12),
            Icon(Icons.error, color: Colors.green),
            SizedBox(width: 12),
            Icon(Icons.fingerprint, color: Colors.green),
          ],
        ),
        sec('③ 字体图标四大优点'),
        const Text(
          '体积小(省安装包) · 矢量(放大不糊) · 可套文字样式(颜色/字号/粗细)\n· 可与文本混排(TextSpan)',
          style: TextStyle(fontSize: 14, height: 1.8),
        ),
      ],
    );
  }
}

Widget _d332Icon(BuildContext context) => _D332Icon();

// ========== 3.5.1 TextField ==========
class _D351Input extends StatefulWidget {
  @override
  State<_D351Input> createState() => _D351InputState();
}

class _D351InputState extends State<_D351Input> {
  final _unameController = TextEditingController();
  final _pwdController = TextEditingController();
  FocusNode focusNode1 = FocusNode();
  FocusNode focusNode2 = FocusNode();

  @override
  void dispose() {
    _unameController.dispose();
    _pwdController.dispose();
    focusNode1.dispose();
    focusNode2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 登录框：labelText/hintText/prefixIcon/obscureText'),
        TextField(
          autofocus: true,
          focusNode: focusNode1,
          controller: _unameController,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '用户名或邮箱',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        TextField(
          focusNode: focusNode2,
          controller: _pwdController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '密码',
            hintText: '您的登录密码',
            prefixIcon: Icon(Icons.lock),
          ),
        ),
        const SizedBox(height: 12),
        sec('② controller 取值（点按钮看 SnackBar）'),
        Wrap(
          spacing: 12,
          children: [
            ElevatedButton(
              onPressed: () {
                final msg =
                    '用户名=${_unameController.text} 密码=${_pwdController.text}';
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(msg)));
              },
              child: const Text('print 两个框内容'),
            ),
            OutlinedButton(
              onPressed: () => FocusScope.of(context).requestFocus(focusNode2),
              child: const Text('移动焦点到密码框'),
            ),
            TextButton(
              onPressed: () {
                focusNode1.unfocus();
                focusNode2.unfocus();
              },
              child: const Text('收起键盘'),
            ),
          ],
        ),
        sec('③ onChanged 监听输入'),
        TextField(
          onChanged: (v) => debugPrint('onChange: $v'),
          decoration: const InputDecoration(
            labelText: '边输边打日志',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

Widget _d351Input(BuildContext context) => _D351Input();

// ========== 3.6 进度指示器 ==========
class _D36Progress extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 模糊进度 vs 精确进度'),
        const LinearProgressIndicator(
          backgroundColor: Colors.black12,
          valueColor: AlwaysStoppedAnimation(Colors.blue),
        ),
        const SizedBox(height: 12),
        const LinearProgressIndicator(
          backgroundColor: Colors.black12,
          valueColor: AlwaysStoppedAnimation(Colors.blue),
          value: .5,
        ),
        sec('② 圆形两态 + strokeWidth'),
        const Row(
          children: [
            CircularProgressIndicator(
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(Colors.blue),
            ),
            SizedBox(width: 24),
            CircularProgressIndicator(
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(Colors.blue),
              value: .7,
              strokeWidth: 8,
            ),
          ],
        ),
        sec('③ 没有尺寸参数——尺寸来自父约束'),
        const SizedBox(height: 3, child: LinearProgressIndicator(value: .5)),
        const SizedBox(height: 12),
        const SizedBox(
          width: 100,
          height: 100,
          child: CircularProgressIndicator(value: .7),
        ),
        const Text(
          '宽高不等 → 变椭圆（下一行）',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(
          width: 130,
          height: 100,
          child: CircularProgressIndicator(value: .7),
        ),
      ],
    );
  }
}

Widget _d36Progress(BuildContext context) => _D36Progress();

// ========== 4.2.3 ConstrainedBox / SizedBox ==========
class _D423Constraints extends StatelessWidget {
  final Widget redBox = const DecoratedBox(
    decoration: BoxDecoration(color: Colors.red),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① ConstrainedBox：minHeight 50 压过你写的 5'),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: double.infinity,
            minHeight: 50.0,
          ),
          child: Container(height: 5.0, child: redBox),
        ),
        const Text(
          'Container 想要 5，约束说最少 50 → 最终 50',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        sec('② 同样的盒子写 80 呢？'),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: double.infinity,
            minHeight: 50.0,
          ),
          child: Container(height: 80.0, child: redBox),
        ),
        const Text(
          '5<50 取 50；80>50 取 80 → min 只托底不封顶',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        sec('③ SizedBox = 固定宽高的 ConstrainedBox'),
        SizedBox(width: 80, height: 40, child: redBox),
      ],
    );
  }
}

Widget _d423Constraints(BuildContext context) => _D423Constraints();

// ========== 4.2.5 多重限制 ==========
class _D425Multi extends StatelessWidget {
  final Widget redBox = const DecoratedBox(
    decoration: BoxDecoration(color: Colors.red),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 父 min60×60 子 min90×20 → 宽90 高60'),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 60.0, minHeight: 60.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 90.0, minHeight: 20.0),
            child: redBox,
          ),
        ),
        sec('② 父子互换：父 min90×20 子 min60×60 → 仍是 90×60'),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 90.0, minHeight: 20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 60.0, minHeight: 60.0),
            child: redBox,
          ),
        ),
        sec('③ 规律：min 取父子较大者（保证不冲突）'),
        const Text(
          'minWidth/minHeight → 取大；\n'
          '思考题(书)：maxWidth/maxHeight → 取小。',
          style: TextStyle(fontSize: 14, height: 1.8),
        ),
      ],
    );
  }
}

Widget _d425Multi(BuildContext context) => _D425Multi();

// ========== 4.2.6 UnconstrainedBox ==========
class _D426Unconstrained extends StatelessWidget {
  final Widget redBox = const DecoratedBox(
    decoration: BoxDecoration(color: Colors.red),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AppBar 实例在下一页 →'),
        actions: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 3, value: .7),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          sec('① 无 UnconstrainedBox：子 ConstrainedBox 90×20，父 min 60×100'),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 60.0, minHeight: 100.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 90.0,
                minHeight: 20.0,
              ),
              child: redBox,
            ),
          ),
          const Text(
            '多重限制规则 → 90×100',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          sec('② 加 UnconstrainedBox：红块回归 90×20，但父仍占 100 高'),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 60.0, minHeight: 100.0),
            child: UnconstrainedBox(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 90.0,
                  minHeight: 20.0,
                ),
                child: redBox,
              ),
            ),
          ),
          const Text(
            '“去除”的是对子布局的约束，父的空间照占（上方有空白）',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          sec('③ 书上实战：AppBar 右侧 loading 按钮改小'),
          const Text(
            'AppBar 的 actions 自带约束，SizedBox(20×20) 不生效 →'
            '\n用 UnconstrainedBox 包住才 20×20（本页 AppBar 就是）。',
            style: TextStyle(fontSize: 13, height: 1.8),
          ),
        ],
      ),
    );
  }
}

Widget _d426Unconstrained(BuildContext context) => _D426Unconstrained();

// ========== 4.3 Row/Column ==========
class _D43RowColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 书上四连问：先猜再看答案'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [Text(' hello world '), Text(' I am Jack ')],
            ),
            Container(
              color: Colors.indigo[50],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [Text(' hello world '), Text(' I am Jack ')],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              textDirection: TextDirection.rtl,
              children: const [Text(' hello world '), Text(' I am Jack ')],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              verticalDirection: VerticalDirection.up,
              children: const [
                Text(' hello world ', style: TextStyle(fontSize: 30.0)),
                Text(' I am Jack '),
              ],
            ),
          ],
        ),
        sec('② 答案'),
        const Text(
          '1.居中；2.min→宽=内容宽，对齐无意义，靠左；'
          '\n3.rtl 参考系反转，end=左；4.up+start=底对齐。',
          style: TextStyle(fontSize: 13, height: 1.8),
        ),
        sec('③ 特殊情况：嵌套 Column 里 max 失效'),
        Container(
          color: Colors.green,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                color: Colors.red,
                child: Column(
                  // 无效：内层 Column 高度=内容高度
                  mainAxisSize: MainAxisSize.max,
                  children: const [Text('hello world '), Text('I am Jack ')],
                ),
              ),
            ],
          ),
        ),
        const Text(
          '外层 max 占满屏，内层 max 无效 → 想撑满用 Expanded',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

Widget _d43RowColumn(BuildContext context) => _D43RowColumn();

// ========== 4.4 Flex/Expanded/Spacer ==========
class _D44Flex extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 水平 1:2'),
        Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(flex: 1, child: Container(height: 30, color: Colors.red)),
            Expanded(
              flex: 2,
              child: Container(height: 30, color: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 20),
        sec('② 垂直 2:1:1（中间塞 Spacer 占位）'),
        SizedBox(
          height: 150,
          child: Flex(
            direction: Axis.vertical,
            children: [
              Expanded(flex: 2, child: Container(color: Colors.red)),
              const Spacer(flex: 1),
              Expanded(flex: 1, child: Container(color: Colors.green)),
            ],
          ),
        ),
        sec('③ Spacer 源码 = Expanded(SizedBox.shrink)'),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.indigo[50],
          child: const Text(
            'class Spacer {\n'
            '  build => Expanded(flex, SizedBox.shrink())\n'
            '}\n'
            '→ Spacer 只是"占住比例但什么都不画"的 Expanded',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ),
        sec('④ Expanded 只能做 Flex 的孩子'),
        const Text(
          'Expanded 放到非 Flex 父组件（如 Center）直接报错；\n'
          'Row/Column 都继承 Flex，所以三家通用。',
          style: TextStyle(fontSize: 13, height: 1.8),
        ),
      ],
    );
  }
}

Widget _d44Flex(BuildContext context) => _D44Flex();

// ========== 4.5 Wrap ==========
class _D45Wrap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 同样一组 Chip：Row 挤不下→溢出，Wrap→折行'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.redAccent),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              for (final n in const [
                'Hamilton',
                'Lafayette',
                'Mulligan',
                'Laurens',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(n[0]),
                    ),
                    label: Text(n),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          alignment: WrapAlignment.center,
          children: [
            for (final n in const [
              'Hamilton',
              'Lafayette',
              'Mulligan',
              'Laurens',
            ])
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(n[0]),
                ),
                label: Text(n),
              ),
          ],
        ),
        sec('② Wrap 特有参数'),
        const Text(
          'spacing 主轴间距 / runSpacing 纵轴(行间)间距 / runAlignment 行对齐',
          style: TextStyle(fontSize: 13, height: 1.8),
        ),
      ],
    );
  }
}

Widget _d45Wrap(BuildContext context) => _D45Wrap();

// ========== 4.6 Stack/Positioned ==========
class _D46Stack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 书上示例：全屏 Stack + 三个 Text'),
        ConstrainedBox(
          constraints: const BoxConstraints.expand(),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                color: Colors.red,
                child: const Text(
                  'Hello world',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const Positioned(left: 18.0, child: Text('I am Jack')),
              const Positioned(top: 18.0, child: Text('Your friend')),
            ],
          ),
        ),
        sec('② fit: StackFit.expand + 顺序对调'),
        SizedBox(
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: <Widget>[
              const Positioned(left: 18.0, child: Text('I am Jack')),
              Container(
                color: Colors.red,
                child: const Text(
                  'Hello world',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const Positioned(top: 18.0, child: Text('Your friend')),
            ],
          ),
        ),
        const Text(
          '未定位的 Container 被 fit 拉满 → 盖住第一个 Positioned',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        sec('③ Positioned 三选二规则'),
        const Text(
          '水平：left/right/width 只能指定其中两个（第三个自动算）；\n'
          '垂直：top/bottom/height 同理。三个全给 → 报错。',
          style: TextStyle(fontSize: 13, height: 1.8),
        ),
      ],
    );
  }
}

Widget _d46Stack(BuildContext context) => _D46Stack();

// ========== 5.4 Container ==========
class _D54Container extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sec('① 书上 5.20 卡片：渐变+阴影+旋转'),
        Container(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.only(top: 10.0),
            constraints: const BoxConstraints.tightFor(
              width: 200.0,
              height: 150.0,
            ),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: const [Colors.red, Colors.orange],
                center: Alignment.topLeft,
                radius: .98,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  offset: Offset(2.0, 2.0),
                  blurRadius: 4.0,
                ),
              ],
            ),
            transform: Matrix4.rotationZ(.2),
            alignment: Alignment.center,
            child: const Text(
              '5.20',
              style: TextStyle(color: Colors.white, fontSize: 40.0),
            ),
          ),
        ),
        const SizedBox(height: 24),
        sec('② padding vs margin'),
        Container(
          margin: const EdgeInsets.all(20.0),
          color: Colors.orange,
          child: const Text('margin 外补白'),
        ),
        Container(
          padding: const EdgeInsets.all(20.0),
          color: Colors.orange,
          child: const Text('padding 内补白'),
        ),
        const Text(
          '两者底层都是 Padding 组件：margin=包在外面的留白',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        sec('③ color 与 decoration 互斥'),
        const Text(
          'Container(color: red, decoration: BoxDecoration(...)) → 编译/运行报错\n'
          'color 要写进 decoration: BoxDecoration(color: ...)',
          style: TextStyle(fontSize: 13, height: 1.8),
        ),
      ],
    );
  }
}

Widget _d54Container(BuildContext context) => _D54Container();

// ========== EX5 朋友圈卡片（微信风格） ==========
Widget _ex5Moments(BuildContext context) => _Ex5Moments();

class _Ex5Moments extends StatefulWidget {
  @override
  State<_Ex5Moments> createState() => _Ex5MomentsState();
}

class _Ex5MomentsState extends State<_Ex5Moments> {
  final _liked = <String>['胡老师'];
  final _comments = <_Comment>[
    _Comment('小云', '这就是卡片套路的实战版！'),
    _Comment('阿吉', 'Wrap九宫格学到了'),
  ];

  // 用色块模拟九宫格照片（课堂上讲：真实 App 里是 Image.network）
  static const _photoColors = [
    Color(0xFF90CAF9),
    Color(0xFFFFCC80),
    Color(0xFFA5D6A7),
    Color(0xFFEF9A9A),
    Color(0xFFCE93D8),
    Color(0xFF80DEEA),
    Color(0xFFFFF59D),
    Color(0xFFBCAAA4),
    Color(0xFFB0BEC5),
  ];

  void _toggleLike(String name) {
    setState(() {
      if (_liked.contains(name)) {
        _liked.remove(name);
      } else {
        _liked.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 知识点标签
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: const [
            Chip(label: Text('Container 卡片')),
            Chip(label: Text('Row 头像+内容')),
            Chip(label: Text('Wrap 九宫格')),
            Chip(label: Text('Text.rich 点赞')),
          ],
        ),
        const SizedBox(height: 12),
        // 主体卡片：模仿微信朋友圈一条动态
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像行：Row + CircleAvatar + 两行 Text
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.indigo,
                        child: Text(
                          '胡',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                      // Stack 角标：黄V认证
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '胡老师',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF5B7DB1),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '2小时前',
                          style: TextStyle(fontSize: 12, color: Colors.black38),
                        ),
                      ],
                    ),
                  ),
                  // 菜单按钮（两点半角标按钮，Stack 再练一次）
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, size: 14, color: Colors.black54),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 正文：Text 换行 + Text.rich 话题高亮
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  children: [
                    const TextSpan(
                      text: '今天第6课：把教科书第3~5章的组件全部做成了 23 个可运行演示页。\n',
                    ),
                    TextSpan(
                      text: '#Flutter基础组件# ',
                      style: TextStyle(color: Color(0xFF5B7DB1)),
                    ),
                    TextSpan(
                      text: '#布局系统#',
                      style: TextStyle(color: Color(0xFF5B7DB1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 九宫格：Wrap + AspectRatio 色块（3列自动折行）
              SizedBox(
                width: 240,
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final c in _photoColors)
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.photo,
                          color: Colors.white24,
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 点赞行：Text.rich 一行聚合所有人
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLike('我'),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const WidgetSpan(
                              child: Icon(
                                Icons.favorite,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                            ),
                            const TextSpan(text: '  '),
                            TextSpan(
                              text: _liked.join('、'),
                              style: const TextStyle(color: Color(0xFF5B7DB1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final c in _comments)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${c.author}：',
                                style: const TextStyle(
                                  color: Color(0xFF5B7DB1),
                                ),
                              ),
                              TextSpan(text: c.text),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 互动按钮：点赞切换（setState 复习）
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _toggleLike('我'),
            icon: Icon(
              _liked.contains('我') ? Icons.favorite : Icons.favorite_border,
              color: _liked.contains('我') ? Colors.redAccent : null,
            ),
            label: Text(_liked.contains('我') ? '已赞（点我取消）' : '点赞（点我试试）'),
          ),
        ),
      ],
    );
  }
}

class _Comment {
  final String author;
  final String text;
  const _Comment(this.author, this.text);
}

// ========== 公共小节标题（m6/m7 共用） ==========
Widget sec(String title) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 8),
  child: Text(
    title,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Colors.indigo,
    ),
  ),
);

// ========== EX1 热区彩蛋 · 点击爆炸 ==========
Widget _ex1Boom(BuildContext context) => _Ex1Boom();

class _Ex1Boom extends StatefulWidget {
  @override
  State<_Ex1Boom> createState() => _Ex1BoomState();
}

class _Ex1BoomState extends State<_Ex1Boom> {
  String? _hitIcon; // 哪个图标被点中了，null 表示没点

  final _icons = const [
    _PosIcon(top: 20, left: 30, icon: Icons.star, color: Colors.amber),
    _PosIcon(top: 60, left: 180, icon: Icons.favorite, color: Colors.redAccent),
    _PosIcon(top: 140, left: 80, icon: Icons.bolt, color: Colors.orange),
    _PosIcon(top: 100, left: 260, icon: Icons.water_drop, color: Colors.blue),
    _PosIcon(
      top: 200,
      left: 150,
      icon: Icons.auto_awesome,
      color: Colors.purpleAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              Chip(label: Text('Stack+Positioned')),
              Chip(label: Text('GestureDetector')),
              Chip(label: Text('Icon')),
              Chip(label: Text('setState')),
            ],
          ),
        ),
        const Text(
          '👆 点一个图标试试，彩蛋就藏在里面',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.indigo.shade100),
              borderRadius: BorderRadius.circular(12),
              color: Colors.indigo.shade50,
            ),
            child: Stack(
              children: [
                for (final p in _icons)
                  Positioned(
                    top: p.top,
                    left: p.left,
                    child: GestureDetector(
                      onTap: () => setState(
                        () => _hitIcon = p.icon.codePoint.toString(),
                      ),
                      child: Icon(p.icon, color: p.color, size: 36),
                    ),
                  ),
                if (_hitIcon != null)
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _hitIcon = null),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          '!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PosIcon {
  final double top;
  final double left;
  final IconData icon;
  final Color color;
  const _PosIcon({
    required this.top,
    required this.left,
    required this.icon,
    required this.color,
  });
}

// ========== EX2 迷你记账本 ==========
Widget _ex2Ledger(BuildContext context) => _Ex2Ledger();

class _Ex2Ledger extends StatefulWidget {
  @override
  State<_Ex2Ledger> createState() => _Ex2LedgerState();
}

class _Ex2LedgerState extends State<_Ex2Ledger> {
  final _items = [
    _LedgerItem('早餐', 15.5, '餐饮', Colors.orange),
    _LedgerItem('地铁', 6.0, '交通', Colors.blue),
    _LedgerItem('午餐', 28.0, '餐饮', Colors.orange),
    _LedgerItem('买书', 59.0, '学习', Colors.purple),
    _LedgerItem('奶茶', 18.0, '饮料', Colors.pink),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: const [
                  Chip(label: Text('Wrap 标签云')),
                  Chip(label: Text('TextSpan 富文本')),
                  Chip(label: Text('Expanded')),
                  Chip(label: Text('Container 卡片')),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final it = _items[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: it.tagColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      it.tag,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: it.tagColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: '¥',
                                style: TextStyle(color: Colors.blueGrey),
                              ),
                              TextSpan(
                                text: it.amount.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // 浮动按钮
        Positioned(
          right: 20,
          bottom: 20,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.indigo,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }
}

class _LedgerItem {
  final String title;
  final double amount;
  final String tag;
  final Color tagColor;
  const _LedgerItem(this.title, this.amount, this.tag, this.tagColor);
}

// ========== EX3 打卡日历 ==========
Widget _ex3Calendar(BuildContext context) => _Ex3Calendar();

class _Ex3Calendar extends StatefulWidget {
  @override
  State<_Ex3Calendar> createState() => _Ex3CalendarState();
}

class _Ex3CalendarState extends State<_Ex3Calendar> {
  // 31 天，true = 已打卡
  final List<bool> _checked = List.generate(31, (_) => false);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: const [
            Chip(label: Text('Wrap 流式')),
            Chip(label: Text('Container 装饰')),
            Chip(label: Text('GestureDetector')),
            Chip(label: Text('setState')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📅 2026 年 10 月 · 31 天',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '已打卡 ${_checked.where((e) => e).length} 天',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(31, (i) {
              final day = i + 1;
              final isOn = _checked[i];
              return GestureDetector(
                onTap: () => setState(() => _checked[i] = !_checked[i]),
                child: Container(
                  width:
                      (MediaQuery.of(context).size.width - 24 - 12 - 6 * 6) / 7,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isOn ? Colors.redAccent : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isOn ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '点格子切换打卡状态 · Wrap 自动换行 7 × 5 + 6 = 31 格',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

// ========== EX4 抽奖转盘 ==========
Widget _ex4Wheel(BuildContext context) => _Ex4Wheel();

class _Ex4Wheel extends StatefulWidget {
  @override
  State<_Ex4Wheel> createState() => _Ex4WheelState();
}

class _Ex4WheelState extends State<_Ex4Wheel> {
  double _rotation = 0;
  String? _result;

  final _prizes = ['谢谢参与', '50 积分', '10 元券', '再来一次', 'iPhone 18', '神秘大奖'];

  void _spin() {
    setState(() {
      _rotation += 6.28 * 3; // 转 3 圈
      _result = _prizes[DateTime.now().millisecond % 6];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              Chip(label: Text('Stack Positioned')),
              Chip(label: Text('ShapeDecoration')),
              Chip(label: Text('AnimatedContainer')),
              Chip(label: Text('transform')),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 转盘主体：AnimatedContainer + transform 旋转
                  AnimatedContainer(
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeOut,
                    width: 260,
                    height: 260,
                    transform: Matrix4.rotationZ(_rotation),
                    decoration: ShapeDecoration(
                      shape: const CircleBorder(),
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFFFFCDD2),
                          Color(0xFFF8BBD9),
                          Color(0xFFE1BEE7),
                          Color(0xFFD1C4E9),
                          Color(0xFFC5CAE9),
                          Color(0xFFBBDEFB),
                        ],
                        stops: [0.0, 0.166, 0.333, 0.5, 0.666, 0.833],
                      ),
                    ),
                  ),
                  // 扇区标记（不旋转的外层）
                  for (var i = 0; i < 6; i++)
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Transform.rotate(
                        angle: i * 6.28 / 6,
                        child: const Icon(
                          Icons.star,
                          color: Colors.deepOrange,
                          size: 20,
                        ),
                      ),
                    ),
                  // 中心大按钮
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 100),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    onPressed: _spin,
                    child: const Text('开始\n抽奖', textAlign: TextAlign.center),
                  ),
                  // 顶部指针（不旋转）
                  Positioned(
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Text(
            _result ?? '点中间按钮开转！',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ),
      ],
    );
  }
}
