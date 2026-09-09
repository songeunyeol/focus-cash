import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/ds.dart';
import '../../models/credit_transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/credit_service.dart';
import 'records_shared.dart';

/// 크레딧 탭 — 보유 잔액 + 원장.
/// 원장은 서버·클라이언트 어느 쪽이 썼든 같은 컬렉션이다 (CreditTransaction.fromMap 이 둘 다 읽는다).
class CreditsTab extends StatefulWidget {
  const CreditsTab({super.key});

  @override
  State<CreditsTab> createState() => _CreditsTabState();
}

class _CreditsTabState extends State<CreditsTab>
    with AutomaticKeepAliveClientMixin {
  final CreditService _creditService = CreditService();
  Future<List<CreditTransaction>>? _future;
  String? _userId;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null && uid != _userId) {
      _userId = uid;
      _future = _creditService.getTransactionHistory(uid);
    }
  }

  Future<void> _reload() async {
    final uid = _userId;
    if (uid == null) return;
    final next = _creditService.getTransactionHistory(uid);
    setState(() => _future = next);
    await context.read<AuthProvider>().loadUser();
    await next.catchError((_) => <CreditTransaction>[]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final DsColors c = context.ds;
    final int total = context.watch<AuthProvider>().user?.totalCredits ?? 0;

    return RefreshIndicator(
      color: c.flame,
      onRefresh: _reload,
      child: FutureBuilder<List<CreditTransaction>>(
        future: _future,
        builder: (context, snapshot) {
          final bool waiting =
              snapshot.connectionState == ConnectionState.waiting;
          final List<CreditTransaction> items =
              snapshot.data ?? const <CreditTransaction>[];

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x12),
            itemCount: 2 + (waiting || snapshot.hasError || items.isEmpty
                ? 1
                : items.length),
            itemBuilder: (context, index) {
              if (index == 0) return _BalanceCard(total: total);
              if (index == 1) {
                return const Padding(
                  padding: EdgeInsets.only(top: Sp.x6),
                  child: RecordSectionTitle('내역'),
                );
              }
              if (waiting) {
                return const Padding(
                  padding: EdgeInsets.all(Sp.x8),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (snapshot.hasError) {
                return const RecordEmpty('내역을 불러오지 못했습니다.\n아래로 당겨 다시 시도해 주세요.');
              }
              if (items.isEmpty) {
                return const RecordEmpty('아직 내역이 없습니다.\n첫 집중을 완료하면 여기에 쌓입니다.');
              }
              final tx = items[index - 2];
              return _TxRow(tx: tx, isLast: index - 2 == items.length - 1);
            },
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Container(
      width: double.infinity,
      padding: Sp.card,
      decoration: DsSurface.e1(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('보유 크레딧', style: DsType.caption.on(c.textTertiary)),
          const SizedBox(height: Sp.x2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('$total', style: DsType.display.on(c.accentText).tnum),
              const SizedBox(width: Sp.x1),
              Text('C', style: DsType.subhead.on(c.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx, required this.isLast});

  final CreditTransaction tx;
  final bool isLast;

  static String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final bool positive = tx.amount >= 0;
    final String amount = positive ? '+${tx.amount}' : '${tx.amount}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: Sp.x3),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: c.borderSubtle, width: Stroke.hairline),
              ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: positive ? c.flameTint : c.surfaceRaised,
              borderRadius: R.rSm,
            ),
            child: Icon(
              positive ? Icons.add_rounded : Icons.remove_rounded,
              size: 18,
              color: positive ? c.accentText : c.textSecondary,
            ),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(tx.description, style: DsType.body.on(c.textPrimary)),
                const SizedBox(height: 2),
                Text(_date(tx.createdAt),
                    style: DsType.micro.on(c.textTertiary).tnum),
              ],
            ),
          ),
          Text(
            amount,
            style: DsType.bodyStrong
                .on(positive ? c.textPrimary : c.textSecondary)
                .tnum,
          ),
        ],
      ),
    );
  }
}
