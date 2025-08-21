import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:url_launcher/url_launcher.dart';
import 'quran_provider.dart';
import 'quran_reader_screen.dart';

class JuzListScreen extends StatelessWidget {
  const JuzListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuranProvider>();
    final items = List<int>.generate(quran.totalJuzCount, (i) => i + 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Juz (1–30)'),
      ),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final juz = items[i];
          final startPage = provider.service.getFirstPageOfJuz(juz);
          final endPage = juz < quran.totalJuzCount
              ? (provider.service.getFirstPageOfJuz(juz + 1) - 1).clamp(1, quran.totalPagesCount)
              : quran.totalPagesCount;
          // Find starting (surah, ayah) of this Juz by scanning
          int startSurah = 1;
          int startAyah = 1;
          outer:
          for (int s = 1; s <= 114; s++) {
            final count = quran.getVerseCount(s);
            for (int v = 1; v <= count; v++) {
              if (quran.getJuzNumber(s, v) == juz) {
                startSurah = s;
                startAyah = v;
                break outer;
              }
            }
          }
          final surahName = quran.getSurahName(startSurah);
          return ListTile(
            leading: CircleAvatar(child: Text('$juz')),
            title: Text('Juz $juz • p.$startPage-$endPage'),
            subtitle: Text('Starts: $surahName $startAyah'),
            trailing: Wrap(spacing: 8, children: [
              IconButton(
                tooltip: 'Open on Quran.com',
                icon: const Icon(Icons.open_in_new),
                onPressed: () async {
                  final uri = Uri.parse(quran.getJuzURL(juz));
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const Icon(Icons.chevron_right),
            ]),
      onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
        child: QuranReaderScreen(startPage: startPage),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
