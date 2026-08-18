import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_service.dart';
import '../widgets/responsive.dart';

/// 设备管理页
class DevicePage extends ConsumerStatefulWidget {
  const DevicePage({super.key});

  @override
  ConsumerState<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends ConsumerState<DevicePage> {
  List<DeviceInfo> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await DeviceService.instance.list();
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logoutDevice(DeviceInfo device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下线设备'),
        content: Text('确定将「${device.deviceName}」强制下线吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('下线'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await DeviceService.instance.logout(device.deviceId);
      _toast('已下线该设备');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录设备')),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败：$_error'));
    }
    if (_devices.isEmpty) {
      return const Center(child: Text('暂无设备记录'));
    }
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (ctx, i) {
        final device = _devices[i];
        return ListTile(
          leading: Icon(
            device.isCurrent ? Icons.phone_android : Icons.devices,
            color: device.isCurrent
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  device.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (device.isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '当前设备',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '${device.os} · ${device.browser}\n${device.ip} ${device.location}\n登录于 ${device.lastLoginTime}',
            style: const TextStyle(fontSize: 12),
          ),
          isThreeLine: true,
          trailing: device.isCurrent
              ? null
              : IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  tooltip: '下线',
                  onPressed: () => _logoutDevice(device),
                ),
        );
      },
    );
  }
}
