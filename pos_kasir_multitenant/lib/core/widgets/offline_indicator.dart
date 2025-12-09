import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_manager.dart';

/// Provider for connectivity status - reactive updates
final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();

  // Check initial status
  Connectivity().checkConnectivity().then((results) {
    final isOnline = _checkConnectivityResults(results);
    controller.add(isOnline);
  });

  // Listen to changes
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    final isOnline = _checkConnectivityResults(results);
    controller.add(isOnline);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Helper to check connectivity results
bool _checkConnectivityResults(dynamic results) {
  if (results is List<ConnectivityResult>) {
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  } else if (results is ConnectivityResult) {
    return results != ConnectivityResult.none;
  }
  return true;
}

/// Offline Indicator Widget
/// Shows a banner when the app is in offline mode
/// Requirements: Display offline status for Android users
class OfflineIndicator extends ConsumerWidget {
  /// Custom message to display (optional)
  final String? message;

  /// Whether to show pending sync badge
  final bool showSyncBadge;

  /// Force show indicator regardless of connectivity
  final bool forceShow;

  const OfflineIndicator({
    super.key,
    this.message,
    this.showSyncBadge = true,
    this.forceShow = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If forceShow is true, always show the indicator
    if (forceShow) {
      return _buildIndicator();
    }

    final connectivityAsync = ref.watch(connectivityProvider);

    return connectivityAsync.when(
      data: (isOnline) {
        if (isOnline) {
          return const SizedBox.shrink();
        }
        return _buildIndicator();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? 'Mode Offline - Data akan disinkronkan saat online',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          if (showSyncBadge) _PendingSyncBadge(),
        ],
      ),
    );
  }
}

/// Pending sync count badge
class _PendingSyncBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _getPendingSyncCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
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
