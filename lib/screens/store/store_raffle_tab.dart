import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../design/ds.dart';
import '../../models/raffle_room.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/credit_service.dart';
import '../../services/server_api.dart';
import '../../services/store_service.dart';
import '../../widgets/common/ds_button.dart';
import 'store_dialogs.dart';

class StoreRaffleTab extends StatelessWidget {
  const StoreRaffleTab({
    super.key,
    required this.storeService,
    required this.creditService,
  });

  final StoreService storeService;
  final CreditService creditService;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const StoreEmpty('로그인이 필요합니다.');
    }

    return StreamBuilder<Set<String>>(
      stream: storeService.watchMyEnteredRoomIds(user.uid),
      builder: (BuildContext context, AsyncSnapshot<Set<String>> entrySnap) {
        final Set<String> myRoomIds = entrySnap.data ?? <String>{};

        return StreamBuilder<List<RaffleRoom>>(
          stream: storeService.watchRaffleRooms(),
          builder:
              (BuildContext context, AsyncSnapshot<List<RaffleRoom>> roomSnap) {
            if (roomSnap.hasError || !roomSnap.hasData) {
              return const StoreEmpty('응모방을 불러오는 중...');
            }

            final DateTime now = DateTime.now();
            final List<RaffleRoom> rooms = roomSnap.data!.where((RaffleRoom room) {
              if (!room.isClosed) return true;
              if (room.closedAt.isEmpty) return false;
              final DateTime? closed = DateTime.tryParse(room.closedAt);
              if (closed == null) return false;
              return now.difference(closed).inHours < 24;
            }).toList();

            if (rooms.isEmpty) {
              return const StoreEmpty('진행 중인 응모방이 없습니다.');
            }

            rooms.sort((RaffleRoom a, RaffleRoom b) {
              final bool aEntered = myRoomIds.contains(a.id);
              final bool bEntered = myRoomIds.contains(b.id);
              if (aEntered != bEntered) return aEntered ? -1 : 1;
              if (a.isClosed != b.isClosed) return a.isClosed ? 1 : -1;
              return 0;
            });

            return ListView.builder(
              padding: const EdgeInsets.all(Sp.x4),
              itemCount: rooms.length,
              itemBuilder: (BuildContext context, int index) {
                return _RaffleCard(
                  room: rooms[index],
                  userId: user.uid,
                  myRoomIds: myRoomIds,
                  storeService: storeService,
                  creditService: creditService,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RaffleCard extends StatelessWidget {
  const _RaffleCard({
    required this.room,
    required this.userId,
    required this.myRoomIds,
    required this.storeService,
    required this.creditService,
  });

  final RaffleRoom room;
  final String userId;
  final Set<String> myRoomIds;
  final StoreService storeService;
  final CreditService creditService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: storeService.watchUserRaffleEntry(userId, room.id),
      builder: (BuildContext context, AsyncSnapshot<int> ticketSnap) {
        final DsColors c = context.ds;
        final int myTickets = ticketSnap.data ?? 0;
        final bool isClosed = room.isClosed;
        final bool iWon = isClosed && room.winner == userId;
        final bool iLost = isClosed &&
            room.winner.isNotEmpty &&
            room.winner != userId &&
            myTickets > 0;

        final Color? statusColor = iWon
            ? c.flame
            : iLost
                ? c.danger
                : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: Sp.x4),
          child: Container(
            decoration: DsSurface.of(
              c,
              DsElevation.e1,
              borderColor: statusColor,
            ),
            padding: Sp.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        room.title,
                        style: DsType.subhead.on(
                            isClosed ? c.textSecondary : c.textPrimary),
                      ),
                    ),
                    if (iWon)
                      StoreChip(
                        label: '당첨',
                        tone: c.flameTint,
                        foreground: c.accentText,
                      )
                    else if (iLost)
                      StoreChip(
                        label: '미당첨',
                        tone: c.danger.withValues(alpha: 0.12),
                        foreground: c.danger,
                      )
                    else
                      StoreChip(
                        label: isClosed ? '종료됨' : '진행중',
                        tone: isClosed
                            ? c.surface
                            : c.danger.withValues(alpha: 0.12),
                        foreground: isClosed ? c.textSecondary : c.danger,
                      ),
                  ],
                ),
                const SizedBox(height: Sp.x2),
                Text('상품: ${room.prize}',
                    style: DsType.caption.on(c.textSecondary)),
                if (isClosed && room.winner.isNotEmpty && !iWon) ...<Widget>[
                  const SizedBox(height: Sp.x1),
                  Text(
                    '당첨자: ${room.winnerName.isNotEmpty ? room.winnerName : '집중러'}',
                    style: DsType.caption.on(c.accentText),
                  ),
                ],
                const SizedBox(height: Sp.x3),
                ClipRRect(
                  borderRadius: R.rSm,
                  child: LinearProgressIndicator(
                    value: room.fillRatio,
                    backgroundColor: c.surfaceOverlay,
                    color: isClosed
                        ? c.textTertiary
                        : room.fillRatio > 0.8
                            ? c.danger
                            : c.flame,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: Sp.x2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${room.currentCreditsPool} / ${room.totalCreditsPool} 크레딧',
                          style: DsType.caption.on(c.textSecondary).tnum,
                        ),
                        if (myTickets > 0)
                          Text(
                            '내 티켓: $myTickets장',
                            style: DsType.caption.on(c.accentText).tnum,
                          ),
                      ],
                    ),
                    if (isClosed)
                      Text('응모 종료', style: DsType.caption.on(c.textTertiary))
                    else
                      SizedBox(
                        width: 96,
                        child: DsButton(
                          label: myTickets > 0 ? '추가 응모' : '응모하기',
                          size: DsButtonSize.md,
                          expand: true,
                          onPressed: () => _showEntrySheet(context),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEntrySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _RaffleEntrySheet(
        room: room,
        storeService: storeService,
        creditService: creditService,
        onSuccess: (String? winnerId) {
          context.read<AuthProvider>().loadUser();
          if (winnerId != null) {
            showRaffleDrawDialog(context);
          }
        },
      ),
    );
  }
}

class _RaffleEntrySheet extends StatefulWidget {
  const _RaffleEntrySheet({
    required this.room,
    required this.storeService,
    required this.creditService,
    required this.onSuccess,
  });

  final RaffleRoom room;
  final StoreService storeService;
  final CreditService creditService;
  final void Function(String? winnerId) onSuccess;

  @override
  State<_RaffleEntrySheet> createState() => _RaffleEntrySheetState();
}

class _RaffleEntrySheetState extends State<_RaffleEntrySheet> {
  final TextEditingController _ticketCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _ticketCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final int? tickets = int.tryParse(_ticketCtrl.text.trim());
    if (tickets == null || tickets <= 0) {
      showStoreSnack(context, '올바른 티켓 수를 입력하세요');
      return;
    }

    if (user.totalCredits < tickets) {
      showStoreSnack(context, '크레딧이 부족합니다');
      return;
    }

    setState(() => _isLoading = true);

    if (AppConfig.useServerStore) {
      try {
        final Map<String, dynamic> r =
            await ServerApi().enterRaffle(widget.room.id, tickets);
        final int actualTickets = r['actualTickets'] as int? ?? tickets;
        final String? winnerId = r['winnerId'] as String?;
        unawaited(AnalyticsService.instance
            .raffleEnter(roomId: widget.room.id, tickets: actualTickets));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess(winnerId);
        }
      } on FirebaseFunctionsException catch (e) {
        if (mounted) showStoreSnack(context, e.message ?? '응모에 실패했습니다');
      } catch (_) {
        if (mounted) showStoreSnack(context, '네트워크 오류로 응모하지 못했습니다');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final bool success = await widget.creditService.spendCredits(
        userId: user.uid,
        amount: tickets,
        description: '${widget.room.title} 응모',
      );

      if (!success) {
        if (mounted) showStoreSnack(context, '크레딧 차감에 실패했습니다');
        return;
      }

      try {
        final (String? winnerId, int actualTickets) =
            await widget.storeService.enterRaffleWithTickets(
          userId: user.uid,
          roomId: widget.room.id,
          tickets: tickets,
        );

        if (actualTickets < tickets) {
          await widget.creditService.addCredits(
            userId: user.uid,
            amount: tickets - actualTickets,
            description: '${widget.room.title} 응모 초과 크레딧 환불',
          );
        }

        unawaited(AnalyticsService.instance
            .raffleEnter(roomId: widget.room.id, tickets: actualTickets));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess(winnerId);
        }
      } catch (e) {
        await widget.creditService.addCredits(
          userId: user.uid,
          amount: tickets,
          description: '${widget.room.title} 응모 실패 환불',
        );
        if (mounted) showStoreSnack(context, '응모 실패: $e');
      }
    } catch (e) {
      if (mounted) showStoreSnack(context, '오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final RaffleRoom room = widget.room;
    final int remaining = room.totalCreditsPool - room.currentCreditsPool;

    return StoreSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const StoreSheetHandle(),
          const SizedBox(height: Sp.x4),
          Text(room.title, style: DsType.subhead.on(c.textPrimary)),
          const SizedBox(height: Sp.x1),
          Text('상품: ${room.prize}', style: DsType.caption.on(c.textSecondary)),
          const SizedBox(height: Sp.x4),
          ClipRRect(
            borderRadius: R.rSm,
            child: LinearProgressIndicator(
              value: room.fillRatio,
              backgroundColor: c.surfaceOverlay,
              color: c.flame,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: Sp.x2),
          Text(
            '${room.currentCreditsPool} / ${room.totalCreditsPool} 크레딧 (남은 자리: $remaining)',
            style: DsType.caption.on(c.textSecondary).tnum,
          ),
          const SizedBox(height: Sp.x6),
          TextField(
            controller: _ticketCtrl,
            keyboardType: TextInputType.number,
            style: DsType.body.on(c.textPrimary),
            decoration: InputDecoration(
              labelText: '투입할 티켓 수 (1크레딧 = 1티켓)',
              labelStyle: DsType.caption.on(c.textSecondary),
              hintText: '최대 $remaining',
              hintStyle: DsType.caption.on(c.textTertiary),
              filled: true,
              fillColor: c.surface,
              border: const OutlineInputBorder(
                borderRadius: R.rMd,
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: Sp.x6),
          DsButton(
            label: _isLoading ? '응모 중...' : '응모하기',
            onPressed: _isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
