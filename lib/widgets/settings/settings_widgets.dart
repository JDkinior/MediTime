import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

/// Cabecera explicativa unificada para todas las páginas de Opciones.
/// Proporciona contexto claro sobre la función de la pantalla, un icono temático,
/// una insignia opcional de estado y soporte para un control principal (ej. Switch).
class SettingsPageHeader extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? color;
  final Color? accentColor;
  final String? statusBadge;
  final String? badgeText;
  final Color? statusBadgeColor;
  final Color? badgeColor;
  final Widget? trailing;
  final Widget? trailingControl;
  final Widget? bottomChild;

  const SettingsPageHeader({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.color,
    this.accentColor,
    this.statusBadge,
    this.badgeText,
    this.statusBadgeColor,
    this.badgeColor,
    this.trailing,
    this.trailingControl,
    this.bottomChild,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefNotifier = context.watch<PreferenceNotifier>();
    final hasBorder = prefNotifier.showCardBorder || prefNotifier.highContrast;
    final effectiveColor = color ?? accentColor ?? AppTheme.primaryColor;
    final effectiveBadge = statusBadge ?? badgeText;
    final effectiveBadgeColor =
        statusBadgeColor ?? badgeColor ?? effectiveColor;
    final effectiveTrailing = trailing ?? trailingControl;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveColor.withValues(alpha: isDark ? 0.18 : 0.10),
            effectiveColor.withValues(alpha: isDark ? 0.08 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: effectiveColor.withValues(alpha: hasBorder ? 0.45 : 0.22),
          width: hasBorder ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: isDark ? 0.25 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: effectiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (effectiveBadge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: effectiveBadgeColor
                                  .withValues(alpha: isDark ? 0.25 : 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: effectiveBadgeColor
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              effectiveBadge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: effectiveBadgeColor,
                              ),
                            ),
                          ),
                        ],
                        if (effectiveTrailing != null) ...[
                          const SizedBox(width: 8),
                          effectiveTrailing,
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bottomChild != null) ...[
            const SizedBox(height: 14),
            bottomChild!,
          ],
        ],
      ),
    );
  }
}

/// Encabezado de sección estándar para agrupar tarjetas de configuración.
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool isDestructive;
  final Widget? trailing;
  final double topPadding;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.isDestructive = false,
    this.trailing,
    this.topPadding = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        isDestructive ? AppTheme.errorColor : AppTheme.primaryTextColor;

    return Padding(
      padding: EdgeInsets.only(left: 4, right: 4, top: topPadding, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: isDestructive ? AppTheme.errorColor : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.secondaryTextColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Contenedor de tarjeta unificado para bloques de opciones (como selectores visuales o vistas previas).
class SettingsCardWrapper extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? iconColor;
  final Widget? trailingHeader;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const SettingsCardWrapper({
    super.key,
    this.title,
    this.subtitle,
    this.leadingIcon,
    this.iconColor,
    this.trailingHeader,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  @override
  Widget build(BuildContext context) {
    final prefNotifier = context.watch<PreferenceNotifier>();
    final showBorder = prefNotifier.showCardBorder || prefNotifier.highContrast;
    final effectiveIconColor = iconColor ?? AppTheme.primaryColor;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: showBorder ? AppTheme.borderColor : Colors.transparent,
          width: showBorder ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingIcon != null) ...[
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: effectiveIconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      leadingIcon,
                      color: effectiveIconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.secondaryTextColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingHeader != null) ...[
                  const SizedBox(width: 8),
                  trailingHeader!,
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Tarjeta unificada con interruptor (Switch) para activar o desactivar preferencias.
class SettingsSwitchTileCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? iconColor;
  final Color? activeColor;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry margin;

  const SettingsSwitchTileCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.iconColor,
    this.activeColor,
    required this.value,
    this.enabled = true,
    required this.onChanged,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final prefNotifier = context.watch<PreferenceNotifier>();
    final showBorder = prefNotifier.showCardBorder || prefNotifier.highContrast;
    final effectiveColor = activeColor ?? iconColor ?? AppTheme.primaryColor;
    final isEnabled = enabled && onChanged != null;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.55,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: margin,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: showBorder ? AppTheme.borderColor : Colors.transparent,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            secondary: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value
                    ? effectiveColor.withValues(alpha: 0.14)
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: value ? effectiveColor : AppTheme.secondaryTextColor,
                size: 22,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.secondaryTextColor,
                  height: 1.35,
                ),
              ),
            ),
            value: value,
            activeThumbColor: effectiveColor,
            onChanged: isEnabled ? onChanged : null,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de acción o navegación unificada (para abrir sub-páginas, diálogos o selectores).
class SettingsActionTileCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? statusBadge;
  final Color? statusBadgeColor;
  final bool isPro;
  final bool isDestructive;
  final EdgeInsetsGeometry margin;

  const SettingsActionTileCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.trailing,
    this.statusBadge,
    this.statusBadgeColor,
    this.isPro = false,
    this.isDestructive = false,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final prefNotifier = context.watch<PreferenceNotifier>();
    final showBorder = prefNotifier.showCardBorder || prefNotifier.highContrast;
    final effectiveIconColor = isDestructive
        ? AppTheme.errorColor
        : (iconColor ?? AppTheme.primaryColor);
    final effectiveBadgeColor = statusBadgeColor ?? effectiveIconColor;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDestructive && showBorder
              ? AppTheme.errorColor.withValues(alpha: 0.35)
              : (showBorder ? AppTheme.borderColor : Colors.transparent),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: effectiveIconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDestructive
                                    ? AppTheme.errorColor
                                    : AppTheme.primaryTextColor,
                              ),
                            ),
                          ),
                          if (isPro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF7C3AED),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          if (statusBadge != null &&
                              statusBadge!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: effectiveBadgeColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusBadge!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: effectiveBadgeColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.secondaryTextColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDestructive
                          ? AppTheme.errorColor.withValues(alpha: 0.7)
                          : AppTheme.secondaryTextColor,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de selección única tipo radio unificada (usada en Idioma, Modo Cuidador, Modo Animales).
class SettingsRadioOptionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? description;
  final IconData? icon;
  final Widget? leadingWidget;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;
  final Color? activeColor;
  final EdgeInsetsGeometry margin;

  const SettingsRadioOptionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.description,
    this.icon,
    this.leadingWidget,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.activeColor,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final prefNotifier = context.watch<PreferenceNotifier>();
    final showBorder = prefNotifier.showCardBorder || prefNotifier.highContrast;
    final effectiveColor = color ?? activeColor ?? AppTheme.primaryColor;
    final effectiveSubtitle = subtitle ?? description ?? '';

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: '$title, $effectiveSubtitle',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? effectiveColor.withValues(alpha: 0.04)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? effectiveColor
                      : (showBorder
                          ? AppTheme.borderColor
                          : Colors.transparent),
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? effectiveColor.withValues(alpha: 0.14)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: leadingWidget ??
                        Icon(
                          icon ?? Icons.check_circle_outline_rounded,
                          color: isSelected
                              ? effectiveColor
                              : AppTheme.secondaryTextColor,
                          size: 22,
                        ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? effectiveColor
                                : AppTheme.primaryTextColor,
                          ),
                        ),
                        if (effectiveSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            effectiveSubtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.secondaryTextColor,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? effectiveColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? effectiveColor
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 15,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta visual en cuadrícula (2 o 3 columnas) para opciones con vista previa gráfica.
class SettingsVisualOptionCard extends StatelessWidget {
  final Widget preview;
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color? selectedColor;
  final VoidCallback onTap;

  const SettingsVisualOptionCard({
    super.key,
    required this.preview,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = selectedColor ?? AppTheme.primaryColor;
    final cardBorderColor =
        isSelected ? effectiveColor : AppTheme.borderColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? effectiveColor.withValues(alpha: 0.05)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cardBorderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 46,
                child: Center(child: preview),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color:
                      isSelected ? effectiveColor : AppTheme.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.secondaryTextColor,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? effectiveColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? effectiveColor : Colors.grey.shade400,
                    width: isSelected ? 0 : 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
