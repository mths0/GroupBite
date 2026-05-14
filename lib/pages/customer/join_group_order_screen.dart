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

    if (code.isEmpty) return;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Group Order'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: MobileScanner(
                      controller: controller,
                      onDetect: _joinWithBarcode,
                    ),
                  ),

                  // Positioned(
                  //   top: 12,
                  //   left: 12,
                  //   right: 12,
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //     children: [
                  //       IconButton(
                  //         icon: const Icon(Icons.close, color: Colors.white),
                  //         onPressed: () => Navigator.pop(context),
                  //       ),
                  //       // ValueListenableBuilder(
                  //       //   valueListenable: controller,
                  //       //   builder: (context, state, child) {
                  //       //     return IconButton(
                  //       //       icon: Icon(
                  //       //         state.torchState == TorchState.on
                  //       //             ? Icons.flash_on
                  //       //             : Icons.flash_off,
                  //       //         color: Colors.white,
                  //       //       ),
                  //       //       onPressed: () => controller.toggleTorch(),
                  //       //     );
                  //       //   },
                  //       // ),
                  //     ],
                  //   ),
                  // ),
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Group Code',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            FilledButton(
              onPressed: _isLoading ? null : _join,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}
