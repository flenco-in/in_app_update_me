import 'package:flutter/material.dart';

class UpdateProgressDialog extends StatelessWidget {
  final int progress;
  final String message;
  final bool isIndeterminate;
  final VoidCallback? onCancel;

  const UpdateProgressDialog({
    Key? key,
    required this.progress,
    required this.message,
    this.isIndeterminate = false,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.download, color: Colors.blue),
          SizedBox(width: 8),
          Text('Updating App'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isIndeterminate)
            const LinearProgressIndicator()
          else
            LinearProgressIndicator(value: progress / 100),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (!isIndeterminate) ...[
            const SizedBox(height: 8),
            Text(
              '$progress%',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
      ],
    );
  }

  static Future<void> show(
    BuildContext context, {
    required int progress,
    required String message,
    bool isIndeterminate = false,
    VoidCallback? onCancel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateProgressDialog(
        progress: progress,
        message: message,
        isIndeterminate: isIndeterminate,
        onCancel: onCancel,
      ),
    );
  }
}