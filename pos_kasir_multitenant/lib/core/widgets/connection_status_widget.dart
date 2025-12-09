import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Widget to display online/offline connection status
/// Requirements 3.1, 4.1: Display connection status indicator
class ConnectionStatusWidget extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSynced;
  final VoidCallback? onRetry;

  const ConnectionStatusWidget({
    super.key,
    required this.isOnline,
    this.lastSynced,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getTooltipMessage(),
      child: InkWell(
        onTap: !isOnline ? onRetry : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline
                ? AppTheme.successColor.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnline
                  ? AppTheme.successColor.withValues(alpha: 0.3)
                  : Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                size: 16,
                color: isOnline ? AppTheme.successColor : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isOnline ? AppTheme.successColor : Colors.orange,
                ),
              ),
              if (!isOnline && onRetry != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.refresh,
                  size: 14,
                  color: Colors.orange,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getTooltipMessage() {
    if (isOnline) {
      if (lastSynced != null) {
        final formattedTime = DateFormat('HH:mm:ss').format(lastSynced!);
        return 'Terhubung ke server\nTerakhir sync: $formattedTime';
      }
      return 'Terhubung ke server';
    } else {
      return 'Mode offline - Tap untuk retry';
    }
  }
}

/// Compact version for AppBar
class ConnectionStatusIcon extends StatelessWidget {
  final bool isOnline;
  final VoidCallback? onTap;

  const ConnectionStatusIcon({
    super.key,
    required this.isOnline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isOnline ? Icons.cloud_done : Icons.cloud_off,
        color: isOnline ? AppTheme.successColor : Colors.orange,
      ),
      tooltip: isOnline ? 'Online' : 'Offline - Tap untuk retry',
      onPressed: onTap,
    );
  }
}
