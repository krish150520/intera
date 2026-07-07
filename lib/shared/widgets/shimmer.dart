import 'package:flutter/material.dart';

class Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const Shimmer.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
  }) : shapeBorder = const RoundedRectangleBorder();

  const Shimmer.circular({
    super.key,
    required this.width,
    required this.height,
    this.shapeBorder = const CircleBorder(),
  });

  Shimmer.rounded({
    super.key,
    this.width = double.infinity,
    required this.height,
    double borderRadius = 12,
  }) : shapeBorder = RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        );

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Base and highlight colors that align with Intera's Twilight theme
    final baseColor = isDark 
        ? const Color(0xFF262947) 
        : const Color(0xFFE2E9FF);
    final highlightColor = isDark 
        ? const Color(0xFF33385F) 
        : const Color(0xFFF3F6FF);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shapeBorder,
            gradient: LinearGradient(
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [
                0.25,
                0.5,
                0.75,
              ],
              begin: Alignment(-1.5 + _controller.value * 3, -0.3),
              end: Alignment(1.5 + _controller.value * 3, 0.3),
            ),
          ),
        );
      },
    );
  }
}

/// A placeholder that mimics the size and structure of a standard Home post card.
class PostCardShimmer extends StatelessWidget {
  const PostCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.white.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.08) 
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Author Info + Tag
          Row(
            children: [
              const Shimmer.circular(width: 40, height: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.rounded(height: 14, width: MediaQuery.of(context).size.width * 0.35),
                    const SizedBox(height: 6),
                    Shimmer.rounded(height: 10, width: MediaQuery.of(context).size.width * 0.2),
                  ],
                ),
              ),
              Shimmer.rounded(height: 20, width: 60, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 14),

          // Title / Body
          Shimmer.rounded(height: 16, width: MediaQuery.of(context).size.width * 0.75),
          const SizedBox(height: 8),
          Shimmer.rounded(height: 12, width: MediaQuery.of(context).size.width * 0.85),
          const SizedBox(height: 6),
          Shimmer.rounded(height: 12, width: MediaQuery.of(context).size.width * 0.5),
          const SizedBox(height: 14),

          // Main media/text block
          Shimmer.rounded(height: 176, borderRadius: 16),
          const SizedBox(height: 14),

          // Footer info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Shimmer.circular(width: 24, height: 24),
                  const SizedBox(width: 6),
                  Shimmer.rounded(height: 10, width: 28),
                ],
              ),
              Row(
                children: [
                  const Shimmer.circular(width: 24, height: 24),
                  const SizedBox(width: 6),
                  Shimmer.rounded(height: 10, width: 28),
                ],
              ),
              const Shimmer.circular(width: 24, height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

/// A staggered card placeholder that mimics Pinterest media cards.
class StaggeredCardShimmer extends StatelessWidget {
  final double height;

  const StaggeredCardShimmer({
    super.key,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.white.withValues(alpha: 0.45);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.08) 
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staggered media box
          Shimmer.rounded(
            height: height - 60,
            borderRadius: 0,
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.rounded(height: 12, width: double.infinity),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Shimmer.circular(width: 16, height: 16),
                    const SizedBox(width: 6),
                    Shimmer.rounded(height: 8, width: 40),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommunityCardShimmer extends StatelessWidget {
  const CommunityCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.white.withValues(alpha: 0.45);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.08) 
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner strip
          const Shimmer.rectangular(height: 72),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                const Shimmer.circular(width: 48, height: 48),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.rounded(height: 14, width: MediaQuery.of(context).size.width * 0.4),
                      const SizedBox(height: 6),
                      Shimmer.rounded(height: 10, width: 80),
                      const SizedBox(height: 8),
                      Shimmer.rounded(height: 12, width: MediaQuery.of(context).size.width * 0.5),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Button
                Shimmer.rounded(height: 30, width: 64, borderRadius: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserRowShimmer extends StatelessWidget {
  const UserRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.white.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.08) 
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          const Shimmer.circular(width: 36, height: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.rounded(height: 12, width: 80),
                const SizedBox(height: 4),
                Shimmer.rounded(height: 10, width: 50),
              ],
            ),
          ),
          Shimmer.rounded(height: 24, width: 64, borderRadius: 20),
        ],
      ),
    );
  }
}

class MiniCommunityRowShimmer extends StatelessWidget {
  const MiniCommunityRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.white.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.08) 
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          const Shimmer.circular(width: 36, height: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.rounded(height: 12, width: 90),
                const SizedBox(height: 4),
                Shimmer.rounded(height: 10, width: 120),
              ],
            ),
          ),
          Shimmer.rounded(height: 18, width: 32, borderRadius: 20),
        ],
      ),
    );
  }
}
