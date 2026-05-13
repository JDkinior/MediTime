import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PharmacyLocation {
	final String name;
	final String openingHours;
	final double latitude;
	final double longitude;
	final double distanceMeters;

	const PharmacyLocation({
		required this.name,
		required this.openingHours,
		required this.latitude,
		required this.longitude,
		required this.distanceMeters,
	});

	Map<String, dynamic> toJson() => {
				'name': name,
				'opening_hours': openingHours,
				'lat': latitude,
				'lon': longitude,
				'distance': distanceMeters,
			};

	static PharmacyLocation fromJson(Map<String, dynamic> m) {
		return PharmacyLocation(
			name: (m['name'] as String?) ?? 'Farmacia cercana',
			openingHours: (m['opening_hours'] as String?) ?? 'Horario no disponible',
			latitude: (m['lat'] as num).toDouble(),
			longitude: (m['lon'] as num).toDouble(),
			distanceMeters: (m['distance'] as num).toDouble(),
		);
	}
}

class _NearbyCacheEntry {
	final List<PharmacyLocation> results;
	final DateTime timestamp;
	_NearbyCacheEntry(this.results) : timestamp = DateTime.now();
}

class LocationHelper {
	// Simple in-memory short-lived cache to avoid repeated slow network calls
	static final Map<String, _NearbyCacheEntry> _nearbyCache = {};

	static const List<String> _overpassEndpoints = [
		'https://overpass-api.de/api/interpreter',
		'https://overpass.kumi.systems/api/interpreter',
		'https://overpass.openstreetmap.ru/api/interpreter',
	];

	// Tags to search for: pharmacies and similar shops
	static const List<List<String>> _overpassTags = [
		['amenity', 'pharmacy'],
		['shop', 'chemist'],
		['shop', 'pharmacy'],
		['shop', 'convenience'],
		['shop', 'supermarket'],
	];

	static const String _nominatimEndpoint =
			'https://nominatim.openstreetmap.org/search';

	static Future<LocationPermission> ensurePermission() async {
		final serviceEnabled = await Geolocator.isLocationServiceEnabled();
		if (!serviceEnabled) {
			return LocationPermission.denied;
		}

		var permission = await Geolocator.checkPermission();
		if (permission == LocationPermission.denied) {
			permission = await Geolocator.requestPermission();
		}

		return permission;
	}

	static Future<Position?> getCurrentPosition() async {
		final permission = await ensurePermission();
		if (permission == LocationPermission.denied ||
				permission == LocationPermission.deniedForever) {
			return null;
		}

		return Geolocator.getCurrentPosition(
			desiredAccuracy: LocationAccuracy.high,
		);
	}

	static Future<List<PharmacyLocation>> searchNearbyPharmacies(
		Position position, {
		int radiusMeters = 2000,
	}) async {
		final cacheKey =
				'${position.latitude.toStringAsFixed(3)},${position.longitude.toStringAsFixed(3)},$radiusMeters';

		// Check in-memory cache
		final cacheEntry = _nearbyCache[cacheKey];
		if (cacheEntry != null &&
				DateTime.now().difference(cacheEntry.timestamp) <
						const Duration(seconds: 60)) {
			return cacheEntry.results;
		}

		// Check persistent cache (SharedPreferences)
		try {
			final prefs = await SharedPreferences.getInstance();
			final cached = prefs.getString('nearby_cache_$cacheKey');
			if (cached != null) {
				final Map<String, dynamic> data = jsonDecode(cached) as Map<String, dynamic>;
				final ts = DateTime.fromMillisecondsSinceEpoch((data['ts'] as num).toInt());
				if (DateTime.now().difference(ts) < const Duration(minutes: 60)) {
					final items = (data['results'] as List<dynamic>).cast<Map<String, dynamic>>();
					final cachedResults = items.map(PharmacyLocation.fromJson).toList();
					_nearbyCache[cacheKey] = _NearbyCacheEntry(cachedResults);
					return cachedResults;
				}
			}
		} catch (_) {
			// ignore shared prefs errors and continue
		}

		// Build Overpass query including similar shop tags
		final buffer = StringBuffer();
		buffer.writeln('[out:json][timeout:10];');
		buffer.writeln('(');
		for (final tag in _overpassTags) {
			final k = tag[0];
			final v = tag[1];
			buffer.writeln(
					'  node["$k"="$v"](around:$radiusMeters,${position.latitude},${position.longitude});');
			buffer.writeln(
					'  way["$k"="$v"](around:$radiusMeters,${position.latitude},${position.longitude});');
			buffer.writeln(
					'  relation["$k"="$v"](around:$radiusMeters,${position.latitude},${position.longitude});');
		}
		buffer.writeln(');');
		buffer.writeln('out center tags;');
		final query = buffer.toString();

		try {
			final decoded = await _fetchOverpassJson(query);
			final elements = (decoded['elements'] as List<dynamic>? ?? const []);

			final pharmacies = _parseOverpassPharmacies(position, elements);
			if (pharmacies.isNotEmpty) {
				_nearbyCache[cacheKey] = _NearbyCacheEntry(pharmacies);
				// persist results
				try {
					final prefs = await SharedPreferences.getInstance();
					await prefs.setString('nearby_cache_$cacheKey', jsonEncode({
						'ts': DateTime.now().millisecondsSinceEpoch,
						'results': pharmacies.map((p) => p.toJson()).toList(),
					}));
				} catch (_) {}
				return pharmacies;
			}
			// If Overpass returned no results quickly, fall back to Nominatim.
		} catch (_) {
			// If Overpass queries fail or time out, fall back to Nominatim.
		}

		final nominatimResults =
				await _fetchNominatimPharmacies(position, radiusMeters: radiusMeters);
		_nearbyCache[cacheKey] = _NearbyCacheEntry(nominatimResults);
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setString('nearby_cache_$cacheKey', jsonEncode({
				'ts': DateTime.now().millisecondsSinceEpoch,
				'results': nominatimResults.map((p) => p.toJson()).toList(),
			}));
		} catch (_) {}
		return nominatimResults;
	}

	static List<PharmacyLocation> _parseOverpassPharmacies(
		Position position,
		List<dynamic> elements,
	) {
		final pharmacies = <PharmacyLocation>[];

		for (final element in elements) {
			if (element is! Map<String, dynamic>) continue;

			final tags = (element['tags'] as Map<String, dynamic>?) ?? const {};
			final name = (tags['name'] as String?)?.trim().isNotEmpty == true
					? tags['name'] as String
					: 'Farmacia cercana';
			final openingHours = (tags['opening_hours'] as String?)?.trim().isNotEmpty == true
					? tags['opening_hours'] as String
					: 'Horario no disponible';

			final center = element['center'] as Map<String, dynamic>?;
			final latitude = (element['lat'] as num?)?.toDouble() ?? (center?['lat'] as num?)?.toDouble();
			final longitude = (element['lon'] as num?)?.toDouble() ?? (center?['lon'] as num?)?.toDouble();

			if (latitude == null || longitude == null) continue;

			pharmacies.add(PharmacyLocation(
				name: name,
				openingHours: openingHours,
				latitude: latitude,
				longitude: longitude,
				distanceMeters: Geolocator.distanceBetween(
					position.latitude,
					position.longitude,
					latitude,
					longitude,
				),
			));
		}

		pharmacies.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
		return pharmacies;
	}

	static Future<List<PharmacyLocation>> _fetchNominatimPharmacies(
		Position position, {
		required int radiusMeters,
	}) async {
		final deltaLat = radiusMeters / 111000;
		final safeLatitude = position.latitude.abs().clamp(0.1, 89.9);
		final latitudeRadians = safeLatitude * math.pi / 180;
		final deltaLon = radiusMeters / (111000 * math.cos(latitudeRadians));

		final queryParameters = <String, String>{
			'format': 'jsonv2',
			'q': 'pharmacy',
			'limit': '25',
			'bounded': '1',
			'viewbox':
					'${position.longitude - deltaLon},${position.latitude + deltaLat},${position.longitude + deltaLon},${position.latitude - deltaLat}',
			'addressdetails': '1',
			'extratags': '1',
		};

		final response = await http
				.get(
					Uri.parse(_nominatimEndpoint).replace(queryParameters: queryParameters),
					headers: {
						'Accept': 'application/json',
						'User-Agent': 'MediTime/1.0 (Flutter app)',
					},
				)
				.timeout(const Duration(seconds: 8));

		if (response.statusCode != 200) {
			throw Exception('Nominatim respondió con HTTP ${response.statusCode}');
		}

		final decoded = jsonDecode(response.body);
		if (decoded is! List<dynamic>) {
			throw Exception('Respuesta inválida de Nominatim');
		}

		final pharmacies = <PharmacyLocation>[];
		for (final item in decoded) {
			if (item is! Map<String, dynamic>) continue;

			final latitude = double.tryParse(item['lat']?.toString() ?? '');
			final longitude = double.tryParse(item['lon']?.toString() ?? '');
			if (latitude == null || longitude == null) continue;

			final distanceMeters = Geolocator.distanceBetween(
				position.latitude,
				position.longitude,
				latitude,
				longitude,
			);

			if (distanceMeters > radiusMeters) continue;

			final displayName = (item['display_name'] as String?) ?? 'Farmacia cercana';
			final name = displayName.split(',').first.trim().isNotEmpty
					? displayName.split(',').first.trim()
					: 'Farmacia cercana';
			final openingHours =
					(item['extratags'] as Map<String, dynamic>?)?['opening_hours']?.toString() ?? 'Horario no disponible';

			pharmacies.add(PharmacyLocation(
				name: name,
				openingHours: openingHours,
				latitude: latitude,
				longitude: longitude,
				distanceMeters: distanceMeters,
			));
		}

		pharmacies.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
		return pharmacies;
	}

	static Future<Map<String, dynamic>> _fetchOverpassJson(String query) async {
		// Send requests to all endpoints in parallel and return the first successful
		// decoded Map. This reduces wait time when some Overpass mirrors are slow.
		final futures = _overpassEndpoints.map((endpoint) async {
			final response = await http
					.post(
						Uri.parse(endpoint),
						headers: {'Content-Type': 'application/x-www-form-urlencoded'},
						body: {'data': query},
					)
					.timeout(const Duration(seconds: 8));

			if (response.statusCode != 200) {
				throw Exception('HTTP ${response.statusCode} from $endpoint');
			}

			final decoded = jsonDecode(response.body);
			if (decoded is Map<String, dynamic>) return decoded;

			throw Exception('Respuesta inválida de Overpass from $endpoint');
		}).toList();

		try {
			return await Future.any(futures);
		} catch (e) {
			// If all parallel attempts fail, surface the error to the caller.
			throw Exception('No se pudieron cargar las farmacias cercanas. Último error: $e');
		}
	}

	static String formatDistance(double meters) {
		if (meters < 1000) {
			return '${meters.round()} m';
		}

		return '${(meters / 1000).toStringAsFixed(1)} km';
	}
}

