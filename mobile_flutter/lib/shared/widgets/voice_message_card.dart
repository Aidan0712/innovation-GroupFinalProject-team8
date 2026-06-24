import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

class VoiceMessageCard extends StatefulWidget {
  const VoiceMessageCard({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.transcript,
  });

  final String audioUrl;
  final int durationSeconds;
  final String transcript;

  @override
  State<VoiceMessageCard> createState() => _VoiceMessageCardState();
}

class _VoiceMessageCardState extends State<VoiceMessageCard> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _playing = false;
        });
      }
      return;
    }

    await _player.play(UrlSource(widget.audioUrl));
    if (mounted) {
      setState(() {
        _playing = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton.filledTonal(
                onPressed: _togglePlay,
                icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '语音回答 · ${AppFormatters.formatDuration(widget.durationSeconds)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (widget.transcript.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              widget.transcript,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
