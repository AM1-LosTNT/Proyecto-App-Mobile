import 'package:flutter/material.dart';

import '../models/reserva.dart';

/// Etiqueta de color con el estado de una reserva.
class ReservationStatusChip extends StatelessWidget {
  final ReservationStatus status;
  final bool withIcon;

  const ReservationStatusChip({
    super.key,
    required this.status,
    this.withIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: status.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withIcon) ...[
            Icon(status.icon, size: 13, color: status.color),
            const SizedBox(width: 4),
          ],
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
