import 'package:flutter/material.dart';

/// Reusable Load More button for paginated lists
class LoadMoreButton extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final VoidCallback onPressed;
  final int? currentCount;
  final int? totalCount;

  const LoadMoreButton({
    super.key,
    required this.isLoading,
    required this.hasMore,
    required this.onPressed,
    this.currentCount,
    this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore && currentCount != null) {
      // Show "End of list" indicator
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '— Akhir daftar —',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more, size: 18),
              label: Text(isLoading ? 'Memuat...' : 'Load More'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF000072),
                side: const BorderSide(color: Color(0xFF000072)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (currentCount != null && totalCount != null) ...[
            const SizedBox(height: 6),
            Text(
              'Menampilkan $currentCount dari $totalCount',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}