import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_task/core/widgets/simple_html.dart';

// The CMS sends the legal pages as HTML; the app renders them itself, so the
// parser has to survive whatever the editor pasted in there.
void main() {
  Future<void> pump(WidgetTester tester, String html) => tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: SimpleHtml(html))),
          ),
        ),
      );

  testWidgets('renders headings, paragraphs and list items', (tester) async {
    await pump(tester, '<h2>1. Using Lokinter</h2><p>Act <strong>honestly</strong>.</p>'
        '<ul><li>No illegal goods</li><li>No cash</li></ul>');

    expect(find.text('1. Using Lokinter'), findsOneWidget);
    expect(find.textContaining('Act honestly.'), findsOneWidget);
    expect(find.textContaining('No illegal goods'), findsOneWidget);
    expect(find.textContaining('No cash'), findsOneWidget);
  });

  testWidgets('decodes entities and drops empty markup', (tester) async {
    await pump(tester, '<p>&nbsp;</p><p>Terms &amp; conditions &#8212; v2</p><p></p>');

    expect(find.text('Terms & conditions — v2'), findsOneWidget);
  });

  testWidgets('plain text with no tags still renders', (tester) async {
    await pump(tester, 'Lorem Ipsum is simply dummy text.');

    expect(find.text('Lorem Ipsum is simply dummy text.'), findsOneWidget);
  });

  test('hasText tells real content from empty markup', () {
    expect(SimpleHtml.hasText(null), isFalse);
    expect(SimpleHtml.hasText('   '), isFalse);
    expect(SimpleHtml.hasText('<p></p><br/>'), isFalse);
    expect(SimpleHtml.hasText('<p>&nbsp;</p>'), isFalse);
    expect(SimpleHtml.hasText('<p>Privacy policy</p>'), isTrue);
  });
}
