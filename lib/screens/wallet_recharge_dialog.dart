import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class WalletRechargeDialog extends StatefulWidget {
  final String razorpayKey;

  const WalletRechargeDialog({super.key, required this.razorpayKey});

  @override
  State<WalletRechargeDialog> createState() => _WalletRechargeDialogState();
}

class _WalletRechargeDialogState extends State<WalletRechargeDialog> {
  final TextEditingController _amountController = TextEditingController();
  late Razorpay _razorpay;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final transactionId = response.paymentId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      
      await UserService().addMoneyToWallet(uid, amount, transactionId);
      
      if (mounted) {
        Navigator.pop(context, true); // Return true indicating success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet Recharge Successful!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating wallet: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet Selected: ${response.walletName}')),
    );
  }

  void _startPayment() {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount (Min: ₹10)')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    var options = {
      'key': widget.razorpayKey,
      'amount': (amount * 100).toInt(),
      'name': 'Smart Box',
      'description': 'Wallet Recharge',
      'prefill': {
        'contact': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
        'email': FirebaseAuth.instance.currentUser?.email ?? ''
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening Razorpay: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recharge Wallet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter the amount you wish to add to your wallet.'),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _startPayment,
          child: const Text('Proceed to Pay'),
        ),
      ],
    );
  }
}
