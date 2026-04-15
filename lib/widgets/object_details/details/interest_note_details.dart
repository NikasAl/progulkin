import 'package:flutter/material.dart';
import '../../../models/map_objects/map_objects.dart';
import 'info_row.dart';

/// Детали заметки об интересном месте
class InterestNoteDetails extends StatelessWidget {
  final InterestNote note;

  const InterestNoteDetails({
    super.key,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(
          icon: Icons.category,
          label: 'Категория',
          value: '${note.category.emoji} ${note.category.name}',
        ),
        if (note.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              note.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        InfoRow(
          icon: Icons.favorite,
          label: 'Интересуются',
          value: '${note.interestCount} человек',
        ),
      ],
    );
  }
}
