// lib/screens/shared/guia_optimizacion_page.dart
import 'package:flutter/material.dart';
import 'package:meditime/services/system_settings_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/primary_button.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/settings/settings_widgets.dart';

class GuiaOptimizacionPage extends StatefulWidget {
  const GuiaOptimizacionPage({super.key});

  @override
  State<GuiaOptimizacionPage> createState() => _GuiaOptimizacionPageState();
}

class _GuiaOptimizacionPageState extends State<GuiaOptimizacionPage>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isIgnoringBattery = false;
  bool _canScheduleExactAlarms = true;
  bool _notificationsEnabled = true;
  bool _canUseFullScreen = true;
  String _manufacturer = 'Android';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final isIgnoring =
        await SystemSettingsService.isIgnoringBatteryOptimizations();
    final canExact = await SystemSettingsService.canScheduleExactAlarms();
    final notifs = await SystemSettingsService.areNotificationsEnabled();
    final canFullScreen = await SystemSettingsService.canUseFullScreenIntent();
    final manufacturer = await SystemSettingsService.getManufacturer();

    if (mounted) {
      setState(() {
        _isIgnoringBattery = isIgnoring;
        _canScheduleExactAlarms = canExact;
        _notificationsEnabled = notifs;
        _canUseFullScreen = canFullScreen;
        _manufacturer = manufacturer;
        _isLoading = false;
      });
    }
  }

  bool get _allOk =>
      _isIgnoringBattery &&
      _canScheduleExactAlarms &&
      _notificationsEnabled &&
      _canUseFullScreen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppTheme.primaryTextColor;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppTheme.secondaryTextColor;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          centerTitle: true,
          title: Text(
            'Optimización de Alarmas',
            style: TextStyle(
              color: primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: primaryTextColor,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
              tooltip: 'Actualizar estado',
              onPressed: () {
                setState(() => _isLoading = true);
                _checkStatus();
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ModernContentFade(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const SettingsSectionHeader(
                    title: 'Diagnóstico y Permisos',
                    topPadding: 0,
                  ),

                  // Tarjeta 1: Diagnóstico en Vivo
                  SettingsCardWrapper(
                    title: 'Estado de Permisos y Batería',
                    subtitle:
                        'Verifica si el sistema operativo permite que MediTime suene en segundo plano.',
                    trailingHeader: _buildStatusBadge(),
                    child: _buildLiveDiagnosisContent(
                        primaryTextColor, secondaryTextColor),
                  ),

                  // Tarjeta 2: Accesos Directos a Configuraciones
                  SettingsCardWrapper(
                    title: 'Accesos Directos del Sistema',
                    subtitle:
                        'Abre directamente las pantallas de configuración de tu teléfono.',
                    child: _buildDirectAccessList(
                        primaryTextColor, secondaryTextColor),
                  ),

                  const SettingsSectionHeader(
                    title: 'Guías por Marca y Ayuda Técnica',
                    topPadding: 8,
                  ),

                  // Tarjeta 3: ¿Por qué ocurre esto?
                  SettingsCardWrapper(
                    title: '¿Por qué ocurre esto en Android?',
                    subtitle:
                        'Conoce los motivos técnicos por los que el sistema puede silenciar recordatorios.',
                    child: _buildReasonsList(
                        primaryTextColor, secondaryTextColor),
                  ),

                  // Tarjeta 4: Guía por Fabricante
                  SettingsCardWrapper(
                    title: 'Guía por Fabricante',
                    subtitle:
                        'Dispositivo detectado: $_manufacturer. Pasos específicos según la marca:',
                    child: _buildBrandGuideList(
                        primaryTextColor, secondaryTextColor),
                  ),

                  // Tarjeta 5: Enlace Web DontKillMyApp
                  _buildDontKillMyAppCard(
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 16),

                  PrimaryButton(
                    text: 'Entendido y Configurado',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
    );
  }

  /// Badge indicador de estado general
  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _allOk
            ? AppTheme.successColor.withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _allOk ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 14,
            color: _allOk ? AppTheme.successColor : Colors.amber.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            _allOk ? 'Óptimo' : 'Requiere Ajustes',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _allOk ? AppTheme.successColor : Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }

  /// Contenido de la tarjeta de diagnóstico en vivo
  Widget _buildLiveDiagnosisContent(
      Color primaryTextColor, Color secondaryTextColor) {
    return Column(
      children: [
        _buildDiagnosisRow(
          title: 'Optimización de Batería',
          statusText: _isIgnoringBattery
              ? 'Sin restricciones (Óptimo)'
              : 'Optimizada (Android puede demorar alarmas)',
          isOk: _isIgnoringBattery,
          actionLabel: _isIgnoringBattery ? 'Revisar' : 'Desactivar',
          onAction: () =>
              SystemSettingsService.openBatteryOptimizationSettings(),
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const Divider(height: 20, thickness: 0.7),
        _buildDiagnosisRow(
          title: 'Alarmas Exactas',
          statusText: _canScheduleExactAlarms
              ? 'Permitido (Sonará a la hora programada)'
              : 'Restringido (El sistema agrupa avisos)',
          isOk: _canScheduleExactAlarms,
          actionLabel: _canScheduleExactAlarms ? 'Configurado' : 'Permitir',
          onAction: () => SystemSettingsService.openExactAlarmSettings(),
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const Divider(height: 20, thickness: 0.7),
        _buildDiagnosisRow(
          title: 'Notificaciones del Sistema',
          statusText: _notificationsEnabled
              ? 'Activas y autorizadas'
              : 'Desactivadas (No recibirás avisos)',
          isOk: _notificationsEnabled,
          actionLabel: _notificationsEnabled ? 'Ver' : 'Activar',
          onAction: () => SystemSettingsService.openNotificationSettings(),
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const Divider(height: 20, thickness: 0.7),
        _buildDiagnosisRow(
          title: 'Avisos en Pantalla Completa (Android 14+)',
          statusText: _canUseFullScreen
              ? 'Autorizado (Enciende y muestra alarma al sonar)'
              : 'Restringido (Solo mostrará banner flotante)',
          isOk: _canUseFullScreen,
          actionLabel: _canUseFullScreen ? 'Configurado' : 'Permitir',
          onAction: () => SystemSettingsService.openFullScreenIntentSettings(),
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
      ],
    );
  }

  Widget _buildDiagnosisRow({
    required String title,
    required String statusText,
    required bool isOk,
    required String actionLabel,
    required VoidCallback onAction,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isOk
                ? AppTheme.successColor.withValues(alpha: 0.12)
                : Colors.amber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOk ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: isOk ? AppTheme.successColor : Colors.amber.shade800,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: isOk ? secondaryTextColor : Colors.amber.shade900,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOk
                  ? AppTheme.borderColor.withValues(alpha: 0.5)
                  : AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOk
                    ? AppTheme.borderColor
                    : AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isOk ? secondaryTextColor : AppTheme.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Lista agrupada de accesos directos
  Widget _buildDirectAccessList(
      Color primaryTextColor, Color secondaryTextColor) {
    final actions = [
      {
        'title': 'Ahorro de Batería',
        'subtitle': 'Selecciona "Sin restricciones" o "No optimizar"',
        'icon': Icons.battery_charging_full_rounded,
        'color': AppTheme.successColor,
        'action': () =>
            SystemSettingsService.openBatteryOptimizationSettings(),
      },
      {
        'title': 'Alarmas y Recordatorios Exactos',
        'subtitle': 'Permitir programación de alarmas al minuto exacto',
        'icon': Icons.alarm_on_rounded,
        'color': Colors.indigo,
        'action': () => SystemSettingsService.openExactAlarmSettings(),
      },
      {
        'title': 'Inicio Automático (Autostart)',
        'subtitle': 'Permitir ejecución tras reiniciar o limpiar memoria',
        'icon': Icons.power_settings_new_rounded,
        'color': Colors.orange,
        'action': () => SystemSettingsService.openAutoStartSettings(),
      },
      {
        'title': 'Ajustes de Notificaciones',
        'subtitle': 'Gestionar canales, sonido y prioridad en pantalla',
        'icon': Icons.notifications_active_rounded,
        'color': Colors.blue,
        'action': () => SystemSettingsService.openNotificationSettings(),
      },
      {
        'title': 'Avisos en Pantalla Completa',
        'subtitle': 'Permitir encendido directo de la alarma (Android 14+)',
        'icon': Icons.fullscreen_rounded,
        'color': Colors.deepPurple,
        'action': () => SystemSettingsService.openFullScreenIntentSettings(),
      },
      {
        'title': 'Información de la App',
        'subtitle': 'Permisos del sistema, almacenamiento y pantalla completa',
        'icon': Icons.settings_rounded,
        'color': Colors.teal,
        'action': () => SystemSettingsService.openAppDetailsSettings(),
      },
    ];

    return Column(
      children: actions.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == actions.length - 1;
        final iconColor = item['color'] as Color;
        final actionFn = item['action'] as VoidCallback;

        return Column(
          children: [
            InkWell(
              onTap: actionFn,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item['icon'] as IconData,
                          color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            if (!isLast) const Divider(height: 12, thickness: 0.6),
          ],
        );
      }).toList(),
    );
  }

  /// Lista de explicaciones técnicas
  Widget _buildReasonsList(Color primaryTextColor, Color secondaryTextColor) {
    final reasons = [
      {
        'title': '1. Suspensión y "Doze Mode" de Android',
        'desc':
            'Cuando la pantalla se apaga, Android suspende procesos en segundo plano. Si MediTime no tiene el permiso "Sin restricciones", las alarmas se silencian hasta que vuelvas a encender la pantalla.',
        'icon': Icons.bedtime_outlined,
      },
      {
        'title': '2. Gestión estricta de memoria (Xiaomi, Samsung, Huawei)',
        'desc':
            'Las capas de personalización cierran apps de la memoria RAM automáticamente. Para evitarlo, es necesario activar "Inicio Automático" y fijar MediTime con candado en las aplicaciones recientes.',
        'icon': Icons.memory_rounded,
      },
      {
        'title': '3. Restricción de Alarmas Exactas (Android 12+)',
        'desc':
            'En versiones modernas de Android, las apps requieren autorización explícita para programar alarmas al minuto exacto. Sin este permiso, Android puede demorarlas entre 10 y 30 minutos.',
        'icon': Icons.timer_outlined,
      },
      {
        'title': '4. Pantalla de Bloqueo y Alarma Completa',
        'desc':
            'Para que la alarma despierte y encienda la pantalla completa con botones de toma y aplazamiento, la app requiere permisos de visualización sobre pantalla de bloqueo.',
        'icon': Icons.screen_lock_portrait_rounded,
      },
    ];

    return Column(
      children: reasons.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == reasons.length - 1;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['desc'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast) const Divider(height: 14, thickness: 0.6),
          ],
        );
      }).toList(),
    );
  }

  /// Guía específica por marca
  Widget _buildBrandGuideList(
      Color primaryTextColor, Color secondaryTextColor) {
    return Column(
      children: [
        _buildBrandTile(
          brandName: 'Xiaomi / Redmi / POCO (MIUI & HyperOS)',
          steps: [
            '1. Toca en "Inicio Automático" arriba y activa MediTime.',
            '2. En Ajustes > Apps > Administrar apps > MediTime > Ahorro de batería, elige "Sin restricciones".',
            '3. En "Otros permisos", activa "Mostrar en pantalla de bloqueo" y "Ventanas emergentes".',
            '4. En apps recientes, mantén pulsada la tarjeta de MediTime y toca el candado 🔒.',
          ],
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const Divider(height: 8, thickness: 0.6),
        _buildBrandTile(
          brandName: 'Samsung (One UI)',
          steps: [
            '1. En "Ahorro de Batería", busca MediTime y selecciona "No restringida".',
            '2. Ve a Ajustes > Cuidado del dispositivo > Batería > Límites de uso en segundo plano.',
            '3. En "Aplicaciones nunca suspendidas", toca "+" y añade MediTime.',
          ],
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const Divider(height: 8, thickness: 0.6),
        _buildBrandTile(
          brandName: 'Huawei / Honor (EMUI / Magic UI)',
          steps: [
            '1. Ve a Ajustes > Batería > Inicio de aplicaciones > MediTime.',
            '2. Desactiva "Gestionar automáticamente".',
            '3. Activa las 3 casillas: Inicio automático, Inicio secundario y Ejecutar en 2do plano.',
          ],
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const Divider(height: 8, thickness: 0.6),
        _buildBrandTile(
          brandName: 'Oppo / Realme / OnePlus (ColorOS / OxygenOS)',
          steps: [
            '1. Ve a Ajustes > Batería > Más ajustes > Uso de batería de la app > MediTime.',
            '2. Activa "Permitir actividad en segundo plano" e "Inicio automático".',
            '3. Bloquea la app con candado en Aplicaciones recientes.',
          ],
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const Divider(height: 8, thickness: 0.6),
        _buildBrandTile(
          brandName: 'Motorola / Google Pixel / Genérico',
          steps: [
            '1. Ve a Información de la App > Uso de batería > "Sin restricciones".',
            '2. Ve a Información de la App > Alarmas y recordatorios > "Permitido".',
            '3. Desactiva "Pausar actividad de la app si no se usa".',
          ],
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
      ],
    );
  }

  Widget _buildBrandTile({
    required String brandName,
    required List<String> steps,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.phone_android_rounded,
            color: AppTheme.primaryColor,
            size: 18,
          ),
        ),
        title: Text(
          brandName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 8, right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    step,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                      height: 1.35,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de enlace a DontKillMyApp
  Widget _buildDontKillMyAppCard({
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return SettingsCardWrapper(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.open_in_browser_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Base de Datos DontKillMyApp',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Consulta trucos adicionales para cualquier modelo.',
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () =>
                SystemSettingsService.openDontKillMyApp(_manufacturer),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Visitar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
