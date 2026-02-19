import 'package:flutter/material.dart';

import '../services/author_wiki_service.dart';

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF14171D),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.36),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<AuthorWikiProfile?>(
                    future: loader(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 46),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final info = snapshot.data;
                      if (info == null) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No reliable Wikipedia match found for this author.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: const Color(0xFF1E2D39),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Text(
                                'Author Snapshot',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.35,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (info.imageUrl != null)
                              _AuthorImageCard(imageUrl: info.imageUrl!),
                            if (info.imageUrl != null)
                              const SizedBox(height: 12),
                            Text(
                              info.wikiTitle,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(height: 1.2),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              info.summary.isEmpty
                                  ? 'Wikipedia entry found, but summary is unavailable.'
                                  : info.summary,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(height: 1.55),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorImageCard extends StatelessWidget {
  const _AuthorImageCard({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 320, minHeight: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF0D1620)),
          Image.network(
            imageUrl,
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
