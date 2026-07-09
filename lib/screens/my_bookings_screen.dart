import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../theme/app_theme.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final BookingService _bookingService = BookingService();
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Refresh countdown every minute
    _countdownTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content:
            Text('Cancel your booking for ${booking.boxId.toUpperCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _bookingService.cancelBooking(booking.bookingId, booking.boxId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: _bookingService.getMyBookings(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data ?? [];

          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border,
                      size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No bookings yet',
                      style: AppTheme.headingSmall
                          .copyWith(color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text(
                    'Find a box on the map and book a slot',
                    style: AppTheme.bodyMedium
                        .copyWith(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          // Group by status
          final active = bookings
              .where((b) =>
                  b.status == BookingStatus.active ||
                  b.status == BookingStatus.scheduled)
              .toList();
          final past = bookings
              .where((b) =>
                  b.status == BookingStatus.fulfilled ||
                  b.status == BookingStatus.cancelled ||
                  b.status == BookingStatus.expired)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            children: [
              if (active.isNotEmpty) ...[
                _sectionHeader('Active Bookings', Icons.bookmark, AppTheme.primaryBlue),
                const SizedBox(height: 8),
                ...active.map((b) => _buildActiveCard(b)),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingLarge),
                _sectionHeader('Past Bookings', Icons.history, Colors.grey),
                const SizedBox(height: 8),
                ...past.map((b) => _buildPastCard(b)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon, Color color) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold, color: color)),
        ],
      );

  Widget _buildActiveCard(BookingModel booking) {
    final isLocked = booking.isLockActive;
    final statusColor =
        isLocked ? AppTheme.warning : AppTheme.primaryBlue;
    final statusLabel = isLocked ? 'Box Reserved' : 'Scheduled';

    String countdownText;
    if (booking.isExpired) {
      countdownText = 'Expired';
    } else if (isLocked) {
      final mins = booking.minutesUntilExpiry;
      countdownText = 'Expires in ${mins}m';
    } else {
      final mins = booking.minutesUntilLock;
      countdownText = 'Locks in ${mins}m';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: statusColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(booking.boxId.toUpperCase(),
                    style: AppTheme.headingSmall
                        .copyWith(color: statusColor)),
                _statusBadge(statusLabel, statusColor),
              ],
            ),
            const SizedBox(height: 6),
            _detailRow(
              Icons.cable,
              booking.deviceType == 'evCharger'
                  ? 'EV Charger'
                  : '3-Pin Socket',
            ),
            _detailRow(
              Icons.access_time,
              'Charging at ${_fmt(booking.scheduledChargingTime)}',
            ),
            _detailRow(
              Icons.lock_clock,
              'Locks at ${_fmt(booking.lockStartTime)}',
            ),
            const SizedBox(height: 8),
            // Countdown banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                '⏱  $countdownText',
                style: TextStyle(
                    color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            // Cancel button (only if lock hasn't started)
            if (!isLocked)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelBooking(booking),
                  icon: const Icon(Icons.cancel_outlined,
                      size: 16, color: AppTheme.error),
                  label: const Text('Cancel Booking',
                      style: TextStyle(color: AppTheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastCard(BookingModel booking) {
    Color statusColor;
    String statusLabel;
    switch (booking.status) {
      case BookingStatus.fulfilled:
        statusColor = AppTheme.success;
        statusLabel = 'Completed';
        break;
      case BookingStatus.expired:
        statusColor = Colors.grey;
        statusLabel = 'Expired';
        break;
      default:
        statusColor = AppTheme.error;
        statusLabel = 'Cancelled';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.history, color: statusColor),
        title: Text(booking.boxId.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${booking.deviceType == 'evCharger' ? 'EV Charger' : '3-Pin Socket'} · ${_fmt(booking.scheduledChargingTime)}',
        ),
        trailing: _statusBadge(statusLabel, statusColor),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _detailRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(text, style: AppTheme.bodySmall),
          ],
        ),
      );

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
