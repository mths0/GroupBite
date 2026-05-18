import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/pages/customer/restaurant_menu_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class JoinGroupOrderScreen extends StatefulWidget {
  const JoinGroupOrderScreen({
    super.key,
    required this.customer,
    this.initialCode,
    this.autoJoin = false,
  });

  final Customer customer;
  final String? initialCode;
  final bool autoJoin;

  @override
  State<JoinGroupOrderScreen> createState() => _JoinGroupOrderScreenState();
}

class _JoinGroupOrderScreenState extends State<JoinGroupOrderScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _codeController = TextEditingController();
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 5000,
    formats: [BarcodeFormat.qrCode],
    returnImage: false,
    invertImage: false,
    autoZoom: false,
  );

  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;

      if (widget.autoJoin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _join();
        });
      }
    }
  }

  void _joinWithBarcode(BarcodeCapture capture) {
    if (_isLoading) return;

    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      final code = barcode.rawValue?.trim().toUpperCase();

      if (code != null && code.isNotEmpty) {
        _codeController.text = code;
        _join();
        break;
      }
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group code to join.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final groupOrderId = await _db.findGroupOrderIdByJoinCode(code);

      if (groupOrderId == null) {
        throw Exception('Invalid group order code.');
      }

      await _db.joinGroupOrder(
        groupOrderId: groupOrderId,
        customerId: widget.customer.id,
      );

      if (!mounted) return;

      final groupOrder = await _db.getGroupOrderById(groupOrderId);

      if (groupOrder == null) {
        throw Exception('Group order not found.');
      }

      final restaurant = await _db.getRestaurantById(groupOrder.restaurantId);

      if (restaurant == null) {
        throw Exception('Restaurant not found.');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantMenuPage(
            restaurant: restaurant,
            customer: widget.customer,
            groupOrderId: groupOrderId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Join Group Order',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MobileScanner(
                                controller: controller,
                                onDetect: _joinWithBarcode,
                              ),
                              Center(
                                child: LayoutBuilder(
                                  builder: (context, c) {
                                    final size = c.maxWidth * 0.78;
                                    return SizedBox(
                                      width: size,
                                      height: size,
                                      child: CustomPaint(
                                        painter: _ScannerFramePainter(
                                          frameColor: Colors.white,
                                          cornerColor: scheme.primary,
                                          radius: 28,
                                          stroke: 4,
                                          cornerLength: 28,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 24,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Scan QR Code to Join',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: scheme.outlineVariant,
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: scheme.outlineVariant,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter Group Code',
                          hintStyle: TextStyle(
                            letterSpacing: 0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(height: 1, color: scheme.outlineVariant),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _join,
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Join Group',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  _ScannerFramePainter({
    required this.frameColor,
    required this.cornerColor,
    required this.radius,
    required this.stroke,
    required this.cornerLength,
  });

  final Color frameColor;
  final Color cornerColor;
  final double radius;
  final double stroke;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final framePaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, framePaint);

    final cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final r = radius;
    final c = cornerLength;

    // Top-left
    final tlPath = Path()
      ..moveTo(0, r + c)
      ..lineTo(0, r)
      ..arcToPoint(
        Offset(r, 0),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(r + c, 0);
    canvas.drawPath(tlPath, cornerPaint);

    // Top-right
    final trPath = Path()
      ..moveTo(size.width - r - c, 0)
      ..lineTo(size.width - r, 0)
      ..arcToPoint(
        Offset(size.width, r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(size.width, r + c);
    canvas.drawPath(trPath, cornerPaint);

    // Bottom-right
    final brPath = Path()
      ..moveTo(size.width, size.height - r - c)
      ..lineTo(size.width, size.height - r)
      ..arcToPoint(
        Offset(size.width - r, size.height),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(size.width - r - c, size.height);
    canvas.drawPath(brPath, cornerPaint);

    // Bottom-left
    final blPath = Path()
      ..moveTo(r + c, size.height)
      ..lineTo(r, size.height)
      ..arcToPoint(
        Offset(0, size.height - r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(0, size.height - r - c);
    canvas.drawPath(blPath, cornerPaint);
  }

  @override
  bool shouldRepaint(_ScannerFramePainter oldDelegate) {
    return frameColor != oldDelegate.frameColor ||
        cornerColor != oldDelegate.cornerColor ||
        radius != oldDelegate.radius ||
        stroke != oldDelegate.stroke ||
        cornerLength != oldDelegate.cornerLength;
  }
}
