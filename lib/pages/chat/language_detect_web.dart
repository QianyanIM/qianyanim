import 'language_detect.dart';

class LanguageDetectImpl implements LanguageDetect {
  @override
  Future<String> detect(String text) async {
    return "";
  }
}

// 提供一个工厂函数，方便外部获取实例
LanguageDetect getLanguageDetector() => LanguageDetectImpl();
