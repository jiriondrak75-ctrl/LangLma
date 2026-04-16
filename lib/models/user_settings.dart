enum InputMode { text, voice }

enum Language {
  english,
  german,
  spanish,
  french,
  italian,
  polish,
  slovenian;

  String get displayName => switch (this) {
        Language.english => 'Angličtina',
        Language.german => 'Němčina',
        Language.spanish => 'Španělština',
        Language.french => 'Francouzština',
        Language.italian => 'Italština',
        Language.polish => 'Polština',
        Language.slovenian => 'Slovinština',
      };

  String get englishName => switch (this) {
        Language.english => 'English',
        Language.german => 'German',
        Language.spanish => 'Spanish',
        Language.french => 'French',
        Language.italian => 'Italian',
        Language.polish => 'Polish',
        Language.slovenian => 'Slovenian',
      };

  String get flag => switch (this) {
        Language.english => '🇬🇧',
        Language.german => '🇩🇪',
        Language.spanish => '🇪🇸',
        Language.french => '🇫🇷',
        Language.italian => '🇮🇹',
        Language.polish => '🇵🇱',
        Language.slovenian => '🇸🇮',
      };

  String get locale => switch (this) {
        Language.english => 'en-US',
        Language.german => 'de-DE',
        Language.spanish => 'es-ES',
        Language.french => 'fr-FR',
        Language.italian => 'it-IT',
        Language.polish => 'pl-PL',
        Language.slovenian => 'sl-SI',
      };
}

enum LanguageLevel {
  beginner,
  elementary,
  intermediate,
  advanced;

  String get displayName => switch (this) {
        LanguageLevel.beginner => 'Totální lama',
        LanguageLevel.elementary => 'Slušná lama',
        LanguageLevel.intermediate => 'Něco umím',
        LanguageLevel.advanced => 'Jsem borec',
      };

  String get emoji => switch (this) {
        LanguageLevel.beginner => '🦙',
        LanguageLevel.elementary => '🦙🦙',
        LanguageLevel.intermediate => '💪',
        LanguageLevel.advanced => '⭐',
      };

  String get description => switch (this) {
        LanguageLevel.beginner => 'Začínám od nuly',
        LanguageLevel.elementary => 'Základy mám',
        LanguageLevel.intermediate => 'Domluvím se',
        LanguageLevel.advanced => 'Pokročilý',
      };

  String get apiName => switch (this) {
        LanguageLevel.beginner => 'beginner',
        LanguageLevel.elementary => 'elementary',
        LanguageLevel.intermediate => 'intermediate',
        LanguageLevel.advanced => 'advanced',
      };
}

class UserSettings {
  final String name;
  final String gender;
  final String nativeLanguage;
  final Language targetLanguage;
  final LanguageLevel level;
  final InputMode inputMode;
  final String teachingStyle;

  const UserSettings({
    this.name = '',
    this.gender = 'Neuvedeno',
    this.nativeLanguage = 'Čeština',
    this.targetLanguage = Language.english,
    this.level = LanguageLevel.intermediate,
    this.inputMode = InputMode.text,
    this.teachingStyle = 'Přátelský',
  });

  UserSettings copyWith({
    String? name,
    String? gender,
    String? nativeLanguage,
    Language? targetLanguage,
    LanguageLevel? level,
    InputMode? inputMode,
    String? teachingStyle,
  }) {
    return UserSettings(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      level: level ?? this.level,
      inputMode: inputMode ?? this.inputMode,
      teachingStyle: teachingStyle ?? this.teachingStyle,
    );
  }
}
