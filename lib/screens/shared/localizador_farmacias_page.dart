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

  Future<bool> _showLocationDisclosureDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on_outlined, color: Theme.of(ctx).primaryColor),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Uso de Ubicación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'MediTime solicita acceso a la ubicación de tu dispositivo mientras usas el Localizador de Farmacias para:',
                  style: TextStyle(fontSize: 13.5, height: 1.35),
                ),
                SizedBox(height: 10),
                Text(
                  '• Detectar tu posición actual y posicionarte en el mapa.\n'
                  '• Buscar y calcular la distancia hacia farmacias, boticas y centros de salud cercanos.',
                  style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                Text(
                  '🔒 Compromiso de Privacidad:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '• Tu ubicación no se almacena en nuestros servidores ni en bases de datos externas.\n'
                  '• No se recopila ubicación en segundo plano.\n'
                  '• No se comparte con redes publicitarias ni terceros.',
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Ahora no'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Entendido y Continuar'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _loadPharmacies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Los servicios de ubicación (GPS) están desactivados en tu dispositivo. Por favor actívalos.';
          _isLoading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        final accepted = await _showLocationDisclosureDialog();
        if (!accepted) {
          if (!mounted) return;
          setState(() {
            _errorMessage =
                'Se requiere permiso de ubicación para mostrarte farmacias cercanas.';
            _isLoading = false;
          });
          return;
        }
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Activa el permiso de ubicación para buscar farmacias cercanas.';
          _isLoading = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'El permiso de ubicación fue denegado permanentemente. Actívalo desde ajustes.';
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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
      debugPrint('Map annotation error: $e');
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
