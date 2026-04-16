import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/review_service.dart';

class AdminReviewManagePage extends ConsumerStatefulWidget {
  const AdminReviewManagePage({super.key});

  @override
  ConsumerState<AdminReviewManagePage> createState() => _AdminReviewManagePageState();
}

class _AdminReviewManagePageState extends ConsumerState<AdminReviewManagePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _reviews = [];
  List<dynamic> _appeals = [];
  int _reviewTotal = 0;
  int _appealTotal = 0;
  bool _isLoading = true;
  int _reviewPage = 1;
  int _appealPage = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ref.read(reviewServiceProvider).getAllReviews(page: _reviewPage, pageSize: 20),
        ref.read(reviewServiceProvider).getAppeals(page: _appealPage, pageSize: 20),
      ]);

      if (results[0].success && results[0].data != null) {
        final data = results[0].data!;
        setState(() {
          _reviews = data['list'] ?? [];
          _reviewTotal = data['total'] ?? 0;
        });
      }

      if (results[1].success && results[1].data != null) {
        final data = results[1].data!;
        setState(() {
          _appeals = data['list'] ?? [];
          _appealTotal = data['total'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Fetch review data error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAppeal(int reviewId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('申诉恶意评价'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请填写申诉理由，系统管理员将审核处理：'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '请详细说明申诉原因...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请填写申诉理由')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('提交申诉'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ref.read(reviewServiceProvider).createAppeal(
          reviewId: reviewId,
          appealReason: reasonController.text.trim(),
        );

    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申诉已提交，等待系统管理员审核'), backgroundColor: AppColors.success),
      );
      _fetchData();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '提交失败')),
      );
    }
  }

  Future<void> _replyReview(int reviewId) async {
    final replyController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('回复评价'),
        content: TextField(
          controller: replyController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: '请输入回复内容...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: AppColors.background,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (replyController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('回复'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ref.read(reviewServiceProvider).replyReview(
          id: reviewId,
          reply: replyController.text.trim(),
        );

    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('回复成功'), backgroundColor: AppColors.success),
      );
      _fetchData();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '回复失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('评价管理', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '评价列表 ($_reviewTotal)'),
            Tab(text: '申诉记录 ($_appealTotal)'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReviewsTab(),
                _buildAppealsTab(),
              ],
            ),
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('暂无评价', style: GoogleFonts.notoSansSc(fontSize: 16, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _reviews.length,
        itemBuilder: (ctx, index) => _buildReviewCard(_reviews[index]),
      ),
    );
  }

  Widget _buildReviewCard(dynamic review) {
    final scoreValue = review['score'];
    double score;
    if (scoreValue is double) {
      score = scoreValue;
    } else if (scoreValue is int) {
      score = scoreValue.toDouble();
    } else if (scoreValue is String) {
      score = double.tryParse(scoreValue) ?? 5.0;
    } else {
      score = 5.0;
    }
    final memberName = review['member_name'] ?? review['member_phone'] ?? '匿名';
    final content = review['content'] ?? '';
    final envRating = review['environment_rating'] ?? 5;
    final facRating = review['facility_rating'] ?? 5;
    final comRating = review['comfort_rating'] ?? 5;
    final reply = review['reply'];
    final createdAt = review['created_at'] ?? '';
    final roomTypeName = review['room_type_name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(memberName, style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) => Icon(
                  i < score.toInt() ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16, color: i < score.toInt() ? AppColors.secondary : AppColors.textHint,
                )),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildRatingChip('环境$envRating', envRating),
              const SizedBox(width: 6),
              _buildRatingChip('设施$facRating', facRating),
              const SizedBox(width: 6),
              _buildRatingChip('舒适$comRating', comRating),
              if (roomTypeName.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(roomTypeName, style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.primary)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.notoSansSc(fontSize: 13, height: 1.4)),
          if (reply != null && reply.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
              child: Text('已回复：$reply', style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(createdAt.toString().substring(0, 10), style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textHint)),
              const Spacer(),
              if (reply == null || reply.toString().isEmpty)
                _buildSmallButton(Icons.reply_rounded, '回复', () => _replyReview(review['id'])),
              const SizedBox(width: 8),
              _buildSmallButton(Icons.gavel_rounded, '申诉', () => _submitAppeal(review['id'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingChip(String text, int rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: rating >= 4 ? AppColors.success.withValues(alpha: 0.1)
            : rating >= 3 ? AppColors.warning.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: GoogleFonts.notoSansSc(fontSize: 11, color: rating >= 4 ? AppColors.success : rating >= 3 ? AppColors.warning : AppColors.error)),
    );
  }

  Widget _buildSmallButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppealsTab() {
    if (_appeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel_outlined, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('暂无申诉记录', style: GoogleFonts.notoSansSc(fontSize: 16, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _appeals.length,
        itemBuilder: (ctx, index) => _buildAppealCard(_appeals[index]),
      ),
    );
  }

  Widget _buildAppealCard(dynamic appeal) {
    final status = appeal['status'] ?? 'pending';
    final appealReason = appeal['appeal_reason'] ?? '';
    final reviewContent = appeal['review_content'] ?? '';
    final score = appeal['score'] ?? 5;
    final createdAt = appeal['created_at'] ?? '';
    final handledAt = appeal['handled_at'] ?? '';
    final handleReason = appeal['handle_reason'] ?? '';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusText = '待处理';
        break;
      case 'approved':
        statusColor = AppColors.success;
        statusText = '已通过';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = '已驳回';
        break;
      default:
        statusColor = AppColors.textHint;
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(statusText, style: GoogleFonts.notoSansSc(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
              ),
              const Spacer(),
              Text(createdAt.toString().substring(0, 10), style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 8),
          Text('被申诉评价（评分：$score）', style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
          if (reviewContent.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reviewContent, style: GoogleFonts.notoSansSc(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const Divider(height: 20),
          Text('申诉理由：', style: GoogleFonts.notoSansSc(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(appealReason, style: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textSecondary)),
          if (status != 'pending' && handleReason.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
              child: Text('处理意见：$handleReason', style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ],
          if (handledAt != null && handledAt.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('处理时间：${handledAt.toString().substring(0, 16)}', style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }
}
