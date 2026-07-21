import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../saints/presentation/saint_feast_editor_page.dart';
import 'event_editor_sheet.dart';

Future<void> showAddEventChoice(
  BuildContext context, {
  required DateTime date,
}) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              showEventEditor(context, date: date);
            },
            child: const Text('일정 추가'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              showSaintFeastEditor(context, date: date);
            },
            child: const Text('축일 추가'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소'),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('일정 추가'),
            onTap: () {
              Navigator.of(ctx).pop();
              showEventEditor(context, date: date);
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('축일 추가'),
            onTap: () {
              Navigator.of(ctx).pop();
              showSaintFeastEditor(context, date: date);
            },
          ),
        ],
      ),
    ),
  );
}
