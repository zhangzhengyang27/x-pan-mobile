# X-Pan 移动端 UI 高级感改造计划

> 本文档为**可交接执行**的页面设计优化方案。任何 AI 或开发者可照此逐步落地。
>
> 改造方向：**科技动感风格**（阿里云盘风）· 深邃蓝品牌色 · 全量 27 页 · 全量精细动效。
>
> 当前状态：**基础体系已搭建完成**（Token + 主题 + 通用组件），页面改造待执行。

---

## 0. 已完成的基础设施（可直接复用，勿重复创建）

以下文件**已经创建并可用**，页面改造时直接 import 使用：

| 文件 | 作用 | 关键导出 |
|------|------|---------|
| `lib/core/theme/app_tokens.dart` | Design Token 体系 | `AppTokens`（颜色/字号/间距/圆角/阴影/动效/路由） |
| `lib/core/theme/app_theme.dart` | 全局主题（已升级） | `AppTheme.light` / `AppTheme.dark` |
| `lib/widgets/app_card.dart` | 高级感卡片 | `AppCard`、`CardElevation` |
| `lib/widgets/empty_state.dart` | 空状态组件 | `EmptyState` |
| `lib/widgets/skeleton.dart` | 骨架屏 | `SkeletonBox`、`FileListSkeleton`、`CardSkeleton` |
| `lib/widgets/gradient_header.dart` | 渐变头部/Logo | `GradientHeader`、`BrandLogoBadge` |
| `lib/widgets/app_list_item.dart` | 列表项 | `AppListItem`、`AppListTile` |

**改造原则**：页面中所有硬编码的颜色/间距/圆角/字号，必须替换为 `AppTokens` 中的对应 Token。禁止再出现裸 `Card`、裸 `CircularProgressIndicator`、裸 `ListTile`，改用上述组件。

---

## 1. 设计体系规范

### 1.1 品牌色

| Token | 值 | 用途 |
|-------|-----|------|
| `AppTokens.brandPrimary` | `#3366FF` | 主色：按钮/选中态/链接 |
| `AppTokens.brandPrimaryDark` | `#165DFF` | 渐变终点 |
| `AppTokens.brandSecondary` | `#00D4C7` | 数据可视化辅色 |
| `AppTokens.brandAccent` | `#7C3AED` | 强调态辅色 |
| `AppTokens.brandGradient` | `#3366FF → #165DFF` | 品牌区/主按钮渐变 |
| `AppTokens.dataGradient` | `#3366FF → #00D4C7` | 图表渐变 |

品牌色阶 `brandScale[50..900]` 已定义，按需取用。

### 1.2 语义色

`success #10B981` · `warning #F59E0B` · `error #EF4444` · `info #3366FF`

### 1.3 中性色（浅色 / 暗色）

| 用途 | 浅色 | 暗色 |
|------|------|------|
| 背景 | `neutral50 #F7F9FC` | `darkBg #0B0E14` |
| 表面（卡片）| `neutral0 #FFFFFF` | `darkSurface #131722` |
| 表面（弹层）| `neutral0 #FFFFFF` | `darkSurfaceElevated #1B2030` |
| 主文字 | `neutral900 #0F172A` | `darkTextPrimary #F1F5F9` |
| 次文字 | `neutral500 #64748B` | `darkTextSecondary #94A3B8` |
| 分割线 | `neutral200 #E4E9F2` | `darkBorder #252B3B` |

便捷访问：`AppTokens.surface(b)` / `AppTokens.background(b)` / `AppTokens.textPrimary(b)` 等。

### 1.4 字号梯度

| Token | 字号 | 字重 | 用途 |
|-------|------|------|------|
| `displayLarge` | 40 | w800 | 大标题（登录页品牌名） |
| `displayMedium` | 32 | w700 | 大标题 |
| `headlineLarge` | 26 | w700 | 页面主标题 |
| `headlineMedium` | 22 | w600 | 区块标题 |
| `titleLarge` | 18 | w600 | AppBar 标题 |
| `titleMedium` | 16 | w600 | 卡片标题 |
| `bodyLarge` | 15 | w400 | 正文 |
| `bodyMedium` | 14 | w400 | 次要正文 |
| `bodySmall` | 12 | w400 | 辅助文字 |
| `labelLarge` | 14 | w600 | 按钮文字 |
| `labelSmall` | 11 | w500 | 标签/角标 |

### 1.5 间距（8pt 栅格）

`space3 / space4 / space8 / space12 / space16 / space20 / space24 / space32 / space40 / space48`

### 1.6 圆角

`radiusSm 8` · `radiusMd 12` · `radiusLg 16` · `radiusXl 20` · `radiusFull 999`

### 1.7 阴影

| Token | 强度 | 用途 |
|-------|------|------|
| `AppTokens.shadowSm(b)` | 轻 | 普通卡片 |
| `AppTokens.shadowMd(b)` | 中 | 浮起卡片/表单 |
| `AppTokens.shadowLg(b)` | 重 | 弹层/对话框 |
| `AppTokens.shadowBrand(b)` | 品牌光晕 | 主按钮/FAB |

### 1.8 动效

| Token | 时长 | 用途 |
|-------|------|------|
| `durationFast` | 150ms | 按压反馈 |
| `durationBase` | 250ms | 常规过渡 |
| `durationSlow` | 400ms | 页面转场 |
| `durationSlower` | 600ms | 复杂动效 |

曲线：`curveStandard`(easeOutCubic) · `curveEmphasized`(easeInOutCubicEmphasized) · `curveDecelerate`

页面转场：使用 `AppTokens.route(page)` 替代 `MaterialPageRoute`（缩放+淡入）。

---

## 2. 通用组件使用规范

### 2.1 卡片

```dart
// 替换裸 Card
AppCard(
  padding: const EdgeInsets.all(AppTokens.space16),
  elevation: CardElevation.medium,
  child: ...,
)
```

### 2.2 空状态

```dart
// 替换 "裸图标 + Text('文件夹为空')"
EmptyState(
  icon: Icons.folder_open,
  title: '文件夹为空',
  subtitle: '点击右下角按钮上传文件',
  actionLabel: '上传文件',
  onAction: _upload,
)
```

### 2.3 骨架屏

```dart
// 替换 Center(child: CircularProgressIndicator())
if (state.loading && state.files.isEmpty) return const FileListSkeleton();
```

### 2.4 列表项

```dart
// 替换裸 ListTile
AppListTile(
  leading: const Icon(Icons.settings_outlined),
  title: '设置',
  subtitle: '修改密码 · 设备管理',
  trailing: const Icon(Icons.chevron_right),
  onTap: ...,
)
```

### 2.5 页面转场

```dart
// 替换 MaterialPageRoute(builder: (_) => page)
Navigator.of(context).push(AppTokens.route(const SettingsPage()));
```

---

## 3. 页面改造清单

### 改造优先级与批次

| 批次 | 页面 | 改造重点 | 状态 |
|------|------|---------|------|
| **1** | login_page | 品牌Logo + 渐变表单卡片 + 品牌光晕按钮 | ✅ 已完成 |
| 1 | register_page | 对齐登录页视觉语言 | ⏳ 待执行 |
| 1 | forgot_password_page | 对齐登录页视觉语言 | ⏳ 待执行 |
| 1 | home_page | 卡片化文件列表 + 骨架屏 + 空状态 + 面包屑优化 + 渐变抽屉头 | ⏳ 待执行 |
| 1 | dashboard_page | 渐变存储卡片 + 数据可视化 + 骨架屏 | ⏳ 待执行 |
| **2** | search_page | 搜索栏优化 + 历史/结果卡片化 + 空状态 | ⏳ 待执行 |
| 2 | favorite_page | 卡片化 + 空状态 | ⏳ 待执行 |
| 2 | recent_page | 时间分组 + 卡片化 | ⏳ 待执行 |
| 2 | recycle_page | 卡片化 + 危险色提示 | ⏳ 待执行 |
| 2 | share_page | 分享卡片 + 状态标签 | ⏳ 待执行 |
| 2 | share_detail_page | 渐变头 + 文件列表 | ⏳ 待执行 |
| 2 | settings_page | 分组卡片 + AppListTile | ⏳ 待执行 |
| 2 | notification_page | 通知卡片 + 已读/未读态 | ⏳ 待执行 |
| 2 | upload_task_page | 进度卡片 + 状态标签 | ⏳ 待执行 |
| **3** | image_preview_page | 渐隐 AppBar + 翻页指示器 + 双指缩放 | ⏳ 待执行 |
| 3 | video_preview_page | 沉浸式控制层 | ⏳ 待执行 |
| 3 | audio_preview_page | 渐变背景 + 唱片式封面 | ⏳ 待执行 |
| 3 | pdf_preview_page | 加载骨架 + 工具栏 | ⏳ 待执行 |
| 3 | office_preview_page | 加载骨架 | ⏳ 待执行 |
| 3 | text_preview_page | 代码高亮风格 + 行号 | ⏳ 待执行 |
| 3 | csv_preview_page | 表格样式优化 | ⏳ 待执行 |
| 3 | xmind_preview_page | 加载骨架 | ⏳ 待执行 |
| 3 | dedup_page | 重复文件卡片 + 对比视图 | ⏳ 待执行 |
| 3 | device_page | 设备卡片 + 在线态 | ⏳ 待执行 |
| 3 | offline_page | 任务卡片 + 进度 | ⏳ 待执行 |
| 3 | vault_page | 安全感视觉 + 文件列表 | ⏳ 待执行 |
| 3 | version_history_page | 时间轴样式 | ⏳ 待执行 |
| 3 | ai_assistant_page | 对话气泡 + 渐变头 | ⏳ 待执行 |

---

## 4. 各页面改造细则

### 4.1 批次 1 · 核心页

#### login_page.dart ✅ 已完成（参考样板）
- `BrandLogoBadge(size: 72)` 品牌Logo
- 表单外包 `Container` + `shadowMd` + `radiusXl` 形成浮起卡片
- 主按钮外包 `shadowBrand` 品牌光晕
- 字间距 `letterSpacing: 4` 的"登 录"文字
- 跳转用 `AppTokens.route()`

#### register_page.dart（对齐 login_page）
**改造要点**：
1. 顶部加 `BrandLogoBadge(size: 56)` + "创建账号"标题 + 副标题
2. 表单用 `Container` 包裹（`shadowMd` + `radiusXl` + `divider` 边框）
3. 注册按钮加 `shadowBrand` 光晕
4. 间距统一用 `AppTokens.space16/24`
5. `SizedBox(height: 16/28)` → `AppTokens.space16/24`
6. 跳转回登录页用 `AppTokens.route()`
7. 加载态 `CircularProgressIndicator` 保留（按钮内小尺寸可接受）

#### forgot_password_page.dart（对齐 login_page）
**改造要点**：
1. 顶部加 `BrandLogoBadge(size: 56)` + "找回密码"标题 + 副标题"通过密保问题重置"
2. 表单卡片化（同 register）
3. 按钮加 `shadowBrand`
4. 间距 Token 化
5. 步骤提示：可在表单顶部加一行 `bodySmall` 文字说明流程

#### home_page.dart（最核心，改动最大）
**改造要点**：

**A. 抽屉导航 `_buildNavList`**
- `UserAccountsDrawerHeader` → 自定义渐变头：
  ```dart
  Container(
    decoration: const BoxDecoration(gradient: AppTokens.brandGradient),
    padding: const EdgeInsets.all(AppTokens.space20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 28, backgroundColor: Colors.white.withValues(alpha: 0.2), child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(height: AppTokens.space12),
        Text(username, style: AppTokens.titleMedium.copyWith(color: Colors.white)),
        Text(used/total, style: AppTokens.bodySmall.copyWith(color: Colors.white70)),
        // 存储进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
          child: LinearProgressIndicator(value: ratio, backgroundColor: Colors.white24, color: Colors.white),
        ),
      ],
    ),
  )
  ```
- 导航项 `ListTile` → `AppListTile`，图标统一 `Icons.xxx_outlined`
- 分组：用 `Padding` + `bodySmall` 灰色小标题分组（如"文件""工具""账号"）

**B. AppBar `_buildAppBar`**
- 普通态：`title` 用 `AppTokens.titleLarge`，加面包屑路径作为副标题
- 选中态：`title` 改为"已选 N 项"，`backgroundColor` 用 `brandPrimary.withValues(alpha:0.08)`
- `PopupMenuButton` 的项加图标

**C. 面包屑 `_buildBreadcrumbs`**
- 容器加 `divider` 底边框，高度 `40` → `44`
- 文字用 `AppTokens.bodyMedium`，当前项 `brandPrimary` + `w600`，其余 `textSecondary`
- 分隔符 `chevron_right` 颜色 `textTertiary`

**D. 文件列表 `_FileTile`**
- `ListTile` → `AppListItem` 包裹
- `leading` 的 `FileTypeIcon` 保留（已较好）
- `subtitle` 用 `AppTokens.bodySmall` + `textSecondary`
- 选中态：左侧加蓝色竖条 + 背景染色
- `trailing` 的 `more_vert` 按钮改为圆形背景 `surface` + `shadowSm`

**E. 文件网格 `_FileGridItem`**
- 容器加 `shadowSm` + `divider` 边框 + `radiusLg`
- 缩略图区域改为 `radiusMd` 圆角 + 占位用 `SkeletonBox`
- 文件名用 `AppTokens.bodySmall`
- 选中态：`brandPrimary` 边框 2px + 角标

**F. 加载/空/错误态 `_buildBody`**
- 加载态：`CircularProgressIndicator` → `FileListSkeleton()`
- 空态：裸图标 → `EmptyState(icon: Icons.folder_open, title: '文件夹为空', subtitle: '上传你的第一个文件吧', actionLabel: '上传文件', onAction: _upload)`
- 错误态：`Icon(Icons.error_outline)` → `EmptyState(icon: Icons.cloud_off, title: '加载失败', subtitle: state.error, actionLabel: '重试', onAction: _refresh)`

**G. 上传进度条 `_buildUploadBar`**
- `Container` 加 `surface` 背景 + `shadowMd` + 顶部 `divider`
- 文件名 `bodyMedium`，百分比 `labelLarge` + `brandPrimary`
- `LinearProgressIndicator` 圆角 `radiusFull`

**H. FAB**
- 已由主题接管，确认 `Icons.add` 即可

#### dashboard_page.dart
**改造要点**：
1. 顶部加 `GradientHeader`（高度 160）展示用户名 + 存储概览
2. `_buildStorageCard` → `AppCard`，进度条改用 `dataGradient` 渐变 + `radiusFull`
3. 大号百分比数字：`displayMedium` + `brandPrimary`
4. "功能说明"卡片改为 `AppCard` + 图标
5. 补充：按文件类型分类的横向条形图（用 `dataGradient`，每种类型一条）
6. 加载态用 `CardSkeleton`

### 4.2 批次 2 · 次级页

> 所有次级页通用规范：
> - `AppBar` 标题用 `titleLarge`（已由主题接管）
> - `ListView` padding 用 `AppTokens.space16`
> - 列表项 → `AppListTile` 或 `AppCard`
> - 空态 → `EmptyState`
> - 加载态 → 骨架屏
> - 跳转 → `AppTokens.route()`

#### search_page.dart
- 搜索框置顶固定，圆角 `radiusFull`，`surface` 背景 + `shadowSm`
- 搜索历史：圆角 `Chip` 样式，点击即填入
- 搜索结果：`AppCard` 卡片化，高亮匹配文字
- 无结果：`EmptyState(icon: Icons.search_off, title: '未找到相关文件')`

#### favorite_page.dart
- 网格/列表切换（同 home_page）
- 空态：`EmptyState(icon: Icons.star_border, title: '还没有收藏', subtitle: '长按文件即可收藏')`

#### recent_page.dart
- 按日期分组（今天/昨天/本周/更早），分组标题用 `bodySmall` + `textSecondary` + `space12` 上间距
- 每项用 `AppListTile`，trailing 显示访问时间

#### recycle_page.dart
- 顶部警示条：`warning` 色背景 + 图标 + "文件 30 天后自动清理"
- 列表项 `AppListTile`，trailing 加"还原"按钮
- 底部"清空回收站"按钮用 `error` 色

#### share_page.dart
- 分享卡片：`AppCard` + 文件名 + 分享链接 + 状态标签（有效/过期）+ 浏览/下载次数
- 状态标签用 `Chip`：有效=`success`，过期=`neutral400`
- 空态：`EmptyState(icon: Icons.share_outlined, title: '暂无分享')`

#### share_detail_page.dart
- 顶部 `GradientHeader` 展示分享名 + 创建时间
- 文件列表用 `AppListTile`
- 底部"保存到我的网盘"按钮 + `shadowBrand`

#### settings_page.dart
- 分组卡片：
  ```dart
  _SettingsGroup(
    title: '账号',
    children: [
      AppListTile(leading: Icon(Icons.lock_outline), title: '修改密码', trailing: Icon(Icons.chevron_right), onTap: _changePassword),
      AppListTile(leading: Icon(Icons.devices), title: '登录设备', trailing: Icon(Icons.chevron_right), onTap: ...),
    ],
  )
  ```
- `_SettingsGroup` = `Padding` + 小标题 `bodySmall textSecondary` + `AppCard` 包裹多个 `AppListTile`（中间用 `Divider`）
- 顶部账号卡片：`AppCard` + `CircleAvatar`(渐变) + 用户名 + 邮箱

#### notification_page.dart
- 通知卡片：`AppCard` + 图标 + 标题 + 内容 + 时间
- 未读：左侧 `brandPrimary` 圆点；已读：整条 `opacity: 0.6`
- 顶部"全部已读"按钮
- 空态：`EmptyState(icon: Icons.notifications_none, title: '暂无通知')`

#### upload_task_page.dart
- 任务卡片：`AppCard` + 文件名 + 进度条(`dataGradient`) + 状态标签(排队/上传中/完成/失败)
- 失败项加"重试"按钮
- 空态：`EmptyState(icon: Icons.cloud_upload_outlined, title: '暂无上传任务')`

### 4.3 批次 3 · 预览页与工具页

#### image_preview_page.dart
- `AppBar` 改为透明 + 渐隐（`backgroundColor: Colors.transparent` + `elevation: 0`）
- 底部加翻页指示器：`"$index+1 / $total"` 圆角胶囊背景
- `CachedNetworkImage` 加载态用 `SkeletonBox`（全屏）
- `PageView` 替代手动点击翻页，支持滑动

#### video_preview_page.dart
- 沉浸式：`SystemChrome.setEnabledSystemUIMode` 隐藏状态栏
- 控制层半透明黑 + 圆角按钮
- 加载态骨架

#### audio_preview_page.dart
- 顶部渐变背景（`brandGradient`）+ 唱片封面旋转动画
- 进度条用 `dataGradient` + `radiusFull`
- 播放/暂停按钮圆形 + `shadowBrand`

#### pdf_preview_page.dart / office_preview_page.dart / xmind_preview_page.dart
- 加载态：`CardSkeleton` 或自定义全屏骨架
- `AppBar` 加页码指示

#### text_preview_page.dart
- 代码风格：`neutral50` 背景 + 等宽字体 + 行号（`neutral400`）+ `radiusMd` 圆角容器
- 普通文本：`surface` 背景 + `radiusLg` + `space16` padding + `bodyLarge`

#### csv_preview_page.dart
- 表格头：`brandPrimary` 背景 + 白字 + `w600`
- 斑马纹：奇数行 `neutral50`，偶数行 `neutral0`
- 单元格 padding `space8/space12` + `divider` 边框

#### dedup_page.dart
- 重复组卡片：`AppCard` + 缩略图对比 + 文件信息 + "保留此项"按钮
- 危险操作用 `error` 色

#### device_page.dart
- 设备卡片：`AppCard` + 设备图标 + 名称 + 最后登录时间 + 在线/离线标签
- 在线标签：`success` 圆点；离线：`neutral400` 圆点

#### offline_page.dart
- 任务卡片：`AppCard` + URL + 进度 + 状态
- 空态：`EmptyState(icon: Icons.cloud_download_outlined, title: '暂无离线任务')`

#### vault_page.dart
- 顶部安全感卡片：`GradientHeader`（用深色渐变 `neutral900 → brandPrimaryDark`）+ 盾牌图标
- 解锁态：文件列表（同 home_page 风格）
- 锁定态：密码输入卡片

#### version_history_page.dart
- 时间轴样式：左侧竖线 + 圆点节点 + 右侧 `AppCard`（版本号 + 时间 + "恢复"按钮）
- 当前版本节点用 `brandPrimary` 实心圆，历史版本用 `neutral300` 空心圆

#### ai_assistant_page.dart
- 顶部 `GradientHeader` + AI 图标 + "智能助手"
- 对话气泡：用户消息右对齐 `brandPrimary` 背景 + 白字；AI 消息左对齐 `surface` + `shadowSm` + `radiusLg`
- 输入框底部固定 + 圆角 `radiusFull`

---

## 5. 执行约束（务必遵守）

1. **不破坏功能**：只改视觉与交互层，不改业务逻辑、Provider、Service。
2. **不破坏测试**：`test/` 下的测试不能因改造而失败。若测试依赖具体 Widget 结构，需同步更新测试。
3. **`flutter analyze` 0 错误**：每改完一个文件，跑 `flutter analyze lib/` 确认无新增错误。
4. **Token 化**：禁止新增硬编码颜色/间距/圆角。所有视觉数值走 `AppTokens`。
5. **组件化**：禁止新增裸 `Card`/`ListTile`/`CircularProgressIndicator`（加载态），改用 `AppCard`/`AppListTile`/骨架屏。
6. **路由**：新增跳转用 `AppTokens.route(page)` 替代 `MaterialPageRoute`（已有跳转可逐步替换，不强制一次全改）。
7. **暗色模式**：所有改造必须同时验证浅色与暗色模式。颜色一律通过 `AppTokens.surface(brightness)` 等带亮度参数的 API 取值。
8. **小步提交**：每完成一个页面即可作为一个独立提交点，便于回滚。

---

## 6. 自检清单

每完成一个页面，对照下表自检：

| 检查项 | 通过标准 |
|--------|---------|
| 硬编码颜色 | 全文搜索 `Color(0x` 无业务新增（仅 Token 文件允许） |
| 硬编码间距 | 全文搜索 `SizedBox(height: 1[0-9]` / `padding: EdgeInsets` 核对是否用 Token |
| 空状态 | 是否使用 `EmptyState` 组件 |
| 加载态 | 是否使用骨架屏（非 `CircularProgressIndicator`，按钮内除外） |
| 卡片 | 是否使用 `AppCard` |
| 列表项 | 是否使用 `AppListTile`/`AppListItem` |
| 暗色模式 | 在 `AppTheme.dark` 下视觉是否正常（手动想象或截图） |
| 字号 | 是否来自 `AppTokens` 字号梯度 |
| 阴影 | 浮起元素是否有 `shadowMd` 以上 |
| 跳转 | 新增跳转是否用 `AppTokens.route()` |
| analyze | `flutter analyze lib/` 0 错误 |

---

## 7. 执行顺序建议

1. 先执行批次 1 剩余 4 页（register / forgot_password / home / dashboard），跑 `flutter analyze` 确认。
2. 再执行批次 2 共 8 页，每 2-3 页跑一次 analyze。
3. 最后执行批次 3 共 14 页，预览页可批量处理（结构相似）。
4. 全部完成后跑 `flutter analyze` + `flutter test test/models_test.dart test/utils_test.dart` 确认无回归。

> **登录页 `login_page.dart` 已完成，可作为视觉样板参考。**
