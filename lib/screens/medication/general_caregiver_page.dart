import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';

class GeneralCaregiverPage extends StatefulWidget {
  const GeneralCaregiverPage({super.key});

  @override
  State<GeneralCaregiverPage> createState() => _GeneralCaregiverPageState();
}

class _GeneralCaregiverPageState extends State<GeneralCaregiverPage> {
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Todos';
  Stream<List<List<Map<String, dynamic>>>>? _combinedStream;
  List<CaregiverProfile>? _lastProfiles;

  bool _esHoy(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _updateStreamIfNeeded(String userId, List<CaregiverProfile> profiles, FirestoreService firestoreService) {
    if (_lastProfiles != null && _lastProfiles!.length == profiles.length && _combinedStream != null) {
      bool same = true;
      for (int i = 0; i < profiles.length; i++) {
        if (_lastProfiles![i].id != profiles[i].id) {
          same = false;
          break;
        }
      }
      if (same) return; // Same profiles, no need to recreate stream
    }

    _lastProfiles = List.from(profiles);
    if (profiles.isEmpty) {
      _combinedStream = null;
      return;
    }

    List<Stream<List<Map<String, dynamic>>>> streams = profiles.map((profile) {
      return firestoreService.getMedicamentosStream(userId, profile).map((tratamientos) {
        return tratamientos.map((t) => {
          'tratamiento': t,
          'profile': profile,
        }).toList();
      });
    }).toList();

    _combinedStream = _combineLatest(streams);
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final user = authService.currentUser;
    final profiles = caregiverNotifier.managedProfiles;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para ver las recetas.')),
      );
    }

    if (profiles.isEmpty) {
      return const EstadoVista(
        state: ViewState.empty,
        emptyMessage: 'No tienes pacientes asignados. Agrega uno desde el menú desplegable.',
        child: SizedBox.shrink(),
      );
    }

    // Formatear fecha seleccionada
    final rawDate = DateFormat("EEEE, d 'de' MMMM", 'es_ES').format(_selectedDate);
    final formattedDate = rawDate.substring(0, 1).toUpperCase() + rawDate.substring(1);

    _updateStreamIfNeeded(user.uid, profiles, firestoreService);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<List<Map<String, dynamic>>>>(
        stream: _combinedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
          }
          if (snapshot.hasError) {
            return EstadoVista(
              state: ViewState.error,
              errorMessage: 'Ocurrió un error al cargar las recetas.',
              onRetry: () => setState(() {}),
              child: const SizedBox.shrink(),
            );
          }
          if (!snapshot.hasData) {
            return const EstadoVista(
              state: ViewState.empty,
              emptyMessage: 'No hay datos disponibles.',
              child: SizedBox.shrink(),
            );
          }

          final List<Map<String, dynamic>> allItems = snapshot.data!.expand((x) => x).toList();
          final hoyDosis = _obtenerDosisDelDia(allItems, _selectedDate);

          Widget datePill = GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                locale: const Locale('es', 'ES'),
              );
              if (picked != null && picked != _selectedDate) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppTheme.secondaryTextColor,
                  ),
                ],
              ),
            ),
          );

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vista General',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Medicamentos de todos los pacientes',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  datePill,
                  const SizedBox(height: 16),
                  _buildCategoryFilter(profiles),
                ],
              ),
              const SizedBox(height: 24),
              
              Text(
                _esHoy(_selectedDate) ? 'Próximas dosis (Todos)' : 'Dosis del día (Todos)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 16),

              if (hoyDosis.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      _esHoy(_selectedDate)
                          ? 'No hay dosis programadas para hoy en ningún paciente.'
                          : 'No hay dosis programadas para este día en ningún paciente.',
                      style: TextStyle(color: AppTheme.secondaryTextColor),
                    ),
                  ),
                )
              else
                Column(
                  children: List.generate(hoyDosis.length, (index) {
                    final dose = hoyDosis[index];
                    final isFirst = index == 0;
                    final isLast = index == hoyDosis.length - 1;
                    return _buildTimelineRow(dose, isFirst, isLast);
                  }),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilter(List<CaregiverProfile> profiles) {
    // Extract unique categories
    final Set<String> categories = {'Todos'};
    for (var p in profiles) {
      if (p.category != null && p.category!.isNotEmpty) {
        categories.add(p.category!);
      }
    }
    
    // Si solo existe 'Todos', no mostramos los filtros
    if (categories.length == 1) return const SizedBox.shrink();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                }
              },
              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              backgroundColor: AppTheme.surfaceColor,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _obtenerDosisDelDia(List<Map<String, dynamic>> allItems, DateTime date) {
    final List<Map<String, dynamic>> hoyDosis = [];
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    for (var item in allItems) {
      final Tratamiento tratamiento = item['tratamiento'];
      final CaregiverProfile profile = item['profile'];
      
      // Aplicar filtro de categoría
      if (_selectedCategory != 'Todos') {
        if (profile.category != _selectedCategory) {
          continue; // Saltar si no coincide la categoría
        }
      }
      
      tratamiento.doseStatus.forEach((dateString, status) {
        final doseTime = DateTime.parse(dateString);
        if (!doseTime.isBefore(startOfDay) && !doseTime.isAfter(endOfDay)) {
          hoyDosis.add({
            'tratamiento': tratamiento,
            'profile': profile,
            'doseTime': doseTime,
            'status': status,
          });
        }
      });
    }

    hoyDosis.sort((a, b) => (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));
    return hoyDosis;
  }

  Widget _buildTimelineRow(Map<String, dynamic> doseInfo, bool isFirst, bool isLast) {
    final Tratamiento tratamiento = doseInfo['tratamiento'];
    final CaregiverProfile profile = doseInfo['profile'];
    final DateTime doseTime = doseInfo['doseTime'];
    final DoseStatus status = doseInfo['status'];
    
    final bool isCompleted = status == DoseStatus.tomada;
    final bool isOmitted = status == DoseStatus.omitida;
    final bool isSkipped = status == DoseStatus.aplazada;
    final bool isNotified = status == DoseStatus.notificada;
    final bool isPending = status == DoseStatus.pendiente;
    final bool isPast = doseTime.isBefore(DateTime.now()) && !isCompleted && !isOmitted;
    
    Color statusColor;
    if (isCompleted) {
      statusColor = AppTheme.successColor;
    } else if (isOmitted) {
      statusColor = Colors.grey;
    } else if (isPast || isSkipped) {
      statusColor = Colors.orange;
    } else if (isNotified) {
      statusColor = AppTheme.primaryColor;
    } else {
      statusColor = const Color(0xFFC3C6D7);
    }
    
    final patientColor = Color(int.parse(profile.colorHex.replaceFirst('#', 'FF'), radix: 16));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('hh:mm').format(doseTime),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                Text(
                  DateFormat('a').format(doseTime),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: isFirst ? Colors.transparent : AppTheme.borderColor,
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? statusColor : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : AppTheme.borderColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: GestureDetector(
                onTap: () {
                  if (status == DoseStatus.pendiente || status == DoseStatus.notificada || status == DoseStatus.aplazada) {
                    _showMarkAsTakenDialog(context, tratamiento, profile, doseTime);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.successColor.withOpacity(0.05) : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCompleted ? AppTheme.successColor.withOpacity(0.3) : AppTheme.borderColor,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              tratamiento.nombreMedicamento,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? AppTheme.successColor : AppTheme.primaryTextColor,
                                decoration: isOmitted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: patientColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              profile.name,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: patientColor),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dosis: ${tratamiento.dosisPorToma} ${tratamiento.presentacion}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                      if (profile.roomNumber != null || profile.bloodType != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              if (profile.roomNumber != null)
                                _buildBadge(Icons.hotel, 'Hab: ${profile.roomNumber}'),
                              if (profile.bloodType != null)
                                _buildBadge(Icons.bloodtype, profile.bloodType!),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showMarkAsTakenDialog(BuildContext context, Tratamiento tratamiento, CaregiverProfile profile, DateTime doseTime) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirmar dosis'),
          content: Text('¿Marcar la dosis de ${tratamiento.nombreMedicamento} de ${profile.name} como tomada?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final authService = context.read<AuthService>();
                final firestoreService = context.read<FirestoreService>();
                if (authService.currentUser != null) {
                  await firestoreService.updateDoseStatus(
                    authService.currentUser!.uid,
                    tratamiento.id,
                    doseTime,
                    DoseStatus.tomada,
                    profile,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosis marcada como tomada.')));
                  }
                }
              },
              child: const Text('Marcar como tomada'),
            ),
          ],
        );
      }
    );
  }
}

// A simple manual stream combiner since we don't have rxdart
Stream<List<T>> _combineLatest<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) {
    return Stream.value([]);
  }
  
  late StreamController<List<T>> controller;
  List<T?> currentValues = List.filled(streams.length, null);
  List<bool> hasValue = List.filled(streams.length, false);
  
  controller = StreamController<List<T>>.broadcast(
    onListen: () {
      int completed = 0;
      List<dynamic> subscriptions = [];
      
      for (int i = 0; i < streams.length; i++) {
        subscriptions.add(streams[i].listen(
          (value) {
            currentValues[i] = value;
            hasValue[i] = true;
            if (!hasValue.contains(false)) {
              controller.add(List<T>.from(currentValues));
            }
          },
          onError: controller.addError,
          onDone: () {
            completed++;
            if (completed == streams.length) {
              controller.close();
            }
          },
        ));
      }
      
      controller.onCancel = () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
      };
    },
  );
  
  return controller.stream;
}
