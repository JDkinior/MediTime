import 'package:flutter/material.dart';

/// Modelo de sección legal para estructurar los términos y la política de privacidad.
class LegalSection {
  final String title;
  final String content;
  final IconData? icon;
  final bool isHighlight;

  const LegalSection({
    required this.title,
    required this.content,
    this.icon,
    this.isHighlight = false,
  });
}

/// Repositorio oficial y completo de Términos de Servicio y Política de Privacidad de MediTime.
///
/// Redactado con rigor técnico-jurídico cumpliendo:
/// - Directivas de Google Play para aplicaciones de salud (Health Apps Policy).
/// - Principios de protección de datos de salud (RGPD/GDPR, normativas de privacidad).
/// - Deslinde explícito de responsabilidad clínica y farmacológica.
class LegalContent {
  static const String version = '2.35.0';
  static const String lastUpdated = '11 de Octubre de 2026';
  static const String legalEntity = 'MediTime App';
  static const String contactEmail = 'privacidad@meditime.app';
  static const String supportEmail = 'soporte@meditime.app';

  // ═══════════════════════════════════════════════════════════════════════════
  // TÉRMINOS DE SERVICIO Y CONDICIONES DE USO
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<LegalSection> termsOfService = [
    LegalSection(
      title: '1. Aceptación y Naturaleza del Servicio',
      content:
          'El presente documento establece los Términos de Servicio y Condiciones de Uso '
          'que rigen la descarga, instalación, acceso y uso de la aplicación móvil MediTime (en adelante, "la Aplicación"). '
          'Al registrarse, acceder o continuar utilizando la Aplicación, usted (en adelante, "el Usuario") declara ser '
          'mayor de edad en su jurisdicción o contar con la autorización legal correspondiente, y acepta quedar vinculado '
          'de forma expresa, plena e incondicional por las presentes cláusulas.\n\n'
          'Si no está de acuerdo con la totalidad de estos términos, debe abstenerse de usar la Aplicación y desinstalarla '
          'de inmediato de su dispositivo.',
      icon: Icons.gavel_rounded,
    ),
    LegalSection(
      title: '2. Deslinde de Responsabilidad Médica (Aviso Clínico Esencial)',
      content:
          'MEDITIME ES EXCLUSIVAMENTE UNA HERRAMIENTA INFORMÁTICA DE REGISTRO, ORGANIZACIÓN Y RECORDATORIO DIGITAL DE HORARIOS '
          'DE TOMA DE MEDICAMENTOS. LA APLICACIÓN NO ES UN DISPOSITIVO MÉDICO (SOFTWARE AS A MEDICAL DEVICE), NO POSEE ACREDITACIÓN '
          'DIAGNÓSTICA CLÍNICA NI SUSTITUYE EN NINGÚN CASO EL JUICIO, DIAGNÓSTICO, PRESCRIPCIÓN O TRATAMIENTO DE UN PROFESIONAL '
          'MÉDICO O FARMACÉUTICO COLEGIADO.\n\n'
          '• Sin Asesoramiento Clínico: Ningún contenido, cálculo de dosis, alerta, gráfico o respuesta provista por la Aplicación '
          'o su Asistente de IA (Midi) debe interpretarse como consejo médico personalizado.\n'
          '• Emergencias y Urgencias: Ante cualquier sintomatología aguda, sospecha de intoxicación, reacción adversa farmacológica, '
          'sobredosis o duda grave, el Usuario debe comunicarse inmediatamente con los servicios de emergencia médica de su país '
          '(p. ej., 911, 112) o acudir al centro asistencial más cercano.\n'
          '• Prevalencia de la Receta Física: El Usuario es el único responsable de confrontar en todo momento las instrucciones de la '
          'receta médica emitida por su facultativo con los datos ingresados en la Aplicación.',
      icon: Icons.warning_amber_rounded,
      isHighlight: true,
    ),
    LegalSection(
      title: '3. Responsabilidad sobre Fármacos, Dosificación e Inventario',
      content:
          'El Usuario asume la responsabilidad exclusiva por la exactitud, veracidad y actualización de toda la información '
          'ingresada en la Aplicación, incluyendo pero no limitándose a: nombres comerciales y genéricos de medicamentos, '
          'concentraciones, dosis por toma, intervalos horarios, inventario de pastillas restante y fechas de caducidad.\n\n'
          'MediTime no verifica químicamente ni valida la compatibilidad entre medicamentos registrados, ni responde por errores '
          'humanos de transcripción o administración de dosis incorrectas por parte del Usuario.',
      icon: Icons.medication_rounded,
    ),
    LegalSection(
      title: '4. Modos Especiales: Cuidador y Animales (Veterinario)',
      content:
          'La Aplicación permite habilitar funcionalidades avanzadas para la gestión de terceros:\n\n'
          '• Modo Cuidador: Permite organizar tomas para familiares, dependientes o pacientes asignados. El cuidador registrado '
          'declara contar con la autorización o consentimiento informado del paciente o de su representante legal para almacenar '
          'sus datos en la Aplicación, y asume la responsabilidad directa en el suministro oportuno y seguro de los medicamentos.\n\n'
          '• Modo Animales (Veterinario): Diseñado para el seguimiento de prescripciones veterinarias en mascotas. MediTime no '
          'constituye un servicio veterinario; la dosificación debe responder con exclusividad a las indicaciones de un '
          'médico veterinario certificado.',
      icon: Icons.supervised_user_circle_rounded,
    ),
    LegalSection(
      title: '5. Asistente con Inteligencia Artificial (Midi)',
      content:
          'La Aplicación incluye un asistente conversacional ("Midi") potenciado por modelos de lenguaje de última generación (Google Gemini). '
          'El Usuario reconoce y acepta que:\n\n'
          '• Las respuestas de Midi tienen carácter exclusivamente informativo, pedagógico y de apoyo general basado en bibliografía '
          'pública sobre salud.\n'
          '• Los modelos de IA pueden generar imprecisiones u omisiones involuntarias ("alucinaciones"). NUNCA suspenda, modifique '
          'ni inicie un tratamiento médico basándose en respuestas de Midi sin consultar a su médico tratante.\n'
          '• Las notas de voz y consultas no se conservan para entrenamiento público de modelos, procesándose de forma segura y efímera.',
      icon: Icons.psychology_rounded,
    ),
    LegalSection(
      title: '6. Fiabilidad Técnica de Alarmas y Limitaciones del Sistema Operativo',
      content:
          'MediTime implementa arquitecturas de alta prioridad (Android AlarmManager, alarmas exactas, flags insistentes y servicios '
          'en segundo plano con soporte offline). No obstante, el Usuario reconoce que la activación y puntualidad de las alarmas '
          'dependen de factores técnicos ajenos a nuestro control directo:\n\n'
          '• Restricciones de fabricantes de hardware (p. ej., políticas agresivas de ahorro de batería de Xiaomi MIUI/HyperOS, '
          'Samsung One UI, Huawei EMUI).\n'
          '• Estado de la batería del dispositivo (agotamiento, apagado o reinicio pendiente).\n'
          '• Revocación de permisos por parte del usuario (permisos de notificaciones, alarmas exactas o exención de optimización de batería).\n\n'
          'MediTime no será responsable patrimonial ni legalmente por tomas omitidas o demoradas a causa de restricciones del sistema operativo.',
      icon: Icons.alarm_rounded,
    ),
    LegalSection(
      title: '7. Cuentas de Usuario, Seguridad y Acceso',
      content:
          'El acceso a las funciones de sincronización requiere autenticación mediante correo electrónico o proveedores federados (Google). '
          'El Usuario es responsable de mantener la confidencialidad de sus credenciales. La Aplicación implementa mecanismos de seguridad '
          'adicionales (como la protección de pantalla contra capturas no autorizadas y ocultamiento de nombres en pantalla bloqueada), '
          'cuya activación queda a discreción del Usuario.',
      icon: Icons.lock_person_rounded,
    ),
    LegalSection(
      title: '8. Propiedad Intelectual y Licencia de Uso',
      content:
          'Todos los derechos de propiedad intelectual sobre el código fuente, diseño, logotipos, nombres comerciales ("MediTime", "Midi"), '
          'iconografía y materiales multimedia pertenecen a los desarrolladores de MediTime. Se otorga al Usuario una licencia personal, '
          'no exclusiva, revocable e intransferible para usar la Aplicación conforme a su finalidad prevista.',
      icon: Icons.copyright_rounded,
    ),
    LegalSection(
      title: '9. Terminación y Modificaciones del Servicio',
      content:
          'Nos reservamos el derecho de actualizar, suspender o discontinuar características de la Aplicación por razones técnicas, '
          'regulatorias o de mantenimiento. El Usuario puede cancelar su cuenta y dejar de usar la Aplicación en cualquier momento, '
          'pudiendo solicitar la eliminación definitiva e inmediata de sus datos desde las opciones de la Aplicación.',
      icon: Icons.cancel_rounded,
    ),
    LegalSection(
      title: '10. Legislación Aplicable y Resolución de Controversias',
      content:
          'Los presentes Términos se rigen por los principios generales de derecho contractual y de protección al consumidor y de datos '
          'personales. Cualquier desacuerdo se intentará resolver en primera instancia de buena fe mediante contacto directo con nuestro '
          'equipo de soporte legal.',
      icon: Icons.balance_rounded,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // POLÍTICA DE PRIVACIDAD Y PROTECCIÓN DE DATOS DE SALUD
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<LegalSection> privacyPolicy = [
    LegalSection(
      title: '1. Compromiso Ético y Marco Regulatorio de Salud',
      content:
          'En MediTime reconocemos la naturaleza altamente sensible de los datos relativos a la salud personal. Nuestra política '
          'está diseñada bajo los estándares más exigentes de privacidad digital, en estricto cumplimiento con la Política de Aplicaciones '
          'de Salud de Google Play (Health Apps Policy), los principios de minimización y privacidad desde el diseño del RGPD/GDPR '
          '(Reglamento General de Protección de Datos) y normas análogas de protección de datos en Latinoamérica y el mundo.',
      icon: Icons.shield_rounded,
      isHighlight: true,
    ),
    LegalSection(
      title: '2. Datos que Recopilamos y Finalidad Específica',
      content:
          'Recopilamos únicamente los datos indispensables para ofrecer las funcionalidades centrales de la Aplicación:\n\n'
          '• Datos de Salud y Prescripciones: Nombres de medicamentos, presentación, dosis por toma, intervalos horarios, inventario '
          'restante, registros de cumplimiento (tomada, omitida, aplazada), notas clínicas, tipo de sangre y alergias opcionales. '
          'Finalidad: Programación de alarmas locales, cálculo de adherencia al tratamiento y generación de reportes médicos.\n\n'
          '• Datos de Identidad y Cuenta: Nombre o alias, dirección de correo electrónico y fotografía de perfil (opcional). '
          'Finalidad: Autenticación segura y sincronización multi-dispositivo.\n\n'
          '• Datos de Pacientes y Mascotas (Terceros): Nombres, parentesco, habitación y categoría asignada. Finalidad: Gestión '
          'organizada en Modo Cuidador y Animales.\n\n'
          '• Consultas al Asistente Midi: Texto y grabaciones de audio enviadas voluntariamente. Finalidad: Procesamiento '
          'conversacional puntual para responder dudas de salud.\n\n'
          '• Datos Técnicos del Dispositivo: Marca, modelo, versión de sistema operativo y huso horario (Timezone). Finalidad: Configurar '
          'canales de alarma con volumen y sonido correcto según el hardware.',
      icon: Icons.folder_shared_rounded,
    ),
    LegalSection(
      title: '3. Prohibición Absoluta de Venta y Monetización de Datos Médicos',
      content:
          'NUESTRO COMPROMISO ES CATEGÓRICO E INNEGOCIABLE:\n\n'
          '• MediTime NUNCA venderá, comercializará, alquilará ni cederá datos de salud ni información personal del Usuario a corredores '
          'de datos (data brokers), aseguradoras, empresas farmacéuticas ni redes publicitarias de terceros.\n'
          '• La Aplicación no incluye rastreadores de publicidad comportamental ni bibliotecas de monetización basadas en perfiles médicos.\n'
          '• Sus registros clínicos nunca serán utilizados para entrenar modelos públicos de inteligencia artificial.',
      icon: Icons.verified_user_rounded,
      isHighlight: true,
    ),
    LegalSection(
      title: '4. Tratamiento del Asistente IA (Midi) y Notas de Voz',
      content:
          'Cuando el Usuario interactúa con Midi:\n'
          '• Los mensajes de texto y fragmentos de voz se transmiten mediante canales cifrados hacia los servicios de la API de Google Gemini.\n'
          '• Dichos envíos se procesan bajo acuerdos de computación en la nube empresarial sin retención para fines de entrenamiento de modelos.\n'
          '• El almacenamiento local del historial de chat reside exclusivamente en su dispositivo y puede ser eliminado en cualquier '
          'momento con un solo toque desde las opciones de la app.',
      icon: Icons.record_voice_over_rounded,
    ),
    LegalSection(
      title: '5. Geolocalización y Búsqueda de Farmacias Cercanas',
      content:
          'La Aplicación requiere acceso al GPS únicamente cuando el Usuario pulsa voluntariamente la función "Buscar Farmacias Cercanas".\n\n'
          '• No se realiza rastreo de ubicación en segundo plano.\n'
          '• Las coordenadas geográficas no se almacenan en nuestros servidores ni se vinculan a su perfil médico; se utilizan de forma '
          'efímera únicamente para centrar el mapa y calcular distancias a establecimientos farmacéuticos públicos.',
      icon: Icons.location_on_rounded,
    ),
    LegalSection(
      title: '6. Almacenamiento, Cifrado y Medidas de Seguridad',
      content:
          'Implementamos salvaguardas técnicas y organizativas de nivel empresarial:\n\n'
          '• Cifrado en Tránsito: Todas las comunicaciones con servidores se protegen mediante protocolos criptográficos modernos (TLS 1.3 / HTTPS).\n'
          '• Cifrado en Reposo: Los datos alojados en la nube de Google Cloud / Firebase Firestore cuentan con cifrado AES-256.\n'
          '• Soporte Offline y Resguardo Local: Las alarmas y datos de emergencia se almacenan localmente en el dispositivo protegido por '
          'la sandbox de seguridad del sistema operativo Android.\n'
          '• Protección en Pantalla: La Aplicación ofrece la opción de bloquear capturas de pantalla indebidas (FLAG_SECURE) y ocultar '
          'los nombres de medicamentos de la vista de bloqueo.',
      icon: Icons.security_rounded,
    ),
    LegalSection(
      title: '7. Derechos del Usuario y Eliminación Total (Derecho al Olvido)',
      content:
          'El Usuario ejerce el control absoluto sobre su información:\n\n'
          '• Derecho de Acceso y Portabilidad: Puede consultar, revisar y exportar su historial de recetas y adherencia en formato PDF.\n'
          '• Derecho de Rectificación: Puede editar cualquier receta, dosis o perfil en cualquier momento.\n'
          '• DERECHO DE ELIMINACIÓN DEFINITIVA: Desde la pantalla "Opciones -> Datos y Privacidad -> Eliminar mi cuenta y datos personales", '
          'el Usuario puede solicitar en cualquier momento la supresión total e irreversible de su cuenta y todos sus registros médicos. '
          'El borrado en bases de datos y en el dispositivo es completo, definitivo y no requiere trámites adicionales.',
      icon: Icons.delete_forever_rounded,
      isHighlight: true,
    ),
    LegalSection(
      title: '8. Protección de Datos de Menores y Pacientes Tutelados',
      content:
          'MediTime no recopila conscientemente datos de menores de edad sin la supervisión y autorización directa de sus padres o tutores '
          'legales. En el Modo Cuidador, el adulto responsable es quien administra y custodia las recetas asignadas al menor o dependiente.',
      icon: Icons.family_restroom_rounded,
    ),
    LegalSection(
      title: '9. Notificación de Cambios en la Política',
      content:
          'Cualquier modificación sustancial a esta Política de Privacidad será notificada oportunamente a través de la Aplicación o de '
          'un aviso visible en la pantalla principal antes de su entrada en vigencia.',
      icon: Icons.update_rounded,
    ),
    LegalSection(
      title: '10. Contacto y Delegado de Protección de Datos',
      content:
          'Para ejercer cualquiera de sus derechos, formular inquietudes legales o reportar cualquier asunto vinculado con la privacidad '
          'de sus datos de salud, puede comunicarse formalmente con nuestro equipo a:\n\n'
          '• Correo de Privacidad: privacidad@meditime.app\n'
          '• Soporte Técnico General: soporte@meditime.app',
      icon: Icons.contact_mail_rounded,
    ),
  ];
}
