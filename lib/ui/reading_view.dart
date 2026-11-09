import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/read_aloud/domain/text_chunk.dart';

/// The text while it is being read: what's been read fades back, the current
/// sentence sits on an accent wash (with the current word in accent when the
/// voice reports words), and the view keeps the current paragraph in sight.
class ReadingView extends StatefulWidget {
  const ReadingView({
    super.key,
    required this.title,
    required this.text,
    required this.offset,
    this.word,
    this.status,
    this.onEdit,
    this.highlight = true,
    this.padding = EdgeInsets.zero,
  });

  /// False when the position in the text isn't known (a generated MP3).
  final bool highlight;

  final String title;
  final String text;

  /// Character offset of where reading is (or paused).
  final int offset;

  /// The word being spoken, when the voice reports it.
  final BodySpan? word;

  /// A short line under the title, e.g. "Reading · 40%".
  final String? status;

  /// Back to editing; null while reading.
  final VoidCallback? onEdit;
  final EdgeInsets padding;

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<ReadingView> {
  late List<BodySpan> _paragraphs;
  late List<BodySpan> _sentences;
  late List<GlobalKey> _keys;
  int _shown = -1;

  @override
  void initState() {
    super.initState();
    _split();
  }

  @override
  void didUpdateWidget(ReadingView old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _split();
      _shown = -1;
    }
  }

  void _split() {
    _paragraphs = paragraphRanges(widget.text);
    _sentences = sentenceRanges(widget.text);
    _keys = [for (final _ in _paragraphs) GlobalKey()];
  }

  BodySpan? get _sentence {
    for (final s in _sentences) {
      if (s.end > widget.offset) return s;
    }
    return null;
  }

  void _follow(int paragraph) {
    if (paragraph == _shown || paragraph < 0) return;
    _shown = paragraph;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[paragraph].currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.25,
        duration: AppMotion.of(context, AppMotion.medium),
        curve: AppMotion.transition,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typography;
    final sentence = widget.highlight ? _sentence : null;
    final word = widget.highlight ? widget.word : null;
    final current = _paragraphs.indexWhere(
      (p) => p.end > (sentence?.start ?? widget.offset),
    );
    _follow(current);

    TextSpan paragraph(BodySpan p) {
      final cuts = <int>{
        p.start,
        p.end,
        if (sentence != null) ...[sentence.start, sentence.end],
        if (word != null) ...[word.start, word.end],
      }.where((i) => i >= p.start && i <= p.end).toList()..sort();
      return TextSpan(
        children: [
          for (var i = 0; i + 1 < cuts.length; i++)
            _piece(cuts[i], cuts[i + 1], sentence, word, c),
        ],
      );
    }

    return ListView(
      padding: widget.padding,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title.trim().isEmpty ? 'Untitled' : widget.title,
                    style: t.headline,
                  ),
                  if (widget.status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        widget.status!,
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.onEdit != null)
              TextButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        for (var i = 0; i < _paragraphs.length; i++)
          Padding(
            key: _keys[i],
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text.rich(paragraph(_paragraphs[i]), style: t.reading),
          ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  TextSpan _piece(
    int start,
    int end,
    BodySpan? sentence,
    BodySpan? word,
    AppColors c,
  ) {
    final text = widget.text.substring(start, end);
    final inSentence =
        sentence != null && start >= sentence.start && end <= sentence.end;
    final inWord = word != null && start >= word.start && end <= word.end;
    final read = !widget.highlight
        ? false
        : sentence != null
        ? end <= sentence.start
        : end <= widget.offset;
    return TextSpan(
      text: text,
      style: TextStyle(
        color: inWord
            ? c.accentStrong
            : read
            ? c.textTertiary
            : c.text,
        fontWeight: inWord ? FontWeight.w600 : null,
        backgroundColor: inSentence ? c.accentSubtle : null,
      ),
    );
  }
}
