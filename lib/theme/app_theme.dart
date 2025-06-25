import 'package:flutter/material.dart';

// -------------------
// Colores Principales
// -------------------

/// Color principal para degradados y elementos activos (azul claro).
const kPrimaryColor = Color(0xFF3FB8EE);

/// Color secundario para textos importantes y degradados (azul oscuro).
const kSecondaryColor = Color(0xFF4092E4);

/// Color de fondo principal para la mayoría de las pantallas.
const kBackgroundColor = Color(0xFFF3F3F3);

/// Color para estados de éxito (verde).
const kSuccessColor = Colors.green;

/// Color para estados de advertencia o peligro (rojo).
const kErrorColor = Colors.red;

/// Color para elementos de información o pendientes (azul).
const kInfoColor = Colors.blue;


// -------------------
// Sombras y Bordes
// -------------------

/// Sombra de tarjeta estándar utilizada en toda la aplicación.
const kCustomBoxShadow = [
  BoxShadow(
    color: Color.fromARGB(20, 47, 109, 180), // Sombra azul sutil
    blurRadius: 6,
    spreadRadius: 3,
    offset: Offset(0, 4),
  ),
];


// -------------------
// Estilos de Texto
// -------------------

/// Estilo para títulos principales de las páginas.
const kPageTitleStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: kSecondaryColor,
);

/// Estilo para subtítulos o encabezados de sección.
const kSectionTitleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  color: Colors.black87,
);

/// Estilo de texto principal para el cuerpo de la aplicación.
const kBodyTextStyle = TextStyle(
  fontSize: 16,
  color: Colors.black87,
);

/// Estilo para textos con menor énfasis o subtítulos.
const kSubtitleTextStyle = TextStyle(
  fontSize: 14,
  color: Colors.grey,
);