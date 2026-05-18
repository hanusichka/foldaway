import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final items = await _apiService.getItems(widget.listId);
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _createItem() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новий пункт'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Назва',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Опис (необовʼязково)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () async {
              final item = await _apiService.createItem(
                widget.listId,
                titleController.text,
                descriptionController.text,
              );
              if (item != null && context.mounted) {
                Navigator.pop(context);
                _loadItems();
              }
            },
            child: const Text('Додати'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleItem(ListItem item) async {
    await _apiService.toggleItem(item.id, !item.isDone);
    _loadItems();
  }

  Future<void> _deleteItem(String id) async {
    await _apiService.deleteItem(id);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final done = _items.where((i) => i.isDone).length;
    final total = _items.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/trips'),
        ),
        bottom: total > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: done / total,
                  backgroundColor: Colors.grey.shade200,
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text(
                    'Список порожній.\nДодай перший пункт! ✍️',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Checkbox(
                          value: item.isDone,
                          onChanged: (_) => _toggleItem(item),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            decoration: item.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: item.isDone ? Colors.grey : null,
                          ),
                        ),
                        subtitle: item.description.isNotEmpty
                            ? Text(item.description)
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteItem(item.id),
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