# Flutter 教科书示例演示工程

《Flutter实战》第 3~5 章基础组件与布局示例的在线演示版源码（移动应用软件开发实训课程配套）。

## 在线浏览（无需安装）

**https://thiswind.github.io/flutter-book-demos/**

- 23 个演示页对应教科书 3.1~5.4 各小节，5 个扩展案例（EX1~EX5）
- 每页可加 `?d=编号` 直达，例如：
  - `?d=3.1.1` Text 基础
  - `?d=3.3.1` BoxFit 七连排
  - `?d=4.3` Row 四连坑
  - `?d=EX4` 抽奖转盘

## 本地运行

```bash
flutter pub get
flutter run -d chrome          # Web 端
# 或 flutter run -d macos / windows 等
```

## 扩展案例一览（EX1~EX5：练习靶子，含缺陷）

> **⚠ 五个扩展案例当前代码都存在缺陷，无法正常运行——这是课程特意设计的教学靶子，不是你的环境问题。**
> 修复任务见《讲义六》"6A 扩展练习"：复现 → 定位 → AI 辅助修复 → 验证 → 提交（选做，不计入成绩）。

| 编号 | 案例 | 涉及知识点 | 待修复的症状（病根自己找） |
|---|---|---|---|
| EX1 | 热区彩蛋 | Stack + Positioned + GestureDetector + setState | 无爆炸粒子效果 |
| EX2 | 迷你记账本 | Wrap + Text.rich + Stack 浮动按钮 | "+"按钮点不动，记账功能缺失 |
| EX3 | 打卡日历 | Wrap 网格 + setState | 宽屏下格子变形 |
| EX4 | 抽奖转盘 | SweepGradient + AnimatedContainer | 转动不可见、结果与盘面不符 |
| EX5 | 朋友圈卡片 | Container 卡片 + Stack 角标 + Wrap 九宫格 | 菜单按钮无响应 |

23 个教科书示例页（3.1.1 ~ 5.4）本身全部正常，可直接对照学习。
