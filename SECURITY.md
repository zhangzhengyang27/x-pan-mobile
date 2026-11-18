# 安全策略

## 报告漏洞

请**不要**通过公开 Issue 报告安全问题。

请使用 GitHub 仓库的 **Security → Advisories → Report a vulnerability** 私密报告，并提供影响范围、复现步骤与潜在影响。

## 安全基线

- Token / API Key 只能存入 `flutter_secure_storage`
- 禁止在日志中输出 Token、密码、完整文件路径
- 生产包必须使用 release 签名；`usesCleartextTraffic` 仅限开发环境
- 提交前执行 `gitleaks protect --staged`，CI 强制执行 Secret Scan
- 依赖由 Dependabot 持续扫描
