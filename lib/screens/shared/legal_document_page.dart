import 'package:flutter/material.dart';
import 'package:meditime/core/legal_content.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/primary_button.dart';

/// Pantalla completa y visor modal interactivo de Términos de Servicio y Política de Privacidad.
class LegalDocumentPage extends StatefulWidget {
  final int initialTabIndex; // 0 para Términos, 1 para Privacidad
  final bool showAcceptButton;
  final VoidCallback? onAccepted;

  const LegalDocumentPage({
    super.key,
    this.initialTabIndex = 0,
    this.showAcceptButton = false,
    this.onAccepted,
  });

  /// Abre un modal bottom sheet deslizable con el visor legal
  static Future<bool?> showAsModalSheet(
    BuildContext context, {
    int initialTabIndex = 0,
    bool showAcceptButton = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: LegalDocumentPage(
              initialTabIndex: initialTabIndex,
              showAcceptButton: showAcceptButton,
              onAccepted: () => Navigator.pop(ctx, true),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: Text(
            'Marco Legal y Privacidad',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.primaryTextColor,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          bottom: TabBar(
            controller: _tabController,
            labelColor: primaryColor,
            unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
            indicatorColor: primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            tabs: const [
              Tab(
                icon: Icon(Icons.description_outlined, size: 20),
                text: 'Términos de Uso',
              ),
              Tab(
                icon: Icon(Icons.shield_outlined, size: 20),
                text: 'Política de Privacidad',
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Banner de versión y última actualización
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, size: 16, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Versión ${LegalContent.version} • Actualizado: ${LegalContent.lastUpdated}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLegalList(LegalContent.termsOfService, isDark),
                _buildLegalList(LegalContent.privacyPolicy, isDark),
              ],
            ),
          ),

          // Botón opcional de aceptación
          if (widget.showAcceptButton)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                ),
                child: PrimaryButton(
                  text: 'Entendido y Acepto los Términos',
                  onPressed: () {
                    widget.onAccepted?.call();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegalList(List<LegalSection> sections, bool isDark) {
    return ModernContentFade(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final sec = sections[index];
          return _buildSectionCard(sec, isDark);
        },
      ),
    );
  }

  Widget _buildSectionCard(LegalSection sec, bool isDark) {
    final cardColor = sec.isHighlight
        ? (isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF0FDF4))
        : Theme.of(context).cardColor;

    final borderColor = sec.isHighlight
        ? (isDark ? Colors.teal.shade700 : Colors.teal.shade300)
        : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: sec.isHighlight ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (sec.icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: sec.isHighlight
                        ? Colors.teal.withValues(alpha: 0.15)
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    sec.icon,
                    size: 18,
                    color: sec.isHighlight ? Colors.teal : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  sec.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: sec.isHighlight
                        ? (isDark ? Colors.teal.shade200 : Colors.teal.shade900)
                        : (isDark ? Colors.white : AppTheme.primaryTextColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sec.content,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
