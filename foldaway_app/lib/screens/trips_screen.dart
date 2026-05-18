import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../models/trip.dart';
import '../theme/app_theme.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final _apiService = ApiService();

  List<Trip> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final trips = await _apiService.getTrips();

      if (!mounted) return;

      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка завантаження подорожей: $e'),
        ),
      );

      debugPrint('TRIPS LOAD ERROR: $e');
    }
  }

  Widget _imagePreview(String url) {
    return Container(
      height: 95,
      width: double.infinity,
      decoration: BoxDecoration(
        color: FoldawayColors.white,
        border: Border.all(color: FoldawayColors.line),
      ),
      clipBehavior: Clip.hardEdge,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;

          return Center(
            child: Text(
              'Завантаження фото...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FoldawayColors.muted,
                  ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Фото не завантажилось.\nВстав пряме посилання на .jpg / .png / .webp',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FoldawayColors.muted,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tripCoverImage(Trip trip) {
    return Container(
      height: 115,
      width: double.infinity,
      decoration: BoxDecoration(
        color: FoldawayColors.white,
        border: Border(
          top: BorderSide(color: FoldawayColors.line),
          left: BorderSide(color: FoldawayColors.line),
          right: BorderSide(color: FoldawayColors.line),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Image.network(
        trip.coverImageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;

          return Center(
            child: Text(
              'Завантаження фото...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FoldawayColors.muted,
                  ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              'Фото недоступне',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FoldawayColors.muted,
                  ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createTrip() async {
    await _showTripDialog();
  }

Future<void> _showTripDialog({Trip? existingTrip}) async {
  final titleController = TextEditingController(
    text: existingTrip?.title ?? '',
  );

  final destinationController = TextEditingController(
    text: existingTrip?.destination ?? '',
  );

  final imageController = TextEditingController(
    text: existingTrip?.coverImageUrl ?? '',
  );

  final bool isEditing = existingTrip != null;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final previewUrl = imageController.text.trim();

          return AlertDialog(
            title: Text(isEditing ? 'РЕДАГУВАТИ ПОДОРОЖ' : 'НОВА ПОДОРОЖ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Назва',
                      hintText: 'Наприклад: Рим 2026',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: destinationController,
                    decoration: const InputDecoration(
                      labelText: 'Країна / місто',
                      hintText: 'Наприклад: Italy, Rome',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(
                      labelText: 'Фото міста',
                      hintText: 'Встав прямий URL картинки',
                    ),
                    onChanged: (_) {
                      setDialogState(() {});
                    },
                  ),
                  if (previewUrl.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _imagePreview(previewUrl),
                  ],
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
                  final destination = destinationController.text.trim();
                  final imageUrl = imageController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Введи назву подорожі'),
                      ),
                    );
                    return;
                  }

                  Trip? result;

                  if (isEditing) {
                    result = await _apiService.updateTrip(
                      existingTrip.id,
                      title,
                      destination,
                      imageUrl.isEmpty ? null : imageUrl,
                    );
                  } else {
                    result = await _apiService.createTrip(
                      title,
                      destination,
                      imageUrl.isEmpty ? null : imageUrl,
                    );
                  }

                  if (!mounted) return;

                  if (result != null) {
                    Navigator.pop(dialogContext);
                    await _loadTrips();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing
                              ? 'Не вдалося оновити подорож'
                              : 'Не вдалося створити подорож',
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
  destinationController.dispose();
  imageController.dispose();
}
  Future<void> _deleteTrip(String id) async {
    final success = await _apiService.deleteTrip(id);

    if (!mounted) return;

    if (success) {
      await _loadTrips();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не вдалося видалити подорож'),
        ),
      );
    }
  }

  bool _hasImage(Trip trip) {
    return trip.coverImageUrl != null && trip.coverImageUrl!.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoldawayColors.paper,
      appBar: AppBar(
        title: const Text('FOLDAWAY'),
        actions: [
          IconButton(
            tooltip: 'Вийти',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _apiService.clearToken();

              if (!mounted) return;

              context.go('/');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NO TRIPS',
                          style: Theme.of(context).textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Створи першу подорож',
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
                  itemCount: _trips.length,
                  itemBuilder: (context, index) {
                    final trip = _trips[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_hasImage(trip)) _tripCoverImage(trip),
                          Container(
                            decoration: BoxDecoration(
                              color: FoldawayColors.white,
                              border: Border.all(
                                color: FoldawayColors.line,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              leading: const Icon(
                                Icons.folder_outlined,
                                size: 34,
                              ),
                              title: Text(
                                trip.title.toUpperCase(),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              subtitle: Text(
                                trip.destination.trim().isEmpty
                                    ? 'NO DESTINATION'
                                    : trip.destination.toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
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
                                      _showTripDialog(existingTrip: trip);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Видалити',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteTrip(trip.id),
                                  ),
                                ],
                              ),
                              onTap: () => context.go(
                                '/trips/${trip.id}?title=${Uri.encodeComponent(trip.title)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTrip,
        child: const Icon(Icons.add),
      ),
    );
  }
}