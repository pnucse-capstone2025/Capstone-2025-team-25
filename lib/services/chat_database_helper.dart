// lib/services/chat_database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_models.dart';

class ChatDatabaseHelper {
  static const _databaseName = "ChatDatabase.db";
  static const _databaseVersion = 1;

  ChatDatabaseHelper._privateConstructor();
  static final ChatDatabaseHelper instance =
      ChatDatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats (
        uuid TEXT PRIMARY KEY,
        other_user_uuid TEXT NOT NULL,
        other_user_display_name TEXT NOT NULL,
        last_message_content TEXT NOT NULL,
        last_message_timestamp TEXT NOT NULL,
        unread_count INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        uuid TEXT PRIMARY KEY,
        chat_uuid TEXT NOT NULL,
        sender_uuid TEXT NOT NULL,
        recipient_uuid TEXT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER NOT NULL,
        is_synced INTEGER NOT NULL
      )
    ''');
  }

  Future<void> insertOrUpdateChat(Chat chat) async {
    final db = await instance.database;
    await db.insert(
      'chats',
      chat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearChats() async {
    final db = await instance.database;
    await db.delete('chats');
  }

  Future<List<Chat>> getChats() async {
    final db = await instance.database;
    final maps = await db.query(
      'chats',
      orderBy: 'last_message_timestamp DESC',
    );
    return maps.map((map) => Chat.fromDbMap(map)).toList();
  }

  Future<void> insertOrUpdateMessage(Message message) async {
    final db = await instance.database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages(String chatUuid) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'chat_uuid = ?',
      whereArgs: [chatUuid],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => Message.fromDbMap(map)).toList();
  }

  Future<List<Message>> getUnsyncedMessages() async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return maps.map((map) => Message.fromDbMap(map)).toList();
  }

  Future<void> deleteMessageByUuid(String uuid) async {
    final db = await instance.database;
    await db.delete('messages', where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<void> clearAllChatData() async {
    final db = await instance.database;
    await db.delete('chats');
    await db.delete('messages');
  }
}
