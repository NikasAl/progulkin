import 'package:flutter/material.dart';
import '../../../models/map_objects/map_objects.dart';
import 'info_row.dart';

/// Детали секретного сообщения
class SecretMessageDetails extends StatelessWidget {
  final SecretMessage secret;

  const SecretMessageDetails({
    super.key,
    required this.secret,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(
          icon: Icons.lock,
          label: 'Тип',
          value: secret.secretType.name,
        ),
        InfoRow(
          icon: Icons.location_on,
          label: 'Радиус разблокировки',
          value: '${secret.unlockRadius.toInt()} м',
        ),
        InfoRow(
          icon: Icons.visibility,
          label: 'Прочитано раз',
          value: '${secret.currentReads}',
        ),
        if (secret.isOneTime)
          InfoRow(
            icon: Icons.timer,
            label: 'Одноразовое',
            value: 'Да',
          ),
      ],
    );
  }
}
