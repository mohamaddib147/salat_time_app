import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'quran_provider.dart';

class QuranSettingsScreen extends StatelessWidget {
  const QuranSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
  return Consumer<QuranProvider>(builder: (context, provider, _) {
      return Scaffold(
        appBar: AppBar(title: Text('Quran Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Font', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: provider.font,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'uthman', child: Text('Uthmanic Naskh (KFGQPC)')),
                DropdownMenuItem(value: 'kfgqpc_an', child: Text('KFGQPC An')),
                DropdownMenuItem(value: 'kufi_ext', child: Text('KFGQPC Kufi Extended')),
                DropdownMenuItem(value: 'kufi_sty', child: Text('KFGQPC Kufi Style')),
                DropdownMenuItem(value: 'ksa', child: Text('KSA Regular')),
                DropdownMenuItem(value: 'ksa_heading', child: Text('KSA Heading')),
                DropdownMenuItem(value: 'amiri', child: Text('Amiri (Google)')),
                DropdownMenuItem(value: 'notonaskh', child: Text('Noto Naskh Arabic (Google)')),
                DropdownMenuItem(value: 'aref', child: Text('Aref Ruqaa (Google)')),
              ],
              onChanged: (v) {
                if (v != null) provider.setFont(v);
              },
            ),
            const SizedBox(height: 16),
            Text('Font Size', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: provider.fontSize,
                    min: 16,
                    max: 40,
                    divisions: 24,
                    label: provider.fontSize.toStringAsFixed(0),
                    onChanged: (v) => provider.setFontSize(v),
                  ),
                ),
                SizedBox(width: 12),
                Text(provider.fontSize.toStringAsFixed(0)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Ayah Marker Style', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: provider.marker,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'circle', child: Text('Circle')),
                DropdownMenuItem(value: 'ornate', child: Text('Ornate')),
              ],
              onChanged: (v) {
                if (v != null) provider.setMarker(v);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show Translation'),
              value: provider.showTranslation,
              onChanged: (val) => provider.setShowTranslation(val),
            ),
            if (provider.showTranslation) ...[
              const SizedBox(height: 8),
              const Text('Translation', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: provider.translationCode,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'enSaheeh', child: Text('English – Saheeh International')),
                  DropdownMenuItem(value: 'enClearQuran', child: Text('English – Clear Quran')),
                  DropdownMenuItem(value: 'urdu', child: Text('Urdu')),
                  DropdownMenuItem(value: 'indonesian', child: Text('Indonesian')),
                  DropdownMenuItem(value: 'turkish', child: Text('Turkish')),
                  DropdownMenuItem(value: 'french', child: Text('French')),
                  DropdownMenuItem(value: 'bengali', child: Text('Bengali')),
                  DropdownMenuItem(value: 'russian', child: Text('Russian')),
                  DropdownMenuItem(value: 'spanish', child: Text('Spanish')),
                  DropdownMenuItem(value: 'portuguese', child: Text('Portuguese')),
                ],
                onChanged: (v) {
                  if (v != null) provider.setTranslationCode(v);
                },
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Use Verse End Symbols (۝)'),
              value: provider.useVerseEndSymbols,
              onChanged: (val) => provider.setUseVerseEndSymbols(val),
            ),
            if (provider.useVerseEndSymbols)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16.0),
                child: SwitchListTile(
                  title: const Text('Use Arabic numerals inside ۝'),
                  subtitle: const Text('Switch between ١٢٣ and 123 inside the marker'),
                  value: provider.verseEndArabicNumerals,
                  onChanged: (v) => provider.setVerseEndArabicNumerals(v),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Theme is now controlled from the main Settings > Appearance.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    });
  }
}
