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
        builder: (_) => const AddAddressScreen(),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Registration saved. A sign-in link was sent to ${widget.email}",
          ),
        ),
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
    return Scaffold(
      appBar: AppBar(title: const Text("Customer Registration")),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Fill customer details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),

                if (errorText != null) ...[
                  Text(errorText!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: InputDecoration(
                    labelText: "Phone number",
                    hintText: "5XXXXXXXX",
                    prefixIcon: const Icon(Icons.phone),
                    errorText: phoneErrorText,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Full name",
                    hintText: "Cristiano Ronaldo",
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: nameErrorText,
                  ),
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _pickAddress,
                  icon: Icon(
                    _selectedAddress != null
                        ? Icons.location_on
                        : Icons.map_outlined,
                    color: _selectedAddress != null ? Colors.green : null,
                  ),
                  label: Text(
                    _selectedAddress != null
                        ? "Address Selected"
                        : "Choose Address on Map",
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _selectedAddress != null
                        ? Colors.green
                        : null,
                  ),
                ),
                if (_selectedAddress != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(_selectedAddress!.label),
                      subtitle: Text(
                        [
                          _selectedAddress!.fullAddress,
                          _selectedAddress!.buildingDetails,
                        ].where((e) => e.trim().isNotEmpty).join('\n'),
                      ),
                      isThreeLine: _selectedAddress!.buildingDetails
                          .trim()
                          .isNotEmpty,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: _pickAddress,
                      ),
                    ),
                  ),
                ],
                if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _locationError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: validateData,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Register"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
