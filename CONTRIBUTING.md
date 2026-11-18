# 贡献指南

## 分支模型

- `main`：受保护分支，只接受 PR 合并
- `feat/*`、`fix/*`、`chore/*`：功能 / 修复 / 杂项分支
- 合并前必须通过 Required Checks，至少 1 名 Owner 评审

## 提交规范

使用 Conventional Commits：

```
feat(scope): 新功能
fix(scope): 缺陷修复
refactor(scope): 重构
perf(scope): 性能优化
test(scope): 测试
ci(scope): 流水线
docs(scope): 文档
chore(deps): 依赖
```

## 本地开发

```bash
# 安装提交前密钥扫描
brew install gitleaks
git config core.hooksPath .githooks

flutter pub get
flutter analyze
flutter test
flutter run
```

## 代码约定

详见 `AGENTS.md`。重点：

- 所有请求必须通过 `HttpClient.instance.request<T>()`
- 上传统一走 `UploadManager` 串行队列
- Riverpod state 用 `copyWith` 复制替换
- `code=10` 必须上抛，走全局重登录
- 页面异步回调中使用 `ref` / `context` 前检查 `mounted`
