import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/author_wiki_service.dart';
import '../theme/app_theme.dart';

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

                          return _AuthorProfileContent(
                            requestedAuthor: widget.author,
                            info: info,
                          );
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
              Text(
                author,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Author profile',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
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
  const _AuthorProfileContent({
    required this.requestedAuthor,
    required this.info,
  });

  final String requestedAuthor;
  final AuthorWikiProfile info;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final facts = _AuthorFacts.fromSummary(info.summary);
    final sourceUrl = info.url?.trim() ?? '';
    final subtitle = _normalize(requestedAuthor) == _normalize(info.wikiTitle)
        ? 'Wikipedia profile'
        : 'Matched from "$requestedAuthor"';

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
              Text(
                info.wikiTitle,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              if (facts.lifeSpan != null) ...[
                const SizedBox(height: 8),
                Text(
                  facts.lifeSpan!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
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
                    textAlign: TextAlign.center,
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
                  info.summary.isEmpty
                      ? 'Wikipedia entry found, but summary is unavailable.'
                      : info.summary,
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

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.92),
                letterSpacing: 0.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child,
        ],
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
        child: imageUrl == null || imageUrl!.trim().isEmpty
            ? _AvatarFallback(size: size)
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _AvatarFallback(size: size);
                },
                errorBuilder: (context, error, stackTrace) {
                  return _AvatarFallback(size: size);
                },
              ),
      ),
    );
  }
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

  String? get lifeSpan {
    if (birthYear == null && deathYear == null) return null;
    if (birthYear != null && deathYear != null) return '$birthYear-$deathYear';
    if (birthYear != null) return 'Born $birthYear';
    return 'Died $deathYear';
  }

  static _AuthorFacts fromSummary(String summary) {
    final clean = summary.trim();
    if (clean.isEmpty) return const _AuthorFacts();

    final roleMatch = RegExp(
      r'\b(?:is|was)\s+(?:an?|the)\s+([^.!?]{6,220})',
      caseSensitive: false,
    ).firstMatch(clean);
    final role = roleMatch == null ? null : _normalize(roleMatch.group(1)!);

    final rangeMatch = RegExp(
      r'\((1[5-9]\d{2}|20[0-2]\d)\s*[-\u2013]\s*(1[5-9]\d{2}|20[0-2]\d|present)\)',
      caseSensitive: false,
    ).firstMatch(clean);
    String? birthYear = rangeMatch?.group(1);
    final rangeDeath = rangeMatch?.group(2);
    String? deathYear;
    if (rangeDeath != null && rangeDeath.toLowerCase() != 'present') {
      deathYear = rangeDeath;
    }

    birthYear ??= RegExp(
      r'\bborn\b[^0-9]{0,24}(1[5-9]\d{2}|20[0-2]\d)',
      caseSensitive: false,
    ).firstMatch(clean)?.group(1);
    deathYear ??= RegExp(
      r'\bdied\b[^0-9]{0,24}(1[5-9]\d{2}|20[0-2]\d)',
      caseSensitive: false,
    ).firstMatch(clean)?.group(1);

    return _AuthorFacts(role: role, birthYear: birthYear, deathYear: deathYear);
  }

  static String _normalize(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
