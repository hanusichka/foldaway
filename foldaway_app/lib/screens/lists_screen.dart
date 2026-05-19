import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../models/trip_list.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';

class ListsScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;

  const ListsScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  final _apiService = ApiService();

  List<TripList> _lists = [];
  bool _isLoading = true;

  final List<String> _availableIcons = [
    '🍽️',
    '☕',
    '🥐',
    '🏛️',
    '🖼️',
    '🛍️',
    '🧳',
    '🏨',
    '🚆',
    '✈️',
    '🌿',
    '⭐',
    '📍',
  ];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    try {
      final lists = await _apiService.getLists(widget.tripId);

      if (!mounted) return;

      setState(() {
        _lists = lists;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка завантаження списків: $e'),
        ),
      );

      debugPrint('LISTS LOAD ERROR: $e');
    }
  }

  Future<void> _createList() async {
    await _showListDialog();
  }

  Future<void> _showListDialog({TripList? existingList}) async {
    final titleController = TextEditingController(
      text: existingList?.title ?? '',
    );

    String selectedIcon = existingList?.icon ?? '🍽️';
    final bool isEditing = existingList != null;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'РЕДАГУВАТИ СПИСОК' : 'НОВИЙ СПИСОК',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Назва списку',
                        hintText: 'Наприклад: Кафе та ресторани',
                      ),
                      autofocus: true,
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'ОБЕРИ ІКОНКУ',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: FoldawayColors.muted,
                          ),
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableIcons.map((icon) {
                        final isSelected = selectedIcon == icon;

                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FoldawayColors.ink
                                  : FoldawayColors.white,
                              border: Border.all(
                                color: isSelected
                                    ? FoldawayColors.ink
                                    : FoldawayColors.line,
                              ),
                            ),
                            child: CategoryIcon(
                              icon: icon,
                              size: 30,
                              //color: isSelected ? FoldawayColors.white : FoldawayColors.ink,
                            ),
                          ),
                        );
                      }).toList(),
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

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Введи назву списку'),
                        ),
                      );
                      return;
                    }

                    TripList? result;

                    if (isEditing) {
                      result = await _apiService.updateList(
                        existingList.id,
                        title,
                        selectedIcon,
                      );
                    } else {
                      result = await _apiService.createList(
                        widget.tripId,
                        title,
                        selectedIcon,
                      );
                    }

                    if (!mounted) return;

                    if (result != null) {
                      Navigator.pop(dialogContext);
                      await _loadLists();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing
                                ? 'Не вдалося оновити список'
                                : 'Не вдалося створити список',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'ЗБЕРЕГТИ' : 'СТВОРИТИ'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
  }

  Future<void> _deleteList(String id) async {
    final success = await _apiService.deleteList(id);

    if (!mounted) return;

    if (success) {
      await _loadLists();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не вдалося видалити список'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoldawayColors.paper,
      appBar: AppBar(
        title: Text(widget.tripTitle.toUpperCase()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/trips'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NO LISTS',
                          style: Theme.of(context).textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Створи перший список для цієї подорожі',
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
                  itemCount: _lists.length,
                  itemBuilder: (context, index) {
                    final list = _lists[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: FoldawayColors.white,
                        border: Border.all(
                          color: FoldawayColors.line,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: SizedBox(
                          width: 44,
                          child: Center(
                            child: CategoryIcon(
                              icon: list.icon,
                              size: 38,
                            ),
                          ),
                        ),
                        title: Text(
                          list.title.toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        subtitle: Text(
                          'LIST ${index + 1}',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: FoldawayColors.muted,
                                  ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Редагувати',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                _showListDialog(existingList: list);
                              },
                            ),
                            IconButton(
                              tooltip: 'Видалити',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteList(list.id),
                            ),
                          ],
                        ),
                        onTap: () => context.go(
                          '/trips/${widget.tripId}/lists/${list.id}',
                          extra: list.title,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'mapButton',
            tooltip: 'Карта подорожі',
            onPressed: () {
              context.go(
                '/trips/${widget.tripId}/map?title=${Uri.encodeComponent(widget.tripTitle)}',
              );
            },
            child: const Icon(Icons.map_outlined),
          ),

          const SizedBox(width: 12),

          FloatingActionButton(
            heroTag: 'addListButton',
            tooltip: 'Додати список',
            onPressed: _createList,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}