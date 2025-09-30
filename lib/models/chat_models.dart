// lib/models/chat_models.dart

class ChatUser {
  final String uuid;
  final String username;
  final String displayName;
  final String? avatarUrl; // ⭐ ADDED

  ChatUser({
    required this.uuid,
    required this.username,
    required this.displayName,
    this.avatarUrl, // ⭐ ADDED
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      uuid: json['user_uuid'],
      username: json['Username'],
      displayName: json['DisplayName'],
      avatarUrl: json['avatar_url'], // ⭐ ADDED
    );
  }
}

class Chat {
  final String chatUuid;
  final String partnerDisplayName;
  final String partnerUuid;
  final String? partnerAvatarUrl; // ⭐ ADDED
  final String lastMessage;
  final DateTime lastMessageSentAt;
  final String lastMessageSenderUuid;
  final int lastMessageStatus;

  Chat({
    required this.chatUuid,
    required this.partnerDisplayName,
    required this.partnerUuid,
    this.partnerAvatarUrl, // ⭐ ADDED
    required this.lastMessage,
    required this.lastMessageSentAt,
    required this.lastMessageSenderUuid,
    required this.lastMessageStatus,
  });

  factory Chat.fromJson(Map<String, dynamic> json, String currentUserUuid) {
    int _parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value.toString()) ?? 0;
    String partnerUuid;
    String partnerDisplayName;
    String? partnerAvatarUrl; // ⭐ ADDED

    if (json['user1_uuid'] == currentUserUuid) {
      partnerUuid = json['user2_uuid'];
      partnerDisplayName = json['user2_display_name'];
      partnerAvatarUrl = json['user2_avatar_url']; // ⭐ ADDED
    } else {
      partnerUuid = json['user1_uuid'];
      partnerDisplayName = json['user1_display_name'];
      partnerAvatarUrl = json['user1_avatar_url']; // ⭐ ADDED
    }

    return Chat(
      chatUuid: json['chat_uuid'],
      partnerDisplayName: partnerDisplayName,
      partnerUuid: partnerUuid,
      partnerAvatarUrl: partnerAvatarUrl, // ⭐ ADDED
      lastMessage: json['last_message_content'] ?? 'No messages yet.',
      lastMessageSentAt:
          DateTime.tryParse(json['last_message_sent_at'] ?? '') ??
          DateTime.now(),
      lastMessageSenderUuid: json['last_message_sender_uuid'],
      lastMessageStatus: _parseInt(json['last_message_status']),
    );
  }
  factory Chat.fromDbMap(Map<String, dynamic> map) {
    return Chat(
      chatUuid: map['uuid'],
      partnerDisplayName: map['other_user_display_name'],
      partnerUuid: map['other_user_uuid'],
      lastMessage: map['last_message_content'],
      lastMessageSentAt:
          DateTime.tryParse(map['last_message_timestamp']) ?? DateTime.now(),
      lastMessageSenderUuid: '', // Not stored locally
      lastMessageStatus: 0, // Not stored locally
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'uuid': chatUuid,
      'other_user_uuid': partnerUuid,
      'other_user_display_name': partnerDisplayName,
      'last_message_content': lastMessage,
      'last_message_timestamp': lastMessageSentAt.toIso8601String(),
      'unread_count': 0, // Default to 0 when inserting/updating
    };
  }
}

class Message {
  final String uuid;
  final String chatUuid;
  final String senderUuid;
  final String? recipientUuid;
  final String content;
  final DateTime sentAt;
  final int status;
  final bool isSynced;

  Message({
    required this.uuid,
    required this.chatUuid,
    required this.senderUuid,
    this.recipientUuid,
    required this.content,
    required this.sentAt,
    required this.status,
    this.isSynced = true,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    int _parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value.toString()) ?? 0;
    return Message(
      uuid: json['message_uuid'],
      chatUuid: json['chat_uuid'],
      senderUuid: json['sender_uuid'],
      content: json['content'],
      sentAt: DateTime.tryParse(json['sent_at'] ?? '') ?? DateTime.now(),
      status: _parseInt(json['status']),
      isSynced: true,
    );
  }
  factory Message.fromDbMap(Map<String, dynamic> map) {
    return Message(
      uuid: map['uuid'],
      chatUuid: map['chat_uuid'],
      senderUuid: map['sender_uuid'],
      recipientUuid: map['recipient_uuid'],
      content: map['content'],
      sentAt: DateTime.tryParse(map['created_at']) ?? DateTime.now(),
      status: map['is_read'] == 1 ? 1 : 0,
      isSynced: map['is_synced'] == 1,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'chat_uuid': chatUuid,
      'sender_uuid': senderUuid,
      'recipient_uuid': recipientUuid,
      'content': content,
      'created_at': sentAt.toIso8601String(),
      'is_read': status,
      'is_synced': isSynced ? 1 : 0,
    };
  }
}
