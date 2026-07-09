import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  final String boxId;
  final String boxLocation;
  final Map<String, dynamic> tariff;

  const BookingScreen({
    super.key,
    required this.boxId,
    required this.boxLocation,
    required this.tariff,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final BookingService _bookingService = BookingService();

  // Form state
  String _selectedDevice = 'evCharger';
  int _selectedDurationMinutes = 60;
  DateTime _scheduledTime = DateTime.now().add(const Duration(minutes: 30));
  String _notes = '';
  bool _isBooking = false;
  String? _availabilityError;

  final _notesController = TextEditingController();
  Timer? _availabilityDebounce;

  @override
  void dispose() {
    _notesController.dispose();
    _availabilityDebounce?.cancel();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  bool get _isTimeValid {
    final now = DateTime.now();
    final diff = _scheduledTime.difference(now);
    return !diff.isNegative && diff.inMinutes <= 180;
  }

  String get _lockTime {
    final lock = _scheduledTime.subtract(const Duration(minutes: 30));
    return '${lock.hour.toString().padLeft(2, '0')}:${lock.minute.toString().padLeft(2, '0')}';
  }

  String get _expiryTime {
    final expiry = _scheduledTime.add(const Duration(minutes: 15));
    return '${expiry.hour.toString().padLeft(2, '0')}:${expiry.minute.toString().padLeft(2, '0')}';
  }

  double get _evRate =>
      (widget.tariff['evRate'] as num?)?.toDouble() ?? 12.0;
  double get _socketRate =>
      (widget.tariff['socketRate'] as num?)?.toDouble() ?? 8.0;

  // ─── Pickers ─────────────────────────────────────────────────────────────────

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final maxTime = now.add(const Duration(hours: 3));

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime),
      helpText: 'Select charging start time (within next 3 hours)',
    );

    if (picked == null) return;

    final candidate = DateTime(
      now.year, now.month, now.day, picked.hour, picked.minute,
    );

    // If picked time is earlier today, assume tomorrow
    final adjusted = candidate.isBefore(now)
        ? candidate.add(const Duration(days: 1))
        : candidate;

    if (adjusted.isAfter(maxTime)) {
      _showError('Please select a time within the next 3 hours.');
      return;
    }

    setState(() {
      _scheduledTime = adjusted;
      _availabilityError = null;
    });

    _checkAvailability();
  }

  void _checkAvailability() {
    _availabilityDebounce?.cancel();
    _availabilityDebounce = Timer(const Duration(milliseconds: 500), () async {
      // Simple optimistic check — full conflict check happens in createBooking
      setState(() => _availabilityError = null);
    });
  }

  // ─── Booking ─────────────────────────────────────────────────────────────────

  Future<void> _confirmBooking() async {
    if (!_isTimeValid) {
      _showError('Please select a valid time (within the next 3 hours).');
      return;
    }

    setState(() => _isBooking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final userName = await BookingService.getCurrentUserName();

      final bookingId = await _bookingService.createBooking(
        boxId: widget.boxId,
        userId: user.uid,
        userName: userName,
        deviceType: _selectedDevice,
        scheduledChargingTime: _scheduledTime,
        estimatedDurationMinutes: _selectedDurationMinutes,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        _showSuccessDialog(bookingId);
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(String bookingId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 28),
            SizedBox(width: 8),
            Text('Booking Confirmed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.ev_station, 'Box', widget.boxId.toUpperCase()),
            _infoRow(Icons.location_on, 'Location', widget.boxLocation),
            _infoRow(
              Icons.cable,
              'Device',
              _selectedDevice == 'evCharger' ? 'EV Charger' : '3-Pin Socket',
            ),
            _infoRow(
              Icons.access_time,
              'Charging starts',
              '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
            ),
            const Divider(),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔒 Box locks at $_lockTime',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warning),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '⏳ Auto-expires at $_expiryTime if unused',
                    style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, bookingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final scheduledFormatted =
        '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Book a Charging Slot'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Box header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              decoration: AppTheme.cardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.boxId.toUpperCase(),
                      style: AppTheme.headingSmall
                          .copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(widget.boxLocation,
                            style: AppTheme.bodySmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _tariffBadge(
                          'EV ₹${_evRate.toStringAsFixed(0)}/kWh',
                          Colors.blue),
                      const SizedBox(width: 8),
                      _tariffBadge(
                          'Socket ₹${_socketRate.toStringAsFixed(0)}/kWh',
                          Colors.teal),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingLarge),

            // Step 1: Device type
            _sectionLabel('1. Select Charging Device'),
            const SizedBox(height: AppTheme.spacingSmall),
            Row(
              children: [
                Expanded(
                  child: _deviceOption(
                    label: 'EV Charger',
                    icon: Icons.ev_station,
                    value: 'evCharger',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _deviceOption(
                    label: '3-Pin Socket',
                    icon: Icons.power,
                    value: 'threePinSocket',
                    color: Colors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingLarge),

            // Step 2: Time
            _sectionLabel('2. Scheduled Charging Time'),
            const SizedBox(height: AppTheme.spacingSmall),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                decoration: BoxDecoration(
                  color: _isTimeValid
                      ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                      : AppTheme.error.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: _isTimeValid
                        ? AppTheme.primaryBlue
                        : AppTheme.error,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: _isTimeValid
                            ? AppTheme.primaryBlue
                            : AppTheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scheduledFormatted,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _isTimeValid
                                  ? AppTheme.primaryBlue
                                  : AppTheme.error,
                            ),
                          ),
                          Text(
                            _isTimeValid
                                ? 'Tap to change · max 3h ahead'
                                : 'Invalid time — pick within 3 hours',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isTimeValid
                                  ? theme.colorScheme.onSurfaceVariant
                                  : AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),

            if (_isTimeValid) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Box locks at $_lockTime · Auto-expires at $_expiryTime',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppTheme.spacingLarge),

            // Step 3: Duration estimate
            _sectionLabel('3. Estimated Duration'),
            const SizedBox(height: AppTheme.spacingSmall),
            Wrap(
              spacing: 8,
              children: [30, 60, 90, 120].map((min) {
                final label = min < 60
                    ? '${min}m'
                    : '${min ~/ 60}h${min % 60 != 0 ? '${min % 60}m' : ''}';
                return ChoiceChip(
                  label: Text(label),
                  selected: _selectedDurationMinutes == min,
                  onSelected: (_) =>
                      setState(() => _selectedDurationMinutes = min),
                  selectedColor:
                      AppTheme.primaryBlue.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _selectedDurationMinutes == min
                        ? AppTheme.primaryBlue
                        : null,
                    fontWeight: _selectedDurationMinutes == min
                        ? FontWeight.bold
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppTheme.spacingLarge),

            // Notes (optional)
            _sectionLabel('4. Notes (optional)'),
            const SizedBox(height: AppTheme.spacingSmall),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g., "Tesla Model 3, need fast charge"',
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium)),
              ),
            ),

            const SizedBox(height: AppTheme.spacingXLarge),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed:
                    (_isBooking || !_isTimeValid) ? null : _confirmBooking,
                icon: _isBooking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bookmark_add),
                label: Text(
                  _isBooking ? 'Booking...' : 'Confirm Booking',
                  style: AppTheme.labelLarge,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMedium),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
      );

  Widget _tariffBadge(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _deviceOption({
    required String label,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final selected = _selectedDevice == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedDevice = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? color : Colors.grey, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
