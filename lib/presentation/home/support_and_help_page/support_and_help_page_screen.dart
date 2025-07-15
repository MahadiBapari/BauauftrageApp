import 'package:flutter/material.dart';

class SupportAndHelpPageScreen extends StatelessWidget {
  const SupportAndHelpPageScreen({super.key});

  Widget _buildSectionHeader(String title) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[400])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSimpleDivider() {
    return Divider(
      color: Colors.grey[200],
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final faqList = [
      {
        'question': 'Was für Ufträgi cha ich uf Bauaufträge24.ch iistelle?',
        'answer': '''Uf Bauaufträge24.ch chasch viu verschideni Bau- und Handwerksufträgi iistelle. Egal ob chlii Reparature, Renovatione, Neubau oder spezifischi Handwerksarbeit – mir verbinde di mit qualifizierte, zertifizierte Handwerker für jedes Projekt.
Vo klassische Handwerksarbeit wie Malerarbeit, Elektrik, Sanitär bis zu komplexere Sache wie Fassade, Innenausbau oder Gartenarbeit – uf Bauaufträge24.ch findsch de richtige Handwerker für dini Bedürfnis.
Stell dis Projekt eifach i und lah der vo unsere Profis e Offert mache!'''
      },
      {
        'question': 'Was kostet es für Handwerker uf Bauaufträge24.ch?',
        'answer': '''Für Handwerker git es eimalig e Jahresgebühr vo 1290 CHF. Mit dere Gebühr hesch s’ganze Jahr Zuegriff uf alli Bauufträgi und chasch vo Kunde kontaktiert werde – kei versteckte Zusatzkoste oder Provision.
Mit dere Gebühr hesch volle Zuegriff uf viu Ufträgi und profitierst vo exklusiver Sichtbarkeit uf de Plattform. So chasch di uf dini Arbeit konzentriere – ohni di um meh Koste sorge z’müesse.'''
      },
      {
        'question': 'Wie weiss ich, dass de Handwerker zuverlässig und qualifiziert isch?',
        'answer': '''Ja, alli Handwerker uf Bauaufträge24.ch sind zertifiziert und verifiziert. Mir lueged druf, dass nur qualifizierte und vertrauenswürdigi Handwerker uf de Plattform sind. Jede Handwerker wird genau überprüeft, inklusiv Qualifikationen, Handelsregister und Berufserfahrung.
Zum sicherstelle, dass du uf Profis zelle chasch, mache mir au regelmässig Telefonate und persönlechi Bsuech. So chöi mir garantierä, dass üsi Handwerker zuverlässig sind und höchste Standards erfülle.'''
      },
      {
        'question': 'Cha ich de Handwerker direkt kontaktiere, zum Detail z’bspräche?',
        'answer': '''Ja, du chasch d’Handwerker direkt kontaktiere, zum alli Detail zu dim Projekt z’bspräche. Sobald du en Handwerker usgwehlt hesch, chasch mit ihm Kontakt ufneh und d’Einzelheitä kläre.
Au d’Handwerker chöi uf dini Aafrog reagiere und der e Offert mache. So chasch sicherstelle, dass alles klar isch, bevor s’Projekt startet, und de Handwerker ussuächä, wo am beschte zu dim Projekt passt.'''
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Support & Hilf'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Our Office Hours Section ---
          _buildSectionHeader('Üsi Öffnigsziite'),
          Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            child: const ListTile(
              leading: Icon(Icons.access_time, color: Colors.brown),
              title: Text(
                'Mo - Fr: 9:00 - 17:00 Uhr',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.normal),
              ),
              subtitle: Text(
                'Am Wucheend und an Feiertäg gschlosse',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          _buildSimpleDivider(),

          // --- Get in Touch Section ---
          _buildSectionHeader('Kontakt ufneh'),
          Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            child: const ListTile(
              leading: Icon(Icons.email_outlined, color: Colors.brown),
              title: Text(
                'info@bauaufellen24.ch',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.normal),
              ),
              subtitle: Text(
                'Schrieb üs dini Froge per Mail',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          _buildSimpleDivider(),
          Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            child: const ListTile(
              leading: Icon(Icons.phone_outlined, color: Colors.brown),
              title: Text(
                '+41 12 345 6789',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.normal),
              ),
              subtitle: Text(
                'Ruf a während de Öffnigsziite',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          _buildSimpleDivider(),
          const SizedBox(height: 24),

          // --- Frequently Asked Questions Section ---
          _buildSectionHeader('FAQ'),
          ...faqList.map((faq) => Column(
            children: [
              ExpansionTile(
                title: Text(
                  faq['question']!,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        faq['answer']!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ),
                ],
              ),
              _buildSimpleDivider(),
            ],
          )),
        ],
      ),
    );
  }
}
