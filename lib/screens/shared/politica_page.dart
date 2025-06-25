import 'package:flutter/material.dart';

class PoliticaPage extends StatelessWidget {
  const PoliticaPage({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
      ),
    );
  }
}
