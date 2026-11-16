import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/network/http_client.dart';
import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/user_service.dart';
import '../widgets/empty_state.dart';

/// 图片在线编辑页
///
/// 支持旋转、水平/垂直翻转、自由裁剪；保存走 PUT /file/content（乐观锁）。
class ImageEditPage extends StatefulWidget {
  const ImageEditPage({super.key, required this.file});

  final FileVO file;

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  static const int _maxPixels = 16000000;
  static const Set<String> _editableSuffixes = {'jpg', 'jpeg', 'png'};

  Uint8List? _bytes;
  int _imageWidth = 0;
  int _imageHeight = 0;
  int _version = 1;

  int _quarterTurns = 0;
  bool _flipH = false;
  bool _flipV = false;
  bool _cropMode = false;
  Rect _crop = const Rect.fromLTWH(0, 0, 1, 1);

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _locked = false;
  bool _unsupported = false;
  String? _error;

  String _lockToken = '';
  Timer? _heartbeat;

  String get _suffix {
    final name = widget.file.filename.toLowerCase();
    final i = name.lastIndexOf('.');
    return i >= 0 ? name.substring(i + 1) : '';
  }

  bool get _isPng => _suffix == 'png';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _locked = false;
      _unsupported = false;
    });
    try {
      if (!_editableSuffixes.contains(_suffix)) {
        setState(() {
          _loading = false;
          _unsupported = true;
          _error = '该图片格式暂不支持在线编辑（支持 JPG/PNG）';
        });
        return;
      }

      final detail = await FileService.instance.getDetail(widget.file.fileId);
      _version = detail.version;

      try {
        final session =
            await FileService.instance.acquireEditSession(widget.file.fileId);
        _lockToken = session.lockToken;
        _version = session.version;
        _startHeartbeat();
      } on ApiException catch (e) {
        if (e.code == 423) {
          setState(() {
            _loading = false;
            _locked = true;
            _error = e.message;
          });
          return;
        }
        rethrow;
      }

      final bytes = await FileService.instance.fetchRawBytes(widget.file.fileId);
      final size = await Isolate.run(() => _decodeSize(bytes));
      if (size == null || size[0] * size[1] > _maxPixels) {
        setState(() {
          _loading = false;
          _unsupported = true;
          _error = '图片像素过大，暂不支持在线编辑';
        });
        return;
      }

      if (mounted) {
        setState(() {
          _bytes = bytes;
          _imageWidth = size[0];
          _imageHeight = size[1];
          _quarterTurns = 0;
          _flipH = false;
          _flipV = false;
          _crop = const Rect.fromLTWH(0, 0, 1, 1);
          _cropMode = false;
          _dirty = false;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ApiException ? e.message : e.toString();
        });
      }
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        final session =
            await FileService.instance.acquireEditSession(widget.file.fileId);
        _lockToken = session.lockToken;
      } catch (_) {
        // 网络异常时等待下一次心跳
      }
    });
  }

  void _releaseLock() {
    _heartbeat?.cancel();
    _heartbeat = null;
    if (_lockToken.isEmpty) return;
    final token = _lockToken;
    _lockToken = '';
    FileService.instance
        .releaseEditSession(fileId: widget.file.fileId, lockToken: token)
        .catchError((_) => null);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('未保存的修改'),
        content: const Text('当前图片修改尚未保存，确定离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('离开'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  void dispose() {
    _releaseLock();
    super.dispose();
  }

  // ─── 编辑操作 ───────────────────────────────────────────────────────────

  void _rotate(int delta) {
    setState(() {
      _quarterTurns = (_quarterTurns + delta) % 4;
      _dirty = true;
    });
  }

  void _toggleFlipH() => setState(() {
        _flipH = !_flipH;
        _dirty = true;
      });

  void _toggleFlipV() => setState(() {
        _flipV = !_flipV;
        _dirty = true;
      });

  void _toggleCrop() {
    setState(() {
      _cropMode = !_cropMode;
      if (_cropMode && _crop.width >= 0.999 && _crop.height >= 0.999) {
        _crop = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
        _dirty = true;
      }
    });
  }

  void _reset() {
    setState(() {
      _quarterTurns = 0;
      _flipH = false;
      _flipV = false;
      _crop = const Rect.fromLTWH(0, 0, 1, 1);
      _cropMode = false;
      _dirty = false;
    });
  }

  void _moveCrop(Offset delta, double w, double h) {
    final dx = delta.dx / w;
    final dy = delta.dy / h;
    final left = (_crop.left + dx).clamp(0.0, 1.0 - _crop.width).toDouble();
    final top = (_crop.top + dy).clamp(0.0, 1.0 - _crop.height).toDouble();
    setState(() {
      _crop = Rect.fromLTWH(left, top, _crop.width, _crop.height);
      _dirty = true;
    });
  }

  void _resizeCrop(_Corner corner, Offset delta, double w, double h) {
    const minPx = 32.0;
    var left = _crop.left * w;
    var top = _crop.top * h;
    var right = _crop.right * w;
    var bottom = _crop.bottom * h;

    if (corner == _Corner.nw || corner == _Corner.sw) {
      left = (left + delta.dx).clamp(0.0, right - minPx).toDouble();
    }
    if (corner == _Corner.ne || corner == _Corner.se) {
      right = (right + delta.dx).clamp(left + minPx, w).toDouble();
    }
    if (corner == _Corner.nw || corner == _Corner.ne) {
      top = (top + delta.dy).clamp(0.0, bottom - minPx).toDouble();
    }
    if (corner == _Corner.sw || corner == _Corner.se) {
      bottom = (bottom + delta.dy).clamp(top + minPx, h).toDouble();
    }

    setState(() {
      _crop = Rect.fromLTRB(left / w, top / h, right / w, bottom / h);
      _dirty = true;
    });
  }

  // ─── 保存 ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || _saving) return;
    setState(() => _saving = true);
    try {
      final quarter = _quarterTurns;
      final flipH = _flipH;
      final flipV = _flipV;
      final left = _crop.left;
      final top = _crop.top;
      final width = _crop.width;
      final height = _crop.height;
      final png = _isPng;

      final result = await Isolate.run(() => _encodeEditedImage(
            bytes,
            quarter,
            flipH,
            flipV,
            left,
            top,
            width,
            height,
            png,
          ));
      final (resultBytes, resultWidth, resultHeight) = result;

      final saved = await FileService.instance.saveContentBytes(
        fileId: widget.file.fileId,
        baseVersion: _version,
        bytes: resultBytes,
        filename: widget.file.filename,
      );

      if (!mounted) return;
      setState(() {
        _bytes = resultBytes;
        _imageWidth = resultWidth;
        _imageHeight = resultHeight;
        _version = saved.version;
        _quarterTurns = 0;
        _flipH = false;
        _flipV = false;
        _crop = const Rect.fromLTWH(0, 0, 1, 1);
        _cropMode = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 409) {
        await _handleConflict();
      } else if (e.code == 423) {
        setState(() {
          _locked = true;
          _error = e.message;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleConflict() async {
    final reload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存冲突'),
        content: const Text('图片已被其他端修改。加载最新内容会丢弃你当前的未保存修改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('保留我的修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('加载最新内容'),
          ),
        ],
      ),
    );
    if (reload != true) return;
    try {
      final detail = await FileService.instance.getDetail(widget.file.fileId);
      final bytes =
          await FileService.instance.fetchRawBytes(widget.file.fileId);
      final size = await Isolate.run(() => _decodeSize(bytes));
      if (size == null) throw Exception('图片解码失败');
      if (!mounted) return;
      setState(() {
        _version = detail.version;
        _bytes = bytes;
        _imageWidth = size[0];
        _imageHeight = size[1];
        _quarterTurns = 0;
        _flipH = false;
        _flipV = false;
        _crop = const Rect.fromLTWH(0, 0, 1, 1);
        _cropMode = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已加载最新内容')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载最新内容失败：$e')),
        );
      }
    }
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) {
          _releaseLock();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.file.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                _dirty ? 'v$_version · 未保存' : 'v$_version',
                style: TextStyle(
                  fontSize: 11,
                  color: _dirty ? AppTokens.warning : AppTokens.neutral400,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '保存',
              onPressed: _loading || _saving || !_dirty ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: _locked
            ? Icons.lock_outline
            : _unsupported
                ? Icons.edit_off_outlined
                : Icons.error_outline,
        title: _locked
            ? '暂时无法编辑'
            : _unsupported
                ? '暂不支持编辑'
                : '加载失败',
        subtitle: _error,
        actionLabel: _locked ? '重试' : null,
        onAction: _locked ? _bootstrap : null,
        actionIcon: Icons.refresh,
      );
    }

    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        _buildToolbar(brightness),
        Expanded(
          child: ColoredBox(
            color: brightness == Brightness.dark
                ? AppTokens.darkBg
                : AppTokens.neutral100,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_bytes == null || _imageWidth <= 0 || _imageHeight <= 0) {
                  return const SizedBox.shrink();
                }
                final swapped = _quarterTurns.isOdd;
                final srcW = swapped ? _imageHeight : _imageWidth;
                final srcH = swapped ? _imageWidth : _imageHeight;
                final maxW = constraints.maxWidth - 32;
                final maxH = constraints.maxHeight - 32;
                if (maxW <= 0 || maxH <= 0) return const SizedBox.shrink();
                final scale = math.min(maxW / srcW, maxH / srcH);
                final w = srcW * scale;
                final h = srcH * scale;
                return Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: ClipRect(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Transform.scale(
                              scaleX: _flipH ? -1 : 1,
                              scaleY: _flipV ? -1 : 1,
                              child: RotatedBox(
                                quarterTurns: _quarterTurns,
                                child: Image.memory(
                                  _bytes!,
                                  fit: BoxFit.fill,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                          ),
                          if (_cropMode) _buildCropOverlay(w, h),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_cropMode)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
            child: Text(
              '拖动框内移动，拖动四角缩放',
              style: AppTokens.bodySmall.copyWith(
                color: AppTokens.textSecondary(brightness),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToolbar(Brightness brightness) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space4),
      decoration: BoxDecoration(
        color: AppTokens.surface(brightness),
        border: Border(
          bottom: BorderSide(
            color: AppTokens.divider(brightness).withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8),
        child: Row(
          children: [
            _toolButton(Icons.rotate_left, '左转', () => _rotate(-1)),
            _toolButton(Icons.rotate_right, '右转', () => _rotate(1)),
            _toolButton(Icons.flip, '水平翻转', _toggleFlipH),
            _toolButton(
              null,
              '垂直翻转',
              _toggleFlipV,
              iconWidget: Transform.rotate(
                angle: math.pi / 2,
                child: const Icon(Icons.flip, size: 20),
              ),
            ),
            _toolButton(
              Icons.crop,
              _cropMode ? '完成裁剪' : '裁剪',
              _toggleCrop,
              active: _cropMode,
            ),
            _toolButton(Icons.restart_alt, '重置', _reset),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(
    IconData? icon,
    String label,
    VoidCallback onTap, {
    Widget? iconWidget,
    bool active = false,
  }) {
    final brightness = Theme.of(context).brightness;
    final color =
        active ? AppTokens.brandPrimary : AppTokens.textSecondary(brightness);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: SizedBox(
        width: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(color: color, size: 20),
                child: iconWidget ?? Icon(icon),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: AppTokens.labelSmall.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropOverlay(double w, double h) {
    final left = _crop.left * w;
    final top = _crop.top * h;
    final cw = _crop.width * w;
    final ch = _crop.height * h;

    return Positioned.fill(
      child: Stack(
        children: [
          // 四周遮罩
          Positioned(left: 0, top: 0, width: w, height: top,
              child: const ColoredBox(color: Colors.black54)),
          Positioned(left: 0, top: top + ch, width: w, height: h - top - ch,
              child: const ColoredBox(color: Colors.black54)),
          Positioned(left: 0, top: top, width: left, height: ch,
              child: const ColoredBox(color: Colors.black54)),
          Positioned(left: left + cw, top: top, width: w - left - cw, height: ch,
              child: const ColoredBox(color: Colors.black54)),
          // 裁剪框（拖动移动）
          Positioned(
            left: left,
            top: top,
            width: cw,
            height: ch,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => _moveCrop(d.delta, w, h),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
          // 四角手柄
          _cornerHandle(_Corner.nw, left, top, w, h),
          _cornerHandle(_Corner.ne, left + cw, top, w, h),
          _cornerHandle(_Corner.se, left + cw, top + ch, w, h),
          _cornerHandle(_Corner.sw, left, top + ch, w, h),
        ],
      ),
    );
  }

  Widget _cornerHandle(_Corner corner, double x, double y, double w, double h) {
    return Positioned(
      left: x - 12,
      top: y - 12,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _resizeCrop(corner, d.delta, w, h),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Corner { nw, ne, se, sw }

/// 解码图片尺寸（isolate 中执行，避免阻塞 UI）
List<int>? _decodeSize(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) return null;
  // 与 Flutter Image 的显示行为保持一致：先应用 EXIF 方向
  image = img.bakeOrientation(image);
  return [image.width, image.height];
}

/// 在 isolate 中应用旋转/翻转/裁剪并重新编码
(Uint8List, int, int) _encodeEditedImage(
  Uint8List bytes,
  int quarterTurns,
  bool flipH,
  bool flipV,
  double left,
  double top,
  double width,
  double height,
  bool png,
) {
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw StateError('图片解码失败');
  }
  // 预览端 Flutter 会自动应用 EXIF 方向，保存端必须先烘焙方向，保证裁剪坐标一致
  image = img.bakeOrientation(image);
  if (quarterTurns % 4 != 0) {
    image = img.copyRotate(image, angle: quarterTurns * 90);
  }
  if (flipH) {
    image = img.flipHorizontal(image);
  }
  if (flipV) {
    image = img.flipVertical(image);
  }
  final x = (left * image.width).round().clamp(0, image.width - 1).toInt();
  final y = (top * image.height).round().clamp(0, image.height - 1).toInt();
  final cw = (width * image.width).round().clamp(1, image.width - x).toInt();
  final ch = (height * image.height).round().clamp(1, image.height - y).toInt();
  image = img.copyCrop(image, x: x, y: y, width: cw, height: ch);
  final encoded = png ? img.encodePng(image) : img.encodeJpg(image, quality: 92);
  return (encoded, image.width, image.height);
}
