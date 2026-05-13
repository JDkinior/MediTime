import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meditime/core/location_helper.dart';

class LocalizadorFarmaciasPage extends StatefulWidget {
  const LocalizadorFarmaciasPage({super.key});

  @override
  State<LocalizadorFarmaciasPage> createState() =>
      _LocalizadorFarmaciasPageState();
}

class _LocalizadorFarmaciasPageState extends State<LocalizadorFarmaciasPage> {
  MapLibreMapController? _mapController;
  Position? _userPosition;
  List<PharmacyLocation> _pharmacies = [];
  bool _isLoading = true;
  bool _isStyleLoaded = false;
  String? _errorMessage;
  int _radiusMeters = 2000;

  static const String _mapStyleJson = '''
{
  "version": 8,
  "name": "OpenStreetMap",
  "sources": {
    "osm": {
      "type": "raster",
      "tiles": ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      "tileSize": 256,
      "attribution": "© OpenStreetMap contributors"
    }
  },
  "layers": [
    {
      "id": "osm",
      "type": "raster",
      "source": "osm",
      "minzoom": 0,
      "maxzoom": 19
    }
  ]
}
''';

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
  }

  Future<void> _loadPharmacies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final permission = await LocationHelper.ensurePermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage =
              'Activa el permiso de ubicación para buscar farmacias cercanas.';
          _isLoading = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'El permiso de ubicación fue denegado permanentemente. Actívalo desde ajustes.';
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final pharmacies = await LocationHelper.searchNearbyPharmacies(
        position,
        radiusMeters: _radiusMeters,
      );

      if (!mounted) return;
      setState(() {
        _userPosition = position;
        _pharmacies = pharmacies;
        _isLoading = false;
      });

      await _syncMapAnnotations();
      await _moveCameraTo(position.latitude, position.longitude, zoom: 14.5);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No fue posible cargar el localizador: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncMapAnnotations() async {
    await _syncMapAnnotationsInternal(retries: 3);
  }

  Future<void> _syncMapAnnotationsInternal({int retries = 0}) async {
    if (_mapController == null || !_isStyleLoaded) return;

    try {
      await _mapController!.clearCircles();

      if (_userPosition != null) {
        await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(
              _userPosition!.latitude,
              _userPosition!.longitude,
            ),
            circleRadius: 10,
            circleColor: '#1E88E5',
            circleOpacity: 0.95,
            circleStrokeWidth: 3,
            circleStrokeColor: '#FFFFFF',
            circleStrokeOpacity: 1,
          ),
        );
      }

      for (final pharmacy in _pharmacies) {
        await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(pharmacy.latitude, pharmacy.longitude),
            circleRadius: 8,
            circleColor: '#2F6DB4',
            circleOpacity: 0.9,
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
            circleStrokeOpacity: 1,
          ),
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (retries > 0 && msg.contains('Annotation Manager has not been initialized')) {
        await Future.delayed(const Duration(milliseconds: 250));
        return _syncMapAnnotationsInternal(retries: retries - 1);
      }
      // Log and swallow errors to avoid crashing UI
      // ignore: avoid_print
      print('Map annotation error: $e');
    }
  }

  Future<void> _openInMaps(double latitude, double longitude, String name) async {
    final encodedName = Uri.encodeComponent(name);
    final googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude&query_place_id=$encodedName');

    try {
      if (!await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la aplicación de mapas.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la aplicación de mapas.')),
      );
    }
  }

  Future<void> _moveCameraTo(
    double latitude,
    double longitude, {
    double zoom = 14,
  }) async {
    final controller = _mapController;
    if (controller == null) return;

    final update = CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(latitude, longitude), zoom: zoom),
    );

    try {
      await controller.animateCamera(update);
    } on MissingPluginException {
      // Some builds may not expose camera#animate on the platform channel.
      try {
        await controller.moveCamera(update);
      } catch (_) {
        // ignore camera movement failures so data/list still works
      }
    } catch (_) {
      // ignore camera movement failures so data/list still works
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    // Small delay to let native annotation managers initialize.
    Future.delayed(const Duration(milliseconds: 200), () async {
      _isStyleLoaded = true;
      await _syncMapAnnotationsInternal(retries: 3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialPosition =
        _userPosition == null
            ? const LatLng(4.7110, -74.0721)
            : LatLng(_userPosition!.latitude, _userPosition!.longitude);

    return Scaffold(
      appBar: AppBar(title: const Text('Localizador de Farmacias')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorState()
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        const Text('Radio:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider.adaptive(
                            min: 500,
                            max: 5000,
                            divisions: 9,
                            value: _radiusMeters.toDouble(),
                            label: '${(_radiusMeters / 1000).toStringAsFixed(1)} km',
                            onChanged: (v) => setState(() => _radiusMeters = v.round()),
                            onChangeEnd: (_) => _loadPharmacies(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${_radiusMeters} m'),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                      child: MapLibreMap(
                        styleString: _mapStyleJson,
                        initialCameraPosition: CameraPosition(
                          target: initialPosition,
                          zoom: 14.5,
                        ),
                        onMapCreated: _onMapCreated,
                        onStyleLoadedCallback: _onStyleLoaded,
                        myLocationEnabled: true,
                        myLocationTrackingMode: MyLocationTrackingMode.tracking,
                        compassEnabled: true,
                        zoomGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                      ),
                    ),
                  ),
                  Expanded(flex: 2, child: _buildPharmacyList()),
                ],
              ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 56,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'No se pudo cargar el mapa.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: _loadPharmacies,
                  child: const Text('Reintentar'),
                ),
                OutlinedButton(
                  onPressed: () => Geolocator.openAppSettings(),
                  child: const Text('Abrir ajustes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPharmacyList() {
    if (_pharmacies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No se encontraron farmacias dentro del radio seleccionado.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Farmacias encontradas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _pharmacies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final pharmacy = _pharmacies[index];
                        return InkWell(
                          onTap:
                              () => _moveCameraTo(
                                pharmacy.latitude,
                                pharmacy.longitude,
                                zoom: 16,
                              ),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F8FC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.local_pharmacy_outlined,
                          color: Color(0xFF2F6DB4),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pharmacy.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pharmacy.openingHours,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                LocationHelper.formatDistance(
                                  pharmacy.distanceMeters,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2F6DB4),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                                IconButton(
                                  icon: const Icon(Icons.directions),
                                  onPressed: () => _openInMaps(
                                    pharmacy.latitude,
                                    pharmacy.longitude,
                                    pharmacy.name,
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
