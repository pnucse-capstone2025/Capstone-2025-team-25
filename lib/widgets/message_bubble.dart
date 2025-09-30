// lib/widgets/message_bubble.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_models.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).primaryColor.withOpacity(0.4)
                    : Colors.white.withOpacity(0.3),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(0),
                  bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.sentAt.toLocal()),
                        style: TextStyle(
                          color: isMe ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 5),
                        Icon(
                          message.status == 2 ? Icons.done_all : Icons.done,
                          size: 16,
                          color: message.status == 2
                              ? Colors.lightBlueAccent
                              : Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
