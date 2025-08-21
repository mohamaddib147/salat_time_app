import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quran/quran.dart' as quran;
import 'quran_provider.dart';
import 'quran_reader_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _q = '';
  bool _arabic = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuranProvider>();
    final results = _q.isEmpty
        ? []
        : (_arabic
            ? provider.service.search(_q)
            : provider.service.searchInTranslation(_q, provider.translationCode));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: _arabic ? 'ابحث في المصحف (عربي)…' : 'Search in translation…',
            border: InputBorder.none,
          ),
          textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _q = v),
          onSubmitted: (v) => setState(() => _q = v),
        ),
        actions: [
          IconButton(
            tooltip: _arabic ? 'Arabic Text' : 'Translations',
            icon: Icon(_arabic ? Icons.translate : Icons.g_translate),
            onPressed: () => setState(() => _arabic = !_arabic),
          ),
        ],
      ),
      body: _q.isEmpty
          ? const Center(child: Text('Type to search'))
          : ListView.separated(
              itemCount: results.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return ListTile(
                    tileColor: Colors.teal.withOpacity(0.06),
                    title: Text('Matches: ${results.length}'),
                    subtitle: Text(_arabic ? 'Arabic text' : 'Translation: ${provider.translationCode}'),
                  );
                }
                final r = results[i - 1];
                final text = r['text'] as String;
                final surah = r['surah'] as int;
                final ayah = r['ayah'] as int;
                final page = r['page'] as int;
                return ListTile(
                  title: Text(
                    text,
                    textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
                  ),
                  subtitle: Text('Surah $surah • Ayah $ayah • Page $page'),
                  trailing: IconButton(
                    tooltip: 'Open on Quran.com',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () async {
                      final uri = Uri.parse(quran.getVerseURL(surah, ayah));
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  onTap: () {
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
    );
  }
}
