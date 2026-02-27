import 'package:flutter/material.dart';

void main() {
  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: TestWalletUI());
  }
}

class TestWalletUI extends StatelessWidget {
  final double walletBalance = 500.0;
  final double evRate = 12.0;
  final double socketRate = 8.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("Test Dashboard"),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Wallet Balance & Tariff Rates Info
            Row(
              children: [
                // Wallet Balance Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007BFF).withOpacity(0.1),
                      border: Border.all(color: const Color(0xFF007BFF)),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet,
                              color: Color(0xFF007BFF),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Wallet Balance',
                              style: TextStyle(
                                color: Color(0xFF007BFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${walletBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF007BFF),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Tariff Rates Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28A745).withOpacity(0.1),
                      border: Border.all(color: const Color(0xFF28A745)),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.local_offer,
                              color: Color(0xFF28A745),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Tariff Rates',
                              style: TextStyle(
                                color: Color(0xFF28A745),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EV: ₹${evRate.toStringAsFixed(0)}/kWh',
                          style: const TextStyle(
                            color: Color(0xFF28A745),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Socket: ₹${socketRate.toStringAsFixed(0)}/kWh',
                          style: const TextStyle(
                            color: Color(0xFF28A745),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
