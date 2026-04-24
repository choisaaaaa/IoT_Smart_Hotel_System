import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/review.dart';
import '../../services/review_service.dart';

class MyReviewsPage extends ConsumerStatefulWidget {
  const MyReviewsPage({super.key});

  @override
  ConsumerState<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends ConsumerState<MyReviewsPage> {
  List<Review> _reviews = [];
  int _total = 0;
  int _page = 1;
  bool _isLoading = true;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(reviewServiceProvider).getMyReviews(
            page: _page,
            pageSize: 10,
          );

      if (result.success && result.data != null) {
        final data = result.data!;
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
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? '获取评价失败')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络错误')),
        );
      }
    }
  }

  Future<void> _deleteReview(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条评价吗？删除后不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ref.read(reviewServiceProvider).deleteReview(id);
    if (result.success) {
      setState(() {
        _reviews.removeWhere((r) => r.id == id);
        _total--;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评价已删除'), backgroundColor: AppColors.success),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '删除失败')),
      );
    }
  }

  void _editReview(Review review) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditReviewSheet(
        review: review,
        onSave: () {
          Navigator.pop(ctx);
          _fetchReviews(refresh: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '我的评价',
          style: GoogleFonts.notoSansSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _reviews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () => _fetchReviews(refresh: true),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification &&
                          notification.metrics.pixels >= notification.metrics.maxScrollExtent * 0.8 &&
                          _hasMore &&
                          !_isLoading) {
                        _page++;
                        _fetchReviews();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length + (_hasMore ? 1 : 0),
                      itemBuilder: (ctx, index) {
                        if (index == _reviews.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _buildReviewCard(_reviews[index]);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('暂无评价记录', style: GoogleFonts.notoSansSc(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('完成入住后可以对酒店进行评价', style: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.hotelName ?? '酒店',
                      style: GoogleFonts.notoSansSc(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    if (review.roomTypeName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        review.roomTypeName!,
                        style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              _buildStarRow(review.score.toInt()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDimensionTag('环境', review.environmentRating),
              const SizedBox(width: 8),
              _buildDimensionTag('设施', review.facilityRating),
              const SizedBox(width: 8),
              _buildDimensionTag('舒适', review.comfortRating),
            ],
          ),
          if (review.content != null && review.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.content!,
              style: GoogleFonts.notoSansSc(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (review.reply != null && review.reply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('酒店回复', style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(review.reply!, style: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                DateUtils.formatDynamic(review.createdAt),
                style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textHint),
              ),
              const Spacer(),
              _buildActionButton(Icons.edit_outlined, '修改', () => _editReview(review)),
              const SizedBox(width: 12),
              _buildActionButton(Icons.delete_outline, '删除', () => _deleteReview(review.id)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarRow(int score) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
        i < score ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 16,
        color: i < score ? AppColors.secondary : AppColors.textHint,
      )),
    );
  }

  Widget _buildDimensionTag(String label, int rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: rating >= 4 ? AppColors.success.withValues(alpha: 0.1)
            : rating >= 3 ? AppColors.warning.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $rating',
        style: GoogleFonts.notoSansSc(
          fontSize: 11,
          color: rating >= 4 ? AppColors.success
              : rating >= 3 ? AppColors.warning
              : AppColors.error,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 2),
          Text(label, style: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EditReviewSheet extends ConsumerStatefulWidget {
  final Review review;
  final VoidCallback onSave;

  const _EditReviewSheet({required this.review, required this.onSave});

  @override
  ConsumerState<_EditReviewSheet> createState() => _EditReviewSheetState();
}

class _EditReviewSheetState extends ConsumerState<_EditReviewSheet> {
  late int _score;
  late int _environmentRating;
  late int _facilityRating;
  late int _comfortRating;
  late TextEditingController _contentController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _score = widget.review.score.toInt();
    _environmentRating = widget.review.environmentRating;
    _facilityRating = widget.review.facilityRating;
    _comfortRating = widget.review.comfortRating;
    _contentController = TextEditingController(text: widget.review.content ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_score == 0 || _environmentRating == 0 || _facilityRating == 0 || _comfortRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请完成所有评分')));
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ref.read(reviewServiceProvider).updateReview(
          id: widget.review.id,
          score: _score,
          environmentRating: _environmentRating,
          facilityRating: _facilityRating,
          comfortRating: _comfortRating,
          content: _contentController.text.trim(),
        );

    setState(() => _isSubmitting = false);

    if (result.success) {
      widget.onSave();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '修改失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('修改评价', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildRatingRow('总体评分', _score, (v) => setState(() => _score = v)),
            const SizedBox(height: 12),
            _buildRatingRow('环境', _environmentRating, (v) => setState(() => _environmentRating = v)),
            const SizedBox(height: 12),
            _buildRatingRow('设施', _facilityRating, (v) => setState(() => _facilityRating = v)),
            const SizedBox(height: 12),
            _buildRatingRow('舒适', _comfortRating, (v) => setState(() => _comfortRating = v)),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: '修改评价内容...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    : Text('保存修改', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(String label, int rating, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: GoogleFonts.notoSansSc(fontSize: 14))),
        Expanded(
          child: Row(
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => onChanged(i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 28,
                  color: i < rating ? AppColors.secondary : AppColors.textHint,
                ),
              ),
            )),
          ),
        ),
      ],
    );
  }
}
