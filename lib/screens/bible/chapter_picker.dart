import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/bible_books.dart';
import '../../core/theme.dart';

/// Opens a chapter of [book] (optionally scrolled to a verse).
void openChapter(BuildContext context, String book, int chapter, String translation, {int? verse}) {
  context.push(
    '/bible/chapter?book=${Uri.encodeComponent(book)}&chapter=$chapter&translation=$translation'
    '${verse != null ? '&verse=$verse' : ''}',
  );
}

/// Bottom sheet with the chapter numbers of [book].
void showChapterPickerFor(BuildContext context, BookInfo book, String translation) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.navySurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(book.name, style: const TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Choose a chapter (1 - ${book.chapters})',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 14),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: book.chapters,
              itemBuilder: (_, i) => InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.pop(sheet);
                  openChapter(context, book.name, i + 1, translation);
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.navyVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.navyOutline),
                  ),
                  child: Text('${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.goldDark)),
                ),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}
