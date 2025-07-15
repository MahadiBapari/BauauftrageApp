import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../screens/email_verification_screen.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:bauauftrage/core/network/safe_http.dart';

class RegisterContractorPage extends StatefulWidget {
  const RegisterContractorPage({super.key});

  @override
  State<RegisterContractorPage> createState() => _RegisterContractorPageState();
}

class _RegisterContractorPageState extends State<RegisterContractorPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firmController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();  
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  //final TextEditingController _availabletimeController = TextEditingController();
  bool _agreeToTerms = false;
  bool _isLoading = false;

  final String apiUrl =
      'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/register/';
  final String apiKey =
      '1234567890abcdef'; // Replace with your actual API key

  List<String> _selectedServiceCategories = [];
  late final Future<List<Map<String, dynamic>>> _serviceCategoriesFuture = _fetchServiceCategories();

  Future<List<Map<String, dynamic>>> _fetchServiceCategories() async {
    final response = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100'));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((item) => {
        'id': item['id'].toString(),
        'name': item['name'],
      }).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate() || !_agreeToTerms) return;

    setState(() => _isLoading = true);

    try {
      final response = await SafeHttp.safePost(context, Uri.parse(apiUrl), headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': apiKey,
      }, body: jsonEncode({
        'username': _emailController.text.trim(),
        'firmenname_': _firmController.text.trim(),
        'uid_nummer': _uidController.text.trim(),
        'email': _emailController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'user_phone_': _phoneController.text.trim(),
        'password': _passwordController.text,
        'available_time': _selectedCategory,
        'role': 'um_contractor',
        '_service_category_': _selectedServiceCategories.map((id) => int.tryParse(id) ?? 0).where((id) => id > 0).toList(),
        },
      ));

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Registration successful
        // Navigate to the email verification screen.  We no longer need the userId.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const EmailVerificationScreen(), // No params for normal registration
          ),
        );
      } else {
        // Registration failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Fehler: ${jsonDecode(response.body)['message'] ?? 'Unbekannter Fehler'}'),
            backgroundColor: const Color.fromARGB(160, 244, 67, 54),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } catch (e) {
      // Handle network errors
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: const Color.fromARGB(160, 244, 67, 54),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: SizedBox(
            width: 400,
            height: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description, size: 48, color: Color.fromARGB(255, 185, 7, 7)),
                const SizedBox(height: 16),
                const Text(
                  'Allgemeine Geschäftsbedingungen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Divider(),
                const Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      '''Allgemeine Geschäftsbedingungen (AGB)
Stand: 14.03.2025
Bauaufträge24.ch ist eine schweizerische Internet-Plattform für die Ausschreibung von Leistungen von Handwerkern und anderen Dienstleistern (nachfolgend die «Plattform»). Betreiberin der Plattform ist die Bauaufträge24.ch GmbH mit Sitz in Olten Basel (nachfolgend die «Betreiberin»). Auftraggeberinnen und Auftraggeber können die Plattform nutzen, um Aufträge auszuschreiben und zu vergeben. Anbieterinnen und Anbieter können die Plattform nutzen, um ausgeschriebene Aufträge anzunehmen und auszuführen.

Diese Allgemeinen Geschäftsbedingungen (AGB) regeln die Rechte und Pflichten von Auftraggeberinnen und Auftraggebern sowie Anbieterinnen und Anbietern (nachfolgend jeweils einheitlich die «Auftraggeber» und die «Anbieter», gemeinsam die «Nutzerinnen und Nutzer»). Für einzelne und/oder zusätzliche Funktionen und Leistungen können besondere und/oder ergänzende Bedingungen gelten.

1. Plattform von Bauaufträge24.ch
1.1
Die Betreiberin stellt den Nutzerinnen und Nutzern die Plattform für die Ausschreibung von Leistungen von Handwerkern und anderen Dienstleistern auf Zusehen hin zur Verfügung. Nutzerinnen und Nutzer können auf der Plattform in eigener Verantwortung untereinander Verträge abschliessen (nachfolgend die «Verträge»). Aus solchen Verträgen werden ausschliesslich die Nutzerinnen und Nutzer verpflichtet und die Vertragserfüllung liegt ausschliesslich in der Verantwortung von Nutzerinnen und Nutzern. Benachrichtigungen auf der Plattform im Zusammenhang mit Ausschreibungen und/oder Verträgen dienen ausschliesslich der Informationen der betreffenden Nutzerinnen und Nutzer.

1.2
Die Betreiberin ist weder Vertragspartei noch Vertreterin im Zusammenhang mit Verträgen. Die Betreiberin übernimmt insbesondere keinerlei Gewähr dafür, dass Nutzerinnen und Nutzer allfälligen untereinander bestehenden vertraglichen Verpflichtungen nachkommen. Die Abwicklung und/oder Durchsetzung von Verträgen obliegt den Nutzerinnen und Nutzern. Die Betreiberin erbringt keine entsprechenden Leistungen wie beispielsweise Inkasso oder Streitschlichtung.

1.3
Die Betreiberin übernimmt keinerlei Gewähr für die Angaben von Nutzerinnen und Nutzern wie beispielsweise zu beruflichen Fähigkeiten, Identität und Versicherungen von Anbietern. Nutzerinnen und Nutzer verpflichten sich, Ausschreibungen und sonstige Inhalte von anderen Nutzerinnen und Nutzern im Zweifelsfall selbst zu überprüfen. Bei Angaben, die durch die Betreiberin verifiziert wurden, besteht keine Gewähr, dass diese Angaben auch im Zeitablauf noch zutreffend sind. Die Betreiberin ist nicht verpflichtet, das Verhalten von Nutzerinnen und Nutzern auf der Plattform zu kontrollieren. Die Betreiberin ist insbesondere nicht verpflichtet, Ausschreibungen und sonstige Inhalte von Nutzerinnen und Nutzern auf ihre Rechtmässigkeit oder sonstige Zulässigkeit zu überprüfen.

1.4
Die Betreiberin bietet kostenlose und kostenpflichtige Funktionen und Leistungen auf der Plattform an. Die Betreiberin veröffentlicht den jeweils aktuellen Funktions- und Leistungsumfang unter Angabe von allfälligen Gebühren auf der Plattform.

1.5
Die Betreiberin ist berechtigt, den Funktionsumfang sowie Gebühren jederzeit zu ändern. Für bereits laufende kostenpflichtige Funktionen und Leistungen gelten solche Änderungen erst ab einer allfälligen weiteren Laufzeit. Die Nutzerinnen und Nutzer werden in geeigneter Art und Weise über solche Änderungen informiert.

2. Nutzung der Plattform
2.1
Die Nutzung der Plattform setzt eine Registrierung als Nutzerin oder Nutzer mit vollständigen und wahrheitsgetreuen Angaben voraus. Die Registrierung steht nur unbeschränkt handlungsfähigen, natürlichen oder juristischen Personen mit Wohnsitz oder Sitz in der Schweiz offen. Nach erfolgreicher Registrierung verfügen Nutzerinnen und Nutzer über ein eigenes Nutzerprofil auf der Plattform und können die Plattform als Auftraggeber oder Anbieter nutzen.

2.2
Die Registrierung mit falschen oder fiktiven Angaben ist untersagt. Für jede natürliche oder juristische Person ist nur eine Registrierung erlaubt. Die Angaben von Nutzerinnen und Nutzern müssen auch nach erfolgter Registrierung jederzeit vollständig und zutreffend sein. Die Betreiberin ist – auch nachträglich – berechtigt, Angaben von Nutzerinnen und Nutzern zu prüfen und/oder durch Dritte prüfen zu lassen sowie von Nutzerinnen und Nutzern ergänzende Angaben zu fordern. Die Betreiberin ist berechtigt, die Registrierung jederzeit – auch nachträglich – und ohne Angabe von Gründen zu verweigern.

2.3
Registrierte Nutzerinnen und Nutzer dürfen ausschliesslich für ihren eigenen, auch gewerbsmässigen, Gebrauch auf die Plattform zugreifen. Registrierte Nutzerinnen und Nutzer verpflichten sich, ihre Zugangsdaten zur Plattform vertraulich zu behandeln und ausschliesslich selbst zu verwenden. Nutzerinnen und Nutzer sind nicht berechtigt, ihren Zugang zur Plattform direkt oder indirekt Dritten entgeltlich oder unentgeltlich zur Verfügung zu stellen. Die Betreiberin ist berechtigt, Nutzerinnen und Nutzern den Zugang zur Plattform jederzeit und ohne Angabe von Gründen zu verweigern. Sofern der Zugriff aufgrund einer Verletzung dieser AGB verweigert wird, bleiben allfällige Gebühren geschuldet. Nutzerinnen und Nutzer sind unabhängig davon verpflichtet, allfälligen untereinander and/or gegenüber der Betreiberin bestehenden vertraglichen Verpflichtungen nachzukommen.

2.4
Registrierte Nutzerinnen und Nutzer können über die Plattform miteinander kommunizieren. Diese Kommunikation ist ausschliesslich im Zusammenhang mit Ausschreibungen zulässig und darf insbesondere keine unerwünschte Werbung umfassen.

2.5
Die Nutzung der Plattform kann, insbesondere aus technischen Gründen, zeitweilig sowie teilweise oder vollständig nicht möglich sein. Die Betreiberin übernimmt keinerlei Gewährleistung für die Verfügbarkeit der Plattform sowie für die Aktualität, die Richtigkeit und/oder die Vollständigkeit von Ausschreibungen.''',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 185, 7, 7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Schließen', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firmController.dispose();
    _uidController.dispose(); 
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _selectedCategory;

  final List<String> _categories = [
    '08.00 - 12.00 Uhr',
    '12.00 - 14.00 Uhr',
    '14.00 - 18.00 Uhr',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Image.asset(
                'assets/images/logolight.png',
                height: 60,
              ),
              const SizedBox(height: 20),
              const Text(
                'Konto als Unternehmer erstellen',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _firmController,
                decoration: InputDecoration(
                  labelText: 'Firmenname',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Firmenname ist erforderlich' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _uidController,
                decoration: InputDecoration(
                  labelText: 'UID-Nummer',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'UID-Nummer ist erforderlich' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-Mail',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'E-Mail ist erforderlich';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'Vorname',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Nachname',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telefonnummer',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Telefonnummer ist erforderlich' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Passwort',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) =>
                    (value?.length ?? 0) < 6 ? 'Das Passwort muss mindestens 6 Zeichen lang sein' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Passwort bestätigen',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) => value != _passwordController.text
                    ? 'Passwörter stimmen nicht überein'
                    : null,
              ),
              const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Verfügbari Zyt',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                    onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                    },
                    validator: (value) =>
                      value == null || value.isEmpty ? 'Kategorie isch nötig' : null,
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Map<String, dynamic>>>(
                  future: _serviceCategoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                    // Zeig en moderner Platzhalter statt CircularProgressIndicator
                    return Container(
                      height: 56,
                      decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                      children: [
                        Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                        width: 120,
                        height: 16,
                        color: Colors.grey[300],
                        ),
                      ],
                      ),
                    );
                    } else if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Fehler bim Lade vo de Kategorie', style: TextStyle(color: Colors.red[800]))),
                      ],
                      ),
                    );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                      color: Colors.yellow[50],
                      borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Kei Kategorie gfunde', style: TextStyle(color: Colors.orange))),
                      ],
                      ),
                    );
                    } else {
                    final categories = snapshot.data!;
                    return Container(
                      decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color.fromARGB(255, 255, 255, 255)!),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      child: MultiSelectDialogField(
                      backgroundColor: Colors.white,
                      items: categories
                        .map((category) => MultiSelectItem(
                          category['id'].toString(), category['name']))
                        .toList(),
                      title: const Text("Service Kategorie"),
                      selectedColor: const Color.fromARGB(255, 185, 33, 33),
                      cancelText: const Text("", style: TextStyle(fontSize: 0)), 
                      confirmText: const Text("OK", style: TextStyle(color: Color.fromARGB(255, 185, 33, 33), fontWeight: FontWeight.bold)),
                      dialogWidth: 400,
                      dialogHeight: 500,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.transparent),
                      ),
                      buttonIcon: const Icon(Icons.category, color: Color.fromARGB(255, 185, 33, 33)),
                      buttonText: Text(
                        _selectedServiceCategories.isEmpty
                          ? "Service Kategorie ussuewähle*"
                          : "${_selectedServiceCategories.length} Kategorie(n) ausgewählt",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      onConfirm: (values) {
                        setState(() => _selectedServiceCategories = values.cast<String>());
                      },
                      chipDisplay: MultiSelectChipDisplay(
                        chipColor: Colors.red.shade50,
                        textStyle: TextStyle(color: Colors.red.shade800),
                        onTap: (value) {
                          setState(() {
                            _selectedServiceCategories.remove(value);
                          });
                        },
                      ),
                      validator: (value) => value == null || value.isEmpty
                        ? 'Bitte wähl mindestens eini Kategorie us'
                        : null,
                      ),
                    );
                    }
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                  const Text('Ich akzeptiere die '),
                  GestureDetector(
                    onTap: _showTermsDialog,
                    child: const Text(
                    'Allgemeinen Geschäftsbedingungen',
                    style: TextStyle(color: Color.fromARGB(255, 201, 45, 45)),
                    ),
                  ),
                  ],
                ),
                value: _agreeToTerms,
                onChanged: (bool? value) {
                  setState(() {
                    _agreeToTerms = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.red.shade800,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: const Text(
                        'Registrieren',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Sie haben bereits ein Konto?"),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: Text(
                      'Anmelden',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

