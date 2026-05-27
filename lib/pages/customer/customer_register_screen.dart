import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yjeek/auth_service.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/abstract_user.dart';
import 'package:yjeek/models/customer.dart';
import 'package:yjeek/models/customer_address.dart';
import 'package:yjeek/pages/customer/add_address_screen.dart';
import 'package:yjeek/pages/start_screen.dart';
import 'package:yjeek/utils/id_generator.dart';
import 'package:yjeek/utils/validators.dart';
import 'package:yjeek/widgets/app_snack.dart';

class CustomerRegisterScreen extends StatefulWidget {
  const CustomerRegisterScreen({super.key, required this.email});
  final String email;

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  String? nameErrorText;
  String? phoneErrorText;
  String? _locationError;
  String? errorText;

  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  CustomerAddress? _selectedAddress;
  bool isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void validateData() async {
    setState(() {
      nameErrorText = null;
      phoneErrorText = null;
      _locationError = null;
      errorText = null;
    });

    final nameError = Validators.validateName(_nameCtrl.text.trim());
    final phoneError = Validators.validatePhone(_phoneCtrl.text.trim());

    if (nameError != null || phoneError != null || _selectedAddress == null) {
      setState(() {
        nameErrorText = nameError;
        phoneErrorText = phoneError;
        _locationError = _selectedAddress == null
            ? "Please choose your address on the map."
            : null;
      });
      return;
    }

    await _submit();
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.push<CustomerAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(
          existing: _selectedAddress,
          title: 'Delivery Address',
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _selectedAddress = result;
      _locationError = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    final db = DatabaseService();
    final phone = _phoneCtrl.text.trim();

    try {
      final existingUser = await db.getUserByPhone(phone);
      if (existingUser != null) {
        setState(() {
          isLoading = false;
          phoneErrorText = "Phone number already exists. Please login.";
        });
        return;
      }

      final customer = Customer(
        id: IdGenerator.generateUserId(UserRole.customer),
        phone: phone,
        email: widget.email,
        name: _nameCtrl.text.trim(),
        location: _selectedAddress!.location,
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.createUser(customer.toJson());

      await db.addCustomerAddress(
        customerId: customer.id,
        address: _selectedAddress!,
      );

      final authService = AuthService();
      await authService.sendMagicLink(widget.email);

      if (!mounted) return;

      showAppSnack(
        context,
        "Registration saved. A sign-in link was sent to ${widget.email}",
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StartScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        isLoading = false;
        errorText = "Something went wrong. Please try again.";
      });
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasAddress = _selectedAddress != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customer Registration',
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
      body: AbsorbPointer(
        absorbing: isLoading,
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text(
                  'Tell us about you',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (errorText != null) ...[
                  Text(
                    errorText!,
                    style: TextStyle(color: scheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                _FieldLabel('Phone number'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  onChanged: (_) {
                    if (phoneErrorText != null) {
                      setState(() => phoneErrorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '5XXXXXXXX',
                    errorText: phoneErrorText,
                  ),
                ),
                const SizedBox(height: 18),
                _FieldLabel('Full name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (nameErrorText != null) {
                      setState(() => nameErrorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Cristiano Ronaldo',
                    errorText: nameErrorText,
                  ),
                ),
                const SizedBox(height: 22),
                _FieldLabel('Delivery address'),
                const SizedBox(height: 6),
                if (hasAddress)
                  Material(
                    color: scheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: InkWell(
                      onTap: _pickAddress,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Icon(Icons.place_outlined, color: scheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedAddress!.label.trim().isEmpty
                                        ? 'Selected address'
                                        : _selectedAddress!.label,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      _selectedAddress!.fullAddress,
                                      _selectedAddress!.buildingDetails,
                                    ]
                                        .where((e) => e.trim().isNotEmpty)
                                        .join('\n'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.edit_outlined,
                              color: scheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _pickAddress,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text(
                        'Choose address on map',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerLowest,
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _locationError!,
                      style: TextStyle(
                        color: scheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: isLoading ? null : validateData,
                    child: isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Text('Register'),
                  ),
                ),
                if (hasAddress) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'You can add more addresses later in your profile.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
