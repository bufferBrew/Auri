import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart';

/// Plain text pulled out of an imported file, ready to read aloud.
typedef ImportedText = ({String title, String body});

/// Thrown when a file cannot be turned into text — the message is shown as is.
class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Decodes a `.txt` file. Malformed UTF-8 is replaced rather than rejected:
/// a stray Latin-1 byte should cost one character, not the whole file.
String textFromTxt(Uint8List bytes) =>
    _tidy(utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', ''));

/// Markdown to the text a listener should hear: headings, list markers,
/// emphasis, link targets, images and HTML tags go; code is kept as words.
String textFromMarkdown(String markdown) {
  String s = markdown.replaceAll('\r\n', '\n');
  s = s.replaceAll(RegExp(r'^```.*$', multiLine: true), '');
  s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
  s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (Match m) => m[1]!);
  s = s.replaceAll(RegExp(r'^[ \t]{0,3}#{1,6}[ \t]+', multiLine: true), '');
  s = s.replaceAll(RegExp(r'^[ \t]*>[ \t]?', multiLine: true), '');
  s = s.replaceAll(
    RegExp(r'^[ \t]*([-*+]|\d+[.)])[ \t]+', multiLine: true),
    '',
  );
  s = s.replaceAll(RegExp(r'^[ \t]*([-*_][ \t]*){3,}$', multiLine: true), '');
  s = s.replaceAllMapped(
    RegExp(r'(\*\*|__|\*|_|~~|`)(\S(?:.*?\S)?)\1'),
    (Match m) => m[2]!,
  );
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  return _tidy(s);
}

/// The readable text of an EPUB: its chapters in spine order, as plain text
/// with a blank line between paragraphs. The title comes from the package
/// metadata when there is one.
ImportedText textFromEpub(Uint8List bytes, {String fallbackTitle = ''}) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const ImportException('This EPUB could not be opened.');
  }

  String? read(String path) {
    final ArchiveFile? f = zip.findFile(path);
    if (f == null) return null;
    return utf8.decode(f.content, allowMalformed: true);
  }

  final String? container = read('META-INF/container.xml');
  if (container == null) {
    throw const ImportException('This EPUB has no container.xml.');
  }
  final String? opfPath = XmlDocument.parse(container)
      .findAllElements('rootfile')
      .map((XmlElement e) => e.getAttribute('full-path'))
      .whereType<String>()
      .firstOrNull;
  final String? opfText = opfPath == null ? null : read(opfPath);
  if (opfPath == null || opfText == null) {
    throw const ImportException('This EPUB has no package file.');
  }

  final XmlDocument opf = XmlDocument.parse(opfText);
  final String base = opfPath.contains('/')
      ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
      : '';
  final Map<String, String> manifest = <String, String>{
    for (final XmlElement item in opf.findAllElements('item'))
      if (item.getAttribute('id') != null && item.getAttribute('href') != null)
        item.getAttribute('id')!: item.getAttribute('href')!,
  };
  final String title =
      opf
          .findAllElements('title', namespaceUri: '*')
          .map((XmlElement e) => e.innerText.trim())
          .where((String t) => t.isNotEmpty)
          .firstOrNull ??
      fallbackTitle;

  final List<String> parts = <String>[];
  for (final XmlElement ref in opf.findAllElements('itemref')) {
    final String? href = manifest[ref.getAttribute('idref')];
    if (href == null) continue;
    final String? page = read(_resolve(base, Uri.decodeFull(href)));
    if (page == null) continue;
    final String text = textFromHtml(page);
    if (text.isNotEmpty) parts.add(text);
  }
  if (parts.isEmpty) {
    throw const ImportException('This EPUB has no readable text.');
  }
  return (title: title, body: parts.join('\n\n'));
}

/// HTML to plain text, one paragraph per block element.
String textFromHtml(String source) {
  final dom.Document doc = html.parse(source);
  doc
      .querySelectorAll('script, style, nav, head')
      .forEach((dom.Element e) => e.remove());
  final dom.Element? root = doc.body;
  if (root == null) return '';

  final StringBuffer out = StringBuffer();
  void walk(dom.Node node) {
    if (node is dom.Text) {
      out.write(node.text.replaceAll(RegExp(r'\s+'), ' '));
      return;
    }
    if (node is! dom.Element) return;
    final bool block = _blocks.contains(node.localName);
    if (block) out.write('\n\n');
    if (node.localName == 'br') out.write('\n');
    node.nodes.forEach(walk);
    if (block) out.write('\n\n');
  }

  walk(root);
  return _tidy(out.toString());
}

const Set<String> _blocks = <String>{
  'p', 'div', 'section', 'article', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', //
  'li', 'blockquote', 'pre', 'tr', 'figcaption', 'dd', 'dt',
};

/// Joins PDF pages and undoes the line breaks PDFs put mid-sentence: a single
/// newline inside a paragraph becomes a space, a hyphen at a line end joins
/// the word back together, and blank lines stay paragraph breaks.
String textFromPdfPages(List<String> pages) {
  final String joined = pages.join('\n\n');
  String s = joined.replaceAll('\r\n', '\n');
  s = s.replaceAllMapped(RegExp(r'(\w)-\n(\w)'), (Match m) => '${m[1]}${m[2]}');
  s = s.replaceAllMapped(RegExp(r'([^\n])\n(?!\n)'), (Match m) => '${m[1]} ');
  return _tidy(s);
}

/// "My_notes-v2.md" → "My notes v2".
String titleFromFileName(String name) {
  final int dot = name.lastIndexOf('.');
  final String stem = dot > 0 ? name.substring(0, dot) : name;
  return stem.replaceAll(RegExp(r'[_-]+'), ' ').trim();
}

String _resolve(String base, String href) {
  final List<String> parts = <String>[];
  for (final String p in '$base$href'.split('/')) {
    if (p == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (p.isNotEmpty && p != '.') {
      parts.add(p);
    }
  }
  return parts.join('/');
}

/// Trims lines, collapses runs of spaces and of blank lines.
String _tidy(String s) {
  final String lines = s
      .split('\n')
      .map((String l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
      .join('\n');
  return lines.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
