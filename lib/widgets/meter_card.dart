import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MeterCard extends StatelessWidget {
  final String title;
  final String value;
  final String? cost;

  const MeterCard({
    super.key,
    required this.title,
    required this.value,
    this.cost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.electrical_services,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppTheme.headingMedium.copyWith(fontSize: 28)),
              if (cost != null)
                Text(
                  cost!,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
