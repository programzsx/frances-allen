import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Renders question text with markdown-like formatting:
/// - **text** → bold indigo text
/// - ==text== → yellow highlight
/// - `text` → code (red text on slate bg)
/// - ---- → horizontal divider (on its own line)
/// - ___ → fill-in-the-blank placeholder
/// - ![url] → image (rendered as full-width block)
class QuestionRichText extends StatelessWidget {
  final String text;
  final bool revealed;
  final List<String> answers;
  final double fontSize;

  const QuestionRichText({
    super.key,
    required this.text,
    this.revealed = false,
    this.answers = const [],
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        switch (block.type) {
          case _BlockType.divider:
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Divider(color: AppTheme.border, thickness: 1, height: 1),
            );
          case _BlockType.image:
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: GestureDetector(
                onTap: () => QuestionRichText.showFullScreenImage(context, block.content!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: CachedNetworkImage(
                    imageUrl: block.content!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => SizedBox(
                      height: 150.h,
                      width: double.infinity,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => SizedBox(
                      height: 100.h,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image, size: 32.sp, color: AppTheme.textTertiary),
                            SizedBox(height: 4.h),
                            Text('图片加载失败', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          case _BlockType.text:
            return RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: fontSize.sp,
                  height: 1.8,
                  color: AppTheme.textPrimary,
                ),
                children: _tokenizeInline(block.content!, 0),
              ),
            );
        }
      }).toList(),
    );
  }

  List<_Block> _parseBlocks(String text) {
    final blocks = <_Block>[];
    final lines = text.split('\n');

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed == '----') {
        blocks.add(_Block(_BlockType.divider, null));
      } else if (trimmed.startsWith('![') && trimmed.endsWith(']')) {
        final url = trimmed.substring(2, trimmed.length - 1);
        if (url.isNotEmpty) {
          blocks.add(_Block(_BlockType.image, url));
        }
      } else {
        blocks.add(_Block(_BlockType.text, rawLine));
      }
    }

    return blocks;
  }

  List<InlineSpan> _tokenizeInline(String text, int startBlankIndex) {
    final spans = <InlineSpan>[];
    int pos = 0;
    int answerIndex = 0;
    StringBuffer buf = StringBuffer();

    void flushText() {
      if (buf.isNotEmpty) {
        spans.add(TextSpan(text: buf.toString()));
        buf = StringBuffer();
      }
    }

    while (pos < text.length) {
      // **bold**
      if (pos + 1 < text.length && text[pos] == '*' && text[pos + 1] == '*') {
        final end = text.indexOf('**', pos + 2);
        if (end != -1) {
          flushText();
          spans.add(TextSpan(
            text: text.substring(pos + 2, end),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
              fontSize: fontSize.sp,
            ),
          ));
          pos = end + 2;
          continue;
        }
      }

      // ==highlight==
      if (pos + 1 < text.length && text[pos] == '=' && text[pos + 1] == '=') {
        final end = text.indexOf('==', pos + 2);
        if (end != -1) {
          flushText();
          spans.add(TextSpan(
            text: text.substring(pos + 2, end),
            style: TextStyle(
              backgroundColor: const Color(0xFFFFF9C4),
              fontSize: fontSize.sp,
            ),
          ));
          pos = end + 2;
          continue;
        }
      }

      // `code`
      if (text[pos] == '`') {
        final end = text.indexOf('`', pos + 1);
        if (end != -1) {
          flushText();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppTheme.bgSection,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                text.substring(pos + 1, end),
                style: TextStyle(
                  color: AppTheme.red,
                  fontFamily: 'monospace',
                  fontSize: fontSize.sp * 0.9,
                ),
              ),
            ),
          ));
          pos = end + 1;
          continue;
        }
      }

      // ___ blank
      if (pos + 2 < text.length && text[pos] == '_' && text[pos + 1] == '_' && text[pos + 2] == '_') {
        flushText();
        if (revealed && answerIndex < answers.length) {
          spans.add(TextSpan(
            text: ' ${answers[answerIndex]} ',
            style: TextStyle(
              backgroundColor: Colors.green.shade100,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade800,
              fontSize: fontSize.sp,
            ),
          ));
          answerIndex++;
        } else {
          spans.add(TextSpan(
            text: ' ______ ',
            style: TextStyle(
              backgroundColor: AppTheme.indigo100,
              fontWeight: FontWeight.w600,
              fontSize: fontSize.sp,
            ),
          ));
        }
        pos += 3;
        continue;
      }

      buf.write(text[pos]);
      pos++;
    }

    flushText();
    return spans;
  }

  static void showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(ctx).padding.top,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _BlockType { text, divider, image }

class _Block {
  final _BlockType type;
  final String? content;
  _Block(this.type, this.content);
}
