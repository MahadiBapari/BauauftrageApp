import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class CustomLoadingIndicator extends StatelessWidget {
  final double size;
  final String? message;
  final bool isHorizontal;
  final int itemCount;
  final double itemHeight;
  final double itemWidth;
  final bool isScrollable;

  const CustomLoadingIndicator({
    super.key,
    this.size = 30.0,
    this.message,
    this.isHorizontal = false,
    this.itemCount = 5,
    this.itemHeight = 100.0,
    this.itemWidth = 160.0,
    this.isScrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    if (message != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildShimmer(),
            const SizedBox(height: 16),
            Text(
              message ?? 'Laden ...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return _buildShimmer();
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: isHorizontal
          ? SizedBox(
              height: itemHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: itemCount,
                itemBuilder: (context, index) => _buildShimmerItem(),
              ),
            )
          : isScrollable
              ? SizedBox(
                  height: itemHeight * itemCount + (16 * itemCount), // Account for padding
                  child: ListView.builder(
                    itemCount: itemCount,
                    itemBuilder: (context, index) => _buildShimmerItem(),
                  ),
                )
              : Column(
                  children: List.generate(
                    itemCount,
                    (index) => _buildShimmerItem(),
                  ),
                ),
    );
  }

  Widget _buildShimmerItem() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        width: itemWidth,
        height: itemHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}