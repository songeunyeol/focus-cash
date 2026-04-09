import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/gifticon_code.dart';
import '../../providers/auth_provider.dart';
import '../../services/store_service.dart';

Widget _safeBase64Image(String base64Str, BuildContext context) {
  try {
    final Uint8List bytes = base64Decode(base64Str);
    return Image.memory(bytes, width: double.infinity, fit: BoxFit.contain);
  } catch (_) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(Icons.broken_image_rounded, color: AppTheme.of(context).textMuted, size: 40),
      ),
    );
  }
}

String _formatDate(String? isoDate) {
  if (isoDate == null) return '';
  try {
    final dt = DateTime.parse(isoDate).toLocal();
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

class MyGifticonsScreen extends StatefulWidget {
  const MyGifticonsScreen({super.key});

  @override
  State<MyGifticonsScreen> createState() => _MyGifticonsScreenState();
}

class _MyGifticonsScreenState extends State<MyGifticonsScreen> {
  final StoreService _storeService = StoreService();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final storeService = _storeService;

    return Scaffold(
      appBar: AppBar(title: Text('내 기프티콘')),
      body: user == null
          ? Center(
              child: Text('로그인이 필요합니다.',
                  style: TextStyle(color: AppTheme.of(context).textSecondary)),
            )
          : StreamBuilder<List<GifticonCode>>(
              stream: storeService.watchMyGifticons(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final gifticons = snapshot.data ?? [];

                if (gifticons.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.card_giftcard_outlined,
                            size: 64,
                            color: AppTheme.of(context).textSecondary
                                .withValues(alpha: 0.4)),
                        SizedBox(height: 16),
                        Text('받은 상품이 없습니다.',
                            style:
                                TextStyle(color: AppTheme.of(context).textSecondary)),
                        SizedBox(height: 8),
                        Text('상점 교환, 룰렛, 응모방에서 상품을 받아보세요!',
                            style: TextStyle(
                                color: AppTheme.of(context).textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: gifticons.length,
                  itemBuilder: (context, index) {
                    final g = gifticons[index];
                    if (g.prizeType == 'direct') {
                      return _DirectDeliveryCard(gifticon: g);
                    }
                    if (g.prizeType == 'roulette') {
                      return _RoulettePrizeCard(gifticon: g);
                    }
                    if (g.storeItemId.startsWith('raffle_')) {
                      return _RaffleGifticonCard(gifticon: g);
                    }
                    return _GifticonCard(gifticon: g);
                  },
                );
              },
            ),
    );
  }
}

// ─── 직접배송 카드 ───────────────────────────────────────────────────────────

class _DirectDeliveryCard extends StatefulWidget {
  final GifticonCode gifticon;
  const _DirectDeliveryCard({required this.gifticon});

  @override
  State<_DirectDeliveryCard> createState() => _DirectDeliveryCardState();
}

class _DirectDeliveryCardState extends State<_DirectDeliveryCard> {
  bool _loading = false;
  bool _showingForm = false;

  Future<void> _showDeliveryForm() async {
    if (_showingForm) return;
    _showingForm = true;

    Map<String, String>? result;
    try {
      result = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.of(context).surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _DeliveryFormSheet(
          itemName: widget.gifticon.storeItemName,
          initialName: widget.gifticon.deliveryName,
          initialPhone: widget.gifticon.deliveryPhone,
          initialAddress: widget.gifticon.deliveryAddress,
        ),
      );
    } finally {
      _showingForm = false;
    }

    if (result == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().user;
      await StoreService().submitDeliveryInfo(
        docId: widget.gifticon.id,
        name: result['name']!,
        phone: result['phone']!,
        address: result['address']!,
        winnerId: user?.uid ?? widget.gifticon.usedBy,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('배송지가 제출되었습니다. 빠른 배송 드리겠습니다!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitted = widget.gifticon.deliveryStatus == 'submitted';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: AppTheme.accentGreen, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.gifticon.storeItemName,
                          style: TextStyle(
                              color: AppTheme.of(context).textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      Text('직접배송 상품',
                          style: TextStyle(
                              color: AppTheme.of(context).textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: submitted
                        ? AppTheme.accentGreen.withValues(alpha: 0.15)
                        : AppTheme.creditGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    submitted ? '제출완료' : '입력 필요',
                    style: TextStyle(
                      color: submitted
                          ? AppTheme.accentGreen
                          : AppTheme.creditGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (submitted) ...[
              SizedBox(height: 12),
              Divider(color: AppTheme.of(context).surface, height: 1),
              const SizedBox(height: 12),
              _InfoRow(label: '수령인', value: widget.gifticon.deliveryName),
              const SizedBox(height: 4),
              _InfoRow(label: '연락처', value: widget.gifticon.deliveryPhone),
              SizedBox(height: 4),
              _InfoRow(label: '배송지', value: widget.gifticon.deliveryAddress),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : _showDeliveryForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.of(context).textSecondary,
                    side: BorderSide(color: AppTheme.of(context).textSecondary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('배송지 수정'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _showDeliveryForm,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.edit_location_alt, size: 18),
                  label: const Text('배송지 입력하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 배송지 입력 폼 (자체 컨트롤러 라이프사이클 관리)
class _DeliveryFormSheet extends StatefulWidget {
  final String itemName;
  final String initialName;
  final String initialPhone;
  final String initialAddress;

  const _DeliveryFormSheet({
    required this.itemName,
    required this.initialName,
    required this.initialPhone,
    required this.initialAddress,
  });

  @override
  State<_DeliveryFormSheet> createState() => _DeliveryFormSheetState();
}

class _DeliveryFormSheetState extends State<_DeliveryFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addrCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _addrCtrl = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('배송지 입력',
              style: TextStyle(
                  color: AppTheme.of(context).textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('${widget.itemName} 배송을 위한 정보를 입력해주세요.',
              style: TextStyle(
                  color: AppTheme.of(context).textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          _DeliveryField(controller: _nameCtrl, label: '수령인 이름', hint: '홍길동'),
          const SizedBox(height: 12),
          _DeliveryField(
              controller: _phoneCtrl,
              label: '연락처',
              hint: '010-0000-0000',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _DeliveryField(
              controller: _addrCtrl,
              label: '배송지 주소',
              hint: '서울특별시 강남구 ...',
              maxLines: 2),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty ||
                    _phoneCtrl.text.trim().isEmpty ||
                    _addrCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('모든 항목을 입력해주세요.')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'name': _nameCtrl.text.trim(),
                  'phone': _phoneCtrl.text.trim(),
                  'address': _addrCtrl.text.trim(),
                });
              },
              child: const Text('배송지 제출'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final int maxLines;

  const _DeliveryField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: AppTheme.of(context).textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.of(context).textSecondary),
        hintText: hint,
        hintStyle:
            TextStyle(color: AppTheme.of(context).textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppTheme.of(context).card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(label,
              style: TextStyle(
                  color: AppTheme.of(context).textSecondary, fontSize: 12)),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: AppTheme.of(context).textPrimary, fontSize: 13)),
        ),
      ],
    );
  }
}

// ─── 룰렛 당첨 카드 ──────────────────────────────────────────────────────────

class _RoulettePrizeCard extends StatefulWidget {
  final GifticonCode gifticon;
  const _RoulettePrizeCard({required this.gifticon});

  @override
  State<_RoulettePrizeCard> createState() => _RoulettePrizeCardState();
}

class _RoulettePrizeCardState extends State<_RoulettePrizeCard> {
  bool _expanded = false;


  @override
  Widget build(BuildContext context) {
    final hasImage = widget.gifticon.imageBase64.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: hasImage ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.creditGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.casino,
                        color: AppTheme.creditGold, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.gifticon.storeItemName,
                          style: TextStyle(
                            color: AppTheme.of(context).textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '룰렛 당첨 · ${_formatDate(widget.gifticon.usedAt)}',
                          style: TextStyle(
                              color: AppTheme.of(context).textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.creditGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('당첨',
                        style: TextStyle(
                            color: AppTheme.creditGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (hasImage) ...[
                    SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.of(context).textSecondary,
                      size: 20,
                    ),
                  ],
                ],
              ),
              if (_expanded && hasImage) ...[
                SizedBox(height: 14),
                Divider(color: AppTheme.of(context).surface, height: 1),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _safeBase64Image(widget.gifticon.imageBase64, context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 응모방 기프티콘 당첨 카드 ─────────────────────────────────────────────────

class _RaffleGifticonCard extends StatefulWidget {
  final GifticonCode gifticon;
  const _RaffleGifticonCard({required this.gifticon});

  @override
  State<_RaffleGifticonCard> createState() => _RaffleGifticonCardState();
}

class _RaffleGifticonCardState extends State<_RaffleGifticonCard> {
  bool _expanded = false;
  bool _confirming = false;


  @override
  Widget build(BuildContext context) {
    final hasImage = widget.gifticon.imageBase64.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.emoji_events,
                        color: AppTheme.accentGreen, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.gifticon.storeItemName,
                          style: TextStyle(
                            color: AppTheme.of(context).textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '응모방 당첨 · ${_formatDate(widget.gifticon.usedAt)}',
                          style: TextStyle(
                              color: AppTheme.of(context).textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('당첨',
                        style: TextStyle(
                            color: AppTheme.accentGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.of(context).textSecondary,
                    size: 20,
                  ),
                ],
              ),
              if (_expanded) ...[
                SizedBox(height: 14),
                Divider(color: AppTheme.of(context).surface, height: 1),
                const SizedBox(height: 14),
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _safeBase64Image(widget.gifticon.imageBase64, context),
                  ),
                if (widget.gifticon.hiddenAt == null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirming
                          ? null
                          : () async {
                              setState(() => _confirming = true);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await StoreService()
                                    .confirmRaffleGifticon(widget.gifticon.id);
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '확인 완료! 이 알림은 24시간 후 사라집니다.'),
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (mounted) setState(() => _confirming = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppTheme.accentGreen.withValues(alpha: 0.85),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _confirming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('당첨 확인 완료'),
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time,
                          size: 13,
                          color: AppTheme.of(context).textSecondary
                              .withValues(alpha: 0.6)),
                      SizedBox(width: 4),
                      Text(
                        '확인 완료 · 24시간 후 자동으로 사라집니다',
                        style: TextStyle(
                          color: AppTheme.of(context).textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 기프티콘 카드 ────────────────────────────────────────────────────────────

class _GifticonCard extends StatefulWidget {
  final GifticonCode gifticon;
  const _GifticonCard({required this.gifticon});

  @override
  State<_GifticonCard> createState() => _GifticonCardState();
}

class _GifticonCardState extends State<_GifticonCard> {
  bool _expanded = false;


  @override
  Widget build(BuildContext context) {
    final hasImage = widget.gifticon.imageBase64.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.card_giftcard,
                        color: AppTheme.primaryColor, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.gifticon.storeItemName,
                          style: TextStyle(
                            color: AppTheme.of(context).textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (widget.gifticon.usedAt != null)
                          Text(
                            '교환일: ${_formatDate(widget.gifticon.usedAt)}',
                            style: TextStyle(
                                color: AppTheme.of(context).textSecondary,
                                fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.of(context).textSecondary,
                  ),
                ],
              ),

              // 펼쳐진 상세 내용
              if (_expanded) ...[
                SizedBox(height: 16),
                Divider(color: AppTheme.of(context).surface, height: 1),
                const SizedBox(height: 16),

                // 이미지
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _safeBase64Image(widget.gifticon.imageBase64, context),
                  ),
                  const SizedBox(height: 16),
                ],

                // 코드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text('기프티콘 코드',
                          style: TextStyle(
                              color: AppTheme.of(context).textSecondary,
                              fontSize: 12)),
                      SizedBox(height: 6),
                      SelectableText(
                        widget.gifticon.code,
                        style: TextStyle(
                          color: AppTheme.of(context).textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 복사 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.gifticon.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('코드가 복사됐습니다!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('코드 복사'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
