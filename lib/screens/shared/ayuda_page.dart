import 'package:flutter/material.dart';
import 'instrucciones_page.dart';
import 'guia_optimizacion_page.dart';
import 'info_page.dart';
import 'package:meditime/widgets/primary_button.dart';
// ignore: camel_case_types
class AyudaPage extends StatelessWidget {
  const AyudaPage({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda'),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('¿Cómo usar la aplicación?',
                style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const InstruccionesPage()),
              );
            },
          ),
          ListTile(
            title: Text('Guía de optimización de recordatorios',
                style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const GuiaOptimizacionPage()),
              );
            },
          ),
          ListTile(
            title: Text('Términos de uso', style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InfoPage( // <-- USAMOS InfoPage
                    title: 'Térmimos de uso',
                    children: [
                      Text('1. Aceptación de los Términos\n',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      Text(
                          'Al acceder y utilizar nuestra aplicación, usted acepta y está de acuerdo con estos Términos de Servicio. Si no está de acuerdo con estos términos, no debe utilizar nuestra aplicación.\n',
                          style: TextStyle(color: textColor)),
                      Text('2. Uso de la Aplicación\n',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      Text(
                          'Usted es responsable de su uso de la aplicación y de cualquier contenido que publique en la aplicación. No puede usar la aplicación para fines ilegales o prohibidos. No puede usar la aplicación de manera que pueda dañar, deshabilitar, sobrecargar o deteriorar la aplicación.\n',
                          style: TextStyle(color: textColor)),
                      Text('3. Contenido del Usuario\n',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      Text(
                          'Usted es el único responsable de toda la información que carga, publica, envía o transmite a través de la aplicación. No reclamamos ninguna propiedad sobre su contenido. Al publicar contenido en la aplicación, usted otorga a la aplicación una licencia no exclusiva, transferible, sublicenciable, libre de regalías y mundial para usar, copiar, modificar, distribuir, almacenar y procesar su contenido.\n',
                          style: TextStyle(color: textColor)),
                      Text('4. Privacidad\n',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      Text(
                          'Nuestra recopilación y uso de su información personal se rige por nuestra Política de Privacidad. Al utilizar la aplicación, usted acepta que podemos recopilar y usar dicha información de acuerdo con nuestra Política de Privacidad.\n',
                          style: TextStyle(color: textColor)),
                      Text('5. Cambios en los Términos\n',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      Text(
                          'Podemos modificar estos Términos de Servicio de vez en cuando. Si hacemos cambios, le notificaremos revisando la fecha en la parte superior de los términos. Le recomendamos que revise periódicamente estos Términos de Servicio para mantenerse informado sobre nuestras prácticas.\n',
                          style: TextStyle(color: textColor)),
                      Text('6. Terminación\n',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      Text(
                          'Nos reservamos el derecho de suspender o terminar su acceso a la aplicación en cualquier momento por cualquier motivo. Si viola estos Términos de Servicio, podemos suspender o terminar su acceso a la aplicación sin previo aviso.\n',
                          style: TextStyle(color: textColor)),
                      Text('7. Contacto\n',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      Text(
                          'Si tiene alguna pregunta sobre estos Términos de Servicio, por favor contáctenos.',
                          style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: Text('Política de Privacidad', style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InfoPage( // <-- USAMOS InfoPage
                    title: 'Política de Privacidad',
                    children: [
                      Text('1. Aceptación de los Términos\n',
                            style:
                                TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        Text(
                            'Al acceder y utilizar nuestra aplicación, usted acepta y está de acuerdo con estos Términos de Servicio. Si no está de acuerdo con estos términos, no debe utilizar nuestra aplicación.\n',
                            style: TextStyle(color: textColor)),
                        Text('2. Uso de la Aplicación\n',
                            style:
                                TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        Text(
                            'Usted es responsable de su uso de la aplicación y de cualquier contenido que publique en la aplicación. No puede usar la aplicación para fines ilegales o prohibidos. No puede usar la aplicación de manera que pueda dañar, deshabilitar, sobrecargar o deteriorar la aplicación.\n',
                            style: TextStyle(color: textColor)),
                        Text('3. Contenido del Usuario\n',
                            style:
                                TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        Text(
                            'Usted es el único responsable de toda la información que carga, publica, envía o transmite a través de la aplicación. No reclamamos ninguna propiedad sobre su contenido. Al publicar contenido en la aplicación, usted otorga a la aplicación una licencia no exclusiva, transferible, sublicenciable, libre de regalías y mundial para usar, copiar, modificar, distribuir, almacenar y procesar su contenido.\n',
                            style: TextStyle(color: textColor)),
                        Text('4. Privacidad\n',
                            style:
                                TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        Text(
                            'Nuestra recopilación y uso de su información personal se rige por nuestra Política de Privacidad. Al utilizar la aplicación, usted acepta que podemos recopilar y usar dicha información de acuerdo con nuestra Política de Privacidad.\n',
                            style: TextStyle(color: textColor)),
                        Text('5. Cambios en los Términos\n',
                            style:
                                TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        Text(
                            'Podemos modificar estos Términos de Servicio de vez en cuando. Si hacemos cambios, le notificaremos revisando la fecha en la parte superior de los términos. Le recomendamos que revise periódicamente estos Términos de Servicio para mantenerse informado sobre nuestras prácticas.\n',
                            style: TextStyle(color: textColor)),
                        Text('6. Terminación\n',
                            style:
                                TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        Text(
                            'Nos reservamos el derecho de suspender o terminar su acceso a la aplicación en cualquier momento por cualquier motivo. Si viola estos Términos de Servicio, podemos suspender o terminar su acceso a la aplicación sin previo aviso.\n',
                            style: TextStyle(color: textColor)),
                        Text('7. Contacto\n',
                            style:
                                TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        Text(
                            'Si tiene alguna pregunta sobre estos Términos de Servicio, por favor contáctenos.',
                            style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: Text('Versión de la aplicación',
                style: TextStyle(color: textColor)),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  const data =
                      'La aplicación se encuentra actualmente en desarrollo, esta es la versión: 2.23.0 alpha.';
                  return AlertDialog(
                    title: Text('Versión de la aplicación',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF4092E4))),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(32.0), // Ajusta el radio aquí
                    ),
                    content: SingleChildScrollView(
                      child: Text(data, style: TextStyle(color: textColor)),
                    ),
                    actions: <Widget>[
                        PrimaryButton(
                            text: 'Entendido',
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            title: Text('Desarrolladores', style: TextStyle(color: textColor)),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Desarrolladores',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF4092E4))),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(32.0), // Ajusta el radio aquí
                    ),
                    content: SingleChildScrollView(
                      padding: const EdgeInsets.all(5.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Programación:\n',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          Text(
                              '● Jorge Eliecer Delgado Cortés\n● Johan Alexander Arévalo Contréras\n',
                              style: TextStyle(color: textColor)),
                          Text('Diseño:\n',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          Text('● Jorge Eliecer Delgado Cortés\n',
                              style: TextStyle(color: textColor)),
                          Text('Testing:\n',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          Text(
                            '● Daniel Esteban Castiblanco\n'
                            '● Brayan Esteban Salinas\n'
                            '● Santiago Garzón Cuadrado\n'
                            '● Jorge Eliecer Delgado\n'
                            '● Johan Alexander Arévalo\n'
                            '● Juan Manuel Castro\n'
                            '● Johan Mauricio Espinosa\n',
                            style: TextStyle(color: textColor),
                          ),
                          Text(
                            '\nAgradecimientos Especiales a la Universidad de Cundinamarca seccional Ubaté por incentivar el desarrollo de proyectos innovadores y el acompañamiento por parte de los docentes y directivos.\n\n'
                            'Universidad de Cundinamarca\n'
                            'Ingeniería en Sistemas y Computación\n'
                            '©Todos los Derechos Reservados\n2022-2025',
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                        PrimaryButton(
                            text: 'Entendido',
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}