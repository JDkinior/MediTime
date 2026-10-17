import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';

/// A rich, resilient message renderer for Midi's chat responses.
///
/// Automatically formats:
/// - Markdown tables (| ... | ... |) as native scrollable Flutter data cards.
/// - Callout / Alert blocks (> Nota:, > Atención:, etc.) with accent borders and icons.
/// - Bullet and numbered lists (- , • , 1. ) with styled markers and clean indentation.
/// - Section headers (### , ## , # ) with themed typography and accents.
/// - Inline bold (**text**), code (`code`), and temporal countdown badges (e.g. "quedan 2 días", "¡Finaliza HOY!").
class MarkdownMessageBody extends StatelessWidget {
  const MarkdownMessageBody({
    super.key,
    required this.text,
    this.textColor,
    this.fontSize = 14.5,
  });

  final String text;
  final Color? textColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTextColor = textColor ??
        (isDark ? Colors.white.withValues(alpha: 0.92) : AppTheme.primaryTextColor);

    final blocks = _parseBlocks(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks.map((block) {
        return _buildBlockWidget(context, block, effectiveTextColor, isDark);
      }).toList(),
    );
  }

  Widget _buildBlockWidget(
    BuildContext context,
    _Block block,
    Color baseColor,
    bool isDark,
  ) {
    if (block is _TableBlock) {
      return _buildTableWidget(context, block, baseColor, isDark);
    } else if (block is _CalloutBlock) {
      return _buildCalloutWidget(context, block, baseColor, isDark);
    } else if (block is _HeaderBlock) {
      return _buildHeaderWidget(context, block, baseColor, isDark);
    } else if (block is _ListBlock) {
      return _buildListWidget(context, block, baseColor, isDark);
    } else if (block is _ParagraphBlock) {
      return _buildParagraphWidget(context, block, baseColor, isDark);
    }
    return const SizedBox.shrink();
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Table Renderer
  // ─────────────────────────────────────────────────────────────

  Widget _buildTableWidget(
    BuildContext context,
    _TableBlock block,
    Color baseColor,
    bool isDark,
  ) {
    if (block.headers.isEmpty && block.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final columnCount = block.headers.isNotEmpty
        ? block.headers.length
        : (block.rows.isNotEmpty ? block.rows.first.length : 0);

    if (columnCount == 0) return const SizedBox.shrink();

    final headerBg = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.28)
        : AppTheme.primaryColor.withValues(alpha: 0.09);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppTheme.primaryColor.withValues(alpha: 0.18);
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFFAFBFD);
    final rowZebraBg = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.02);

    final tableRows = <TableRow>[];

    // Header Row
    if (block.headers.isNotEmpty) {
      final paddedHeaders = List<String>.from(block.headers);
      while (paddedHeaders.length < columnCount) {
        paddedHeaders.add('');
      }

      tableRows.add(
        TableRow(
          decoration: BoxDecoration(color: headerBg),
          children: paddedHeaders.take(columnCount).map((h) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text.rich(
                TextSpan(
                  children: _buildInlineSpans(
                    h.trim(),
                    isDark ? Colors.white : AppTheme.primaryColor,
                    isDark,
                    isHeader: true,
                  ),
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: isDark ? Colors.white : AppTheme.primaryColor,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    // Data Rows
    for (int i = 0; i < block.rows.length; i++) {
      final row = block.rows[i];
      final paddedRow = List<String>.from(row);
      while (paddedRow.length < columnCount) {
        paddedRow.add('');
      }

      final isEven = i % 2 == 0;
      tableRows.add(
        TableRow(
          decoration: BoxDecoration(
            color: isEven ? Colors.transparent : rowZebraBg,
          ),
          children: paddedRow.take(columnCount).map((cell) {
            final cellText = cell.trim().isEmpty ? '—' : cell.trim();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text.rich(
                TextSpan(
                  children: _buildInlineSpans(
                    cellText,
                    baseColor,
                    isDark,
                  ),
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: baseColor,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Callout / Alert Box Renderer
  // ─────────────────────────────────────────────────────────────

  Widget _buildCalloutWidget(
    BuildContext context,
    _CalloutBlock block,
    Color baseColor,
    bool isDark,
  ) {
    final textContent = block.content.trim();
    if (textContent.isEmpty) return const SizedBox.shrink();

    Color accentColor = AppTheme.primaryColor;
    IconData icon = Icons.info_outline;

    final lower = textContent.toLowerCase();
    if (lower.contains('alerta') ||
        lower.contains('advertencia') ||
        lower.contains('atención') ||
        lower.contains('atencion') ||
        lower.contains('peligro') ||
        lower.contains('tóxico') ||
        lower.contains('toxico') ||
        lower.contains('cuidado') ||
        lower.contains('urgencia')) {
      accentColor = const Color(0xFFE65100); // Amber/Orange
      icon = Icons.warning_amber_rounded;
    } else if (lower.contains('éxito') ||
        lower.contains('completado') ||
        lower.contains('listo') ||
        lower.contains('finalizado')) {
      accentColor = const Color(0xFF2E7D32); // Green
      icon = Icons.check_circle_outline;
    } else if (lower.contains('mascota') || lower.contains('veterinari')) {
      accentColor = const Color(0xFF2E7D32); // Greenish
      icon = Icons.pets;
    } else {
      accentColor = const Color(0xFF0284C7); // Sky Blue
      icon = Icons.lightbulb_outline;
    }

    // Strip duplicate leading emoji icons and any markdown blockquote markers
    var displayContent = textContent;
    displayContent = displayContent.replaceAll(RegExp(r'(^|\n)\s*>\s*'), r'$1').trim();
    if (displayContent.startsWith('💡 ') || displayContent.startsWith('⚠️ ')) {
      displayContent = displayContent.substring(2).trim();
    }
    if (displayContent.startsWith('⚠️ ')) {
      displayContent = displayContent.substring(2).trim();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: accentColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: _buildInlineSpans(displayContent, baseColor, isDark),
                ),
                style: TextStyle(
                  fontSize: 13.0,
                  height: 1.35,
                  color: baseColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Header Renderer
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeaderWidget(
    BuildContext context,
    _HeaderBlock block,
    Color baseColor,
    bool isDark,
  ) {
    final double headerFontSize = block.level == 1
        ? 16.5
        : (block.level == 2 ? 15.5 : 14.5);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3.5,
            height: 14,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: _buildInlineSpans(
                  block.content,
                  isDark ? Colors.white : AppTheme.primaryTextColor,
                  isDark,
                  isHeader: true,
                ),
              ),
              style: TextStyle(
                fontSize: headerFontSize,
                fontWeight: FontWeight.bold,
                height: 1.3,
                color: isDark ? Colors.white : AppTheme.primaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. List Renderer
  // ─────────────────────────────────────────────────────────────

  Widget _buildListWidget(
    BuildContext context,
    _ListBlock block,
    Color baseColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: block.items.map((item) {
          final double leftIndent = item.depth * 14.0;

          Widget marker;
          if (item.number != null) {
            marker = Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.3 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${item.number}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.primaryColor,
                ),
              ),
            );
          } else if (item.depth == 0) {
            marker = Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 7, left: 1, right: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            );
          } else {
            marker = Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 8, left: 2, right: 3),
              decoration: BoxDecoration(
                color: isDark ? Colors.white60 : Colors.black45,
                shape: BoxShape.circle,
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(left: leftIndent, top: 2.5, bottom: 2.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                marker,
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _buildInlineSpans(item.content, baseColor, isDark),
                    ),
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.35,
                      color: baseColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Paragraph Renderer
  // ─────────────────────────────────────────────────────────────

  Widget _buildParagraphWidget(
    BuildContext context,
    _ParagraphBlock block,
    Color baseColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Text.rich(
        TextSpan(
          children: _buildInlineSpans(block.content, baseColor, isDark),
        ),
        style: TextStyle(
          fontSize: fontSize,
          height: 1.38,
          color: baseColor,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Inline Parser (Bold, Badges, Highlights)
  // ─────────────────────────────────────────────────────────────

  static List<InlineSpan> _buildInlineSpans(
    String text,
    Color baseColor,
    bool isDark, {
    bool isHeader = false,
  }) {
    final List<InlineSpan> spans = [];

    // Regex to match bold **text**, code `text`, and countdown patterns
    final RegExp tokenRegex = RegExp(
      r'(\*\*(.*?)\*\*)|(`(.*?)`)|(¡Finaliza HOY!|Finaliza HOY|Finaliza MAÑANA|quedan \d+ días(?: restantes)?|\d+ días restantes|\d+ días|queda 1 día|Continuo / Indefinido|sin fecha de fin programada)',
      caseSensitive: false,
    );

    int lastIndex = 0;

    for (final match in tokenRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: baseColor),
        ));
      }

      final boldGroup = match.group(2);
      final codeGroup = match.group(4);
      final badgeGroup = match.group(5);

      if (boldGroup != null) {
        final isBrand = boldGroup.toLowerCase().contains('meditime') ||
            boldGroup.toLowerCase().contains('midi');
        spans.add(TextSpan(
          text: boldGroup,
          style: TextStyle(
            color: isBrand ? AppTheme.primaryColor : baseColor,
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (codeGroup != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              codeGroup,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: baseColor,
              ),
            ),
          ),
        ));
      } else if (badgeGroup != null && !isHeader) {
        // Render a cute pill badge for countdowns & deadlines
        final badgeWidget = _buildBadge(badgeGroup, isDark);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: badgeWidget,
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: baseColor),
      ));
    }

    return spans;
  }

  static Widget _buildBadge(String rawText, bool isDark) {
    final lower = rawText.toLowerCase();

    Color bgColor;
    Color fgColor;
    IconData? icon;

    if (lower.contains('hoy')) {
      bgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
      fgColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
      icon = Icons.alarm;
    } else if (lower.contains('mañana') ||
        lower.contains('1 día') ||
        lower.contains('2 días') ||
        lower.contains('3 días')) {
      bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      fgColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706);
      icon = Icons.hourglass_top;
    } else if (lower.contains('continuo') || lower.contains('sin fecha')) {
      bgColor = isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF);
      fgColor = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5);
      icon = Icons.all_inclusive;
    } else {
      bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
      fgColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
      icon = Icons.event_available;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fgColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fgColor),
          const SizedBox(width: 3.5),
          Text(
            rawText.trim(),
            style: TextStyle(
              color: fgColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 7. Structural Block Parser
  // ─────────────────────────────────────────────────────────────

  static List<_Block> _parseBlocks(String input) {
    final List<_Block> blocks = [];
    final lines = input.split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // 1. Table Detection
      if (trimmed.startsWith('|') && trimmed.contains('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          tableLines.add(lines[i].trim());
          i++;
        }

        final parsedTable = _tryParseTable(tableLines);
        if (parsedTable != null) {
          blocks.add(parsedTable);
          continue;
        } else {
          // If table parsing failed, fallback to paragraph
          blocks.add(_ParagraphBlock(tableLines.join('\n')));
          continue;
        }
      }

      // 2. Callout Block Detection (> ...)
      if (trimmed.startsWith('>')) {
        final calloutLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          var cl = lines[i].trim();
          while (cl.startsWith('>')) {
            cl = cl.substring(1).trimLeft();
          }

          // If a new distinct alert/note header starts on this line and we already have lines collected,
          // emit the current block and start a new one so they appear as separate styled cards
          final isNewAlertHeader = cl.startsWith('💡') ||
              cl.startsWith('⚠️') ||
              cl.startsWith('**Nota') ||
              cl.startsWith('**Atención') ||
              cl.startsWith('**Alerta') ||
              cl.startsWith('Nota:') ||
              cl.startsWith('Atención:') ||
              cl.startsWith('Alerta:');

          if (isNewAlertHeader && calloutLines.isNotEmpty) {
            blocks.add(_CalloutBlock(calloutLines.join('\n')));
            calloutLines.clear();
          }

          calloutLines.add(cl.trim());
          i++;
        }
        if (calloutLines.isNotEmpty) {
          blocks.add(_CalloutBlock(calloutLines.join('\n')));
        }
        continue;
      }

      // 3. Header Detection (# , ## , ### )
      if (trimmed.startsWith('#')) {
        final headerMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
        if (headerMatch != null) {
          final level = headerMatch.group(1)!.length;
          final content = headerMatch.group(2)!.trim();
          blocks.add(_HeaderBlock(level: level, content: content));
          i++;
          continue;
        }
      }

      // 4. List Block Detection (- , * , • , 1. )
      if (_isListLine(line)) {
        final listItems = <_ListItemBlock>[];
        while (i < lines.length && _isListLine(lines[i])) {
          final l = lines[i];
          final parsed = _parseListItem(l);
          if (parsed != null) {
            listItems.add(parsed);
          }
          i++;
        }
        if (listItems.isNotEmpty) {
          blocks.add(_ListBlock(listItems));
          continue;
        }
      }

      // 5. Default Paragraph
      final paragraphLines = <String>[line];
      i++;
      while (i < lines.length) {
        final nextTrimmed = lines[i].trim();
        if (nextTrimmed.isEmpty ||
            nextTrimmed.startsWith('|') ||
            nextTrimmed.startsWith('>') ||
            nextTrimmed.startsWith('#') ||
            _isListLine(lines[i])) {
          break;
        }
        paragraphLines.add(lines[i]);
        i++;
      }
      blocks.add(_ParagraphBlock(paragraphLines.join('\n')));
    }

    return blocks;
  }

  static bool _isListLine(String rawLine) {
    final trimmed = rawLine.trim();
    if (trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        trimmed.startsWith('• ')) {
      return true;
    }
    return RegExp(r'^\d+\.\s+').hasMatch(trimmed);
  }

  static _ListItemBlock? _parseListItem(String rawLine) {
    final leadingSpaces = rawLine.length - rawLine.trimLeft().length;
    final depth = (leadingSpaces / 2).floor();
    final trimmed = rawLine.trim();

    final numberMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
    if (numberMatch != null) {
      final num = int.tryParse(numberMatch.group(1)!);
      return _ListItemBlock(
        content: numberMatch.group(2)!.trim(),
        depth: depth,
        number: num,
      );
    }

    final bulletMatch = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
    if (bulletMatch != null) {
      return _ListItemBlock(
        content: bulletMatch.group(1)!.trim(),
        depth: depth,
      );
    }

    return null;
  }

  static _TableBlock? _tryParseTable(List<String> lines) {
    if (lines.length < 2) return null;

    List<String> splitRow(String line) {
      var content = line.trim();
      if (content.startsWith('|')) content = content.substring(1);
      if (content.endsWith('|')) content = content.substring(0, content.length - 1);
      return content.split('|').map((c) => c.trim()).toList();
    }

    bool isSeparator(String line) {
      final cells = splitRow(line);
      if (cells.isEmpty) return false;
      return cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c));
    }

    final headers = splitRow(lines[0]);
    int startIndex = 1;

    // Check if line 1 is separator
    if (startIndex < lines.length && isSeparator(lines[startIndex])) {
      startIndex = 2;
    }

    final rows = <List<String>>[];
    for (int k = startIndex; k < lines.length; k++) {
      if (!isSeparator(lines[k])) {
        rows.add(splitRow(lines[k]));
      }
    }

    return _TableBlock(headers: headers, rows: rows);
  }
}

// ─────────────────────────────────────────────────────────────
// Abstract Block Models
// ─────────────────────────────────────────────────────────────

abstract class _Block {}

class _TableBlock extends _Block {
  _TableBlock({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}

class _CalloutBlock extends _Block {
  _CalloutBlock(this.content);
  final String content;
}

class _HeaderBlock extends _Block {
  _HeaderBlock({required this.level, required this.content});
  final int level;
  final String content;
}

class _ListItemBlock {
  _ListItemBlock({
    required this.content,
    required this.depth,
    this.number,
  });
  final String content;
  final int depth;
  final int? number;
}

class _ListBlock extends _Block {
  _ListBlock(this.items);
  final List<_ListItemBlock> items;
}

class _ParagraphBlock extends _Block {
  _ParagraphBlock(this.content);
  final String content;
}
