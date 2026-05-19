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

  Map<String, double>? _extractCoordinatesFromGoogleMapsUrl(String url) {
    final trimmedUrl = url.trim();

    if (trimmedUrl.isEmpty) return null;

    // Example: https://www.google.com/maps/place/.../@48.8584,2.2945,17z
    final atPattern = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
    final atMatch = atPattern.firstMatch(trimmedUrl);

    if (atMatch != null) {
      return {
        'latitude': double.parse(atMatch.group(1)!),
        'longitude': double.parse(atMatch.group(2)!),
      };
    }

    // Example: ...!3d48.8584!4d2.2945
    final placePattern = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)');
    final placeMatch = placePattern.firstMatch(trimmedUrl);

    if (placeMatch != null) {
      return {
        'latitude': double.parse(placeMatch.group(1)!),
        'longitude': double.parse(placeMatch.group(2)!),
      };
    }

    // Example: ...?query=48.8584,2.2945
    final queryPattern = RegExp(r'query=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
    final queryMatch = queryPattern.firstMatch(trimmedUrl);

    if (queryMatch != null) {
      return {
        'latitude': double.parse(queryMatch.group(1)!),
        'longitude': double.parse(queryMatch.group(2)!),
      };
    }

    // Example: ...?q=48.8584,2.2945
    final qPattern = RegExp(r'[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
    final qMatch = qPattern.firstMatch(trimmedUrl);

    if (qMatch != null) {
      return {
        'latitude': double.parse(qMatch.group(1)!),
        'longitude': double.parse(qMatch.group(2)!),
      };
    }

    return null;
  }

  Future<void> _createItem() async {
    await _showItemDialog();
  }

  Future<void> _showItemDialog({ListItem? existingItem}) async {
    final titleController = TextEditingController(
      text: existingItem?.title ?? '',
    );

    final descriptionController = TextEditingController(
      text: existingItem?.description ?? '',
    );

    final mapLinkController = TextEditingController(
      text: existingItem?.externalLink ?? '',
    );

    final bool isEditing = existingItem != null;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'РЕДАГУВАТИ ПУНКТ' : 'НОВИЙ ПУНКТ'),
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
                    hintText: 'Встав довге посилання на Google Maps',
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

                final coordinates =
                    _extractCoordinatesFromGoogleMapsUrl(mapLink);

                final latitude = coordinates?['latitude'];
                final longitude = coordinates?['longitude'];

                if (mapLink.isNotEmpty && coordinates == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Посилання збережено, але координати не знайдено. Для карти краще вставити довге Google Maps посилання.',
                      ),
                    ),
                  );
                }

                ListItem? result;

                if (isEditing) {
                  result = await _apiService.updateItem(
                    existingItem.id,
                    title,
                    description,
                    mapLink,
                    latitude,
                    longitude,
                  );
                } else {
                  result = await _apiService.createItem(
                    widget.listId,
                    title,
                    description,
                    mapLink,
                    latitude,
                    longitude,
                  );
                }

                if (!mounted) return;

                if (result != null) {
                  Navigator.pop(dialogContext);
                  await _loadItems();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Не вдалося оновити пункт'
                            : 'Не вдалося створити пункт',
                      ),
                    ),
                  );
                }
              },
              child: Text(isEditing ? 'ЗБЕРЕГТИ' : 'ДОДАТИ'),
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
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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
                              tooltip: 'Редагувати',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                _showItemDialog(existingItem: item);
                              },
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