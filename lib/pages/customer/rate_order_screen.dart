import 'package:flutter/material.dart';
import 'package:food_delivery_platform/models/order.dart';

class RateOrderSheet extends StatefulWidget {
  const RateOrderSheet({
    super.key,
    required this.order,
    required this.onSubmit,
  });

  final Order order;
  final Future<void> Function({
    required int restaurantRating,
    required int driverRating,
  })
  onSubmit;

  @override
  State<RateOrderSheet> createState() => _RateOrderSheetState();
}

class _RateOrderSheetState extends State<RateOrderSheet> {
  int _restaurantRating = 0;
  int _driverRating = 0;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_restaurantRating == 0 || _driverRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please rate both the restaurant and the driver'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(
        restaurantRating: _restaurantRating,
        driverRating: _driverRating,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your rating')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildStars({
    required int currentValue,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return IconButton(
          onPressed: () => onChanged(starValue),
          icon: Icon(
            starValue <= currentValue ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Rate Your Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Restaurant Rating',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildStars(
                currentValue: _restaurantRating,
                onChanged: (value) {
                  setState(() => _restaurantRating = value);
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Driver Rating',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildStars(
                currentValue: _driverRating,
                onChanged: (value) {
                  setState(() => _driverRating = value);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Rating'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
