import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/author_wiki_service.dart';
import '../theme/app_theme.dart';

class AuthorInfoSheet extends StatelessWidget {
  const AuthorInfoSheet({
    super.key,
    required this.author,
    required this.loader,
  });

  final String author;
  final Future<AuthorWikiProfile?> Function() loader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppThemeTokens>();
    final fill = tokens?.glassFill ?? scheme.surface.withValues(alpha: 0.84);
    final border = tokens?.glassBorder ?? Colors.white.withValues(alpha: 0.18);
    final shadow = tokens?.glassShadow ?? Colors.black.withValues(alpha: 0.34);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fill.withValues(alpha: 0.95),
                  scheme.surface.withValues(alpha: 0.9),
                ],
              ),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: shadow,
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.84,
                ),
                child: Column(
                  children: [
                    const _DragHandle(),
                    Expanded(
                      child: FutureBuilder<AuthorWikiProfile?>(
                        future: loader(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const _AuthorLoadingState();
                          }

                          final info = snapshot.data;
                          if (info == null) {
                            return _AuthorUnavailableState(author: author);
                          }

                          return _AuthorProfileContent(
                            requestedAuthor: author,
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
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.35),
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
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading author snapshot...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
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
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AuthorAvatar(imageUrl: null, size: 126),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _MetaPill(
                      icon: Icons.info_outline,
                      label: 'No verified match',
                      color: scheme.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'About this author',
            child: Text(
              'No reliable Wikipedia profile was found yet. Try another quote by this author or a cleaner author name.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
    final theme = Theme.of(context);
    final facts = _AuthorFacts.fromSummary(info.summary);
    final subtitle = _normalized(requestedAuthor) == _normalized(info.wikiTitle)
        ? null
        : 'Quoted as $requestedAuthor';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorAvatar(imageUrl: info.imageUrl, size: 135),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.wikiTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                icon: Icons.auto_stories_outlined,
                label: 'Author Snapshot',
                color: theme.colorScheme.primary,
              ),
              _MetaPill(
                icon: Icons.public,
                label: 'Wikipedia',
                color: theme.colorScheme.secondary,
              ),
              if (facts.lifeSpan != null)
                _MetaPill(
                  icon: Icons.timeline,
                  label: facts.lifeSpan!,
                  color: theme.colorScheme.tertiary,
                ),
            ],
          ),
          if (facts.tagline != null) ...[
            const SizedBox(height: 18),
            _InfoSection(
              title: 'At a glance',
              child: Text(
                facts.tagline!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (facts.role != null) ...[
            const SizedBox(height: 12),
            _InfoSection(
              title: 'Known for',
              child: Text(
                facts.role!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _InfoSection(
            title: 'Bio',
            child: Text(
              info.summary.isEmpty
                  ? 'Wikipedia entry found, but summary is unavailable.'
                  : info.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.58,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _normalized(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withValues(alpha: 0.7),
            scheme.surface.withValues(alpha: 0.52),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.88),
              letterSpacing: 0.18,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.95)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
            scheme.primary.withValues(alpha: 0.75),
            scheme.secondary.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: size * 0.44,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _AuthorFacts {
  const _AuthorFacts({this.tagline, this.role, this.birthYear, this.deathYear});

  final String? tagline;
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

    final sentenceMatch = RegExp(
      r'^(.{0,220}?[.!?])(?:\s|$)',
      multiLine: true,
    ).firstMatch(clean);
    final firstSentence = (sentenceMatch?.group(1) ?? clean).trim();
    final tagline = _clip(firstSentence, 180);

    final roleMatch = RegExp(
      r'\b(?:is|was)\s+(?:an?|the)\s+([^.,;]{6,85})',
      caseSensitive: false,
    ).firstMatch(clean);
    final role = roleMatch == null
        ? null
        : _clip(_normalize(roleMatch.group(1)!), 72);

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

    return _AuthorFacts(
      tagline: tagline,
      role: role,
      birthYear: birthYear,
      deathYear: deathYear,
    );
  }

  static String _normalize(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _clip(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max - 1).trimRight()}...';
  }
}
