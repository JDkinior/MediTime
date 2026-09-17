import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/primary_button.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'guia_optimizacion_page.dart';
import 'info_page.dart';
import 'instrucciones_page.dart';

class AyudaPage extends StatelessWidget {
  const AyudaPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<PreferenceNotifier>();
    final l10n = AppLocalizations.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDarkMode ? Colors.white : AppTheme.primaryTextColor;
    final secondaryTextColor =
        isDarkMode ? Colors.white70 : AppTheme.secondaryTextColor;
    final cardBg = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          l10n?.helpSupport ?? 'Ayuda y Soporte',
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryTextColor,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: <Widget>[
          // Tarjeta Destacada: Guía de Optimización de Recordatorios
          _buildSpecialCard(
            context: context,
            title: l10n?.helpGuideTitle ?? 'Guía de Optimización de Recordatorios',
            subtitle: l10n?.helpGuideSubtitle ??
                'Evita que el ahorro de batería o el sistema silencien tus alarmas. Diagnóstico en vivo y accesos directos a configuraciones.',
            icon: Icons.shield_outlined,
            iconColor: Colors.white,
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, const Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GuiaOptimizacionPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // ¿Cómo usar la app?
          _buildItemCard(
            context: context,
            cardBg: cardBg,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            title: l10n?.helpHowToUseTitle ?? '¿Cómo usar la aplicación?',
            subtitle: l10n?.helpHowToUseSubtitle ?? 'Aprende a registrar tratamientos, horarios e inventario.',
            icon: Icons.menu_book_rounded,
            iconColor: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InstruccionesPage(),
                ),
              );
            },
          ),

          // Términos de uso
          _buildItemCard(
            context: context,
            cardBg: cardBg,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            title: l10n?.helpTermsTitle ?? 'Términos de uso',
            subtitle: l10n?.helpTermsSubtitle ?? 'Condiciones de servicio y responsabilidades.',
            icon: Icons.description_outlined,
            iconColor: Colors.blueGrey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InfoPage(
                    title: l10n?.helpTermsTitle ?? 'Términos de uso',
                    children: [
                      Text(
                        '1. Aceptación de los Términos\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Al acceder y utilizar nuestra aplicación, usted acepta y está de acuerdo con estos Términos de Servicio. Si no está de acuerdo con estos términos, no debe utilizar nuestra aplicación.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '2. Uso de la Aplicación\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Usted es responsable de su uso de la aplicación y de cualquier contenido que publique en la aplicación. No puede usar la aplicación para fines ilegales o prohibidos. No puede usar la aplicación de manera que pueda dañar, deshabilitar, sobrecargar o deteriorar la aplicación.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '3. Contenido del Usuario\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Usted es el único responsable de toda la información que carga, publica, envía o transmite a través de la aplicación. No reclamamos ninguna propiedad sobre su contenido. Al publicar contenido en la aplicación, usted otorga a la aplicación una licencia no exclusiva, transferible, sublicenciable, libre de regalías y mundial para usar, copiar, modificar, distribuir, almacenar y procesar su contenido.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '4. Privacidad\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Nuestra recopilación y uso de su información personal se rige por nuestra Política de Privacidad. Al utilizar la aplicación, usted acepta que podemos recopilar y usar dicha información de acuerdo con nuestra Política de Privacidad.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '5. Cambios en los Términos\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Podemos modificar estos Términos de Servicio de vez en cuando. Si hacemos cambios, le notificaremos revisando la fecha en la parte superior de los términos. Le recomendamos que revise periódicamente estos Términos de Servicio para mantenerse informado sobre nuestras prácticas.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '6. Terminación\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Nos reservamos el derecho de suspender o terminar su acceso a la aplicación en cualquier momento por cualquier motivo. Si viola estos Términos de Servicio, podemos suspender o terminar su acceso a la aplicación sin previo aviso.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '7. Contacto\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Si tiene alguna pregunta sobre estos Términos de Servicio, por favor contáctenos.',
                        style: TextStyle(color: primaryTextColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Política de privacidad
          _buildItemCard(
            context: context,
            cardBg: cardBg,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            title: l10n?.helpPrivacyTitle ?? 'Política de Privacidad',
            subtitle: l10n?.helpPrivacySubtitle ?? 'Cómo tratamos y protegemos tus datos médicos.',
            icon: Icons.privacy_tip_outlined,
            iconColor: Colors.indigo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InfoPage(
                    title: l10n?.helpPrivacyTitle ?? 'Política de Privacidad',
                    children: [
                      Text(
                        '1. Aceptación de los Términos\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Al acceder y utilizar nuestra aplicación, usted acepta y está de acuerdo con estos Términos de Servicio. Si no está de acuerdo con estos términos, no debe utilizar nuestra aplicación.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '2. Uso de la Aplicación\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Usted es responsable de su uso de la aplicación y de cualquier contenido que publique en la aplicación. No puede usar la aplicación para fines ilegales o prohibidos. No puede usar la aplicación de manera que pueda dañar, deshabilitar, sobrecargar o deteriorar la aplicación.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '3. Contenido del Usuario\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Usted es el único responsable de toda la información que carga, publica, envía o transmite a través de la aplicación. No reclamamos ninguna propiedad sobre su contenido. Al publicar contenido en la aplicación, usted otorga a la aplicación una licencia no exclusiva, transferible, sublicenciable, libre de regalías y mundial para usar, copiar, modificar, distribuir, almacenar y procesar su contenido.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '4. Privacidad\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Nuestra recopilación y uso de su información personal se rige por nuestra Política de Privacidad. Al utilizar la aplicación, usted acepta que podemos recopilar y usar dicha información de acuerdo con nuestra Política de Privacidad.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '5. Cambios en los Términos\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Podemos modificar estos Términos de Servicio de vez en cuando. Si hacemos cambios, le notificaremos revisando la fecha en la parte superior de los términos. Le recomendamos que revise periódicamente estos Términos de Servicio para mantenerse informado sobre nuestras prácticas.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '6. Terminación\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Nos reservamos el derecho de suspender o terminar su acceso a la aplicación en cualquier momento por cualquier motivo. Si viola estos Términos de Servicio, podemos suspender o terminar su acceso a la aplicación sin previo aviso.\n',
                        style: TextStyle(color: primaryTextColor),
                      ),
                      Text(
                        '7. Contacto\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Si tiene alguna pregunta sobre estos Términos de Servicio, por favor contáctenos.',
                        style: TextStyle(color: primaryTextColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Versión de la aplicación
          _buildItemCard(
            context: context,
            cardBg: cardBg,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            title: l10n?.helpAppVersionTitle ?? 'Versión de la aplicación',
            subtitle: l10n?.helpAppVersionSubtitle ?? 'Información de la versión y compilación actual.',
            icon: Icons.info_outline_rounded,
            iconColor: Colors.blue,
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      String versionText = l10n?.helpLoadingVersion ?? 'Cargando versión...';
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData) {
                        final info = snapshot.data!;
                        versionText = l10n?.helpVersionText(info.version, info.buildNumber) ??
                            'MediTime versión ${info.version} (Build ${info.buildNumber}).';
                      }
                      return AlertDialog(
                        title: Text(
                          l10n?.helpAppVersionTitle ?? 'Versión de la aplicación',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        content: Text(
                          versionText,
                          style: TextStyle(color: primaryTextColor),
                        ),
                        actions: <Widget>[
                          PrimaryButton(
                            text: l10n?.helpUnderstood ?? 'Entendido',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          // Desarrolladores
          _buildItemCard(
            context: context,
            cardBg: cardBg,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            title: l10n?.helpDevelopersTitle ?? 'Desarrolladores',
            subtitle: l10n?.helpDevelopersSubtitle ?? 'Equipo creador y créditos del proyecto.',
            icon: Icons.code_rounded,
            iconColor: Colors.deepPurple,
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      l10n?.helpDevelopersTitle ?? 'Desarrolladores',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${l10n?.helpProgramming ?? 'Programación:'}\n',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          Text(
                            '● Jorge Eliecer Delgado Cortés\n● Johan Alexander Arévalo Contréras\n',
                            style: TextStyle(color: primaryTextColor),
                          ),
                          Text(
                            '${l10n?.helpDesign ?? 'Diseño:'}\n',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          Text(
                            '● Jorge Eliecer Delgado Cortés\n',
                            style: TextStyle(color: primaryTextColor),
                          ),
                          Text(
                            '${l10n?.helpTesting ?? 'Testing:'}\n',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          Text(
                            '● Daniel Esteban Castiblanco\n'
                            '● Brayan Esteban Salinas\n'
                            '● Santiago Garzón Cuadrado\n'
                            '● Jorge Eliecer Delgado\n'
                            '● Johan Alexander Arévalo\n'
                            '● Juan Manuel Castro\n'
                            '● Johan Mauricio Espinosa\n',
                            style: TextStyle(color: primaryTextColor),
                          ),
                          Text(
                            l10n?.helpSpecialThanks ??
                                '\nAgradecimientos Especiales a la Universidad de Cundinamarca seccional Ubaté por incentivar el desarrollo de proyectos innovadores y el acompañamiento por parte de los docentes y directivos.\n\n'
                                'Universidad de Cundinamarca\n'
                                'Ingeniería en Sistemas y Computación\n'
                                '©Todos los Derechos Reservados\n2022-2026',
                            style: TextStyle(color: primaryTextColor),
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      PrimaryButton(
                        text: l10n?.helpUnderstood ?? 'Entendido',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSpecialCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard({
    required BuildContext context,
    required Color cardBg,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final prefNotifier = context.watch<PreferenceNotifier>();
    final hasBorder =
        prefNotifier.showCardBorder || prefNotifier.highContrast;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: hasBorder ? Border.all(color: AppTheme.borderColor) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: secondaryTextColor,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}