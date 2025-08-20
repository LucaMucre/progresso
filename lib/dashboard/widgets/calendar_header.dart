import 'package:flutter/material.dart';

class CalendarHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final List<String> areaNames;
  final String? selectedAreaName;
  final ValueChanged<String?> onAreaSelected;

  const CalendarHeader({
    super.key,
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.areaNames,
    required this.selectedAreaName,
    required this.onAreaSelected,
  });

  @override
  Widget build(BuildContext context) {
    final title = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        const Spacer(),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 120),
            child: DropdownButton<String?>(
              value: selectedAreaName,
              hint: const Text('All areas', overflow: TextOverflow.ellipsis, maxLines: 1),
              onChanged: onAreaSelected,
              isExpanded: true,
              isDense: true,
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(value: null, child: Text('All areas', overflow: TextOverflow.ellipsis, maxLines: 1)),
                ...areaNames.map((n) => DropdownMenuItem<String?>(value: n, child: Text(n, overflow: TextOverflow.ellipsis, maxLines: 1)))
              ],
            ),
          ),
        ),
      ],
    );
  }
}

