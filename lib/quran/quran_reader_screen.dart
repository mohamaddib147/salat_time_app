import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import 'package:url_launcher/url_launcher.dart';
import 'quran_provider.dart';
import 'quran_settings_screen.dart';
import 'quran_audio_provider.dart';

class QuranReaderScreen extends StatefulWidget {
  final int startPage;
  const QuranReaderScreen({super.key, this.startPage = 1});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.startPage - 1);
    // ensure provider currentPage is set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuranProvider>().setPage(widget.startPage);
    });
  }

  @override
  void dispose() {
    // Persist last-read page explicitly on close
    final p = context.read<QuranProvider>();
    p.setPage(p.currentPage);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<QuranProvider, QuranAudioProvider>(
      builder: (context, provider, audio, _) {
        final currentPage = provider.currentPage;
        final surahInfo = provider.service.getPageSurahInfo(currentPage);
  final isDark = Theme.of(context).brightness == Brightness.dark;
        final baseTextStyle = _fontFromProvider(provider);
        final bg = isDark ? const Color(0xFF121212) : Colors.white;
        final fg = isDark ? Colors.white : Colors.black;
  return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${surahInfo['name']}'),
                Text(
                  'Page $currentPage / ${quran.totalPagesCount} • Juz ${provider.service.getJuzForPage(currentPage)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.map),
                tooltip: 'Go to Page / Juz / Surah / Ayah',
                onPressed: () async {
                  final page = await _showGoToDialog(context, provider, currentPage);
                  if (page != null) {
                    _controller.jumpToPage(page - 1);
                    provider.setPage(page);
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'open_juz') {
                    final juz = provider.service.getJuzForPage(currentPage);
                    final uri = Uri.parse(quran.getJuzURL(juz));
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else if (v == 'open_page') {
                    // Quran.com doesn't have direct page URLs; open juz instead.
                    final juz = provider.service.getJuzForPage(currentPage);
                    final uri = Uri.parse(quran.getJuzURL(juz));
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'open_juz', child: Text('Open Juz on Quran.com')),
                  const PopupMenuItem(value: 'open_page', child: Text('Open Near Page on Quran.com')),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Go to Page',
                onPressed: () async {
                  final ctrl = TextEditingController(text: currentPage.toString());
                  final page = await showDialog<int>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Go to Page'),
                      content: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Page (1–604)'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            final p = int.tryParse(ctrl.text);
                            if (p != null && p >= 1 && p <= 604) {
                              Navigator.pop(ctx, p);
                            }
                          },
                          child: const Text('Go'),
                        ),
                      ],
                    ),
                  );
                  if (page != null) {
                    _controller.jumpToPage(page - 1);
                    provider.setPage(page);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuranSettingsScreen()),
                ),
              ),
              // Removed per-verse clutter: rely on bottom audio bar for playback
              IconButton(
                icon: Icon(provider.isBookmarked(currentPage) ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => provider.toggleBookmark(currentPage),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _controller,
            itemCount: 604,
            onPageChanged: (i) => provider.setPage(i + 1),
            itemBuilder: (_, index) {
              final page = index + 1;
              final segs = provider.service.getPageSegments(page);
              final juz = provider.service.getJuzForPage(page);

              return Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 72),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Juz header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.teal.withOpacity(0.2))),
                        ),
                        child: Text('Juz $juz • Page $page',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
                      ),
                      const SizedBox(height: 12),
                      // Render segments for this page
                      ...segs.expand((seg) {
                        final s = seg['surah']!;
                        final start = seg['start']!;
                        final end = seg['end']!;
                        final atSurahStart = start == 1;
                        final showBasmala = atSurahStart && s != 1 && s != 9;

                        final widgets = <Widget>[];
                        // Surah header only when segment starts at verse 1
                        if (atSurahStart) {
                          widgets.add(
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
                              child: Text(
                                provider.service.getSurahNameArabicByIndex(s),
                                textAlign: TextAlign.center,
                                style: baseTextStyle.copyWith(fontSize: provider.fontSize + 2, color: fg),
                              ),
                            ),
                          );
                        }
                        if (showBasmala) {
                          widgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '﷽',
                                textAlign: TextAlign.center,
                                style: baseTextStyle.copyWith(fontSize: provider.fontSize + 2, color: fg),
                              ),
                            ),
                          );
                        }

                        for (int v = start; v <= end; v++) {
                          // Render verse without built-in end symbol; we'll append our own symbol (۝) optionally
                          final text = quran.getVerse(s, v, verseEndSymbol: false);
                          final sajdah = provider.service.isSajdah(s, v);
                          final isCurrentFromAudio = audio.currentSurah == s && audio.currentAyah == v;
                          widgets.add(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GestureDetector(
                                    onLongPress: () async {
                                      final uri = Uri.parse(quran.getVerseURL(s, v));
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: RichText(
                                        textAlign: TextAlign.right,
                                        text: TextSpan(
                                          style: baseTextStyle.copyWith(
                                            color: isCurrentFromAudio ? Colors.teal : fg,
                                            backgroundColor: isCurrentFromAudio ? Colors.teal.withOpacity(0.08) : null,
                                          ),
                                          children: [
                                            TextSpan(text: text.trim() + ' '),
                                            if (!provider.useVerseEndSymbols)
                                              WidgetSpan(
                                                alignment: PlaceholderAlignment.middle,
                                                child: _ayahMarker(v, provider),
                                              ),
                if (provider.useVerseEndSymbols)
                                              TextSpan(
                                                text: quran.getVerseEndSymbol(
                                                  v,
                  arabicNumeral: ((provider as dynamic).verseEndArabicNumerals as bool?) ?? true,
                                                ),
                                                style: baseTextStyle.copyWith(color: fg),
                                              ),
                                            if (sajdah)
                                              WidgetSpan(
                                                alignment: PlaceholderAlignment.middle,
                                                child: Padding(
                                                  padding: const EdgeInsetsDirectional.only(start: 6.0),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                                    ),
                                                    child: Text(quran.sajdah, style: TextStyle(color: Colors.orange[800], fontSize: 12)),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Per-ayah play/pause controls removed to keep reading clean.
                                  if (provider.showTranslation)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(start: 8.0, top: 6.0),
                                      child: Text(
                                        provider.service.getVerseTranslation(s, v, provider.translationCode),
                                        textDirection: TextDirection.ltr,
                                        style: TextStyle(
                                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }

                        return widgets;
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          ),
          bottomSheet: _AudioControlBar(),
        );
      },
    );
  }

  TextStyle _fontFromProvider(QuranProvider p) {
    switch (p.font) {
      case 'uthman':
        return TextStyle(fontFamily: 'UthmanTN', fontSize:  p.fontSize, height: 1.8);
      case 'kfgqpc_an':
        return TextStyle(fontFamily: 'KFGQPCAn', fontSize:  p.fontSize, height: 1.8);
      case 'kufi_ext':
        return TextStyle(fontFamily: 'KFGQPCKufiExt', fontSize:  p.fontSize, height: 1.7);
      case 'kufi_sty':
        return TextStyle(fontFamily: 'KFGQPCKufiSty', fontSize:  p.fontSize, height: 1.7);
      case 'ksa':
        return TextStyle(fontFamily: 'KSA', fontSize:  p.fontSize, height: 1.7);
      case 'ksa_heading':
        return TextStyle(fontFamily: 'KSAHeading', fontSize:  p.fontSize, height: 1.6);
      case 'notonaskh':
        return GoogleFonts.notoNaskhArabic(fontSize: p.fontSize, height: 1.7);
      case 'aref':
        return GoogleFonts.arefRuqaa(fontSize: p.fontSize, height: 1.6);
      case 'amiri':
      default:
        return GoogleFonts.amiri(fontSize: p.fontSize, height: 1.7);
    }
  }

  Widget _ayahMarker(int ayah, QuranProvider p) {
    if (p.marker == 'ornate') {
      return Container(
        margin: const EdgeInsetsDirectional.only(start: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(colors: [Color(0xFF59C173), Color(0xFFA17FE0)]),
        ),
        child: Text('$ayah', style: GoogleFonts.amiri(color: Colors.white, fontSize: 14)),
      );
    }
    // circle
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.teal, width: 1.2),
      ),
      child: Text('$ayah', style: GoogleFonts.amiri(fontSize: 14, color: Colors.teal[800])),
    );
  }

  Future<int?> _showGoToDialog(BuildContext context, QuranProvider provider, int currentPage) async {
    final pageCtrl = TextEditingController(text: currentPage.toString());
    final juzCtrl = TextEditingController();
    final surahCtrl = TextEditingController();
    final ayahCtrl = TextEditingController();
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go To'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Page (1–604)')),
            TextField(controller: juzCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Juz (1–30)')),
            TextField(controller: surahCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Surah (1–114)')),
            TextField(controller: ayahCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ayah (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              int? targetPage;
              final page = int.tryParse(pageCtrl.text);
              final juz = int.tryParse(juzCtrl.text);
              final surah = int.tryParse(surahCtrl.text);
              final ayah = int.tryParse(ayahCtrl.text);
              if (page != null && page >= 1 && page <= 604) {
                targetPage = page;
              } else if (juz != null && juz >= 1 && juz <= 30) {
                targetPage = provider.service.getFirstPageOfJuz(juz);
              } else if (surah != null && surah >= 1 && surah <= 114) {
                final v = (ayah != null && ayah >= 1) ? ayah : 1;
                targetPage = quran.getPageNumber(surah, v);
              }
              if (targetPage != null) Navigator.pop(ctx, targetPage);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
    return res;
  }
}

class _AudioControlBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<QuranProvider, QuranAudioProvider>(
      builder: (context, provider, audio, _) {
        final isDark = provider.theme == 'dark';
        final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final fg = isDark ? Colors.white : Colors.black87;
        final s = audio.currentSurah;
        final v = audio.currentAyah;
        final label = s == null
            ? 'No verse selected'
            : 'Surah $s' + (v != null ? ' • Ayah $v' : '');
        final pos = audio.position;
        final dur = audio.duration.inMilliseconds == 0 ? const Duration(milliseconds: 1) : audio.duration;
        final progress = (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
        return Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: audio.isPlaying ? 'Pause' : (audio.isPaused ? 'Resume' : 'Play'),
                    icon: Icon(
                      audio.isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: Colors.teal,
                      size: 28,
                    ),
                    onPressed: () async {
                      if (audio.isPlaying) {
                        await audio.pause();
                        return;
                      }
                      if (audio.isPaused) {
                        await audio.resume();
                        return;
                      }
                      // Not playing and not paused: start default
                      if (s != null) {
                        if (v != null) {
                          await audio.playAyah(s, v);
                        } else {
                          await audio.playSurah(s);
                        }
                      } else {
                        // Default to current page first ayah
                        final page = provider.currentPage;
                        final segs = provider.service.getPageSegments(page);
                        if (segs.isNotEmpty) {
                          final first = segs.first;
                          await audio.playAyah(first['surah']!, first['start']!);
                        }
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Next Ayah',
                    icon: const Icon(Icons.skip_next, color: Colors.teal, size: 28),
                    onPressed: audio.nextAyah,
                  ),
                  IconButton(
                    tooltip: 'Stop',
                    icon: const Icon(Icons.stop_circle, color: Colors.teal, size: 26),
                    onPressed: () => audio.stopAndClear(),
                  ),
                ],
              ),
              SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
