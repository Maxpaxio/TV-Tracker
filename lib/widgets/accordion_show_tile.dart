import 'package:flutter/material.dart';
import '../models/show_models.dart';

class AccordionShowTile extends StatelessWidget {
  final Show show;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? trailingBadges;

  const AccordionShowTile({
    super.key,
    required this.show,
    required this.expanded,
    required this.onTap,
    this.trailingBadges,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: show.posterUrl != null
                ? Image.network(
                    show.posterUrl!,
                    width: 60,
                    height: 90,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.tv),
            title: Text(
              show.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: trailingBadges,
            onTap: onTap,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: show.seasons.map((s) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Season ${s.number}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...s.episodes.map(
                        (e) => Row(
                          children: [
                            Checkbox(value: e.watched, onChanged: (_) {}),
                            Expanded(
                              child: Text(
                                "Ep ${e.number}: ${e.title}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
