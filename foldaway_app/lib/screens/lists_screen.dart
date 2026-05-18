import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../models/trip_list.dart';
import '../theme/app_theme.dart';

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
    final titleController = TextEditingController();
    String selectedIcon = '🍽️';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('НОВИЙ СПИСОК'),
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
                            child: Text(
                              icon,
                              style: const TextStyle(fontSize: 23),
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

                    if (title.isEmpty) return;

                    final list = await _apiService.createList(
                      widget.tripId,
                      title,
                      selectedIcon,
                    );

                    if (list != null && mounted) {
                      Navigator.pop(dialogContext);
                      _loadLists();
                    }
                  },
                  child: const Text('СТВОРИТИ'),
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
    await _apiService.deleteList(id);
    _loadLists();
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
                        border: Border.all(color: FoldawayColors.line),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: Text(
                          list.icon,
                          style: const TextStyle(fontSize: 30),
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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteList(list.id.toString()),
                        ),
                        onTap: () => context.go(
                          '/trips/${widget.tripId}/lists/${list.id}',
                          extra: list.title,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createList,
        child: const Icon(Icons.add),
      ),
    );
  }
}