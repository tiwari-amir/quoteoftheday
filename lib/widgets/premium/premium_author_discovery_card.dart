import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../../providers/quote_providers.dart';
import '../../services/author_wiki_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/adaptive_author_image.dart';
import '../../widgets/scale_tap.dart';

enum PremiumAuthorDiscoveryCardVariant { rail, grid }

final _authorDiscoveryProfileProvider =
    FutureProvider.family<AuthorWikiProfile?, String>((ref, author) async {
      final normalized = author.trim();
      if (normalized.isEmpty) return null;
      return ref.read(authorWikiServiceProvider).fetchAuthor(normalized);
    });

class PremiumAuthorDiscoveryCard extends ConsumerWidget {
  const PremiumAuthorDiscoveryCard({
    super.key,
    required this.authorName,
    required this.rank,
    required this.quoteCount,
    required this.onTap,
    this.variant = PremiumAuthorDiscoveryCardVariant.rail,
    this.animationIndex = 0,
  });

  final String authorName;
  final int rank;
  final int quoteCount;
  final VoidCallback onTap;
  final PremiumAuthorDiscoveryCardVariant variant;
  final int animationIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final profileAsync = ref.watch(_authorDiscoveryProfileProvider(authorName));
    final profile = profileAsync.valueOrNull;
    final descriptor = _buildDescriptor(profile);
    final roleLabel = _shortRoleLabel(profile);
    final visuals = _AuthorRankVisuals.forRank(rank, colors);
    final isRail = variant == PremiumAuthorDiscoveryCardVariant.rail;
    final compact = !isRail;

    return ScaleTap(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorArtworkTile(
                authorName: authorName,
                profile: profile,
                rank: rank,
                quoteCount: quoteCount,
                roleLabel: roleLabel,
                visuals: visuals,
                compact: compact,
              ),
              SizedBox(height: compact ? 10 : 12),
              AutoSizeText(
                authorName,
                maxLines: 2,
                minFontSize: compact ? 12 : 13,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors?.textPrimary,
                  fontSize: isRail ? 15.8 : 15.1,
                  height: compact ? 1.06 : 1.08,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: compact ? 3 : 2),
              Text(
                descriptor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors?.textSecondary.withValues(alpha: 0.88),
                  fontSize: isRail ? 11.3 : 10.9,
                  height: compact ? 1.16 : 1.2,
                ),
              ),
            ],
          ),
        )
        .animate(delay: (70 * animationIndex).ms)
        .fadeIn(duration: 360.ms, curve: Curves.easeOutCubic)
        .moveY(begin: 14, end: 0, duration: 360.ms, curve: Curves.easeOutCubic)
        .scaleXY(
          begin: 0.985,
          end: 1,
          duration: 360.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _AuthorArtworkTile extends StatelessWidget {
  const _AuthorArtworkTile({
    required this.authorName,
    required this.profile,
    required this.rank,
    required this.quoteCount,
    required this.roleLabel,
    required this.visuals,
    required this.compact,
  });

  final String authorName;
  final AuthorWikiProfile? profile;
  final int rank;
  final int quoteCount;
  final String roleLabel;
  final _AuthorRankVisuals visuals;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final radius = BorderRadius.circular(compact ? 20 : 24);
    final imageUrl = profile?.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return AspectRatio(
          aspectRatio: compact ? 1.14 : 1.02,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  visuals.surface.withValues(alpha: 0.98),
                  (colors?.surface ?? const Color(0xFF0D141C)).withValues(
                    alpha: 0.9,
                  ),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: compact ? 16 : 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: visuals.glow.withValues(alpha: compact ? 0.12 : 0.16),
                  blurRadius: compact ? 18 : 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    AdaptiveAuthorImage(
                      imageUrl: imageUrl,
                      placeholder: _ArtworkFallback(
                        authorName: authorName,
                        visuals: visuals,
                      ),
                      error: _ArtworkFallback(
                        authorName: authorName,
                        visuals: visuals,
                      ),
                    )
                  else
                    _ArtworkFallback(authorName: authorName, visuals: visuals),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.06),
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.48),
                        ],
                        stops: const [0.0, 0.56, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: compact ? 8 : 10,
                    top: compact ? 8 : 10,
                    child: _MicroRoleBadge(
                      label: roleLabel,
                      visuals: visuals,
                      compact: compact,
                    ),
                  ),
                  Positioned(
                    right: compact ? 8 : 10,
                    top: compact ? 8 : 10,
                    child: _TinySignalDot(visuals: visuals, compact: compact),
                  ),
                  Positioned(
                    left: compact ? 10 : 12,
                    bottom: compact ? 10 : 12,
                    child: _RankStamp(
                      rank: rank,
                      visuals: visuals,
                      compact: compact,
                    ),
                  ),
                  Positioned(
                    right: compact ? 10 : 12,
                    bottom: compact ? 10 : 12,
                    child: _CountPill(
                      label: quoteCount > 999
                          ? '${(quoteCount / 1000).toStringAsFixed(1)}k'
                          : '$quoteCount',
                      visuals: visuals,
                      compact: compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 360.ms)
        .scaleXY(
          begin: 0.94,
          end: 1,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.authorName, required this.visuals});

  final String authorName;
  final _AuthorRankVisuals visuals;

  @override
  Widget build(BuildContext context) {
    final initials = authorName
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .take(2)
        .map((token) => token.characters.first.toUpperCase())
        .join();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            visuals.glow.withValues(alpha: 0.28),
            visuals.surface,
            visuals.surface.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? 'A' : initials,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: visuals.glow.withValues(alpha: 0.94),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MicroRoleBadge extends StatelessWidget {
  const _MicroRoleBadge({
    required this.label,
    required this.visuals,
    required this.compact,
  });

  final String label;
  final _AuthorRankVisuals visuals;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: visuals.glow.withValues(alpha: 0.96),
          fontSize: compact ? 9.8 : 10.6,
          letterSpacing: 0.42,
        ),
      ),
    );
  }
}

class _TinySignalDot extends StatelessWidget {
  const _TinySignalDot({required this.visuals, required this.compact});

  final _AuthorRankVisuals visuals;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 12 : 14,
      height: compact ? 12 : 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: visuals.glow,
        boxShadow: [
          BoxShadow(
            color: visuals.glow.withValues(alpha: 0.35),
            blurRadius: compact ? 8 : 10,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _RankStamp extends StatelessWidget {
  const _RankStamp({
    required this.rank,
    required this.visuals,
    required this.compact,
  });

  final int rank;
  final _AuthorRankVisuals visuals;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: visuals.glow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            rank.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: visuals.rankText,
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        )
        .animate(delay: 120.ms)
        .fadeIn(duration: 280.ms)
        .moveX(begin: -8, end: 0, duration: 280.ms, curve: Curves.easeOutCubic);
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.visuals,
    required this.compact,
  });

  final String label;
  final _AuthorRankVisuals visuals;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: compact ? 10.0 : 10.8,
          letterSpacing: 0.28,
        ),
      ),
    );
  }
}

class _AuthorRankVisuals {
  const _AuthorRankVisuals({
    required this.glow,
    required this.surface,
    required this.rankText,
  });

  final Color glow;
  final Color surface;
  final Color rankText;

  static _AuthorRankVisuals forRank(int rank, FlowColorTokens? colors) {
    final baseSurface = colors?.elevatedSurface ?? const Color(0xFF18232E);
    return switch (rank) {
      1 => _AuthorRankVisuals(
        glow: colors?.accent ?? const Color(0xFFD6A55C),
        surface: baseSurface,
        rankText: const Color(0xFF201204),
      ),
      2 => _AuthorRankVisuals(
        glow: const Color(0xFFC9D2F2),
        surface: baseSurface,
        rankText: const Color(0xFF111827),
      ),
      3 => _AuthorRankVisuals(
        glow: const Color(0xFFE39A72),
        surface: baseSurface,
        rankText: const Color(0xFF2A1207),
      ),
      4 => _AuthorRankVisuals(
        glow: const Color(0xFFD2E56F),
        surface: baseSurface,
        rankText: const Color(0xFF152009),
      ),
      5 => _AuthorRankVisuals(
        glow: const Color(0xFFE6BF87),
        surface: baseSurface,
        rankText: const Color(0xFF221507),
      ),
      _ => _AuthorRankVisuals(
        glow: (colors?.accent ?? const Color(0xFFD6A55C)).withValues(
          alpha: 0.84,
        ),
        surface: baseSurface,
        rankText: const Color(0xFF1E1206),
      ),
    };
  }
}

String _buildDescriptor(AuthorWikiProfile? profile) {
  const fallback = 'Featured writer and thinker';
  final summary = profile?.summary.trim() ?? '';
  if (summary.isEmpty) return fallback;

  var line = summary
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .trim();
  if (line.isEmpty) return fallback;

  final sentenceMatch = RegExp(r'^(.+?[.!?])(?:\s|$)').firstMatch(line);
  if (sentenceMatch != null) {
    line = sentenceMatch.group(1) ?? line;
  }

  final roleMatch = RegExp(
    r'\b(?:was|is)\b\s+(.*)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (roleMatch != null) {
    line = roleMatch.group(1) ?? line;
  }

  line = line
      .split(
        RegExp(
          r',| who | whose | best known | widely regarded | remembered | notable for | noted for ',
          caseSensitive: false,
        ),
      )
      .first
      .replaceFirst(RegExp(r'^(an?|the)\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.!?]+$'), '')
      .trim();

  if (line.isEmpty) return fallback;
  if (line.length <= 40) return line;

  final words = line.split(' ');
  final buffer = StringBuffer();
  for (final word in words) {
    final nextLength = buffer.isEmpty
        ? word.length
        : buffer.length + word.length + 1;
    if (nextLength > 40) break;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(word);
  }
  final compact = buffer.toString().trim();
  return compact.isEmpty ? fallback : compact;
}

String _shortRoleLabel(AuthorWikiProfile? profile) {
  final summary = profile?.summary.toLowerCase() ?? '';
  if (summary.contains('philosopher')) return 'PHILOSOPHER';
  if (summary.contains('poet')) return 'POET';
  if (summary.contains('novelist')) return 'NOVELIST';
  if (summary.contains('essayist')) return 'ESSAYIST';
  if (summary.contains('playwright')) return 'PLAYWRIGHT';
  if (summary.contains('scientist')) return 'SCIENTIST';
  if (summary.contains('psychologist')) return 'PSYCHOLOGIST';
  if (summary.contains('teacher')) return 'TEACHER';
  if (summary.contains('mystic')) return 'MYSTIC';
  if (summary.contains('leader')) return 'LEADER';
  if (summary.contains('historian')) return 'HISTORIAN';
  return 'AUTHOR';
}
