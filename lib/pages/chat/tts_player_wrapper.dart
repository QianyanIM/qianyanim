import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 通用的TTS播放包装组件
/// 可以包裹任何子组件，并提供播放/停止功能
class TtsPlayerWrapper extends StatefulWidget {
  /// 需要朗读的文本内容
  final String text;
  final String languageCode;

  /// 被包裹的子组件
  final Widget child;

  /// 自定义播放图标（可选）
  final Icon? playIcon;

  /// 自定义停止图标（可选）
  final Icon? stopIcon;

  /// 图标尺寸（可选）
  final double? iconSize;

  /// 图标颜色（可选）
  final Color? iconColor;

  /// 播放状态变化回调（可选）
  final Function(bool isPlaying)? onPlayStateChanged;

  const TtsPlayerWrapper({
    super.key,
    required this.text,
    required this.languageCode,
    required this.child,
    this.playIcon,
    this.stopIcon,
    this.iconSize,
    this.iconColor,
    this.onPlayStateChanged,
  });

  @override
  State<TtsPlayerWrapper> createState() => _TtsPlayerWrapperState();
}

class _TtsPlayerWrapperState extends State<TtsPlayerWrapper> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  Future<void> _initTTS() async {
    // 配置TTS参数
    // await _flutterTts.setLanguage("zh-CN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak() async {
    await _flutterTts.setLanguage(widget.languageCode);
    await _flutterTts.speak(widget.text);
  }

  @override
  Widget build(BuildContext context) {
    // 默认图标
    final defaultPlayIcon = Icon(
      Icons.play_arrow,
      size: widget.iconSize ?? 24,
      color: widget.iconColor ?? Theme.of(context).primaryColor,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(child: widget.child),
        // 播放按钮
        IconButton(
          icon: defaultPlayIcon,
          onPressed: _speak,
          splashRadius: widget.iconSize ?? 24,
        ),
      ],
    );
  }

  @override
  void dispose() {
    // 页面销毁时停止播放并释放资源
    _flutterTts.stop();
    super.dispose();
  }
}
