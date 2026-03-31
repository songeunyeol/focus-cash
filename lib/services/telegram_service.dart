import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class TelegramService {
  static const String _token = AppSecrets.telegramBotToken;
  static const int _chatId = AppSecrets.telegramChatId;

  static Future<void> sendRaffleWinnerAlert({
    required String roomTitle,
    required String prize,
    required String winnerName,
    required String winnerPhone,
    required String winnerAddress,
    required String winnerId,
  }) async {
    final message = '''
🎉 *응모방 당첨자 발생!*

📦 응모방: $roomTitle
🎁 상품: $prize
👤 수령인: $winnerName
📱 연락처: $winnerPhone
🏠 배송지: $winnerAddress
🆔 UID: $winnerId

배송지로 상품을 발송해주세요.
''';

    try {
      await http.post(
        Uri.parse('https://api.telegram.org/bot$_token/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _chatId,
          'text': message,
          'parse_mode': 'Markdown',
        }),
      );
    } catch (_) {
      // 네트워크 오류 시 무시 (Firestore에 기록됨)
    }
  }
}
