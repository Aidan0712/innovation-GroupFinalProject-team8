import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordedClip {
  const RecordedClip({
    required this.filePath,
    required this.durationSeconds,
  });

  final String filePath;
  final int durationSeconds;
}

class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({
    super.key,
    required this.onRecorded,
    required this.onError,
    this.enabled = true,
    this.busy = false,
  });

  final ValueChanged<RecordedClip> onRecorded;
  final ValueChanged<String> onError;
  final bool enabled;
  final bool busy;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  bool _isRecording = false;
  bool _isCancelling = false;
  int _durationSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording(LongPressStartDetails _) async {
    if (!widget.enabled || widget.busy || _isRecording) {
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      widget.onError('请先授予麦克风权限');
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );
      _durationSeconds = 0;
      _isCancelling = false;
      _isRecording = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _durationSeconds += 1;
          });
        }
      });
      setState(() {});
    } catch (_) {
      widget.onError('录音启动失败，请稍后重试');
    }
  }

  void _updateRecording(LongPressMoveUpdateDetails details) {
    if (!_isRecording) {
      return;
    }

    final shouldCancel = details.offsetFromOrigin.dy < -80;
    if (_isCancelling != shouldCancel) {
      setState(() {
        _isCancelling = shouldCancel;
      });
    }
  }

  Future<void> _finishRecording([LongPressEndDetails? _]) async {
    if (!_isRecording) {
      return;
    }

    _timer?.cancel();
    final path = await _recorder.stop();
    final wasCancelling = _isCancelling;
    final duration = _durationSeconds;

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isCancelling = false;
        _durationSeconds = 0;
      });
    }

    if (path == null || path.isEmpty) {
      if (!wasCancelling) {
        widget.onError('录音失败，请重试');
      }
      return;
    }

    if (wasCancelling) {
      File(path).deleteSync();
      widget.onError('已取消录音');
      return;
    }

    if (duration < 1) {
      File(path).deleteSync();
      widget.onError('录音时间过短，请重新录制');
      return;
    }

    widget.onRecorded(
      RecordedClip(filePath: path, durationSeconds: duration),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.busy
        ? '转写中...'
        : _isRecording
            ? (_isCancelling ? '松开取消' : '松开发送')
            : '按住说话';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_isRecording || widget.busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  widget.busy ? Icons.sync : Icons.mic,
                  size: 18,
                  color: widget.busy
                      ? const Color(0xFF6366F1)
                      : (_isCancelling
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF6366F1)),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.busy
                      ? '正在上传并转写录音'
                      : '${_durationSeconds.toString().padLeft(2, '0')} 秒 · ${_isCancelling ? '上滑取消' : '继续说话'}',
                  style: TextStyle(
                    color: widget.busy
                        ? const Color(0xFF6366F1)
                        : (_isCancelling
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF6366F1)),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onLongPressStart: _startRecording,
          onLongPressMoveUpdate: _updateRecording,
          onLongPressEnd: _finishRecording,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: widget.busy
                  ? const Color(0xFFE5E7EB)
                  : _isRecording
                      ? (_isCancelling
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF6366F1))
                      : Colors.white,
              border: Border.all(
                color: _isRecording
                    ? Colors.transparent
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: widget.busy || _isRecording
                    ? Colors.white
                    : const Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
