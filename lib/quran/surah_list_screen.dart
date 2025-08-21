import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:url_launcher/url_launcher.dart';
import 'quran_provider.dart';
import 'quran_reader_screen.dart';
import 'quran_settings_screen.dart';

class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuranProvider>();
    final surahs = provider.service.getAllSurahs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surahs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Juz List',
            onPressed: () => Navigator.pushNamed(context, '/juz'),
          ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Go to Juz / Surah / Ayah',
            onPressed: () => _showGoToDialog(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuranSettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () => Navigator.pushNamed(context, '/bookmarks'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/qsearch'),
          ),
        ],
      ),
      body: Column(
        children: [
          _lastReadTile(context, provider),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: surahs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = surahs[index];
                final idx = s['index'] as int;
                final label = provider.service.getPlaceLabel(idx);
                final range = provider.service.getSurahPageRange(idx);
                return ListTile(
                  title: Text('${s['index']}. ${s['englishName']}'),
                  subtitle: Text('${s['name']} • ${s['verses']} verses • $label • p.${range.start}-${range.end}'),
                  trailing: Wrap(spacing: 8, children: [
                    IconButton(
                      tooltip: 'Open on Quran.com',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openSurahURL(idx),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                  onTap: () {
                    final page = s['startPage'] as int;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: QuranReaderScreen(startPage: page),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGoToDialog(BuildContext context, QuranProvider provider) async {
    final juzCtrl = TextEditingController();
    final surahCtrl = TextEditingController();
    final ayahCtrl = TextEditingController();
  final pageCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Go To'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pageCtrl,
                decoration: const InputDecoration(labelText: 'Page (1-604)')
              ),
              TextField(
                controller: juzCtrl,
                decoration: const InputDecoration(labelText: 'Juz (1-30)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: surahCtrl,
                decoration: const InputDecoration(labelText: 'Surah (1-114)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: ayahCtrl,
                decoration: const InputDecoration(labelText: 'Ayah (optional)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final page = int.tryParse(pageCtrl.text);
                final juz = int.tryParse(juzCtrl.text);
                final surah = int.tryParse(surahCtrl.text);
                final ayah = int.tryParse(ayahCtrl.text);

                int? targetPage;
                if (page != null && page >= 1 && page <= 604) {
                  targetPage = page;
                } else
                if (juz != null && juz >= 1 && juz <= 30) {
                  targetPage = provider.service.getFirstPageOfJuz(juz);
                } else if (surah != null && surah >= 1 && surah <= 114) {
                  final v = (ayah != null && ayah >= 1) ? ayah : 1;
                  targetPage = quran.getPageNumber(surah, v);
                }

                if (targetPage != null) {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: provider,
                        child: QuranReaderScreen(startPage: targetPage!),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  Widget _lastReadTile(BuildContext context, QuranProvider provider) {
    final last = provider.currentPage; // already restored on provider init
    return ListTile(
      tileColor: Colors.teal.withOpacity(0.06),
      leading: const Icon(Icons.play_arrow, color: Colors.teal),
      title: Text('Last read: Page $last', style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: QuranReaderScreen(startPage: last),
            ),
          ),
        );
      },
    );
  }

  void _openSurahURL(int surah) async {
    final uri = Uri.parse(quran.getSurahURL(surah));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
