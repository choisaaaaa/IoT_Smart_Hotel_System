import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../services/review_service.dart';
import '../../services/upload_service.dart' show uploadServiceProvider;

class ReviewSubmitPage extends ConsumerStatefulWidget {
  final int bookingId;
  final int? hotelId;
  final String? hotelName;

  const ReviewSubmitPage({
    super.key,
    required this.bookingId,
    this.hotelId,
    this.hotelName,
  });

  @override
  ConsumerState<ReviewSubmitPage> createState() => _ReviewSubmitPageState();
}

class _ReviewSubmitPageState extends ConsumerState<ReviewSubmitPage> {
  int _overallRating = 0;
  int _environmentRating = 0;
  int _facilityRating = 0;
  int _comfortRating = 0;
  final _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  bool _isSubmitting = false;
  bool _isUploadingImages = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _overallRating > 0 &&
      _environmentRating > 0 &&
      _facilityRating > 0 &&
      _comfortRating > 0 &&
      _contentController.text.trim().isNotEmpty &&
      !_isSubmitting;

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多上传6张图片')),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 80);
      if (images.isEmpty) return;
      final remaining = 6 - _selectedImages.length;
      final toAdd = images.take(remaining).map((x) => File(x.path)).toList();
      setState(() => _selectedImages.addAll(toAdd));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选择图片失败')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) return;
    setState(() => _isUploadingImages = true);
    try {
      final uploadService = ref.read(uploadServiceProvider);
      for (var image in _selectedImages) {
        final result = await uploadService.uploadImage(image, folder: 'reviews');
        if (result.success && result.data != null) {
          _uploadedImageUrls.add(result.data!['url'] ?? result.data!['path'] ?? '');
        }
      }
    } catch (e) {
      debugPrint('Upload images error: $e');
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _submitReview() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    try {
      if (_selectedImages.isNotEmpty) {
        await _uploadImages();
      }

      final result = await ref.read(reviewServiceProvider).createReview(
            orderId: widget.bookingId,
            hotelId: widget.hotelId,
            score: _overallRating,
            content: _contentController.text.trim(),
            environmentRating: _environmentRating,
            facilityRating: _facilityRating,
            comfortRating: _comfortRating,
            photos: _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls : null,
          );

      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('评价提交成功，感谢您的反馈！'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '提交失败，请重试')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提交失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          '评价入住体验',
          style: GoogleFonts.notoSansSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.hotelName != null) _buildHotelInfo(),
            const SizedBox(height: 16),
            _buildOverallRating(),
            const SizedBox(height: 16),
            _buildDimensionRatings(),
            const SizedBox(height: 16),
            _buildContentInput(),
            const SizedBox(height: 16),
            _buildImageUpload(),
            const SizedBox(height: 32),
            _buildSubmitButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.hotel_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.hotelName ?? '智联酒店',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '订单号：${widget.bookingId}',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallRating() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            _overallRating == 0
                ? '请为本次入住打分'
                : _overallRating <= 2
                    ? '还需努力'
                    : _overallRating <= 3
                        ? '一般体验'
                        : _overallRating <= 4
                            ? '满意入住'
                            : '非常满意',
            style: GoogleFonts.notoSansSc(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _overallRating == 0 ? AppColors.textSecondary : AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          _buildStarRating(
            rating: _overallRating,
            size: 40,
            onRatingChanged: (rating) => setState(() => _overallRating = rating),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionRatings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分项评分',
            style: GoogleFonts.notoSansSc(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildDimensionRow(
            icon: Icons.nature_people_rounded,
            label: '环境',
            rating: _environmentRating,
            onRatingChanged: (r) => setState(() => _environmentRating = r),
          ),
          const SizedBox(height: 16),
          _buildDimensionRow(
            icon: Icons.apartment_rounded,
            label: '设施',
            rating: _facilityRating,
            onRatingChanged: (r) => setState(() => _facilityRating = r),
          ),
          const SizedBox(height: 16),
          _buildDimensionRow(
            icon: Icons.weekend_rounded,
            label: '舒适',
            rating: _comfortRating,
            onRatingChanged: (r) => setState(() => _comfortRating = r),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionRow({
    required IconData icon,
    required String label,
    required int rating,
    required ValueChanged<int> onRatingChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: GoogleFonts.notoSansSc(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStarRating(
            rating: rating,
            size: 24,
            onRatingChanged: onRatingChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            rating > 0 ? '$rating.0' : '',
            style: GoogleFonts.notoSansSc(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildStarRating({
    required int rating,
    required double size,
    required ValueChanged<int> onRatingChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return GestureDetector(
          onTap: () => onRatingChanged(starValue),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.15),
            child: Icon(
              starValue <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: starValue <= rating ? AppColors.secondary : AppColors.textHint,
              size: size,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '文字评价',
            style: GoogleFonts.notoSansSc(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '分享您的入住体验，帮助其他旅客做出选择...',
              hintStyle: GoogleFonts.notoSansSc(
                fontSize: 14,
                color: AppColors.textHint,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUpload() {
    return Container(
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
              Text(
                '上传图片',
                style: GoogleFonts.notoSansSc(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '（可选，最多6张）',
                style: GoogleFonts.notoSansSc(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._selectedImages.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;
                return _buildImageItem(image, index);
              }),
              if (_selectedImages.length < 6) _buildAddImageButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageItem(File image, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            image,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined,
                size: 28, color: AppColors.textHint),
            const SizedBox(height: 4),
            Text(
              '${_selectedImages.length}/6',
              style: GoogleFonts.notoSansSc(
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _canSubmit && !_isUploadingImages ? _submitReview : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '提交评价',
                    style: GoogleFonts.notoSansSc(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '取消',
              style: GoogleFonts.notoSansSc(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
