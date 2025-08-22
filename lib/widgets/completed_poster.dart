import 'package:flutter/material.dart';
import '../models/show_models.dart';

class CompletedPoster extends StatelessWidget {
  final Show show;
  final VoidCallback onTap; // tap poster to open details
  final double width;
  final double height;

  const CompletedPoster({
    super.key,
    required this.show,
    required this.onTap,
    this.width = 80,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final title = show.title;
    // Use up to 4 logos in a 2×2 grid (same style as homepage)
    final logos = show.subscriptionLogos;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: show.posterUrl != null
                      ? Image.network(
                          show.posterUrl!,
                          width: width,
                          height: height,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(context),
                        )
                      : _placeholder(context),
                ),
              ),
              if (logos.isNotEmpty)
                Positioned(
                  left: 4,
                  top: 4,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      children: logos.take(4).map((logo) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                              width: 0.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            logo,
                            fit: BoxFit.contain,
                            width: 18,
                            height: 18,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              // Completed badge (green check) top-right
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.tv),
    );
  }
}
