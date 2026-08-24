# 5 用户 × 7 天个性化故事数据包（顺时）

19 项要求第 19 项前置交付：五类用户连续一周登录后的首页 UI 变化，
以可复现、可注入的脚本化数据 + 驱动测试 + golden 截图形式落地。

## 文件

| 文件 | persona | 目标（HomeGoal） | 选目标日 |
|---|---|---|---|
| `persona_a_newcomer_sleep.json` | A 想改善作息的新手 | `sleep` 睡个好觉 | Day 1 |
| `persona_b_coach_energy.json` | B 健康/成长教练 | `energy` 白天更有精神 | Day 1 |
| `persona_c_family_organizer.json` | C 家庭组织者 | `family` 照顾好家人 | Day 1 |
| `persona_d_habit_tracker.json` | D 习惯打卡用户 | `energy` 白天更有精神 | Day 1 |
| `persona_e_privacy_sensitive.json` | E 隐私敏感用户 | `calm` 放松减压 | Day 3（前两天不选目标） |

五类用户与角色映射见《四项目-19项要求-整体修改建议-2026-08-20.md》第 19 条矩阵。

## 数据格式（与存储层完全对齐）

- `days[].events[]` 的行为事件格式与 `HomeProfileStorage._encodeEvents`
  完全一致：`{"cardId": ..., "type": "seen|opened|completed", "at": "ISO8601"}`，
  对应存储键 `home_behavior_events`；`cardId` 取自首页候选卡
  （`solar_term / rhythm / family / chat / breath / food / exercise / anomaly_inactive`）。
- `goal` 为 `HomeGoal.name`，对应存储键 `home_profile_goal`。
- `muteDuringDay` 为 `HomeCardCategory.name`，对应存储键
  `home_profile_muted_categories`（当天操作，次日起生效）。
- `completed` 事件同时对应存储键 `home_completions` 中 `yyyy-MM-dd` 日期键
  的完成集合（与 `HomeProfileStorage.markCompleted` 语义一致）。
- `renderAt` 是当天首页渲染的日期锚点（模拟用户当天首次打开 App 的时刻）。
  渲染发生在当天事件**之前**：Day N 的首页由 Day 1..N-1 的行为决定，
  即「Day 2 按首日行为重排」的因果方向。
- `seen` 事件不手写：App 每渲染一张卡会自动记录 `seen`（按天去重），
  驱动层 `test/personas/persona_story.dart` 按同一规则合成，保证与真实
  客户端行为一致。

## 用法

```bash
cd 手机端-Flutter

# 1) 7 天状态递进断言（纯 Dart 驱动，逐日断言卡序/理由/分数变化）
flutter test test/personas/persona_week_driver_test.dart

# 2) fake storage 注入 → 真实首页（SharedPreferences 键直注，验证格式对齐）
flutter test test/personas/persona_storage_injection_test.dart

# 3) 生成/校验 35 张 golden 截图 + manifest + 全量数据 dump
flutter test --update-goldens test/personas/persona_golden_test.dart   # 生成/更新基线
flutter test test/personas/persona_golden_test.dart                    # 常规校验
```

golden 基线在本包 `test/personas/goldens/`（版本控制内，差异需审查后
`--update-goldens` 更新）；证据副本与 manifest 输出到
`验收证据/顺时/personas/`。

golden 渲染需要中文字体，测试启动时加载 macOS 系统字体
`/System/Library/Fonts/Supplemental/Arial Unicode.ttf`；在其他机器上
如字体缺失，请用 `--update-goldens` 重新生成基线并人工审查差异。
