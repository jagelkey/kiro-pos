import 'package:flutter/material.dart';
import '../services/sync_manager.dart';

/// Widget to display sync status in the UI
class SyncStatusWidget extends StatefulWidget {
  final bool showLabel;
  final bool showPendingCount;

  const SyncStatusWidget({
    super.key,
    this.showLabel = true,
    this.showPendingCount = true,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final SyncManager _syncManager = SyncManager.instance;

  @override
  void initState() {
    super.initState();
    // Refresh UI every 5 seconds to show updated status
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {});
        initState();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _syncManager.isOnline;
    final isSyncing = _syncManager.isSyncing;
    final pendingCount = _syncManager.pendingSyncCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          else
            Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_off,
              size: 16,
              color: isOnline ? Colors.green : Colors.grey,
            ),
          if (widget.showLabel) ...[
            const SizedBox(width: 6),
            Text(
              isSyncing
                  ? 'Syncing...'
                  : isOnline
                      ? 'Online'
                      : 'Offline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isOnline ? Colors.green : Colors.grey,
              ),
            ),
          ],
          if (widget.showPendingCount && pendingCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sync button widget with manual sync trigger
class SyncButton extends StatefulWidget {
  final VoidCallback? onSyncComplete;

  const SyncButton({
    super.key,
    this.onSyncComplete,
  });

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> {
  bool _isSyncing = false;

  Future<void> _handleSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await SyncManager.instance.syncPendingOperations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sync completed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onSyncComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = SyncManager.instance.pendingSyncCount;

    if (pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: _isSyncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Badge(
              label: Text('$pendingCount'),
              child: const Icon(Icons.sync),
            ),
      onPressed: _isSyncing ? null : _handleSync,
      tooltip: 'Sync $pendingCount pending operations',
    );
  }
}
