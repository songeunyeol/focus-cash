import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/friend_service.dart';

// ── 토스트 헬퍼 ────────────────────────────────────────────────
enum _ToastType { success, cancel, error, info }

void _toast(
  BuildContext context,
  String message, {
  _ToastType type = _ToastType.info,
}) {
  final (icon, color) = switch (type) {
    _ToastType.success => (Icons.check_circle_rounded, const Color(0xFF4CAF50)),
    _ToastType.cancel  => (Icons.cancel_rounded,       const Color(0xFF9E9E9E)),
    _ToastType.error   => (Icons.error_rounded,         const Color(0xFFEF5350)),
    _ToastType.info    => (Icons.info_rounded,           AppTheme.primaryColor),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.35), width: 1),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 2),
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final FriendService _friendService = FriendService();
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  String _searchMode = 'name'; // 'name' | 'code'

  List<UserModel> _friends = [];
  Set<String> _friendUids = {};
  Set<String> _sentPendingUids = {};
  List<Map<String, dynamic>> _pendingRequests = [];

  StreamSubscription<List<UserModel>>? _friendsSub;
  StreamSubscription<Set<String>>? _sentPendingSub;
  StreamSubscription<List<Map<String, dynamic>>>? _receivedSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final myUid = context.read<AuthProvider>().user?.uid ?? '';
      if (myUid.isEmpty) return;

      _friendsSub = _friendService.watchFriends(myUid).listen((friends) {
        if (mounted) {
          setState(() {
            _friends = friends;
            _friendUids = friends.map((f) => f.uid).toSet();
          });
        }
      });

      _sentPendingSub =
          _friendService.watchSentPendingUids(myUid).listen((uids) {
        if (mounted) setState(() => _sentPendingUids = uids);
      });

      _receivedSub =
          _friendService.watchPendingRequests(myUid).listen((requests) {
        if (mounted) setState(() => _pendingRequests = requests);
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _friendsSub?.cancel();
    _sentPendingSub?.cancel();
    _receivedSub?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      List<UserModel> results;
      if (_searchMode == 'code') {
        final user = await _friendService.searchByInviteCode(query);
        results = user != null ? [user] : [];
        if (results.isEmpty && mounted) {
          _toast(context, '유효하지 않은 초대 코드예요.', type: _ToastType.error);
        }
      } else {
        results = await _friendService.searchByName(query);
      }
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) {
        _toast(context, '검색 중 오류가 발생했습니다. 다시 시도해주세요.', type: _ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _toggleRequest(String myUid, String toUid) async {
    if (_sentPendingUids.contains(toUid)) {
      // 대기중 → 취소
      await _friendService.cancelFriendRequest(
          fromUid: myUid, toUid: toUid);
      if (mounted) {
        _toast(context, '친구 요청을 취소했습니다.', type: _ToastType.cancel);
      }
    } else {
      // 요청 보내기
      await _friendService.sendFriendRequest(fromUid: myUid, toUid: toUid);
      if (mounted) {
        _toast(context, '친구 요청을 보냈습니다!', type: _ToastType.success);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final myUid = authProvider.user?.uid ?? '';
    final myModel = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            const Tab(text: '친구'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('요청'),
                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: '찾기'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendListTab(myUid, myModel),
          _buildRequestsTab(myUid),
          _buildSearchTab(myUid),
        ],
      ),
    );
  }

  // ── 친구 탭 ───────────────────────────────────────────────
  Widget _buildFriendListTab(String myUid, UserModel? myModel) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMyInviteCard(myModel),
        const SizedBox(height: 20),
        _buildFriendList(myUid),
      ],
    );
  }

  Widget _buildMyInviteCard(UserModel? myModel) {
    final code = myModel?.inviteCode ?? '불러오는 중...';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.3),
            AppTheme.primaryColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard,
                  color: AppTheme.creditGold, size: 20),
              const SizedBox(width: 8),
              const Text(
                '내 초대 코드',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                code,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  _toast(context, '초대 코드가 복사되었습니다!', type: _ToastType.info);
                },
                icon: const Icon(Icons.copy, color: AppTheme.textSecondary),
                tooltip: '코드 복사',
              ),
              IconButton(
                onPressed: () {
                  Share.share(
                    '포커스캐시 같이 해요! 🎯\n'
                    '내 초대 코드: $code\n\n'
                    '초대 코드로 가입하면 둘 다 200 크레딧 받아요!\n'
                    '집중하고 기프티콘 받는 앱 → 포커스캐시',
                  );
                },
                icon: const Icon(Icons.share, color: AppTheme.primaryColor),
                tooltip: '공유',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '친구가 이 코드로 가입하면 둘 다 200 크레딧!',
            style: TextStyle(color: AppTheme.creditGold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendList(String myUid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '친구 ${_friends.length}명',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_friends.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '아직 친구가 없어요.\n찾기 탭에서 친구를 추가해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          ..._friends.map((friend) => _FriendTile(
                friend: friend,
                myUid: myUid,
                friendService: _friendService,
              )),
      ],
    );
  }

  // ── 요청 탭 ───────────────────────────────────────────────
  Widget _buildRequestsTab(String myUid) {
    if (_pendingRequests.isEmpty) {
      return const Center(
        child: Text(
          '받은 친구 요청이 없어요.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '받은 친구 요청 ${_pendingRequests.length}건',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._pendingRequests.map((req) => _PendingRequestTile(
              fromUid: req['from'] as String? ?? '',
              requestId: req['id'] as String? ?? '',
              friendService: _friendService,
            )),
      ],
    );
  }

  // ── 찾기 탭 ───────────────────────────────────────────────
  Widget _buildSearchTab(String myUid) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 검색 모드 토글
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _searchMode = 'name';
                    _searchResults = [];
                    _searchController.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _searchMode == 'name'
                          ? AppTheme.primaryColor
                          : AppTheme.surfaceColor,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(10)),
                    ),
                    child: Center(
                      child: Text(
                        '닉네임 검색',
                        style: TextStyle(
                          color: _searchMode == 'name'
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _searchMode = 'code';
                    _searchResults = [];
                    _searchController.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _searchMode == 'code'
                          ? AppTheme.primaryColor
                          : AppTheme.surfaceColor,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10)),
                    ),
                    child: Center(
                      child: Text(
                        '초대 코드',
                        style: TextStyle(
                          color: _searchMode == 'code'
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        _searchMode == 'code' ? '초대 코드 8자리 입력' : '닉네임 검색',
                    hintStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search,
                        color: AppTheme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _search,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('검색'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? '검색어를 입력해주세요'
                          : '검색 결과가 없습니다',
                      style:
                          const TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return _SearchResultTile(
                        user: user,
                        myUid: myUid,
                        isFriend: _friendUids.contains(user.uid),
                        isPending: _sentPendingUids.contains(user.uid),
                        onToggleRequest: () =>
                            _toggleRequest(myUid, user.uid),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 받은 요청 타일 ─────────────────────────────────────────────
class _PendingRequestTile extends StatefulWidget {
  final String fromUid;
  final String requestId;
  final FriendService friendService;

  const _PendingRequestTile({
    required this.fromUid,
    required this.requestId,
    required this.friendService,
  });

  @override
  State<_PendingRequestTile> createState() => _PendingRequestTileState();
}

class _PendingRequestTileState extends State<_PendingRequestTile> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final snap = await widget.friendService.getUserByUid(widget.fromUid);
      if (mounted) setState(() => _user = snap);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _user?.displayName.isNotEmpty == true ? _user!.displayName : '집중러';
    final avatarIdx =
        (_user?.avatarIndex ?? 0).clamp(0, AppConstants.avatarEmojis.length - 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withAlpha(50),
            child: Text(AppConstants.avatarEmojis[avatarIdx],
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              await widget.friendService
                  .rejectFriendRequest(widget.requestId);
              if (!context.mounted) return;
              _toast(context, '친구 요청을 거절했습니다.', type: _ToastType.cancel);
            },
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
            child: const Text('거절'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () async {
              await widget.friendService
                  .acceptFriendRequest(widget.requestId);
              if (!context.mounted) return;
              _toast(context, '친구가 되었습니다! 🎉', type: _ToastType.success);
            },
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: const Text('수락'),
          ),
        ],
      ),
    );
  }
}

// ── 친구 목록 타일 ─────────────────────────────────────────────
class _FriendTile extends StatelessWidget {
  final UserModel friend;
  final String myUid;
  final FriendService friendService;

  const _FriendTile({
    required this.friend,
    required this.myUid,
    required this.friendService,
  });

  @override
  Widget build(BuildContext context) {
    final avatarIdx =
        friend.avatarIndex.clamp(0, AppConstants.avatarEmojis.length - 1);
    final name =
        friend.displayName.isNotEmpty ? friend.displayName : '집중러';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withAlpha(50),
            child: Text(AppConstants.avatarEmojis[avatarIdx],
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text('${friend.currentStreak}일 연속 집중',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_remove_outlined,
                color: AppTheme.textSecondary, size: 20),
            onPressed: () => _confirmRemove(context),
            tooltip: '친구 삭제',
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    final displayName =
        friend.displayName.isNotEmpty ? friend.displayName : '집중러';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('친구 삭제',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '$displayName님을 친구 목록에서 삭제하시겠어요?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await friendService.removeFriend(
                  myUid: myUid, friendUid: friend.uid);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── 검색 결과 타일 ─────────────────────────────────────────────
class _SearchResultTile extends StatelessWidget {
  final UserModel user;
  final String myUid;
  final bool isFriend;
  final bool isPending;
  final VoidCallback onToggleRequest;

  const _SearchResultTile({
    required this.user,
    required this.myUid,
    required this.isFriend,
    required this.isPending,
    required this.onToggleRequest,
  });

  @override
  Widget build(BuildContext context) {
    final avatarIdx =
        user.avatarIndex.clamp(0, AppConstants.avatarEmojis.length - 1);
    final name = user.displayName.isNotEmpty ? user.displayName : '집중러';
    final isMe = user.uid == myUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withAlpha(50),
            child: Text(AppConstants.avatarEmojis[avatarIdx],
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      _badge('나', AppTheme.primaryColor),
                    ] else if (isFriend) ...[
                      const SizedBox(width: 6),
                      _badge('친구', AppTheme.accentGreen),
                    ],
                  ],
                ),
                Text('${user.currentStreak}일 연속 집중',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          // 버튼 영역
          if (isMe)
            const SizedBox.shrink()
          else if (isFriend)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.accentGreen.withValues(alpha: 0.4)),
              ),
              child: const Text(
                '✓ 친구',
                style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            )
          else if (isPending)
            // 대기중 → 탭하면 취소
            GestureDetector(
              onTap: onToggleRequest,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top,
                        size: 13, color: AppTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      '대기중',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: onToggleRequest,
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('요청'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}
