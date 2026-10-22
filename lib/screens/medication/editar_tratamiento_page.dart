import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/models/treatment_form_data.dart';
import 'package:meditime/notifiers/treatment_form_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/gemini_service.dart';
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/widgets/drug_interaction_dialog.dart';
import 'package:meditime/widgets/pill_icon.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

/// Pantalla personalizada y concisa para la edición completa del tratamiento.
/// Muestra las dosis del medicamento en una lista visual con la estética de la app.
class EditarTratamientoPage extends StatefulWidget {
  final Tratamiento tratamiento;
  final CaregiverProfile? profile;

  const EditarTratamientoPage({
    super.key,
    required this.tratamiento,
    this.profile,
  });

  @override
  State<EditarTratamientoPage> createState() => _EditarTratamientoPageState();
}

class _EditarTratamientoPageState extends State<EditarTratamientoPage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  late final TextEditingController _nombreController;
  late final TextEditingController _notasController;
  late final TextEditingController _cantidadActualController;
  late final TextEditingController _cantidadTotalController;
  late final TextEditingController _duracionController;
  late final TextEditingController _customIntervalController;

  // Estado del tratamiento
  late String _presentacion;
  late int _dosisPorToma;
  late int _intervaloHoras;
  late TimeOfDay _horaPrimeraDosis;
  late int _duracionNumero;
  late DurationUnit _duracionUnidad;
  late bool _esIndefinido;
  late bool _hasInventario;
  bool _isCustomInterval = false;
  bool _isSaving = false;

  // Lista de presentaciones farmacéuticas estándar
  static const List<String> _presentacionesBase = [
    'Comprimidos',
    'Cápsulas',
    'Grageas',
    'Sobres',
    'Jarabes',
    'Gotas',
    'Suspensiones',
    'Emulsiones',
    'Inyección',
    'Inhalador',
    'Pomada',
    'Parches',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.tratamiento;
    final formData = TreatmentFormData.fromTratamiento(t);

    _nombreController = TextEditingController(text: t.nombreMedicamento);
    _notasController = TextEditingController(text: t.notas);
    _cantidadActualController = TextEditingController(
      text: t.cantidadActual > 0 ? t.cantidadActual.toString() : '',
    );
    _cantidadTotalController = TextEditingController(
      text: t.cantidadTotalCaja > 0 ? t.cantidadTotalCaja.toString() : '',
    );
    _duracionController = TextEditingController(
      text: formData.duracionNumero.toString(),
    );

    _presentacion = t.presentacion.isNotEmpty ? t.presentacion : 'Comprimidos';
    _dosisPorToma = t.dosisPorToma > 0 ? t.dosisPorToma : 1;
    _intervaloHoras =
        t.intervaloDosis.inHours > 0 ? t.intervaloDosis.inHours : 8;
    _horaPrimeraDosis = t.horaPrimeraDosis;
    _duracionNumero = formData.duracionNumero > 0 ? formData.duracionNumero : 7;
    _duracionUnidad = formData.duracionUnidad;
    _esIndefinido = formData.esIndefinido;
    _hasInventario = t.hasInventarioConfigurado;

    final standardIntervals = [4, 6, 8, 12, 24];
    _isCustomInterval = !standardIntervals.contains(_intervaloHoras);
    _customIntervalController = TextEditingController(
      text: _isCustomInterval ? _intervaloHoras.toString() : '',
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _notasController.dispose();
    _cantidadActualController.dispose();
    _cantidadTotalController.dispose();
    _duracionController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  List<String> get _availablePresentations {
    final list = List<String>.from(_presentacionesBase);
    if (_presentacion.isNotEmpty && !list.contains(_presentacion)) {
      list.insert(0, _presentacion);
    }
    return list;
  }

  /// Calcula las dosis del día según la primera toma y el intervalo de horas
  List<TimeOfDay> _calculateDoseSchedule() {
    if (_intervaloHoras <= 0) return [_horaPrimeraDosis];
    final dosesPerDay = (24 / _intervaloHoras).floor().clamp(1, 24);
    final List<TimeOfDay> schedule = [];
    DateTime cur = DateTime(
      2026,
      1,
      1,
      _horaPrimeraDosis.hour,
      _horaPrimeraDosis.minute,
    );
    for (int i = 0; i < dosesPerDay; i++) {
      schedule.add(TimeOfDay(hour: cur.hour, minute: cur.minute));
      cur = cur.add(Duration(hours: _intervaloHoras));
    }
    return schedule;
  }

  /// Al seleccionar una hora para una dosis específica, recalcula la pauta general
  Future<void> _onPickDoseTime(int index, TimeOfDay initialTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (index == 0) {
          _horaPrimeraDosis = picked;
        } else {
          // Desplaza la primera toma para que la dosis seleccionada caiga a la hora elegida
          int desiredMinutes = picked.hour * 60 + picked.minute;
          int offsetMinutes = index * _intervaloHoras * 60;
          int baseMinutes = desiredMinutes - offsetMinutes;
          baseMinutes = ((baseMinutes % 1440) + 1440) % 1440;
          _horaPrimeraDosis = TimeOfDay(
            hour: baseMinutes ~/ 60,
            minute: baseMinutes % 60,
          );
        }
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Horario ajustado. Primera toma programada a las ${AppUtils.formatDoseTimeOfDay(_horaPrimeraDosis)}.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<bool> _checkAndWarnDrugInteractions(String newDrugName) async {
    if (newDrugName.trim().isEmpty) return true;
    if (newDrugName.trim().toLowerCase() ==
        widget.tratamiento.nombreMedicamento.trim().toLowerCase()) {
      return true;
    }

    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      if (userId == null) return true;

      final treatmentRepo = context.read<TreatmentRepository>();
      final geminiService = context.read<GeminiService>();
      final result = await treatmentRepo.getTreatments(userId);
      if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
        return true;
      }

      final activeTreatments =
          result.data!
              .where(
                (t) =>
                    (t.isActivo || !t.isFinalizado) &&
                    t.id != widget.tratamiento.id,
              )
              .toList();

      if (activeTreatments.isEmpty) return true;

      final checkResult = await geminiService.checkDrugInteractions(
        newDrugName: newDrugName,
        activeTreatments: activeTreatments,
      );

      if (checkResult['hasInteraction'] == true && mounted) {
        final l10n = AppLocalizations.of(context);
        final warningMessage =
            checkResult['warningMessage'] as String? ??
            (l10n?.addPrescriptionInteractionWarning ??
                'Se detectó una posible interacción medicamentosa.');

        final proceed = await DrugInteractionDialog.show(
          context,
          warningMessage: warningMessage,
        );

        return proceed;
      }
    } catch (e) {
      debugPrint('Error en la verificación de interacciones: $e');
    }

    return true;
  }

  Future<void> _saveTreatment() async {
    if (!_formKey.currentState!.validate()) return;
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final proceed = await _checkAndWarnDrugInteractions(nombre);
    if (!proceed || !mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final cantidadActual =
          _hasInventario
              ? int.tryParse(_cantidadActualController.text.trim()) ?? 0
              : 0;
      final cantidadTotal =
          _hasInventario
              ? int.tryParse(_cantidadTotalController.text.trim()) ??
                  cantidadActual
              : 0;

      final updatedFormData = TreatmentFormData(
        nombreMedicamento: nombre,
        presentacion: _presentacion,
        cantidadActual: cantidadActual,
        cantidadTotalCaja: cantidadTotal > 0 ? cantidadTotal : cantidadActual,
        dosisPorToma: _dosisPorToma,
        horaPrimeraDosis: _horaPrimeraDosis,
        intervaloDosis: _intervaloHoras,
        duracionNumero: _duracionNumero,
        duracionUnidad: _duracionUnidad,
        esIndefinido: _esIndefinido,
        notas: _notasController.text.trim(),
      );

      final notifier = context.read<TreatmentFormNotifier>();
      final success = await notifier.updateExistingTreatment(
        originalTratamiento: widget.tratamiento,
        formData: updatedFormData,
        profile: widget.profile,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.addPrescriptionTreatmentUpdated(nombre) ??
                  'Tratamiento actualizado para $nombre',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              notifier.errorMessage ??
                  (l10n?.addPrescriptionSaveError ??
                      'Error al guardar el tratamiento'),
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el tratamiento: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final showBorder =
        preferenceNotifier.showCardBorder || preferenceNotifier.highContrast;

    final schedule = _calculateDoseSchedule();
    final dosesPerDay = schedule.length;

    DateTime calculatedEndDate;
    if (_esIndefinido) {
      calculatedEndDate = widget.tratamiento.fechaInicioTratamiento.add(
        const Duration(days: 90),
      );
    } else {
      final totalDays = _duracionUnidad.toDays(_duracionNumero);
      calculatedEndDate = widget.tratamiento.fechaInicioTratamiento.add(
        Duration(days: totalDays),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2D3C) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppTheme.primaryTextColor,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        title: Text(
          l10n?.editTreatmentTitle ?? 'Editar Tratamiento',
          style: TextStyle(
            color: AppTheme.primaryTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child:
                _isSaving
                    ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                    : TextButton.icon(
                      onPressed: _saveTreatment,
                      icon: Icon(
                        Icons.check_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      label: Text(
                        l10n?.commonSave ?? 'Guardar',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Tarjeta: Medicamento y Presentación
              _buildCardContainer(
                showBorder: showBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.medication_rounded,
                      title: 'Medicamento',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreController,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTextColor,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n?.addPrescriptionStep0Hint ??
                              'Ingresa el nombre del medicamento';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Nombre del medicamento',
                        labelStyle: TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.medication_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        filled: true,
                        fillColor:
                            isDark
                                ? const Color(0xFF1E2235)
                                : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color:
                                isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color:
                                isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Presentación',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            _availablePresentations.map((pres) {
                              final isSelected =
                                  _presentacion.toLowerCase() ==
                                  pres.toLowerCase();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  selected: isSelected,
                                  showCheckmark: false,
                                  avatar: MedicationPresentationIcon(
                                    presentation: pres,
                                    size: 16,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : AppTheme.primaryColor,
                                  ),
                                  label: Text(
                                    AppUtils.localizePresentation(
                                      context,
                                      pres,
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : AppTheme.primaryTextColor,
                                    ),
                                  ),
                                  selectedColor: AppTheme.primaryColor,
                                  backgroundColor:
                                      isDark
                                          ? const Color(0xFF1E2235)
                                          : AppTheme.primaryColor.withValues(
                                            alpha: 0.08,
                                          ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color:
                                          isSelected
                                              ? AppTheme.primaryColor
                                              : Colors.transparent,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 6,
                                  ),
                                  onSelected: (_) {
                                    setState(() {
                                      _presentacion = pres;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Tarjeta: Pauta, Intervalo y Horarios (Dosis en Lista)
              _buildCardContainer(
                showBorder: showBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.access_time_filled_rounded,
                      title: 'Dosis y Horarios',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$dosesPerDay ${dosesPerDay == 1 ? 'dosis al día' : 'dosis al día'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dosis por toma (Stepper)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dosis por toma',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Cantidad administrada en cada horario',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? const Color(0xFF1E2235)
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                color:
                                    _dosisPorToma > 1
                                        ? AppTheme.primaryColor
                                        : Colors.grey,
                                onPressed:
                                    _dosisPorToma > 1
                                        ? () {
                                          setState(() {
                                            _dosisPorToma--;
                                          });
                                        }
                                        : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  '$_dosisPorToma',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryTextColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                color: AppTheme.primaryColor,
                                onPressed: () {
                                  setState(() {
                                    _dosisPorToma++;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Selector de frecuencia / intervalo
                    Text(
                      'Frecuencia entre tomas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...[4, 6, 8, 12, 24].map((hours) {
                          final isSelected =
                              !_isCustomInterval && _intervaloHoras == hours;
                          return ChoiceChip(
                            label: Text('Cada $hours h'),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : AppTheme.primaryTextColor,
                            ),
                            backgroundColor:
                                isDark
                                    ? const Color(0xFF1E2235)
                                    : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _isCustomInterval = false;
                                  _intervaloHoras = hours;
                                });
                              }
                            },
                          );
                        }),
                        ChoiceChip(
                          label: const Text('Otro'),
                          selected: _isCustomInterval,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                _isCustomInterval
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                            color:
                                _isCustomInterval
                                    ? Colors.white
                                    : AppTheme.primaryTextColor,
                          ),
                          backgroundColor:
                              isDark
                                  ? const Color(0xFF1E2235)
                                  : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _isCustomInterval = true;
                            });
                          },
                        ),
                      ],
                    ),

                    if (_isCustomInterval) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _customIntervalController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Intervalo en horas',
                                hintText: 'Ej: 5',
                                suffixText: 'horas',
                                filled: true,
                                fillColor:
                                    isDark
                                        ? const Color(0xFF1E2235)
                                        : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null &&
                                    parsed > 0 &&
                                    parsed <= 24) {
                                  setState(() {
                                    _intervaloHoras = parsed;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // LISTA VISUAL DE LAS DOSIS PROGRAMADAS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Horario de dosis programadas',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        Text(
                          'Toca para ajustar',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista de tarjetas de dosis
                    ...List.generate(schedule.length, (index) {
                      final doseTime = schedule[index];
                      final isFirst = index == 0;
                      final isLast = index == schedule.length - 1;
                      final localizedPres = AppUtils.localizePresentation(
                        context,
                        _presentacion,
                      );
                      final doseText = '$_dosisPorToma $localizedPres';

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Línea de tiempo visual
                            SizedBox(
                              width: 28,
                              child: Column(
                                children: [
                                  if (!isFirst)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 12),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          isFirst
                                              ? AppTheme.primaryColor
                                              : AppTheme.primaryColor
                                                  .withValues(alpha: 0.12),
                                      border: Border.all(
                                        color: AppTheme.primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isFirst
                                                ? Colors.white
                                                : AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 12),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            // Tarjeta de la toma
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () => _onPickDoseTime(index, doseTime),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? const Color(0xFF1E2235)
                                              : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color:
                                            isDark
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Hora formateada
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Dosis ${index + 1}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppTheme.secondaryTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              AppUtils.formatDoseTimeOfDay(
                                                doseTime,
                                              ),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    AppTheme.primaryTextColor,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(width: 16),
                                        Container(
                                          height: 32,
                                          width: 1,
                                          color:
                                              isDark
                                                  ? Colors.grey.shade800
                                                  : Colors.grey.shade300,
                                        ),
                                        const SizedBox(width: 16),

                                        // Cantidad y presentación
                                        Expanded(
                                          child: Row(
                                            children: [
                                              MedicationPresentationIcon(
                                                presentation: _presentacion,
                                                size: 14,
                                                color:
                                                    AppTheme.secondaryTextColor,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  doseText,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        AppTheme
                                                            .primaryTextColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Icono de edición
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 18,
                                          color: AppTheme.primaryColor,
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
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Tarjeta: Duración del Tratamiento
              _buildCardContainer(
                showBorder: showBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.calendar_today_rounded,
                      title: 'Duración del Tratamiento',
                    ),
                    const SizedBox(height: 16),

                    // Switch tratamiento indefinido
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _esIndefinido,
                      title: Text(
                        'Tratamiento continuo / indefinido',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      subtitle: Text(
                        'Para medicamentos crónicos o sin fecha de término fija',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                      activeTrackColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setState(() {
                          _esIndefinido = val;
                        });
                      },
                    ),

                    if (!_esIndefinido) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Cantidad numérica
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _duracionController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryTextColor,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cantidad',
                                filled: true,
                                fillColor:
                                    isDark
                                        ? const Color(0xFF1E2235)
                                        : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onChanged: (val) {
                                final n = int.tryParse(val);
                                if (n != null && n > 0) {
                                  setState(() {
                                    _duracionNumero = n;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Unidad de tiempo
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<DurationUnit>(
                              initialValue: _duracionUnidad,
                              decoration: InputDecoration(
                                labelText: 'Unidad',
                                filled: true,
                                fillColor:
                                    isDark
                                        ? const Color(0xFF1E2235)
                                        : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: DurationUnit.days,
                                  child: Text('Días'),
                                ),
                                DropdownMenuItem(
                                  value: DurationUnit.months,
                                  child: Text('Meses'),
                                ),
                                DropdownMenuItem(
                                  value: DurationUnit.years,
                                  child: Text('Años'),
                                ),
                              ],
                              onChanged: (unit) {
                                if (unit != null) {
                                  setState(() {
                                    _duracionUnidad = unit;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Finaliza el: ${AppUtils.formatDate(calculatedEndDate)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Tarjeta: Control de Inventario
              _buildCardContainer(
                showBorder: showBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.inventory_2_outlined,
                      title: 'Control de Inventario',
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _hasInventario,
                      title: Text(
                        'Gestionar inventario de este medicamento',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      subtitle: Text(
                        'Descuenta dosis automáticamente y te alerta si el stock es bajo',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                      activeTrackColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setState(() {
                          _hasInventario = val;
                        });
                      },
                    ),
                    if (_hasInventario) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cantidadActualController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Cantidad actual',
                                hintText: 'Ej: 30',
                                filled: true,
                                fillColor:
                                    isDark
                                        ? const Color(0xFF1E2235)
                                        : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cantidadTotalController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Total por caja',
                                hintText: 'Ej: 60',
                                filled: true,
                                fillColor:
                                    isDark
                                        ? const Color(0xFF1E2235)
                                        : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. Tarjeta: Indicaciones y Notas
              _buildCardContainer(
                showBorder: showBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.notes_rounded,
                      title: 'Notas e Indicaciones Médicas',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notasController,
                      maxLines: null,
                      minLines: 3,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryTextColor,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Ej: Tomar con las comidas, evitar tomar junto con antiácidos...',
                        hintStyle: TextStyle(
                          color: AppTheme.secondaryTextColor.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        filled: true,
                        fillColor:
                            isDark
                                ? const Color(0xFF1E2235)
                                : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color:
                                isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color:
                                isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 6. Botón de Guardar Cambios Prominente
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveTreatment,
                  icon:
                      _isSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                          ),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar Cambios',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer({
    required Widget child,
    required bool showBorder,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: showBorder ? Border.all(color: AppTheme.borderColor) : null,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
