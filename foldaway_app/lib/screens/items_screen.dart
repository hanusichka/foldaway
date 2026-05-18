import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../models/list_item.dart';
import '../theme/app_theme.dart';

class ItemsScreen extends StatefulWidget {
  final String listId;
  final String listTitle;

  const ItemsScreen({
    super.key,
    required this.listId,
    required this.listTitle,
  });

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _apiService = ApiService();

  List<ListItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _apiService.getItems(widget.listId);

      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка завантаження пунктів: $e'),
        ),
      );

      debugPrint('ITEMS LOAD ERROR: $e');
    }
  }

  Future<void> _openMap(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Некоректне посилання на карту'),
        ),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не вдалося відкрити карту'),
        ),
      );
    }
  }

  Future<void> _createItem() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final mapLinkController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('НОВИЙ ПУНКТ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Назва',
                    hintText: 'Наприклад: Центральний парк',
                  ),
                  autofocus: true,
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Опис',
                    hintText: 'Необовʼязково',
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: mapLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Місце в Google Maps',
                    hintText: 'Встав посилання на Google Maps',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('СКАСУВАТИ'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final mapLink = mapLinkController.text.trim();

                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Введи назву пункту'),
                    ),
                  );
                  return;
                }

                final item = await _apiService.createItem(
                  widget.listId,
                  title,
                  description,
                  mapLink.isEmpty ? '' : mapLink,
                );

                if (!mounted) return;

                if (item != null) {
                  Navigator.pop(dialogContext);
                  await _loadItems();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Не вдалося створити пункт'),
                    ),
                  );
                }
              },
              child: const Text('ДОДАТИ'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    mapLinkController.dispose();
  }

  Future<void> _toggleItem(ListItem item) async {
    await _apiService.toggleItem(item.id, !item.isDone);
    _loadItems();
  }

  Future<void> _deleteItem(String id) async {
    final success = await _apiService.deleteItem(id);

    if (!mounted) return;

    if (success) {
      await _loadItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не вдалося видалити пункт'),
        ),
      );
    }
  }

  bool _hasMapLink(ListItem item) {
    return item.externalLink.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final done = _items.where((i) => i.isDone).length;
    final total = _items.length;

    return Scaffold(
      backgroundColor: FoldawayColors.paper,
      appBar: AppBar(
        title: Text(widget.listTitle.toUpperCase()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/trips'),
        ),
        bottom: total > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: done / total,
                  backgroundColor: FoldawayColors.line,
                  color: FoldawayColors.ink,
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NO ITEMS',
                          style: Theme.of(context).textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Додай перший пункт до цього списку',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: FoldawayColors.muted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: FoldawayColors.white,
                        border: Border.all(color: FoldawayColors.line),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: Checkbox(
                          value: item.isDone,
                          onChanged: (_) => _toggleItem(item),
                        ),
                        title: Text(
                          item.title.toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                decoration: item.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isDone
                                    ? FoldawayColors.muted
                                    : FoldawayColors.ink,
                              ),
                        ),
                        subtitle: item.description.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  item.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: FoldawayColors.muted,
                                      ),
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasMapLink(item))
                              IconButton(
                                tooltip: 'Глянути на карті',
                                icon: const Icon(Icons.map_outlined),
                                onPressed: () => _openMap(item.externalLink),
                              ),
                            IconButton(
                              tooltip: 'Видалити',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteItem(item.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}