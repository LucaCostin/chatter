@isTest
private class ChatterHtmlSanitizerTest {

    @isTest
    static void testStripSimpleHtml() {
        System.assertEquals('Hello', ChatterHtmlSanitizer.stripTags('<p>Hello</p>'));
        System.assertEquals('Bold', ChatterHtmlSanitizer.stripTags('<b>Bold</b>'));
    }

    @isTest
    static void testStripNestedHtml() {
        String input = '<p><b>Bold</b> and <i>italic</i></p>';
        String result = ChatterHtmlSanitizer.stripTags(input);
        System.assert(result.contains('Bold'), 'Should contain Bold');
        System.assert(result.contains('italic'), 'Should contain italic');
        System.assert(!result.contains('<'), 'Should not contain tags');
    }

    @isTest
    static void testStripEmptyParagraphs() {
        System.assertEquals('', ChatterHtmlSanitizer.stripTags('<p></p>'));
        System.assertEquals('', ChatterHtmlSanitizer.stripTags('<p>   </p>'));
        System.assertEquals('Text', ChatterHtmlSanitizer.stripTags('<p>Text</p><p></p>'));
    }

    @isTest
    static void testStripParagraphBreaks() {
        String input = '<p>First</p><p>Second</p>';
        String result = ChatterHtmlSanitizer.stripTags(input);
        System.assert(result.contains('First'));
        System.assert(result.contains('Second'));
        System.assert(result.contains('\n'), 'Paragraphs should be separated by newline');
    }

    @isTest
    static void testStripEntities() {
        System.assertEquals('A & B', ChatterHtmlSanitizer.stripTags('A &amp; B'));
        System.assertEquals('a < b', ChatterHtmlSanitizer.stripTags('a &lt; b'));
        System.assertEquals('a > b', ChatterHtmlSanitizer.stripTags('a &gt; b'));
        System.assertEquals('"quoted"', ChatterHtmlSanitizer.stripTags('&quot;quoted&quot;'));
    }

    @isTest
    static void testStripBlank() {
        System.assertEquals('', ChatterHtmlSanitizer.stripTags(null));
        System.assertEquals('', ChatterHtmlSanitizer.stripTags(''));
        System.assertEquals('', ChatterHtmlSanitizer.stripTags('   '));
    }

    @isTest
    static void testStripCollapsesNewlines() {
        String input = '<p>A</p><p></p><p></p><p></p><p>B</p>';
        String result = ChatterHtmlSanitizer.stripTags(input);
        System.assert(!result.contains('\n\n\n'), 'Should collapse excess newlines');
    }

    @isTest
    static void testStripTrimsWhitespace() {
        String input = '   <p>  Hello  </p>   ';
        String result = ChatterHtmlSanitizer.stripTags(input);
        System.assertEquals('Hello', result);
    }

    @isTest
    static void testStripPlainText() {
        System.assertEquals('Just text', ChatterHtmlSanitizer.stripTags('Just text'));
    }
}