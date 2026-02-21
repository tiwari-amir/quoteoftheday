import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:new_social_share/new_social_share.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../models/quote_model.dart';

final storyShareServiceProvider = Provider<_StoryShareService>((ref) {
  return _StoryShareService();
});

Future<void> showStoryShareSheet({
  required BuildContext context,
  required QuoteModel quote,
  String subject = 'QuoteFlow: Daily Scroll Quotes',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StoryShareSheet(quote: quote, subject: subject),
  );
}

enum StoryShareTarget {
  instagramStory,
  facebookStory,
  whatsapp,
  telegram,
  twitter,
  sms,
  moreApps,
}

class _StoryShareSheet extends ConsumerStatefulWidget {
  const _StoryShareSheet({required this.quote, required this.subject});

  final QuoteModel quote;
  final String subject;

  @override
  ConsumerState<_StoryShareSheet> createState() => _StoryShareSheetState();
}

class _StoryShareSheetState extends ConsumerState<_StoryShareSheet> {
  late final List<_StoryThemeStyle> _styles;
  late final List<_StoryBackground> _backgrounds;

  int _selectedStyle = 0;
  int _selectedBackground = 0;
  StoryShareTarget _selectedTarget = StoryShareTarget.moreApps;
  List<StoryShareTarget> _availableTargets = const <StoryShareTarget>[
    StoryShareTarget.moreApps,
  ];
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    final tags = widget.quote.revisedTags
        .map((t) => t.trim().toLowerCase())
        .toSet();
    _styles = _StoryThemeCatalog.recommendedFor(tags);
    _backgrounds = _StoryBackgroundCatalog.recommendedFor(tags);
    _loadAvailableTargets();
  }

  Future<void> _loadAvailableTargets() async {
    final targets = await ref
        .read(storyShareServiceProvider)
        .availableTargets();
    if (!mounted) return;
    setState(() {
      _availableTargets = targets;
      if (_availableTargets.contains(_selectedTarget) &&
          _selectedTarget != StoryShareTarget.moreApps) {
        return;
      }
      _selectedTarget = _availableTargets.first;
    });
  }

  Future<void> _shareToTarget() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    final result = await ref
        .read(storyShareServiceProvider)
        .shareToTarget(
          quote: widget.quote,
          style: _styles[_selectedStyle],
          background: _backgrounds[_selectedBackground],
          target: _selectedTarget,
          subject: widget.subject,
        );

    if (!mounted) return;
    setState(() => _isSharing = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _shareAnywhere() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    final result = await ref
        .read(storyShareServiceProvider)
        .shareEverywhere(
          quote: widget.quote,
          style: _styles[_selectedStyle],
          background: _backgrounds[_selectedBackground],
          subject: widget.subject,
        );

    if (!mounted) return;
    setState(() => _isSharing = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _styles[_selectedStyle];
    final background = _backgrounds[_selectedBackground];

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                background.previewUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: style.overlayBase,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      style.overlayTintTop.withValues(alpha: 0.74),
                      style.overlayTintBottom.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Story Composer',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.97),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Free-use photo backgrounds matched to quote tags. Pick a style and post.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StoryPreviewCard(
                      quote: widget.quote,
                      style: style,
                      background: background,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Backgrounds',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _backgrounds.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = _backgrounds[index];
                          return _BackgroundChipCard(
                            item: item,
                            selected: index == _selectedBackground,
                            onTap: () =>
                                setState(() => _selectedBackground = index),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Text Showcase',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _styles.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = _styles[index];
                          return _StyleChipCard(
                            item: item,
                            selected: index == _selectedStyle,
                            onTap: () => setState(() => _selectedStyle = index),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Platform',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final target in _availableTargets)
                          _PlatformChip(
                            label: _targetLabel(target),
                            icon: _targetIcon(target),
                            selected: _selectedTarget == target,
                            onTap: () =>
                                setState(() => _selectedTarget = target),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSharing ? null : _shareToTarget,
                        icon: _isSharing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSharing
                              ? 'Preparing...'
                              : _shareLabel(_selectedTarget),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSharing ? null : _shareAnywhere,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share As Post/Message'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shareLabel(StoryShareTarget target) {
    return switch (target) {
      StoryShareTarget.instagramStory => 'Share To Instagram Story',
      StoryShareTarget.facebookStory => 'Share To Facebook Story',
      StoryShareTarget.whatsapp => 'Share To WhatsApp',
      StoryShareTarget.telegram => 'Share To Telegram',
      StoryShareTarget.twitter => 'Share To X / Twitter',
      StoryShareTarget.sms => 'Share As SMS',
      StoryShareTarget.moreApps => 'Open Share Sheet',
    };
  }

  String _targetLabel(StoryShareTarget target) {
    return switch (target) {
      StoryShareTarget.instagramStory => 'Instagram Story',
      StoryShareTarget.facebookStory => 'Facebook Story',
      StoryShareTarget.whatsapp => 'WhatsApp',
      StoryShareTarget.telegram => 'Telegram',
      StoryShareTarget.twitter => 'X / Twitter',
      StoryShareTarget.sms => 'SMS',
      StoryShareTarget.moreApps => 'More Apps',
    };
  }

  IconData _targetIcon(StoryShareTarget target) {
    return switch (target) {
      StoryShareTarget.instagramStory => Icons.auto_awesome_rounded,
      StoryShareTarget.facebookStory => Icons.facebook_rounded,
      StoryShareTarget.whatsapp => Icons.chat_rounded,
      StoryShareTarget.telegram => Icons.send_rounded,
      StoryShareTarget.twitter => Icons.alternate_email_rounded,
      StoryShareTarget.sms => Icons.sms_rounded,
      StoryShareTarget.moreApps => Icons.apps_rounded,
    };
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.46)
                  : Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.96),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryPreviewCard extends StatelessWidget {
  const _StoryPreviewCard({
    required this.quote,
    required this.style,
    required this.background,
  });

  final QuoteModel quote;
  final _StoryThemeStyle style;
  final _StoryBackground background;

  @override
  Widget build(BuildContext context) {
    final previewQuote = quote.quote.trim();
    final quoteSize = _previewQuoteSize(previewQuote.length);

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              background.previewUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: style.overlayBase,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    style.overlayTintTop.withValues(alpha: 0.62),
                    style.overlayTintBottom.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withValues(alpha: 0.2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: style.quoteAlign == _QuoteAlign.left
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Text(
                          '"$previewQuote"',
                          textAlign: style.quoteAlign == _QuoteAlign.left
                              ? TextAlign.left
                              : TextAlign.center,
                          maxLines: 12,
                          overflow: TextOverflow.fade,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: style.textColor,
                                fontSize: quoteSize,
                                height: 1.36,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          quote.author,
                          textAlign: style.quoteAlign == _QuoteAlign.left
                              ? TextAlign.left
                              : TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: style.authorColor.withValues(alpha: 0.9),
                                fontSize: 12,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _previewQuoteSize(int length) {
    if (length <= 90) return 23;
    if (length <= 150) return 20;
    if (length <= 220) return 18;
    if (length <= 300) return 16;
    return 14.5;
  }
}

class _StyleChipCard extends StatelessWidget {
  const _StyleChipCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _StoryThemeStyle item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 174,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: item.overlayBase),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.24),
                width: selected ? 1.8 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.quoteAlign == _QuoteAlign.left
                            ? Icons.format_align_left_rounded
                            : Icons.format_align_center_rounded,
                        size: 14,
                        color: item.badgeColor.withValues(alpha: 0.94),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.name,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: item.textColor,
                                fontWeight: FontWeight.w800,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      '"Quiet minds\\ncreate loud clarity"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: item.textColor.withValues(alpha: 0.95),
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: item.quoteAlign == _QuoteAlign.left
                          ? TextAlign.left
                          : TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '- Author',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: item.authorColor.withValues(alpha: 0.9),
                      fontSize: 10.5,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 30,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: item.badgeColor.withValues(
                        alpha: selected ? 0.95 : 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundChipCard extends StatelessWidget {
  const _BackgroundChipCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _StoryBackground item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.2),
                width: selected ? 1.8 : 1,
              ),
              color: Colors.black.withValues(alpha: 0.16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        item.previewUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryShareService {
  final _renderer = _StoryRenderer();

  Future<List<StoryShareTarget>> availableTargets() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const <StoryShareTarget>[StoryShareTarget.moreApps];
    }

    final targets = <StoryShareTarget>[];
    try {
      final apps = await SocialShare.checkInstalledAppsForShare();
      final installed = <String, bool>{};
      if (apps != null) {
        for (final entry in apps.entries) {
          installed[entry.key.toString().toLowerCase()] = entry.value == true;
        }
      }
      if (installed['instagram'] == true) {
        targets.add(StoryShareTarget.instagramStory);
      }
      if (installed['facebook'] == true) {
        targets.add(StoryShareTarget.facebookStory);
      }
      if (installed['whatsapp'] == true) {
        targets.add(StoryShareTarget.whatsapp);
      }
      if (installed['telegram'] == true) {
        targets.add(StoryShareTarget.telegram);
      }
      if (installed['twitter'] == true) {
        targets.add(StoryShareTarget.twitter);
      }
      if (installed['sms'] == true) {
        targets.add(StoryShareTarget.sms);
      }
    } catch (error) {
      debugPrint('Installed share apps check failed: $error');
    }

    targets.add(StoryShareTarget.moreApps);
    return targets.toSet().toList(growable: false);
  }

  Future<_StoryShareResult> shareToTarget({
    required QuoteModel quote,
    required _StoryThemeStyle style,
    required _StoryBackground background,
    required StoryShareTarget target,
    required String subject,
  }) async {
    String? imagePath;
    final caption = _caption(quote);

    try {
      imagePath = await _renderer.createImagePath(
        quote: quote,
        style: style,
        background: background,
      );

      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        await _fallbackShare(
          imagePath: imagePath,
          caption: caption,
          subject: subject,
        );
        return const _StoryShareResult(
          success: true,
          message: 'Direct stories are mobile-only. Opened share sheet.',
        );
      }

      final directResult = await _shareToInstalledTarget(
        imagePath: imagePath,
        style: style,
        target: target,
        caption: caption,
      );
      if (directResult != null) {
        return directResult;
      }

      await _fallbackShare(
        imagePath: imagePath,
        caption: caption,
        subject: subject,
      );
      return const _StoryShareResult(
        success: true,
        message: 'Opened share options.',
      );
    } catch (error, stack) {
      debugPrint('Story share failed: $error');
      debugPrint('$stack');

      try {
        if (imagePath != null) {
          await _fallbackShare(
            imagePath: imagePath,
            caption: caption,
            subject: subject,
          );
        } else {
          await Share.share(caption, subject: subject);
        }
        return const _StoryShareResult(
          success: true,
          message: 'Opened share options.',
        );
      } catch (_) {
        return const _StoryShareResult(
          success: false,
          message: 'Could not prepare story. Please try again.',
        );
      }
    }
  }

  Future<_StoryShareResult> shareEverywhere({
    required QuoteModel quote,
    required _StoryThemeStyle style,
    required _StoryBackground background,
    required String subject,
  }) async {
    String? imagePath;
    try {
      imagePath = await _renderer.createImagePath(
        quote: quote,
        style: style,
        background: background,
      );
      await _fallbackShare(
        imagePath: imagePath,
        caption: _caption(quote),
        subject: subject,
      );
      return const _StoryShareResult(
        success: true,
        message: 'Opened share options.',
      );
    } catch (error, stack) {
      debugPrint('Generic share failed: $error');
      debugPrint('$stack');
      try {
        if (imagePath != null) {
          await _fallbackShare(
            imagePath: imagePath,
            caption: _caption(quote),
            subject: subject,
          );
        } else {
          await Share.share(_caption(quote), subject: subject);
        }
        return const _StoryShareResult(
          success: true,
          message: 'Opened share options.',
        );
      } catch (_) {
        return const _StoryShareResult(
          success: false,
          message: 'Could not prepare share image right now.',
        );
      }
    }
  }

  Future<void> _fallbackShare({
    required String imagePath,
    required String caption,
    required String subject,
  }) {
    return Share.shareXFiles(
      [XFile(imagePath)],
      text: caption,
      subject: subject,
    );
  }

  Future<_StoryShareResult?> _shareToInstalledTarget({
    required String imagePath,
    required _StoryThemeStyle style,
    required StoryShareTarget target,
    required String caption,
  }) async {
    switch (target) {
      case StoryShareTarget.instagramStory:
        final response = await _safeShareCall(
          () => SocialShare.shareInstagramStory(
            appId: _storyAppId(metaStoryAppId),
            imagePath: imagePath,
            backgroundResourcePath: imagePath,
            backgroundTopColor: _toHex(style.overlayBase.first),
            backgroundBottomColor: _toHex(style.overlayBase.last),
            attributionURL: storyAttributionUrl,
          ),
        );
        if (_isStorySuccess(response)) {
          return const _StoryShareResult(
            success: true,
            message: 'Opening Instagram Story...',
          );
        }
        return null;
      case StoryShareTarget.facebookStory:
        final response = await _safeShareCall(
          () => SocialShare.shareFacebookStory(
            appId: _storyAppId(facebookStoryAppId),
            imagePath: imagePath,
            backgroundResourcePath: imagePath,
            backgroundTopColor: _toHex(style.overlayBase.first),
            backgroundBottomColor: _toHex(style.overlayBase.last),
            attributionURL: storyAttributionUrl,
          ),
        );
        if (_isStorySuccess(response)) {
          return const _StoryShareResult(
            success: true,
            message: 'Opening Facebook Story...',
          );
        }
        return null;
      case StoryShareTarget.whatsapp:
        final response = await _safeShareCall(
          () => SocialShare.shareWhatsapp(caption),
        );
        if (_isStorySuccess(response)) {
          return const _StoryShareResult(
            success: true,
            message: 'Opening WhatsApp...',
          );
        }
        return null;
      case StoryShareTarget.telegram:
        final response = await _safeShareCall(
          () => SocialShare.shareTelegram(caption),
        );
        if (_isStorySuccess(response)) {
          return const _StoryShareResult(
            success: true,
            message: 'Opening Telegram...',
          );
        }
        return null;
      case StoryShareTarget.twitter:
        final response = await _safeShareCall(
          () => SocialShare.shareTwitter(caption),
        );
        if (_isStorySuccess(response)) {
          return const _StoryShareResult(
            success: true,
            message: 'Opening X / Twitter...',
          );
        }
        return null;
      case StoryShareTarget.sms:
        final response = await _safeShareCall(
          () => SocialShare.shareSms(caption),
        );
        if (_isStorySuccess(response)) {
          return const _StoryShareResult(
            success: true,
            message: 'Opening SMS...',
          );
        }
        return null;
      case StoryShareTarget.moreApps:
        return null;
    }
  }

  Future<String?> _safeShareCall(Future<String?> Function() action) async {
    try {
      return await action();
    } catch (error) {
      debugPrint('Direct story share plugin error: $error');
      return null;
    }
  }

  bool _isStorySuccess(String? response) {
    final normalized = (response ?? '').trim().toLowerCase();
    return normalized == 'success' ||
        normalized == 'ok' ||
        normalized == 'true';
  }

  String _storyAppId(String configured) {
    final clean = configured.trim();
    if (clean.isNotEmpty) return clean;
    return 'quoteflow.app';
  }

  String _caption(QuoteModel quote) {
    final tags = quote.revisedTags
        .take(2)
        .map((tag) => '#${_slugToTag(tag)}')
        .join(' ');
    return '"${quote.quote}"\n\n- ${quote.author}\n\n$tags #quoteflow';
  }

  String _slugToTag(String value) {
    final clean = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    return clean.isEmpty ? 'quote' : clean;
  }

  String _toHex(Color color) {
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    final rgb = (r << 16) | (g << 8) | b;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }
}

class _StoryShareResult {
  const _StoryShareResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class _StoryRenderer {
  final _imageCache = _StoryImageCache.instance;

  Future<String> createImagePath({
    required QuoteModel quote,
    required _StoryThemeStyle style,
    required _StoryBackground background,
  }) async {
    try {
      return await _render(
        quote: quote,
        style: style,
        background: background,
        width: 1080,
        height: 1920,
      );
    } catch (error, stack) {
      debugPrint('1080x1920 story render failed, retrying lower size: $error');
      debugPrint('$stack');
      return _render(
        quote: quote,
        style: style,
        background: background,
        width: 720,
        height: 1280,
      );
    }
  }

  Future<String> _render({
    required QuoteModel quote,
    required _StoryThemeStyle style,
    required _StoryBackground background,
    required int width,
    required int height,
  }) async {
    final w = width.toDouble();
    final h = height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    await _drawBaseImage(canvas, width: w, height: h, background: background);
    _drawTint(canvas, width: w, height: h, style: style);
    _drawAmbientGlows(
      canvas,
      width: w,
      height: h,
      style: style,
      seed: quote.id.hashCode,
    );
    _drawGrain(canvas, width: w, height: h, seed: quote.quote.hashCode);
    _drawPanel(canvas, width: w, height: h, style: style);
    _drawQuoteAndAuthor(
      canvas,
      quote: quote,
      style: style,
      width: w,
      height: h,
    );

    final image = await recorder.endRecording().toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to render image bytes');
    }
    final png = byteData.buffer.asUint8List();

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}story_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(png, flush: true);
    return file.path;
  }

  Future<void> _drawBaseImage(
    Canvas canvas, {
    required double width,
    required double height,
    required _StoryBackground background,
  }) async {
    final fallback = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(width, height),
        const [Color(0xFF1A2330), Color(0xFF2A3F57), Color(0xFF607D8B)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), fallback);

    final image = await _imageCache.loadImage(
      background.renderUrl,
      targetWidth: width.toInt(),
      targetHeight: height.toInt(),
    );
    if (image == null) return;

    final destination = Rect.fromLTWH(0, 0, width, height);
    final source = _coverSourceRect(
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
      outputWidth: width,
      outputHeight: height,
    );

    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  Rect _coverSourceRect({
    required double imageWidth,
    required double imageHeight,
    required double outputWidth,
    required double outputHeight,
  }) {
    final imageAspect = imageWidth / imageHeight;
    final outputAspect = outputWidth / outputHeight;

    if (imageAspect > outputAspect) {
      final srcWidth = imageHeight * outputAspect;
      final left = (imageWidth - srcWidth) / 2;
      return Rect.fromLTWH(left, 0, srcWidth, imageHeight);
    }

    final srcHeight = imageWidth / outputAspect;
    final top = (imageHeight - srcHeight) / 2;
    return Rect.fromLTWH(0, top, imageWidth, srcHeight);
  }

  void _drawTint(
    Canvas canvas, {
    required double width,
    required double height,
    required _StoryThemeStyle style,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, height),
          [
            style.overlayTintTop.withValues(alpha: 0.62),
            style.overlayTintBottom.withValues(alpha: 0.84),
          ],
          [0.05, 1],
        ),
    );
  }

  void _drawAmbientGlows(
    Canvas canvas, {
    required double width,
    required double height,
    required _StoryThemeStyle style,
    required int seed,
  }) {
    final random = Random(seed);
    for (var i = 0; i < 6; i++) {
      final dx = random.nextDouble() * width;
      final dy = random.nextDouble() * height;
      final radius = 160 + random.nextDouble() * 280;
      canvas.drawCircle(
        Offset(dx, dy),
        radius,
        Paint()
          ..color = style.accent.withValues(
            alpha: 0.08 + random.nextDouble() * 0.1,
          ),
      );
    }
  }

  void _drawGrain(
    Canvas canvas, {
    required double width,
    required double height,
    required int seed,
  }) {
    final random = Random(seed);
    final lightPaint = Paint()..color = Colors.white.withValues(alpha: 0.022);
    final darkPaint = Paint()..color = Colors.black.withValues(alpha: 0.02);

    for (var i = 0; i < 2600; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      canvas.drawRect(
        Rect.fromLTWH(x, y, 1.2, 1.2),
        i.isEven ? lightPaint : darkPaint,
      );
    }
  }

  void _drawPanel(
    Canvas canvas, {
    required double width,
    required double height,
    required _StoryThemeStyle style,
  }) {
    const horizontal = 76.0;
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(horizontal, 230, width - horizontal * 2, height - 460),
      const Radius.circular(44),
    );
    canvas.drawRRect(
      panel,
      Paint()..color = style.panelFill.withValues(alpha: 0.44),
    );
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = style.panelStroke.withValues(alpha: 0.62),
    );
  }

  void _drawQuoteAndAuthor(
    Canvas canvas, {
    required QuoteModel quote,
    required _StoryThemeStyle style,
    required double width,
    required double height,
  }) {
    final panelWidth = width - 152;
    final areaTop = 355.0;
    final areaHeight = height * 0.56;
    const authorReserve = 120.0;
    final quoteAreaHeight = max(260.0, areaHeight - authorReserve);
    final quoteText = '"${quote.quote.trim()}"';

    final markPainter = TextPainter(
      text: TextSpan(
        text: '"',
        style: TextStyle(
          color: style.textColor.withValues(alpha: 0.22),
          fontSize: 150,
          height: 0.9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    markPainter.paint(canvas, const Offset(122, 370));

    final quotePainter = _fitQuoteText(
      text: quoteText,
      maxWidth: panelWidth - 110,
      maxHeight: quoteAreaHeight,
      color: style.textColor,
      align: style.quoteAlign == _QuoteAlign.left
          ? TextAlign.left
          : TextAlign.center,
    );

    final quoteX = style.quoteAlign == _QuoteAlign.left
        ? 140.0
        : (width - quotePainter.width) / 2;
    final quoteY =
        areaTop + max(0, (quoteAreaHeight - quotePainter.height) / 2) - 8;
    quotePainter.paint(canvas, Offset(quoteX, quoteY));

    final authorSize = quote.quote.trim().length > 220 ? 20.0 : 22.0;
    final authorPainter = TextPainter(
      text: TextSpan(
        text: '- ${quote.author}',
        style: TextStyle(
          color: style.authorColor.withValues(alpha: 0.92),
          fontSize: authorSize,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textAlign: style.quoteAlign == _QuoteAlign.left
          ? TextAlign.left
          : TextAlign.center,
    )..layout(maxWidth: panelWidth - 110);

    final authorX = style.quoteAlign == _QuoteAlign.left
        ? quoteX
        : (width - authorPainter.width) / 2;
    final authorY = min(
      quoteY + quotePainter.height + 22,
      areaTop + areaHeight - authorPainter.height - 10,
    );
    authorPainter.paint(canvas, Offset(authorX, authorY));
  }

  TextPainter _fitQuoteText({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required Color color,
    required TextAlign align,
  }) {
    final cleanLength = text.replaceAll(RegExp(r'\s+'), ' ').trim().length;
    final maxSize = cleanLength <= 90
        ? 64.0
        : cleanLength <= 170
        ? 56.0
        : cleanLength <= 260
        ? 48.0
        : 42.0;

    for (var size = maxSize; size >= 18; size -= 2) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: size,
            height: 1.24,
            letterSpacing: 0.25,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                blurRadius: 12,
                offset: Offset(0, 3),
                color: Color(0x66000000),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(maxWidth: maxWidth);
      if (painter.height <= maxHeight) {
        return painter;
      }
    }

    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 17,
          height: 1.18,
          letterSpacing: 0.15,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
  }
}

class _StoryImageCache {
  _StoryImageCache._();
  static final _StoryImageCache instance = _StoryImageCache._();

  final Map<String, Uint8List?> _bytesCache = {};

  Future<ui.Image?> loadImage(
    String url, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    final bytes = await _loadBytes(url);
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _loadBytes(String url) async {
    if (_bytesCache.containsKey(url)) {
      return _bytesCache[url];
    }

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.add('User-Agent', 'QuoteOfTheDay/1.0');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _bytesCache[url] = null;
        client.close(force: true);
        return null;
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      _bytesCache[url] = bytes;
      client.close(force: true);
      return bytes;
    } catch (_) {
      _bytesCache[url] = null;
      return null;
    }
  }
}

class _StoryBackgroundCatalog {
  static const List<_StoryBackground> _base = [
    _StoryBackground(
      id: 'mist_forest',
      name: 'Mist Forest',
      seed: 'calm-forest',
      tags: {'calm', 'anxious', 'stressed', 'sad', 'mindfulness'},
    ),
    _StoryBackground(
      id: 'valley_light',
      name: 'Valley Light',
      seed: 'sunset-vibe',
      tags: {'hopeful', 'grateful', 'motivated', 'happy'},
    ),
    _StoryBackground(
      id: 'snow_peak',
      name: 'Snow Peak',
      seed: 'mountain-air',
      tags: {'confident', 'motivated', 'discipline', 'goal'},
    ),
    _StoryBackground(
      id: 'ocean_aerial',
      name: 'Ocean Aerial',
      seed: 'ocean-blue',
      tags: {'calm', 'romantic', 'happy', 'peace'},
    ),
    _StoryBackground(
      id: 'lagoon_boat',
      name: 'Lagoon',
      seed: 'neon-night',
      tags: {'hopeful', 'romantic', 'grateful', 'life'},
    ),
    _StoryBackground(
      id: 'green_falls',
      name: 'Forest Falls',
      seed: 'grateful-earth',
      tags: {'grateful', 'calm', 'spiritual', 'nature'},
    ),
    _StoryBackground(
      id: 'bamboo_lines',
      name: 'Bamboo Lines',
      seed: 'dream-pastel',
      tags: {'mindfulness', 'calm', 'focus', 'zen'},
    ),
    _StoryBackground(
      id: 'sand_minimal',
      name: 'Sand Minimal',
      seed: 'focus-architecture',
      tags: {'stressed', 'anxious', 'minimal', 'clarity'},
    ),
    _StoryBackground(
      id: 'city_rainbow',
      name: 'City Rainbow',
      seed: 'storm-clouds',
      tags: {'hopeful', 'happy', 'confident', 'motivated'},
    ),
    _StoryBackground(
      id: 'autumn_valley',
      name: 'Autumn Valley',
      seed: 'vintage-grain',
      tags: {'wisdom', 'life', 'reflection', 'grateful'},
    ),
    _StoryBackground(
      id: 'blue_shore',
      name: 'Blue Shore',
      seed: 'romance-flowers',
      tags: {'romantic', 'sad', 'calm', 'lonely'},
    ),
    _StoryBackground(
      id: 'urban_lines',
      name: 'Urban Lines',
      seed: 'romance-rose',
      tags: {'confident', 'motivated', 'discipline', 'focus'},
    ),
  ];

  static List<_StoryBackground> recommendedFor(Set<String> tags) {
    final scored =
        _base
            .map((item) {
              var score = 0;
              for (final tag in tags) {
                if (item.tags.contains(tag)) {
                  score += 5;
                } else if (item.tags.any(
                  (known) => known.contains(tag) || tag.contains(known),
                )) {
                  score += 2;
                }
              }
              return (item: item, score: score);
            })
            .toList(growable: false)
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) return byScore;
            return a.item.id.compareTo(b.item.id);
          });

    final ordered = scored.map((e) => e.item).toList(growable: true);
    if (ordered.length < 8) {
      for (final item in _base) {
        if (ordered.any((e) => e.id == item.id)) continue;
        ordered.add(item);
        if (ordered.length == 8) break;
      }
    }
    return ordered.take(8).toList(growable: false);
  }
}

class _StoryBackground {
  const _StoryBackground({
    required this.id,
    required this.name,
    required this.seed,
    required this.tags,
  });

  final String id;
  final String name;
  final String seed;
  final Set<String> tags;

  String get previewUrl => 'https://picsum.photos/seed/$seed/540/960';
  String get renderUrl => 'https://picsum.photos/seed/$seed/1080/1920';
}

class _StoryThemeCatalog {
  static const List<_StoryThemeStyle> _base = [
    _StoryThemeStyle(
      id: 'neo_editorial',
      name: 'Neo Editorial',
      subtitle: 'Bold high-contrast serif',
      overlayBase: [Color(0xFF0B1524), Color(0xFF2F4A63), Color(0xFF92B9D2)],
      overlayTintTop: Color(0xFF13263B),
      overlayTintBottom: Color(0xFF0B101B),
      panelFill: Color(0xFF0B1320),
      panelStroke: Color(0xFFA7C9E5),
      textColor: Colors.white,
      authorColor: Color(0xFFE9F5FF),
      badgeColor: Color(0xFF9FD0FF),
      accent: Color(0xFF9ED5FF),
      quoteAlign: _QuoteAlign.left,
      tags: {'motivated', 'confident', 'success', 'goal', 'discipline'},
    ),
    _StoryThemeStyle(
      id: 'sunset_pulse',
      name: 'Sunset Pulse',
      subtitle: 'Warm grainy storyteller',
      overlayBase: [Color(0xFF2D1231), Color(0xFF8A3A31), Color(0xFFED9F62)],
      overlayTintTop: Color(0xFF401935),
      overlayTintBottom: Color(0xFF180F1A),
      panelFill: Color(0xFF241323),
      panelStroke: Color(0xFFF2B07A),
      textColor: Colors.white,
      authorColor: Color(0xFFFFF1DE),
      badgeColor: Color(0xFFFFD3A2),
      accent: Color(0xFFFFB97B),
      quoteAlign: _QuoteAlign.center,
      tags: {'happy', 'hopeful', 'grateful', 'romantic'},
    ),
    _StoryThemeStyle(
      id: 'rose_soft',
      name: 'Rose Soft',
      subtitle: 'Romantic soft spotlight',
      overlayBase: [Color(0xFF2B1231), Color(0xFF7A3A74), Color(0xFFD590B7)],
      overlayTintTop: Color(0xFF3D1B3D),
      overlayTintBottom: Color(0xFF170E1A),
      panelFill: Color(0xFF2D1630),
      panelStroke: Color(0xFFF4B9DA),
      textColor: Colors.white,
      authorColor: Color(0xFFFFE8F7),
      badgeColor: Color(0xFFFFC4EA),
      accent: Color(0xFFF3A3D0),
      quoteAlign: _QuoteAlign.center,
      tags: {'romantic', 'love', 'lonely', 'sad'},
    ),
    _StoryThemeStyle(
      id: 'noir_minimal',
      name: 'Noir Minimal',
      subtitle: 'Muted monochrome premium',
      overlayBase: [Color(0xFF0A0D12), Color(0xFF252B34), Color(0xFF5C6674)],
      overlayTintTop: Color(0xFF0D1118),
      overlayTintBottom: Color(0xFF090B10),
      panelFill: Color(0xFF0C1018),
      panelStroke: Color(0xFFA9B7C9),
      textColor: Color(0xFFF1F5FA),
      authorColor: Color(0xFFDFE7F2),
      badgeColor: Color(0xFFC8D4E3),
      accent: Color(0xFFAAB8CA),
      quoteAlign: _QuoteAlign.left,
      tags: {'anxious', 'stressed', 'angry', 'sad', 'lonely'},
    ),
    _StoryThemeStyle(
      id: 'zen_glow',
      name: 'Zen Glow',
      subtitle: 'Tranquil airy composition',
      overlayBase: [Color(0xFF0D2233), Color(0xFF2E6C71), Color(0xFF9AD8D0)],
      overlayTintTop: Color(0xFF11304A),
      overlayTintBottom: Color(0xFF0A1520),
      panelFill: Color(0xFF102232),
      panelStroke: Color(0xFFA7E6DD),
      textColor: Colors.white,
      authorColor: Color(0xFFE9FFF9),
      badgeColor: Color(0xFFA8F3E6),
      accent: Color(0xFF8CEADB),
      quoteAlign: _QuoteAlign.center,
      tags: {'calm', 'mindfulness', 'spiritual', 'grateful'},
    ),
  ];

  static List<_StoryThemeStyle> recommendedFor(Set<String> tags) {
    final scored =
        _base
            .map((style) {
              var score = 0;
              for (final tag in tags) {
                if (style.tags.contains(tag)) {
                  score += 5;
                } else if (style.tags.any(
                  (known) => known.contains(tag) || tag.contains(known),
                )) {
                  score += 2;
                }
              }
              return (style: style, score: score);
            })
            .toList(growable: false)
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) return byScore;
            return a.style.id.compareTo(b.style.id);
          });

    return scored.map((e) => e.style).toList(growable: false);
  }
}

enum _QuoteAlign { left, center }

class _StoryThemeStyle {
  const _StoryThemeStyle({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.overlayBase,
    required this.overlayTintTop,
    required this.overlayTintBottom,
    required this.panelFill,
    required this.panelStroke,
    required this.textColor,
    required this.authorColor,
    required this.badgeColor,
    required this.accent,
    required this.quoteAlign,
    required this.tags,
  });

  final String id;
  final String name;
  final String subtitle;
  final List<Color> overlayBase;
  final Color overlayTintTop;
  final Color overlayTintBottom;
  final Color panelFill;
  final Color panelStroke;
  final Color textColor;
  final Color authorColor;
  final Color badgeColor;
  final Color accent;
  final _QuoteAlign quoteAlign;
  final Set<String> tags;
}
