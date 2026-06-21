import 'package:flutter/material.dart';
import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  static const Color _primary    = Color(0xFF7C3AED);
  static const Color _bubbleMine = Color(0xFF7C3AED);
  static const Color _bubbleTheir = Color(0xFFEDE9FF);
  static const Color _textMine   = Colors.white;
  static const Color _textTheir  = Color(0xFF2D1B69);
  static const Color _timeDim    = Color(0xFFA89FCC);

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.type == MessageType.image && message.imageUrl != null)
              ClipRRect(
                borderRadius: radius,
                child: Image.network(
                  message.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 200,
                      height: 200,
                      color: _bubbleTheir,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: _primary,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) => Container(
                    width: 200,
                    height: 200,
                    color: _bubbleTheir,
                    child: const Icon(Icons.broken_image_outlined,
                        color: _timeDim),
                  ),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? _bubbleMine : _bubbleTheir,
                  borderRadius: radius,
                ),
                child: Text(
                  message.text ?? '',
                  style: TextStyle(
                    color: isMe ? _textMine : _textTheir,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _formatTime(message.createdAt),
                style: const TextStyle(fontSize: 10, color: _timeDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}