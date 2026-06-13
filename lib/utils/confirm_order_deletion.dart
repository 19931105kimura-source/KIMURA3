import 'package:flutter/material.dart';

Future<bool> confirmOrderDeletion(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('注文削除の確認'),
      content: const Text('本当にこの注文を削除しますか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('削除する'),
        ),
      ],
    ),
  );

  return confirmed == true;
}
