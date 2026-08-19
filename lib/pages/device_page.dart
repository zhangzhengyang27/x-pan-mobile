import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/device_service.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
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
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const FileListSkeleton(itemCount: 4);
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        subtitle: _error,
        actionLabel: '重试',
        actionIcon: Icons.refresh,
        onAction: _load,
      );
    }
    if (_devices.isEmpty) {
      return const EmptyState(
        icon: Icons.devices_outlined,
        title: '暂无设备记录',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      itemCount: _devices.length,
      itemBuilder: (ctx, i) => _buildDevice(_devices[i], brightness),
    );
  }

  Widget _buildDevice(DeviceInfo device, Brightness b) {
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      elevation: CardElevation.low,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 设备图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: device.isCurrent
                  ? AppTokens.brandPrimary.withValues(alpha: 0.1)
                  : AppTokens.background(b),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Icon(
              device.isCurrent ? Icons.phone_android : Icons.devices,
              size: 22,
              color: device.isCurrent
                  ? AppTokens.brandPrimary
                  : AppTokens.textSecondary(b),
            ),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.titleMedium.copyWith(
                          color: AppTokens.textPrimary(b),
                        ),
                      ),
                    ),
                    if (device.isCurrent) ...[
                      const SizedBox(width: AppTokens.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTokens.brandPrimary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusFull,
                          ),
                        ),
                        child: const Text(
                          '当前设备',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTokens.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  '${device.os} · ${device.browser}',
                  style: AppTokens.bodySmall.copyWith(
                    color: AppTokens.textSecondary(b),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.ip} ${device.location}',
                  style: AppTokens.bodySmall.copyWith(
                    color: AppTokens.textTertiary(b),
                  ),
                ),
                const SizedBox(height: AppTokens.space8),
                // 登录时间 + 在线状态
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: device.isCurrent
                            ? AppTokens.success
                            : AppTokens.neutral400,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space8),
                    Text(
                      '登录于 ${device.lastLoginTime}',
                      style: AppTokens.labelSmall.copyWith(
                        color: AppTokens.textTertiary(b),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!device.isCurrent)
            IconButton(
              icon: const Icon(Icons.logout, color: AppTokens.error, size: 20),
              tooltip: '下线',
              onPressed: () => _logoutDevice(device),
            ),
        ],
      ),
    );
  }
}
