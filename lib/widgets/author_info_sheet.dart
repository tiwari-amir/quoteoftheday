import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/author_wiki_service.dart';
import '../theme/app_theme.dart';
import 'adaptive_author_image.dart';

class AuthorInfoSheet extends StatefulWidget {
  const AuthorInfoSheet({
    super.key,
    required this.author,
    required this.loader,
  });

  final String author;
  final Future<AuthorWikiProfile?> Function() loader;

  @override
  State<AuthorInfoSheet> createState() => _AuthorInfoSheetState();
}

class _AuthorInfoSheetState extends State<AuthorInfoSheet> {
  late Future<AuthorWikiProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.loader();
  }

  @override
  void didUpdateWidget(covariant AuthorInfoSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.author != widget.author) {
      _profileFuture = widget.loader();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<AppThemeTokens>();

    final fill = tokens?.glassFill ?? scheme.surface.withValues(alpha: 0.88);
    final border = tokens?.glassBorder ?? Colors.white.withValues(alpha: 0.18);
    final shadow = tokens?.glassShadow ?? Colors.black.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: shadow,
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                child: Column(
                  children: [
                    const _DragHandle(),
                    Expanded(
                      child: FutureBuilder<AuthorWikiProfile?>(
                        future: _profileFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const _AuthorLoadingState();
                          }

                          final info = snapshot.data;
                          if (info == null) {
                            return _AuthorUnavailableState(
                              author: widget.author,
                            );
                          }

                          return _AuthorProfileContent(info: info);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _AuthorLoadingState extends StatelessWidget {
  const _AuthorLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading author info',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorUnavailableState extends StatelessWidget {
  const _AuthorUnavailableState({required this.author});

  final String author;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _AuthorAvatar(imageUrl: null, size: 132),
              const SizedBox(height: 16),
              _GoldBlueFadeName(
                text: author,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionBlock(
            title: 'Profile',
            child: Text(
              'No reliable Wikipedia profile was found yet for this author.',
              style: textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorProfileContent extends StatelessWidget {
  const _AuthorProfileContent({required this.info});
  final AuthorWikiProfile info;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final facts = _AuthorFacts.fromSummary(info.summary);
    final biography = _formatBiography(info.summary);
    final sourceUrl = info.url?.trim() ?? '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AuthorAvatar(imageUrl: info.imageUrl, size: 132),
              const SizedBox(height: 16),
              _GoldBlueFadeName(
                text: info.wikiTitle,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              if (facts.hasLifeData) ...[
                const SizedBox(height: 10),
                _LifeMetaRow(facts: facts),
              ],
            ],
          ),
          if (facts.role != null) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _SectionBlock(
                  title: 'Known for',
                  child: Text(
                    facts.role!,
                    textAlign: TextAlign.start,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _SectionBlock(
                title: 'Biography',
                child: Text(
                  biography.isEmpty
                      ? 'Wikipedia entry found, but summary is unavailable.'
                      : biography,
                  textAlign: TextAlign.start,
                  style: textTheme.bodyMedium?.copyWith(
                    height: 1.62,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
          if (sourceUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Source: $sourceUrl',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoldBlueFadeName extends StatelessWidget {
  const _GoldBlueFadeName({
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final fillStyle =
        style?.copyWith(color: Colors.white) ??
        const TextStyle(color: Colors.white);
    final edgeStyle = fillStyle.copyWith(
      foreground: (Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF53340F).withValues(alpha: 0.88)),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, textAlign: textAlign, style: edgeStyle),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6B4512),
                Color(0xFFB57A22),
                Color(0xFFF9DC8E),
                Color(0xFFC98A2F),
                Color(0xFF7A5117),
              ],
              stops: [0.0, 0.25, 0.5, 0.74, 1.0],
            ).createShader(bounds);
          },
          child: Text(text, textAlign: textAlign, style: fillStyle),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00FFFFFF),
                Color(0x99FFF4CD),
                Color(0x11FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.28, 0.46, 1.0],
            ).createShader(bounds);
          },
          child: Text(text, textAlign: textAlign, style: fillStyle),
        ),
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.35,
            color: Colors.white.withValues(alpha: 0.94),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.34),
                Colors.white.withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _LifeMetaRow extends StatelessWidget {
  const _LifeMetaRow({required this.facts});

  final _AuthorFacts facts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lifeLine = facts.lifeLine;
    if (lifeLine == null) return const SizedBox.shrink();

    return Text(
      '($lifeLine)',
      textAlign: TextAlign.center,
      style: textTheme.labelSmall?.copyWith(
        fontSize: 10.6,
        letterSpacing: 0.24,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.78),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final normalizedUrl = imageUrl?.trim();
    final hasImage = normalizedUrl != null && normalizedUrl.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: !hasImage
            ? _AvatarFallback(size: size)
            : AdaptiveAuthorImage(
                imageUrl: normalizedUrl,
                placeholder: _AvatarFallback(size: size),
                error: _AvatarFallback(size: size),
              ),
      ),
    );
  }
}

String _formatBiography(String summary) {
  if (summary.trim().isEmpty) return '';
  return summary
      .replaceAll(RegExp(r'\[[^\]]+\]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.74),
            scheme.secondary.withValues(alpha: 0.74),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          size: size * 0.36,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _AuthorFacts {
  const _AuthorFacts({this.role, this.birthYear, this.deathYear});

  final String? role;
  final String? birthYear;
  final String? deathYear;

  bool get hasLifeData => birthYear != null || deathYear != null;

  String? get lifeLine {
    if (!hasLifeData) return null;
    if (birthYear != null && deathYear != null) {
      return '$birthYear - $deathYear';
    }
    if (birthYear != null) {
      final born = int.tryParse(birthYear!);
      if (born != null) {
        final age = DateTime.now().year - born;
        if (age >= 0 && age <= 125) {
          return '$birthYear - $age years old';
        }
      }
      return birthYear;
    }
    return 'Died $deathYear';
  }

  static _AuthorFacts fromSummary(String summary) {
    final clean = summary.trim();
    if (clean.isEmpty) return const _AuthorFacts();

    final roleMatch = RegExp(
      r'\b(?:is|was)\s+(?:an?|the)\s+([^.!?]{6,220})',
      caseSensitive: false,
    ).firstMatch(clean);
    final role = _refineRole(roleMatch?.group(1));

    final rangeMatch = RegExp(
      r'\(([^)]{0,48})\s*[-\u2013]\s*([^)]{0,48})\)',
      caseSensitive: false,
    ).firstMatch(clean);
    String? birthYear = _extractYearToken(rangeMatch?.group(1) ?? '');
    final rangeSecond = rangeMatch?.group(2) ?? '';
    String? deathYear;
    if (!RegExp(r'\bpresent\b', caseSensitive: false).hasMatch(rangeSecond)) {
      deathYear = _extractYearToken(rangeSecond);
    }

    birthYear ??= _extractYearFromKeyword(clean, 'born');
    deathYear ??= _extractYearFromKeyword(clean, 'died');

    return _AuthorFacts(role: role, birthYear: birthYear, deathYear: deathYear);
  }

  static String? _refineRole(String? raw) {
    if (raw == null) return null;
    var value = raw.replaceAll(RegExp(r'\([^)]*\)'), '');
    value = value.replaceAll(
      RegExp(r'\b(best known for|known for)\b.*$', caseSensitive: false),
      '',
    );
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isEmpty) return null;
    final words = value.split(' ');
    if (words.length > 14) {
      value = '${words.take(14).join(' ')}...';
    }
    return value;
  }

  static String? _extractYearFromKeyword(String text, String keyword) {
    final scope = RegExp(
      '\\b$keyword\\b[^.\\n]{0,80}',
      caseSensitive: false,
    ).firstMatch(text)?.group(0);
    if (scope == null) return null;
    return _extractYearToken(scope);
  }

  static String? _extractYearToken(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    final year = RegExp(
      r'(1[5-9]\d{2}|20[0-2]\d)',
    ).firstMatch(cleaned)?.group(0);
    if (year != null) return year;
    return null;
  }
}
