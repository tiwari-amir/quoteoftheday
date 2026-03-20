import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/quote_providers.dart';
import '../services/author_wiki_service.dart';
import '../theme/design_tokens.dart';
import 'adaptive_author_image.dart';
import 'author_info_sheet.dart';

final _authorPortraitProvider =
    FutureProvider.family<AuthorWikiProfile?, String>((ref, author) async {
      final normalized = author.trim();
      if (normalized.isEmpty) return null;
      return ref.read(authorWikiServiceProvider).fetchAuthor(normalized);
    });

class AuthorPortraitCircle extends ConsumerWidget {
  const AuthorPortraitCircle({
    super.key,
    required this.author,
    this.size = 56,
    this.interactive = true,
    this.fetchProfile = false,
  });

  final String author;
  final double size;
  final bool interactive;
  final bool fetchProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final profileAsync = fetchProfile
        ? ref.watch(_authorPortraitProvider(author))
        : const AsyncData<AuthorWikiProfile?>(null);
    final portrait = SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (colors?.surface ?? Colors.black).withValues(alpha: 0.86),
          border: Border.all(
            color: (colors?.divider ?? Colors.white24).withValues(alpha: 0.62),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: profileAsync.when(
            data: (profile) {
              final imageUrl = profile?.imageUrl?.trim();
              if (imageUrl == null || imageUrl.isEmpty) {
                return _AuthorPortraitFallback(colors: colors, author: author);
              }
              return AdaptiveAuthorImage(
                imageUrl: imageUrl,
                placeholder: _AuthorPortraitFallback(
                  colors: colors,
                  author: author,
                ),
                error: _AuthorPortraitFallback(colors: colors, author: author),
              );
            },
            loading: () =>
                _AuthorPortraitFallback(colors: colors, author: author),
            error: (_, _) =>
                _AuthorPortraitFallback(colors: colors, author: author),
          ),
        ),
      ),
    );

    if (!interactive) {
      return portrait;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAuthorInfoSheetForAuthor(context, ref, author),
        child: portrait,
      ),
    );
  }
}

class AuthorPortraitFill extends ConsumerWidget {
  const AuthorPortraitFill({
    super.key,
    required this.author,
    this.borderRadius = 18,
    this.interactive = true,
    this.fetchProfile = true,
  });

  final String author;
  final double borderRadius;
  final bool interactive;
  final bool fetchProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final profileAsync = fetchProfile
        ? ref.watch(_authorPortraitProvider(author))
        : const AsyncData<AuthorWikiProfile?>(null);
    final portrait = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: (colors?.surface ?? Colors.black).withValues(alpha: 0.88),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: profileAsync.when(
          data: (profile) {
            final imageUrl = profile?.imageUrl?.trim();
            if (imageUrl == null || imageUrl.isEmpty) {
              return _AuthorPortraitRectFallback(
                colors: colors,
                author: author,
              );
            }
            return AdaptiveAuthorImage(
              imageUrl: imageUrl,
              placeholder: _AuthorPortraitRectFallback(
                colors: colors,
                author: author,
              ),
              error: _AuthorPortraitRectFallback(
                colors: colors,
                author: author,
              ),
            );
          },
          loading: () =>
              _AuthorPortraitRectFallback(colors: colors, author: author),
          error: (_, _) =>
              _AuthorPortraitRectFallback(colors: colors, author: author),
        ),
      ),
    );

    if (!interactive) {
      return portrait;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAuthorInfoSheetForAuthor(context, ref, author),
        child: portrait,
      ),
    );
  }
}

class _AuthorPortraitFallback extends StatelessWidget {
  const _AuthorPortraitFallback({required this.colors, required this.author});

  final FlowColorTokens? colors;
  final String author;

  @override
  Widget build(BuildContext context) {
    final initials = _authorInitials(author);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (colors?.accent ?? Colors.white).withValues(alpha: 0.24),
            (colors?.surface ?? Colors.black).withValues(alpha: 0.88),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors?.textPrimary.withValues(alpha: 0.94) ?? Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _AuthorPortraitRectFallback extends StatelessWidget {
  const _AuthorPortraitRectFallback({
    required this.colors,
    required this.author,
  });

  final FlowColorTokens? colors;
  final String author;

  @override
  Widget build(BuildContext context) {
    final initials = _authorInitials(author);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (colors?.accent ?? Colors.white).withValues(alpha: 0.28),
            (colors?.surface ?? Colors.black).withValues(alpha: 0.94),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors?.textPrimary.withValues(alpha: 0.94) ?? Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

String _authorInitials(String rawAuthor) {
  final parts = rawAuthor
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'Q';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
