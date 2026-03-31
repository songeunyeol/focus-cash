import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/credit_transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/credit_service.dart';

class CreditHistoryScreen extends StatefulWidget {
  const CreditHistoryScreen({super.key});

  @override
  State<CreditHistoryScreen> createState() => _CreditHistoryScreenState();
}

class _CreditHistoryScreenState extends State<CreditHistoryScreen> {
  final _creditService = CreditService();
  late Future<List<CreditTransaction>> _future;
  String? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user;
    if (user != null && user.uid != _userId) {
      _userId = user.uid;
      _future = _creditService.getTransactionHistory(user.uid);
    } else if (user == null && _userId == null) {
      _future = Future.value([]);
    }
  }

  void _reload() {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    setState(() {
      _future = _creditService.getTransactionHistory(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalCredits = context.watch<AuthProvider>().user?.totalCredits ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('크레딧 내역'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTotalCard(totalCredits),
          Expanded(
            child: FutureBuilder<List<CreditTransaction>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('내역을 불러오지 못했습니다.\n잠시 후 다시 시도해주세요.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary)),
                  );
                }
                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return const Center(
                    child: Text(
                      '내역이 없습니다',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: AppTheme.cardColor,
                    height: 1,
                  ),
                  itemBuilder: (context, index) =>
                      _buildTransactionTile(transactions[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(int totalCredits) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '보유 크레딧',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.monetization_on,
                  color: AppTheme.creditGold, size: 28),
              const SizedBox(width: 8),
              Text(
                '$totalCredits',
                style: const TextStyle(
                  color: AppTheme.creditGold,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(CreditTransaction tx) {
    final isPositive = tx.amount >= 0;
    final amountText = isPositive ? '+${tx.amount}' : '${tx.amount}';
    final amountColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: amountColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.add : Icons.remove,
              color: amountColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(tx.createdAt),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$amountText C',
            style: TextStyle(
              color: amountColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
