import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shown when data is served from cache after a network failure.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.savedAt});
  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final when = savedAt != null
        ? ' от ${DateFormat('d MMM, HH:mm', 'ru_RU').format(savedAt!.toLocal())}'
        : '';
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3CD),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Color(0xFF8A6D3B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Нет сети — показаны сохранённые данные$when',
              style: const TextStyle(color: Color(0xFF8A6D3B), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
