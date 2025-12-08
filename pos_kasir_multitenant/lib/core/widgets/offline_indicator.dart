import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_manager.dart';

/// Offline Indicator Widget
/// Shows a banner when the app is in offline mode
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: This is a simplified version
    // In production, you'd want to use a StreamProvider to watch connectivity
    return FutureBuilder<bool>(
      future: _checkOnlineStatus(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        if (isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.orange,
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mode Offline - Data akan disinkronkan saat online',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              FutureBuilder<int>(
                future: _getPendingSyncCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count pending',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _checkOnlineStatus() async {
    try {
      return SyncManager.instance.isOnline;
    } catch (e) {
      return true; // Assume online if check fails
    }
  }

  Future<int> _getPendingSyncCount() async {
    try {
      return SyncManager.instance.pendingSyncCount;
    } catch (e) {
      return 0;
    }
  }
}

/// Sync Status Badge for AppBar
/// Shows pending sync count as a badge
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: _getPendingSyncCount(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;

        if (pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.cloud_upload),
                onPressed: () => _triggerSync(),
                tooltip: 'Sync Data ($pendingCount pending)',
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int> _getPendingSyncCount() async {
    try {
      return SyncManager.instance.pendingSyncCount;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _triggerSync() async {
    try {
      await SyncManager.instance.syncPendingOperations();
    } catch (e) {
      debugPrint('Error triggering sync: $e');
    }
  }
}
