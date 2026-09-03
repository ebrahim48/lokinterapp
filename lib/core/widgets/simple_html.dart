import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders the small HTML documents the CMS returns (terms, privacy policy)
/// in the app's own typography — headings, paragraphs, lists, bold/italic and
/// links — instead of shipping a webview for two static pages. Tags it does
/// not know are dropped, so plain-text content passes straight through.
class SimpleHtml extends StatefulWidget {
  final String html;
  const SimpleHtml(this.html, {super.key});

  /// Whether the CMS actually sent something worth rendering — `<p></p>` and
  /// stray markup count as empty, and the caller shows its own fallback.
  static bool hasText(String? html) =>
      html != null && _decode(html.replaceAll(RegExp(r'<[^>]*>'), ' ')).trim().isNotEmpty;

  @override
  State<SimpleHtml> createState() => _SimpleHtmlState();
}

class _SimpleHtmlState extends State<SimpleHtml> {
  late List<_Block> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = _parse(widget.html);
  }

  @override
  void didUpdateWidget(SimpleHtml old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) {
      _disposeRecognizers();
      _blocks = _parse(widget.html);
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final b in _blocks) {
      for (final s in b.spans) {
        s.tap?.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.6);
    final children = <Widget>[];

    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      final heading = _headingLevel(block.tag);
      final style = heading == 0
          ? body
          : TextStyle(
              fontSize: (heading <= 2 ? 16 : 14).sp,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              height: 1.4,
            );

      if (i > 0) children.add(SizedBox(height: (heading > 0 ? 18 : 10).h));

      final text = Text.rich(TextSpan(children: _spans(block, style, cs)));
      children.add(block.tag == 'li'
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: body),
                Expanded(child: text),
              ],
            )
          : text);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  List<InlineSpan> _spans(_Block block, TextStyle base, ColorScheme cs) => [
        for (final s in block.spans)
          TextSpan(
            text: s.text,
            recognizer: s.tap,
            style: base.copyWith(
              fontWeight: s.bold ? FontWeight.w700 : null,
              fontStyle: s.italic ? FontStyle.italic : null,
              color: s.href != null ? cs.primary : null,
              decoration: s.href != null ? TextDecoration.underline : null,
              decorationColor: s.href != null ? cs.primary : null,
            ),
          ),
      ];

  int _headingLevel(String tag) =>
      tag.length == 2 && tag[0] == 'h' ? int.tryParse(tag[1]) ?? 0 : 0;
}

class _Block {
  final String tag; // h1..h6 | li | p
  final List<_Span> spans;
  const _Block(this.tag, this.spans);
}

class _Span {
  final String text;
  final bool bold;
  final bool italic;
  final String? href;
  final TapGestureRecognizer? tap;
  const _Span(this.text, {this.bold = false, this.italic = false, this.href, this.tap});
}

// Block tags decide where a paragraph starts; everything else is inline.
final _blockTag = RegExp(r'<\s*(/?)\s*(h[1-6]|p|li|div|blockquote|br|tr)[^>]*>', caseSensitive: false);
final _anyTag = RegExp(r'<\s*(/?)\s*([a-z0-9]+)([^>]*)>', caseSensitive: false);
final _href = RegExp(r'''href\s*=\s*["']([^"']+)["']''', caseSensitive: false);

List<_Block> _parse(String html) {
  final source = html.replaceAll(
      RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), '');
  final blocks = <_Block>[];
  var cursor = 0;
  var tag = 'p';

  void flush(String raw, String forTag) {
    final spans = _inline(raw);
    if (spans.isNotEmpty) blocks.add(_Block(forTag, spans));
  }

  for (final m in _blockTag.allMatches(source)) {
    flush(source.substring(cursor, m.start), tag);
    final name = m.group(2)!.toLowerCase();
    // a close, a <br> or a row boundary just ends the block — the text that
    // follows is a plain paragraph until the next opening tag says otherwise
    tag = (m.group(1) == '/' || name == 'br' || name == 'tr' || name == 'div' || name == 'blockquote')
        ? 'p'
        : name;
    cursor = m.end;
  }
  flush(source.substring(cursor), tag);
  return blocks;
}

List<_Span> _inline(String raw) {
  final spans = <_Span>[];
  var bold = 0;
  var italic = 0;
  String? href;
  var cursor = 0;

  void addText(String chunk) {
    final text = _decode(chunk).replaceAll(RegExp(r'[ \t\r\n]+'), ' ');
    if (text.isEmpty) return;
    spans.add(_Span(
      text,
      bold: bold > 0,
      italic: italic > 0,
      href: href,
      tap: href == null ? null : (TapGestureRecognizer()..onTap = _open(href)),
    ));
  }

  for (final m in _anyTag.allMatches(raw)) {
    addText(raw.substring(cursor, m.start));
    cursor = m.end;
    final closing = m.group(1) == '/';
    switch (m.group(2)!.toLowerCase()) {
      case 'strong':
      case 'b':
        bold = closing ? (bold > 0 ? bold - 1 : 0) : bold + 1;
      case 'em':
      case 'i':
        italic = closing ? (italic > 0 ? italic - 1 : 0) : italic + 1;
      case 'a':
        href = closing ? null : _href.firstMatch(m.group(3) ?? '')?.group(1);
    }
  }
  addText(raw.substring(cursor));

  // trim the block's own edges, then drop it if nothing but spacing is left
  if (spans.isNotEmpty) {
    spans[0] = spans.first.copyWith(text: spans.first.text.trimLeft());
    spans[spans.length - 1] = spans.last.copyWith(text: spans.last.text.trimRight());
    spans.removeWhere((s) => s.text.isEmpty);
  }
  if (spans.every((s) => s.text.trim().isEmpty)) {
    for (final s in spans) {
      s.tap?.dispose();
    }
    return const [];
  }
  return spans;
}

VoidCallback _open(String url) => () {
      final uri = Uri.tryParse(url);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
    };

const _entities = <String, String>{
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'rsquo': '’',
  'lsquo': '‘',
  'ldquo': '“',
  'rdquo': '”',
  'mdash': '—',
  'ndash': '–',
  'hellip': '…',
  'bull': '•',
  'eacute': 'é',
  'egrave': 'è',
  'agrave': 'à',
  'ccedil': 'ç',
  'ugrave': 'ù',
  'ocirc': 'ô',
  'ecirc': 'ê',
};

String _decode(String s) =>
    s.replaceAllMapped(RegExp(r'&(#[xX]?[0-9a-fA-F]+|[a-zA-Z]+);'), (m) {
      final entity = m.group(1)!;
      if (entity.startsWith('#')) {
        final hex = entity.length > 1 && (entity[1] == 'x' || entity[1] == 'X');
        final code =
            int.tryParse(entity.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      }
      return _entities[entity.toLowerCase()] ?? m.group(0)!;
    });

extension on _Span {
  _Span copyWith({String? text}) =>
      _Span(text ?? this.text, bold: bold, italic: italic, href: href, tap: tap);
}
