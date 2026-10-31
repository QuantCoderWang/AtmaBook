import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../data/models/map_source.dart';
import '../../l10n/app_localizations.dart';

/// 在地图上重新选点：
/// 点按地图即移动十字准星，底部显示实时坐标；确认返回 LatLng、取消返回 null
class PickPointPage extends StatefulWidget {
  const PickPointPage({super.key, required this.initial, required this.source});

  final LatLng initial;
  final MapSource source;

  @override
  State<PickPointPage> createState() => _PickPointPageState();
}

class _PickPointPageState extends State<PickPointPage> {
  late LatLng _point = widget.initial;
  final MapController _map = MapController();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(t.pickPointTitle)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 16,
              onTap: (_, point) => setState(() => _point = point),
            ),
            children: [
              TileLayer(
                urlTemplate: widget.source.urlTemplate,
                subdomains: widget.source.subdomains,
                userAgentPackageName: 'com.example.atma_book',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _point,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.trip_origin,
                        size: 40, color: Color(0xCC00695C)),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_point.latitude.toStringAsFixed(6)}, '
                  '${_point.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12.5),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, null),
            child: Text(t.cancel),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 17),
            label: Text(t.pickConfirm),
            onPressed: () => Navigator.pop(context, _point),
          ),
        ],
      ),
    );
  }
}
