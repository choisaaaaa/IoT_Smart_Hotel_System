import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/review.dart';
import '../../services/review_service.dart';

class HotelReviewsPage extends ConsumerStatefulWidget {
  final int hotelId;
  final String? hotelName;

  const HotelReviewsPage({super.key, required this.hotelId, this.hotelName});

  @override
  ConsumerState<HotelReviewsPage> createState() => _HotelReviewsPageState();
}

class _HotelReviewsPageState extends ConsumerState<HotelReviewsPage> {
  List<Review> _reviews = [];
  int _total = 0;
  int _page = 1;
  bool _isLoading = true;
  bool _hasMore = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ref.read(reviewServiceProvider).getHotelReviews(widget.hotelId, page: _page, pageSize: 10),
        if (refresh || _stats == null)
          ref.read(reviewServiceProvider).getReviewStats(widget.hotelId),
      ]);

      final reviewResult = results[0];
      if (reviewResult.success && reviewResult.data != null) {
        final data = reviewResult.data!;
        final list = (data['list'] as List<dynamic>? ?? [])
            .map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          if (refresh) {
            _reviews = list;
          } else {
            _reviews.addAll(list);
          }
          _total = data['total'] ?? 0;
          _hasMore = _reviews.length < _total;
        });
      }

      if (results.length > 1) {
        final statsResult = results[1];
        if (statsResult.success && statsResult.data != null) {
          setState(() => _stats = statsResult.data);
        }
      }
    } catch (e) {
      debugPrint('Fetch reviews error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.hotelName ?? '评价详情',
          style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _reviews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchData(refresh: true),
              child: CustomScrollView(
                slivers: [
                  if (_stats != null) SliverToBoxAdapter(child: _buildStatsHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: _reviews.isEmpty
                        ? SliverToBoxAdapter(child: _buildEmpty())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, index) => _buildReviewItem(_reviews[index]),
                              childCount: _reviews.length,
                            ),
                          ),
                  ),
                  if (_hasMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsHeader() {
    final stats = _stats!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Text(
                    stats['avg_score'] ?? '0.0',
                    style: GoogleFonts.notoSansSc(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < (double.tryParse(stats['avg_score'] ?? '0')?.round() ?? 0)
                          ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16, color: AppColors.secondary,
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text('${stats['total_reviews'] ?? 0}条评价', style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildDimensionBar('环境', stats['avg_environment'] ?? '0.0'),
                    const SizedBox(height: 8),
                    _buildDimensionBar('设施', stats['avg_facility'] ?? '0.0'),
                    const SizedBox(height: 8),
                    _buildDimensionBar('舒适', stats['avg_comfort'] ?? '0.0'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionBar(String label, String avgStr) {
    final avg = double.tryParse(avgStr) ?? 0.0;
    return Row(
      children: [
        SizedBox(width: 28, child: Text(label, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avg / 5,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(avg >= 4 ? AppColors.success : avg >= 3 ? AppColors.warning : AppColors.error),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 28, child: Text(avgStr, style: GoogleFonts.notoSansSc(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
      ],
    );
  }

  Widget _buildReviewItem(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  review.displayUsername.isNotEmpty ? review.displayUsername[0] : '?',
                  style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.displayUsername, style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w500)),
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(
                          i < review.score.toInt() ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 14, color: i < review.score.toInt() ? AppColors.secondary : AppColors.textHint,
                        )),
                        const SizedBox(width: 6),
                        if (review.roomTypeName != null)
                          Text(review.roomTypeName!, style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textHint)),
                      ],
                    ),
                  ],
                ),
              ),
              Text(review.createdAt ?? '', style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniTag('环境${review.environmentRating}'),
              const SizedBox(width: 6),
              _buildMiniTag('设施${review.facilityRating}'),
              const SizedBox(width: 6),
              _buildMiniTag('舒适${review.comfortRating}'),
            ],
          ),
          if (review.content != null && review.content!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.content!, style: GoogleFonts.notoSansSc(fontSize: 14, height: 1.5)),
          ],
          if (review.reply != null && review.reply!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(child: Text('酒店回复：${review.reply!}', style: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textSecondary))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textSecondary)),
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('暂无评价', style: GoogleFonts.notoSansSc(fontSize: 16, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
