import 'package:flutter/material.dart';

/// Async button with loading state and double-submit prevention
class AsyncButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;
  final IconData? icon;
  final bool isDestructive;
  final bool isOutlined;
  final bool isFullWidth;

  const AsyncButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isDestructive = false,
    this.isOutlined = false,
    this.isFullWidth = false,
  });

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading) return; // Prevent double-submit

    setState(() => _isLoading = true);

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = widget.icon != null
        ? ElevatedButton.icon(
            onPressed: _isLoading ? null : _handlePress,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(widget.icon),
            label: Text(widget.label),
            style: _getButtonStyle(),
          )
        : ElevatedButton(
            onPressed: _isLoading ? null : _handlePress,
            style: _getButtonStyle(),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(widget.label),
          );

    return widget.isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  ButtonStyle _getButtonStyle() {
    if (widget.isOutlined) {
      return OutlinedButton.styleFrom(
        foregroundColor: widget.isDestructive ? Colors.red : null,
        side: BorderSide(
          color: widget.isDestructive ? Colors.red : Colors.grey,
        ),
      );
    }

    return ElevatedButton.styleFrom(
      backgroundColor: widget.isDestructive ? Colors.red : null,
      foregroundColor: Colors.white,
    );
  }
}

/// Async icon button with loading state
class AsyncIconButton extends StatefulWidget {
  final IconData icon;
  final Future<void> Function() onPressed;
  final String? tooltip;
  final Color? color;

  const AsyncIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  @override
  State<AsyncIconButton> createState() => _AsyncIconButtonState();
}

class _AsyncIconButtonState extends State<AsyncIconButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _isLoading ? null : _handlePress,
      icon: _isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.color ?? Theme.of(context).primaryColor,
                ),
              ),
            )
          : Icon(widget.icon, color: widget.color),
      tooltip: widget.tooltip,
    );
  }
}
