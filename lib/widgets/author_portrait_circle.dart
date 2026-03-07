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
  const AuthorPortraitCircle({super.key, required this.author, this.size = 56});

  final String author;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final profileAsync = ref.watch(_authorPortraitProvider(author));
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
                return _AuthorPortraitFallback(colors: colors);
              }
              return AdaptiveAuthorImage(
                imageUrl: imageUrl,
                placeholder: _AuthorPortraitFallback(colors: colors),
                error: _AuthorPortraitFallback(colors: colors),
              );
            },
            loading: () => _AuthorPortraitFallback(colors: colors),
            error: (_, _) => _AuthorPortraitFallback(colors: colors),
          ),
        ),
      ),
    );

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
  const _AuthorPortraitFallback({required this.colors});

  final FlowColorTokens? colors;

  @override
  Widget build(BuildContext context) {
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
        child: Icon(
          Icons.person_outline_rounded,
          size: 22,
          color:
              colors?.textSecondary.withValues(alpha: 0.94) ?? Colors.white70,
        ),
      ),
    );
  }
}
