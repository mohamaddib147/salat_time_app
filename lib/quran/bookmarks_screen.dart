import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'quran_provider.dart';
import 'quran_reader_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<QuranProvider>(
      builder: (context, provider, _) {
        final items = provider.bookmarks;
        return Scaffold(
          appBar: AppBar(title: Text('Bookmarks')),
          body: items.isEmpty
              ? Center(child: Text('No bookmarks yet'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final page = items[index];
                    return ListTile(
                      title: Text('Page $page'),
                      leading: Icon(Icons.bookmark),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.delete_outline),
                            onPressed: () => provider.removeBookmark(page),
                          ),
                          Icon(Icons.chevron_right),
                        ],
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
      },
    );
  }
}
