import 'language_detect.dart';
import 'package:learning_language/learning_language.dart';

class LanguageDetectImpl implements LanguageDetect {
  @override
  Future<String> detect(String text) async {
    final identifier = LanguageIdentifier();
    return await identifier.identify(text);
  }
}

// 提供一个工厂函数，方便外部获取实例
LanguageDetect getLanguageDetector() => LanguageDetectImpl();
