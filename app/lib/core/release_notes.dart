const bundledReleaseNotes = {
  '0.5.10': [
    'Расписание подскажет, как загрузить форму обучения групп с портала',
    'Кнопка «Заполнить шапку формы 28» в почасовой нагрузке',
    'После обновления — коротко о новом, как здесь',
  ],
  '0.5.9': [
    'Форма обучения у групп в расписании: (оз), (з), (о)',
    'Можно выбрать, как часто проверять почту',
    'Фоновая проверка почты на Honor и Huawei',
    'Исправлена отправка писем с длинным именем получателя',
  ],
};

/// Decides what to show and remember for the installed release.
final class ReleaseNotes {
  ReleaseNotes({
    required this.version,
    required Map<String, List<String>> notes,
    required String seenVersion,
    required bool signedIn,
  })  : shouldRemember = version.isNotEmpty && version != seenVersion,
        lines = version.isNotEmpty &&
                version != seenVersion &&
                (seenVersion.isNotEmpty || signedIn)
            ? List.unmodifiable(notes[version] ?? const <String>[])
            : const [];

  final String version;
  final bool shouldRemember;
  final List<String> lines;
}
