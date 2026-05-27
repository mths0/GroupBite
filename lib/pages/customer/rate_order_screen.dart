import 'package:flutter/material.dart';
import 'package:yjeek/models/order.dart';
import 'package:yjeek/widgets/app_snack.dart';

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
      showAppSnack(
        context,
        'Please rate both the restaurant and the driver',
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

      showAppSnack(context, 'Thank you for your rating');
    } catch (e) {
      if (!mounted) return;
      showAppError(context, 'Failed to submit rating: $e');
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = starValue <= currentValue;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: InkResponse(
            onTap: () => onChanged(starValue),
            radius: 26,
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 38,
              color: const Color(0xFFE9C176),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final bottomSafe = mq.padding.bottom;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset + bottomSafe),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Rate Your Order',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Restaurant Rating',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildStars(
              currentValue: _restaurantRating,
              onChanged: (value) {
                setState(() => _restaurantRating = value);
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Driver Rating',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildStars(
              currentValue: _driverRating,
              onChanged: (value) {
                setState(() => _driverRating = value);
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Rating',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
