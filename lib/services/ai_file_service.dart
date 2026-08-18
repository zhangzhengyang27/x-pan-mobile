import '../models/file_vo.dart';
import 'llm_service.dart';
import 'user_service.dart';

/// AI 文件操作（摘要 / 重命名建议）
///
/// 对齐网页版 useAIAssistant 的 summarize / rename 能力。
class AiFileService {
  AiFileService._();

  static final AiFileService instance = AiFileService._();

  static const int _maxContentChars = 4000;

  /// 提取文件文本内容（用于摘要）
  Future<String> _extractContent(FileVO file) async {
    try {
      final result = await FileService.instance.textExtract(file.fileId);
      var text = result.text;
      if (text.length > _maxContentChars) {
        text = text.substring(0, _maxContentChars);
      }
      return text;
    } catch (_) {
      return '';
    }
  }

  /// 文件摘要
  Future<String> summarize(FileVO file) async {
    final content = await _extractContent(file);
    if (content.isEmpty) {
      return '无法提取该文件的文本内容（可能是二进制文件，或内容为空）。';
    }

    final result = await LLMService.instance.chat(
      [
        const LLMMessage(
          role: 'system',
          content:
              '你是文件摘要助手。请用简洁的中文概括文件的核心内容，输出 3-5 个要点，每个要点一行，使用 markdown 列表格式。',
        ),
        LLMMessage(
          role: 'user',
          content: '文件名：${file.filename}\n\n内容：\n$content',
        ),
      ],
      temperature: 0.3,
    );
    return result;
  }

  /// 重命名建议
  Future<String> suggestRename(FileVO file) async {
    final content = await _extractContent(file);
    final result = await LLMService.instance.chat(
      [
        const LLMMessage(
          role: 'system',
          content:
              '你是文件命名助手。根据文件名和内容，给出 3 个更清晰、规范的文件名建议（保留原扩展名）。直接输出 3 行文件名，每行一个，不要编号，不要其他说明。',
        ),
        LLMMessage(
          role: 'user',
          content: '当前文件名：${file.filename}\n\n'
              '${content.isEmpty ? '' : '内容预览：\n$content'}',
        ),
      ],
      temperature: 0.5,
    );
    return result;
  }
}
