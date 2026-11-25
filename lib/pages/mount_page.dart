import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../services/mount_service.dart';
import 'mount_browser_page.dart';

/// 外部存储挂载管理：只管理连接，不把外部对象写入主网盘配额。
class MountPage extends StatefulWidget {
  const MountPage({super.key});

  @override
  State<MountPage> createState() => _MountPageState();
}

class _MountPageState extends State<MountPage> {
  List<MountVO> _mounts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final mounts = await MountService.instance.list();
      if (!mounted) return;
      setState(() {
        _mounts = mounts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _edit([MountVO? mount]) async {
    final controllers = {
      'name': TextEditingController(text: mount?.name ?? ''),
      'endpoint': TextEditingController(text: mount?.endpoint ?? ''),
      'bucket': TextEditingController(text: mount?.bucket ?? ''),
      'accessKey': TextEditingController(text: mount?.accessKey ?? ''),
      'secretKey': TextEditingController(),
      'basePrefix': TextEditingController(text: mount?.basePrefix ?? ''),
    };
    var enabled = mount?.enabled ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(mount == null ? '新建挂载点' : '编辑挂载点'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in controllers.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: switch (entry.key) {
                            'name' => '名称',
                            'endpoint' => 'Endpoint（含 https://）',
                            'bucket' => 'Bucket',
                            'accessKey' => 'AccessKey',
                            'secretKey' => mount == null ? 'SecretKey' : 'SecretKey（留空不修改）',
                            _ => '基础前缀（可选）',
                          },
                        ),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用'),
                    value: enabled,
                    onChanged: (v) => setLocal(() => enabled = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final po = MountSave(
      id: mount?.id,
      name: controllers['name']!.text.trim(),
      endpoint: controllers['endpoint']!.text.trim(),
      bucket: controllers['bucket']!.text.trim(),
      accessKey: controllers['accessKey']!.text.trim(),
      secretKey: controllers['secretKey']!.text.trim(),
      basePrefix: controllers['basePrefix']!.text.trim(),
      enabled: enabled,
    );
    try {
      if (mount == null) {
        await MountService.instance.create(po);
      } else {
        await MountService.instance.update(po);
      }
      await _load();
      _toast('已保存');
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _test(MountVO mount) async {
    try {
      final message = await MountService.instance.testSaved(mount.id);
      _toast(message.isEmpty ? '连接正常' : message);
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _delete(MountVO mount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除挂载点'),
        content: const Text('只解除挂载，外部存储里的内容不会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MountService.instance.delete(mount.id);
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: const Text('外部存储'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: '刷新'),
          IconButton(onPressed: () => _edit(), icon: const Icon(Icons.add), tooltip: '新建挂载'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center, style: AppTokens.bodyMedium.copyWith(color: AppTokens.textPrimary(b))))
              : _mounts.isEmpty
                  ? Center(child: Text('暂无挂载点\n点击右上角添加 S3 兼容存储', textAlign: TextAlign.center, style: AppTokens.bodyMedium.copyWith(color: AppTokens.textSecondary(b))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _mounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final mount = _mounts[i];
                        return InkWell(
                          onTap: mount.enabled
                              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => MountBrowserPage(mount: mount)))
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTokens.surface(b),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTokens.divider(b)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(mount.name, style: AppTokens.titleMedium.copyWith(color: AppTokens.textPrimary(b))),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (mount.enabled ? AppTokens.success : AppTokens.warning).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        mount.enabled ? '已启用' : '已停用',
                                        style: AppTokens.labelSmall.copyWith(
                                          color: mount.enabled ? AppTokens.success : AppTokens.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${mount.bucket} · ${mount.endpoint}', style: AppTokens.bodySmall.copyWith(color: AppTokens.textSecondary(b))),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton(onPressed: () => _test(mount), child: const Text('测试')),
                                    TextButton(onPressed: () => _edit(mount), child: const Text('编辑')),
                                    const Spacer(),
                                    TextButton(onPressed: () => _delete(mount), child: const Text('删除', style: TextStyle(color: AppTokens.error))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
