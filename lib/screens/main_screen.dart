import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/user_settings.dart';
import '../providers/app_mode_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/weak_areas_provider.dart';
import 'conversation_screen.dart';
import 'translation_screen.dart';
import 'test_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 72,
        leading: GestureDetector(
          onTap: () => _showLanguageSheet(context, ref, settings),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.userBubbleBorder),
              ),
              child: Text(
                '${settings.targetLanguage.flag} ${settings.level.emoji}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
        title: _ModeSwitcher(mode: mode),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _buildBody(mode),
    );
  }

  Widget _buildBody(AppMode mode) {
    switch (mode) {
      case AppMode.conversation:
        return const ConversationWidget();
      case AppMode.translation:
        return const TranslationWidget();
      case AppMode.test:
        return const TestWidget();
    }
  }

  void _showLanguageSheet(
      BuildContext context, WidgetRef ref, UserSettings currentSettings) {
    Language selectedLang = currentSettings.targetLanguage;
    LanguageLevel selectedLevel = currentSettings.level;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.92,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            'Jazyk výuky',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 2.8,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            children: Language.values.map((lang) {
                              final active = lang == selectedLang;
                              return GestureDetector(
                                onTap: () => setSheetState(
                                    () => selectedLang = lang),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.accentDim
                                        : AppColors.cardColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: active
                                          ? AppColors.userBubbleBorder
                                          : AppColors.borderColor,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(lang.flag,
                                          style: const TextStyle(
                                              fontSize: 18)),
                                      const SizedBox(width: 8),
                                      Text(lang.displayName,
                                          style: TextStyle(
                                              color: active
                                                  ? AppColors.accentSecondary
                                                  : AppColors.textPrimary,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const Divider(height: 24),
                          const Text(
                            'Tvoje úroveň',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 2.4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            children: LanguageLevel.values.map((lvl) {
                              final active = lvl == selectedLevel;
                              return GestureDetector(
                                onTap: () => setSheetState(
                                    () => selectedLevel = lvl),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.accentDim
                                        : AppColors.cardColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: active
                                          ? AppColors.userBubbleBorder
                                          : AppColors.borderColor,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(lvl.emoji,
                                          style: const TextStyle(
                                              fontSize: 16)),
                                      Text(lvl.displayName,
                                          style: TextStyle(
                                              color: active
                                                  ? AppColors.accentSecondary
                                                  : AppColors.textPrimary,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateLanguageAndLevel(
                                      selectedLang, selectedLevel);
                              ref
                                  .read(conversationProvider.notifier)
                                  .clearConversation();
                              ref
                                  .read(weakAreasProvider.notifier)
                                  .switchLanguage(selectedLang);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPrimary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Potvrdit',
                                style: TextStyle(fontSize: 15)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ---------- Mode switcher widget ----------

class _ModeSwitcher extends ConsumerWidget {
  final AppMode mode;
  const _ModeSwitcher({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppMode.values.map((m) {
          final active = m == mode;
          return GestureDetector(
            onTap: () =>
                ref.read(appModeProvider.notifier).setMode(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.accentDim : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: active
                    ? Border.all(color: AppColors.userBubbleBorder)
                    : null,
              ),
              child: Text(
                _label(m),
                style: TextStyle(
                  color:
                      active ? AppColors.accentSecondary : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(AppMode m) => switch (m) {
        AppMode.conversation => 'Konverzace',
        AppMode.translation => 'Překlad',
        AppMode.test => 'Test',
      };
}
