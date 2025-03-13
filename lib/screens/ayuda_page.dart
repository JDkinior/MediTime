import 'package:flutter/material.dart';
import 'instrucciones_page.dart';
import 'terminos_page.dart';
import 'politica_page.dart';

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
            title: Text('Términos de uso', style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TerminosPage()),
              );
            },
          ),
          ListTile(
            title: Text('Política de Privacidad',
                style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PoliticaPage()),
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
                      'La aplicación se encuentra actualmente en desarrollo, esta es la versión: 10.0.2 Alpha';
                  return AlertDialog(
                    title: Text('Versión de la aplicación',
                        style: TextStyle(color: textColor)),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(20.0), // Ajusta el radio aquí
                    ),
                    content: SingleChildScrollView(
                      child: Text(data, style: TextStyle(color: textColor)),
                    ),
                    actions: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: const Size(150, 50), // Ta
                            backgroundColor: Colors.blue, // Color del botón
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10), // Radio del botón
                            ),
                            foregroundColor: Colors.white, // Color del texto
                          ),
                          child: const Text('Entendido'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
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
                        style: TextStyle(color: textColor)),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(20.0), // Ajusta el radio aquí
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
                            '● Juan Sebastian Gómez\n'
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
                            '©Todos los Derechos Reservados\n2022-2024',
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: const Size(150, 50), // Ta
                            backgroundColor: Colors.blue, // Color del botón
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10), // Radio del botón
                            ),
                            foregroundColor: Colors.white, // Color del texto
                          ),
                          child: const Text('Entendido'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
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
