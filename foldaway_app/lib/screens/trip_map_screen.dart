import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/list_item.dart';
import '../models/trip_list.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';

class TripMapScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;

  const TripMapScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final _apiService = ApiService();

  List<ListItem> _items = [];
  Map<String, TripList> _listsById = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMapItems();
  }

  Future<void> _loadMapItems() async {
    try {
      final lists = await _apiService.getLists(widget.tripId);
      final items = await _apiService.getItemsByTrip(widget.tripId);

      final mappedLists = <String, TripList>{
        for (final list in lists) list.id.toString(): list,
      };

      if (!mounted) return;

      setState(() {
        _listsById = mappedLists;
        _items = items
            .where((item) => item.latitude != null && item.longitude != null)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка завантаження карти: $e'),
        ),
      );
    }
  }

  TripList? _getParentList(ListItem item) {
    return _listsById[item.listId.toString()];
  }

  Future<void> _openMapLink(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null || !uri.hasScheme) return;

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  LatLng _initialCenter() {
    if (_items.isNotEmpty) {
      return LatLng(_items.first.latitude!, _items.first.longitude!);
    }

    return const LatLng(48.8566, 2.3522);
  }

  void _showItemInfo(ListItem item) {
    final parentList = _getParentList(item);

    showModalBottomSheet(
      context: context,
      backgroundColor: FoldawayColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FoldawayColors.paper,
            border: Border.all(color: FoldawayColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (parentList != null) ...[
                Row(
                  children: [
                    CategoryIcon(
                      icon: parentList.icon,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      parentList.title.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: FoldawayColors.muted,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                item.title.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FoldawayColors.muted,
                      ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'LAT: ${item.latitude}, LNG: ${item.longitude}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: FoldawayColors.muted,
                    ),
              ),
              if (item.externalLink.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => _openMapLink(item.externalLink),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('ВІДКРИТИ В GOOGLE MAPS'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Marker> _buildMarkers() {
  return _items.map((item) {
    final parentList = _getParentList(item);
    final listIcon = parentList?.icon ?? item.mapSymbol;
    final markerIcon = listIcon.isEmpty ? '📍' : listIcon;

    final isVisited = item.isDone;

      return Marker(
        point: LatLng(item.latitude!, item.longitude!),
        width: 56,
        height: 56,
        child: GestureDetector(
          onTap: () => _showItemInfo(item),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isVisited ? FoldawayColors.rust : FoldawayColors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isVisited ? FoldawayColors.rust : FoldawayColors.ink,
                width: 1.4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: CategoryIcon(
              icon: markerIcon,
              size: 26,
              //color: isVisited ? Colors.white : FoldawayColors.ink,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoldawayColors.paper,
      appBar: AppBar(
        title: Text('${widget.tripTitle.toUpperCase()} MAP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go(
              '/trips/${widget.tripId}?title=${Uri.encodeComponent(widget.tripTitle)}',
            );
          },
        ),
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
                          'NO MAP POINTS',
                          style: Theme.of(context).textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Додай Google Maps посилання до пунктів списку, щоб вони зʼявилися на карті.',
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
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: _initialCenter(),
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.foldaway_app',
                    ),
                    MarkerLayer(
                      markers: _buildMarkers(),
                    ),
                  ],
                ),
    );
  }
}