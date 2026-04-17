import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/auth_service.dart';

class QrScannerPage extends ConsumerStatefulWidget {
  const QrScannerPage({super.key});

  @override
  ConsumerState<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends ConsumerState<QrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final token = barcode.rawValue!;
        _handleScannedToken(token);
        return;
      }
    }
  }

  Future<void> _handleScannedToken(String token) async {
    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先登录后再使用扫码功能'),
            backgroundColor: AppColors.error,
          ),
        );
        context.pop();
      }
      return;
    }

    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.login_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('确认登录'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('是否确认在Web端登录？'),
            SizedBox(height: 8),
            Text(
              '确认后，Web端将使用您的账号身份登录',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认登录'),
          ),
        ],
      ),
    );

    if (shouldConfirm != true) {
      setState(() {
        _isProcessing = false;
        _hasScanned = false;
      });
      return;
    }

    try {
      final result = await ref.read(authServiceProvider).qrConfirm(token);
      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('扫码登录成功，Web端已登录'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '扫码确认失败'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isProcessing = false;
          _hasScanned = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('网络错误：$e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isProcessing = false;
          _hasScanned = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        title: const Text('扫一扫', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          _buildScanOverlay(),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('正在确认登录...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    final size = MediaQuery.of(context).size;
    final scanSize = size.width * 0.65;

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.black54,
            BlendMode.srcOver,
          ),
          child: Stack(
            children: [
              Container(color: Colors.transparent),
            ],
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 60),
              CustomPaint(
                size: Size(scanSize, scanSize),
                painter: _ScanBorderPainter(),
              ),
              const SizedBox(height: 24),
              const Text(
                '将二维码放入框内，即可自动扫描',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLen = 24.0;

    final path = Path();
    path.moveTo(0, cornerLen);
    path.lineTo(0, 0);
    path.lineTo(cornerLen, 0);

    path.moveTo(size.width - cornerLen, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, cornerLen);

    path.moveTo(size.width, size.height - cornerLen);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width - cornerLen, size.height);

    path.moveTo(cornerLen, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, size.height - cornerLen);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension PopContext on BuildContext {
  void pop<T>() => Navigator.of(this).pop<T>();
}
