import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _apiKeyController;
  String _gender = 'Neuvedeno';
  String _nativeLanguage = 'Čeština';
  String _teachingStyle = 'Přátelský';
  bool _obscureApiKey = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _apiKeyController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final apiKey = await notifier.getApiKey();
    setState(() {
      _nameController.text = settings.name;
      _gender = settings.gender;
      _nativeLanguage = settings.nativeLanguage;
      _teachingStyle = settings.teachingStyle;
      _apiKeyController.text = apiKey;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);
    try {
      await notifier.save(current.copyWith(
        name: _nameController.text.trim(),
        gender: _gender,
        nativeLanguage: _nativeLanguage,
        teachingStyle: _teachingStyle,
      ));
      await notifier.saveApiKey(_apiKeyController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uloženo')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při ukládání: $e'),
            backgroundColor: AppColors.colorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionCard(
              title: 'Profil',
              children: [
                _buildField(
                  label: 'Oslovení',
                  child: TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Jak ti máme říkat?',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: 'Pohlaví',
                  child: _buildDropdown(
                    value: _gender,
                    items: ['Muž', 'Žena', 'Neuvedeno'],
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: 'Mateřský jazyk',
                  child: _buildDropdown(
                    value: _nativeLanguage,
                    items: ['Čeština', 'Slovenština', 'Jiný'],
                    onChanged: (v) => setState(() => _nativeLanguage = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Claude API',
              children: [
                _buildField(
                  label: 'API klíč',
                  child: TextFormField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    style: const TextStyle(color: AppColors.colorYellow),
                    decoration: InputDecoration(
                      hintText: 'Uloženo bezpečně v zařízení',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscureApiKey = !_obscureApiKey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Výuka',
              children: [
                _buildField(
                  label: 'Styl učitele',
                  child: _buildDropdown(
                    value: _teachingStyle,
                    items: ['Přátelský', 'Přísný', 'Socratic'],
                    onChanged: (v) => setState(() => _teachingStyle = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Uložit', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.accentSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: AppColors.cardColor,
        style: const TextStyle(color: AppColors.textPrimary),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
