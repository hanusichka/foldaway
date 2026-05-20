import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../models/list_item.dart';
import '../theme/app_theme.dart';

class ItemsScreen extends StatefulWidget {
  final String listId;
  final String listTitle;
  final String tripId;
  final String tripTitle;

  const ItemsScreen({
    super.key,
    required this.listId,
    required this.listTitle,
    required this.tripId,
    required this.tripTitle,
  });

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _apiService = ApiService();

  List<ListItem> _items = [];
  List<Map<String, dynamic>> _placeRecommendations = [];

  bool _isLoading = true;
  bool _isLoadingRecommendations = false;
  final Set<String> _addingRecommendationTitles = {};

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

  Future<void> _loadPlaceRecommendations() async {
    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final recommendations = await _apiService.getPlaceRecommendations(
        widget.listId,
      );

      if (!mounted) return;

      setState(() {
        _placeRecommendations = recommendations;
      });

      _showRecommendationsSheet();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не вдалося отримати рекомендації: $e'),
        ),
      );

      debugPrint('PLACE RECOMMENDATIONS ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  Future<void> _addRecommendation(Map<String, dynamic> recommendation) async {
    final title = recommendation['title']?.toString().trim() ?? '';
    final description = _buildRecommendationDescription(recommendation);
    final externalLink =
        recommendation['external_link']?.toString().trim() ?? '';

    final latitude = _toDouble(recommendation['latitude']);
    final longitude = _toDouble(recommendation['longitude']);

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У рекомендації немає назви'),
        ),
      );
      return;
    }

    setState(() {
      _addingRecommendationTitles.add(title);
    });

    try {
      final createdItem = await _apiService.createItem(
        widget.listId,
        title,
        description,
        externalLink,
        latitude,
        longitude,
      );

      if (!mounted) return;

      if (createdItem != null) {
        setState(() {
          _placeRecommendations.removeWhere(
            (item) => item['title']?.toString().trim() == title,
          );
        });

        await _loadItems();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Додано: $title'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не вдалося додати рекомендацію'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка додавання: $e'),
        ),
      );

      debugPrint('ADD RECOMMENDATION ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _addingRecommendationTitles.remove(title);
        });
      }
    }
  }

  String _buildRecommendationDescription(Map<String, dynamic> recommendation) {
    final aiDescription =
        recommendation['ai_description']?.toString().trim() ?? '';
    final reason = recommendation['reason']?.toString().trim() ?? '';
    final originalDescription =
        recommendation['description']?.toString().trim() ?? '';

    final parts = <String>[];

    if (aiDescription.isNotEmpty) {
      parts.add(aiDescription);
    }

    if (originalDescription.isNotEmpty) {
      parts.add(originalDescription);
    }

    if (reason.isNotEmpty) {
      parts.add('AI: $reason');
    }

    return parts.join('\n\n');
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();

    return double.tryParse(value.toString());
  }

  void _showRecommendationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: FoldawayColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: FoldawayColors.line,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          const Icon(Icons.auto_awesome),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'AI RECOMMENDATIONS',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    fontSize: 24,
                                  ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Ось кілька місць, підібраних для списку “${widget.listTitle}” у подорожі “${widget.tripTitle}”. Додай тільки ті, які тобі підходять.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: FoldawayColors.muted,
                            ),
                      ),

                      const SizedBox(height: 18),

                      if (_placeRecommendations.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: FoldawayColors.white,
                            border: Border.all(color: FoldawayColors.line),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Нових рекомендацій немає. Можливо, найкращі місця вже додані в список.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        ..._placeRecommendations.map((recommendation) {
                          final title =
                              recommendation['title']?.toString().trim() ?? '';
                          final aiDescription = recommendation['ai_description']
                                  ?.toString()
                                  .trim() ??
                              '';
                          final reason =
                              recommendation['reason']?.toString().trim() ?? '';
                          final description = recommendation['description']
                                  ?.toString()
                                  .trim() ??
                              '';
                          final externalLink = recommendation['external_link']
                                  ?.toString()
                                  .trim() ??
                              '';
                          final mapSymbol =
                              recommendation['map_symbol']?.toString() ?? '📍';
                          final rating = recommendation['rating'];
                          final ratingCount = recommendation['rating_count'];
                          final isAdding =
                              _addingRecommendationTitles.contains(title);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: FoldawayColors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: FoldawayColors.line,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mapSymbol,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        title.toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontSize: 16,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),

                                if (aiDescription.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    aiDescription,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: FoldawayColors.ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],

                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: FoldawayColors.muted,
                                        ),
                                  ),
                                ],

                                if (rating != null || ratingCount != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        [
                                          if (rating != null)
                                            rating.toString(),
                                          if (ratingCount != null)
                                            '$ratingCount відгуків',
                                        ].join(' · '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: FoldawayColors.muted,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],

                                if (reason.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: FoldawayColors.paper,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: FoldawayColors.line,
                                      ),
                                    ),
                                    child: Text(
                                      reason,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: FoldawayColors.muted,
                                          ),
                                    ),
                                  ),
                                ],

                                if (externalLink.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () => _openMap(externalLink),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.map_outlined,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Відкрити в Google Maps',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: externalLink.isEmpty
                                            ? null
                                            : () => _openMap(externalLink),
                                        icon: const Icon(Icons.map_outlined),
                                        label: const Text('КАРТА'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: isAdding
                                            ? null
                                            : () async {
                                                await _addRecommendation(
                                                  recommendation,
                                                );
                                                setSheetState(() {});
                                              },
                                        icon: isAdding
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.add),
                                        label: Text(
                                          isAdding ? 'ДОДАЮ...' : 'ДОДАТИ',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
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

    final atPattern = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
    final atMatch = atPattern.firstMatch(trimmedUrl);

    if (atMatch != null) {
      return {
        'latitude': double.parse(atMatch.group(1)!),
        'longitude': double.parse(atMatch.group(2)!),
      };
    }

    final placePattern = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)');
    final placeMatch = placePattern.firstMatch(trimmedUrl);

    if (placeMatch != null) {
      return {
        'latitude': double.parse(placeMatch.group(1)!),
        'longitude': double.parse(placeMatch.group(2)!),
      };
    }

    final queryPattern = RegExp(r'query=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
    final queryMatch = queryPattern.firstMatch(trimmedUrl);

    if (queryMatch != null) {
      return {
        'latitude': double.parse(queryMatch.group(1)!),
        'longitude': double.parse(queryMatch.group(2)!),
      };
    }

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
          onPressed: () => context.go(
            '/trips/${widget.tripId}?title=${Uri.encodeComponent(widget.tripTitle)}',
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'AI-рекомендації',
            onPressed: _isLoadingRecommendations
                ? null
                : _loadPlaceRecommendations,
            icon: _isLoadingRecommendations
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
          ),
        ],
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
                          'Додай перший пункт вручну або натисни ✨ для AI-рекомендацій',
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