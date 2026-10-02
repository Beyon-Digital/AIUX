import 'package:flutter/material.dart';

import 'models.dart';
import 'surface_node.dart';

/// Semantic icon names → Material icons. Unknown names fall back to a
/// neutral glyph — semantic names are renderer-mapped, never raw asset keys
/// (PLAN §6).
IconData aiuxIcon(String name) => switch (name.toLowerCase()) {
      'check' || 'ok' || 'done' => Icons.check,
      'close' || 'cancel' || 'x' => Icons.close,
      'warning' || 'warn' => Icons.warning_amber,
      'error' => Icons.error_outline,
      'info' => Icons.info_outline,
      'success' => Icons.check_circle_outline,
      'add' || 'plus' => Icons.add,
      'remove' || 'minus' => Icons.remove,
      'search' => Icons.search,
      'settings' || 'gear' => Icons.settings,
      'user' || 'person' || 'account' => Icons.person_outline,
      'file' || 'document' || 'doc' => Icons.description_outlined,
      'folder' => Icons.folder_outlined,
      'link' || 'url' => Icons.link,
      'code' => Icons.code,
      'image' || 'photo' => Icons.photo_outlined,
      'star' || 'favorite' => Icons.star_outline,
      'heart' => Icons.favorite_border,
      'calendar' || 'date' => Icons.calendar_today,
      'clock' || 'time' => Icons.schedule,
      'download' => Icons.download,
      'upload' => Icons.upload,
      'open' || 'external' => Icons.open_in_new,
      'more' || 'overflow' => Icons.more_horiz,
      'play' => Icons.play_arrow,
      'stop' => Icons.stop,
      'refresh' || 'reload' => Icons.refresh,
      'back' => Icons.chevron_left,
      'forward' || 'next' => Icons.chevron_right,
      'send' => Icons.send,
      'attach' || 'attachment' => Icons.attach_file,
      'lock' || 'secure' => Icons.lock_outline,
      'unlock' => Icons.lock_open,
      'eye' || 'visible' => Icons.visibility_outlined,
      'tool' || 'wrench' => Icons.build_outlined,
      'artifact' => Icons.article_outlined,
      _ => Icons.help_outline,
    };

/// Semantic status-severity icon.
IconData aiuxStatusIcon(AiuxStatusLevel? level) => switch (level) {
      AiuxStatusLevel.success => Icons.check_circle_outline,
      AiuxStatusLevel.warning => Icons.warning_amber,
      AiuxStatusLevel.error => Icons.error_outline,
      _ => Icons.info_outline,
    };

/// Semantic tone icon for `status` nodes.
IconData aiuxToneIcon(AiuxTone? tone) => switch (tone) {
      AiuxTone.accent => Icons.info_outline,
      AiuxTone.success => Icons.check_circle_outline,
      AiuxTone.warning => Icons.warning_amber,
      AiuxTone.destructive => Icons.error_outline,
      _ => Icons.circle,
    };

/// A small icon keyed to a semantic attachment `mimeType` prefix.
IconData aiuxAttachmentIcon(String? mimeType) {
  if (mimeType == null) return Icons.attach_file;
  if (mimeType.startsWith('image/')) return Icons.photo_outlined;
  if (mimeType.startsWith('audio/')) return Icons.graphic_eq;
  if (mimeType.startsWith('video/')) return Icons.videocam_outlined;
  if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
  if (mimeType.startsWith('text/')) return Icons.notes;
  if (mimeType.contains('zip') || mimeType.contains('archive')) {
    return Icons.archive_outlined;
  }
  return Icons.attach_file;
}

/// A semantic icon for a context entity `kind`.
IconData aiuxContextIcon(String kind) => switch (kind.toLowerCase()) {
      'file' || 'document' => Icons.description_outlined,
      'url' || 'link' || 'web' => Icons.link,
      'record' || 'entity' || 'object' => Icons.inventory_2_outlined,
      'user' || 'person' || 'contact' => Icons.person_outline,
      'code' || 'repo' || 'repository' => Icons.code,
      'image' => Icons.photo_outlined,
      _ => Icons.label_outline,
    };

/// Human-readable byte count ("12 KB") for attachment rows.
String? aiuxByteCount(int? bytes) {
  if (bytes == null) return null;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value == value.roundToDouble() || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
