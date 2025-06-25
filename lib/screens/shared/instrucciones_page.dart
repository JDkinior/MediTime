import 'package:flutter/material.dart';

class InstruccionesPage extends StatelessWidget {
  const InstruccionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Cómo usar la aplicación?'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Paso 1: Ingresa los datos del usuario\n',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Text(
                  'En la pantalla principal, ingresa el nombre del usuario que recibirá la receta.'
                  'Asegúrate de escribir el nombre completo y correcto del paciente.\n',
                  style: TextStyle(color: textColor)),
              Text('Paso 2: Agrega el medicamento\n',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Text(
                  'En el campo "Nombre del medicamento", escribe el nombre del medicamento que se recetará.'
                  'Puedes ingresar el nombre comercial o el nombre genérico del medicamento.\n',
                  style: TextStyle(color: textColor)),
              Text('Paso 3: Selecciona la hora de toma\n',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Text(
                  'Toca el campo "Hora de tomar el medicamento".'
                  'Se abrirá un selector de tiempo.'
                  'Ajusta la hora y los minutos en que el paciente debe tomar el medicamento.\n',
                  style: TextStyle(color: textColor)),
              Text('Paso 4: Elige el número de dosis\n',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Text(
                  'En el menú desplegable "Número de dosis", selecciona la cantidad de veces al día que el paciente debe tomar el medicamento.'
                  'Las opciones disponibles generalmente van desde 1 hasta 10 dosis.\n',
                  style: TextStyle(color: textColor)),
              Text('Paso 5: Revisa y confirma\n',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Text(
                  'Revisa cuidadosamente todos los datos ingresados: nombre del usuario, nombre del medicamento, hora de toma y número de dosis.'
                  'Asegúrate de que toda la información sea correcta y completa.\n',
                  style: TextStyle(color: textColor)),
              Text('Paso 6: Agrega la receta\n',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Text(
                  'Presiona el botón "Agregar".'
                  'La aplicación validará la información ingresada.'
                  'Si todo está correcto, se mostrará un mensaje de confirmación indicando que la receta se ha agregado correctamente.'
                  'La nueva receta se guardará y estará disponible para su consulta en la sección de recetas de la aplicación.',
                  style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}