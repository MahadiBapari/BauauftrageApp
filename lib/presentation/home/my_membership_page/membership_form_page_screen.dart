import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

class MembershipFormPageScreen extends StatefulWidget {
  const MembershipFormPageScreen({super.key});

  @override
  State<MembershipFormPageScreen> createState() =>
      _MembershipFormPageScreenState();
}

class _MembershipFormPageScreenState
    extends State<MembershipFormPageScreen> {
  String? membershipName;
  int? initialPayment;
  String? userEmail;
  bool isLoading = true;
  String? errorMessage;
  bool agreeToTerms = false;
  bool _isProcessing = false;

  CardFieldInputDetails? _card;

  @override
  void initState() {
    super.initState();
    _fetchMembershipAndUser();
  }

  Future<void> _fetchMembershipAndUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      userEmail = prefs.getString('user_email');
      if (token == null) {
        setState(() {
          errorMessage = 'Nicht authentifiziert.';
          isLoading = false;
        });
        return;
      }
      final response = await http.get(
        Uri.parse(
            'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/membership/1'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['level'] != null) {
          setState(() {
            membershipName = data['level']['name'] ?? '';
            initialPayment = data['level']['initial_payment'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Mitgliedschaftsinformationen konnten nicht geladen werden.';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Mitgliedschaftsinformationen konnten nicht geladen werden.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Fehler: $e';
        isLoading = false;
      });
    }
  }

  String _formatPrice(int? price) {
    if (price == null) return '';
    final priceStr = price.toString();
    final formatted = priceStr.length > 3
        ? "${priceStr.substring(0, priceStr.length - 3)}'${priceStr.substring(priceStr.length - 3)}"
        : priceStr;
    return "$formatted.00 CHF pro Jahr";
  }

  Future<void> _handleBuyMembership() async {
    if (_card == null || !_card!.complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bitte füllen Sie die Kartendaten vollständig aus.'),
          backgroundColor: const Color.fromARGB(160, 244, 67, 54),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userEmail = prefs.getString('user_email');
      final userName = prefs.getString('displayName'); // full name

      if (userEmail == null || userName == null) {
        throw Exception('Benutzerdaten fehlen. Bitte melden Sie sich erneut an.');
      }
      if (token == null) {
        throw Exception('Benutzer nicht authentifiziert. Bitte melden Sie sich erneut an.');
      }

      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(email: userEmail),
          ),
        ),
      );

      final response = await http.post(
        Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/bongdevs/v1/pmpro-subscribe'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': userEmail,
          'name': userName, // full name
          'level_id': 1, // or the correct level if dynamic
          'payment_method_id': paymentMethod.id,
        }),
      );

      final data = jsonDecode(response.body);

      print('API response: \\n${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        final expires = data['expires'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mitgliedschaft aktiv bis $expires. '),
            backgroundColor: const Color.fromARGB(129, 0, 0, 0),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception(data['error'] ?? 'Failed to purchase membership.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Fehler: $e'),
          backgroundColor: const Color.fromARGB(160, 244, 67, 54),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
            height: 600, // Increased height for a taller dialog
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description,
                    size: 48, color: Color.fromARGB(255, 185, 7, 7)),
                const SizedBox(height: 16),
                const Text(
                  'Allgemeine Geschäftsbedingungen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Divider(),
                Expanded(
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
Registrierte Nutzerinnen und Nutzer dürfen ausschliesslich für ihren eigenen, auch gewerbsmässigen, Gebrauch auf die Plattform zugreifen. Registrierte Nutzerinnen und Nutzer verpflichten sich, ihre Zugangsdaten zur Plattform vertraulich zu behandeln und ausschliesslich selbst zu verwenden. Nutzerinnen und Nutzer sind nicht berechtigt, ihren Zugang zur Plattform direkt oder indirekt Dritten entgeltlich oder unentgeltlich zur Verfügung zu stellen. Die Betreiberin ist berechtigt, Nutzerinnen und Nutzern den Zugang zur Plattform jederzeit und ohne Angabe von Gründen zu verweigern. Sofern der Zugriff aufgrund einer Verletzung dieser AGB verweigert wird, bleiben allfällige Gebühren geschuldet. Nutzerinnen und Nutzer sind unabhängig davon verpflichtet, allfälligen untereinander und/oder gegenüber der Betreiberin bestehenden vertraglichen Verpflichtungen nachzukommen.

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
                      backgroundColor: const Color.fromARGB(255, 185, 7, 7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child:
                        const Text('Schliessen', style: TextStyle(fontSize: 16)),
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
  Widget build(BuildContext context) {
    final Color lightText = Colors.grey[600]!;
    final Color lighterText = Colors.grey[400]!;
    final Color lightTitle = Colors.grey[800]!;

    return Scaffold(
      appBar: AppBar(
       // title: const Text('Buy Membership'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: lightTitle,
      ),
      backgroundColor: Colors.white,
      body: AbsorbPointer(
        absorbing: _isProcessing,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
                    child: Text(errorMessage!,
                        style: TextStyle(color: Colors.red[300])))
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Membership Info Card
                              Card(
                                color: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                                margin: const EdgeInsets.only(bottom: 18),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Informationen zur Mitgliedschaft',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                            color: lightTitle),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Mitgliedschaftsstufe des Auftragnehmers. ',
                                        style: TextStyle(
                                            fontSize: 15, color: lightText),
                                      ),
                                      // RichText(
                                      //   text: TextSpan(
                                      //     style: TextStyle(
                                      //         fontSize: 15, color: lightText),
                                      //     children: [
                                      //       TextSpan(
                                      //           text: membershipName ?? '',
                                      //           style: TextStyle(
                                      //               fontWeight: FontWeight.bold,
                                      //               color: lightTitle)),
                                      //       TextSpan(
                                      //           text: ' ausgewählt.',
                                      //           style: TextStyle(
                                      //               fontWeight: FontWeight.normal,
                                      //               color: lightText)),
                                      //     ],
                                      //   ),
                                      // ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Der Preis für die Mitgliedschaft beträgt ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.normal,
                                            color: lightText),
                                      ),
                                      Text(
                                        initialPayment != null
                                            ? _formatPrice(initialPayment)
                                            : '',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color: lightTitle),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Die Mitgliedschaft ist für 1 Jahr gültig und kann danach ganz bequem verlängert werden.',
                                        style:
                                            TextStyle(fontSize: 15, color: lightText),
                                      ),
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: isLoading || _isProcessing
                                              ? null
                                              : () {
                                                  showModalBottomSheet(
                                                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                                                    context: context,
                                                    isScrollControlled: true,
                                                    shape: const RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                                    ),
                                                    builder: (context) => Padding(
                                                      padding: EdgeInsets.only(
                                                        bottom: MediaQuery.of(context).viewInsets.bottom,
                                                      ),
                                                      child: StatefulBuilder(
                                                        builder: (context, setModalState) {
                                                          return Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    const Text(
                                                                        'Füg dini Zahlungsinformation zue',
                                                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color.fromARGB(255, 0, 0, 0)),
                                                                    ),
                                                                    IconButton(
                                                                      icon: const Icon(Icons.close),
                                                                      onPressed: () => Navigator.pop(context),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(height: 16),
                                                                CardFormField(
                                                                  style: CardFormStyle(
                                                                  backgroundColor: const Color.fromARGB(255, 255, 255, 255), // or Colors.black for dark
                                                                  textColor: const Color.fromARGB(255, 0, 0, 0),       // or Colors.white for dark
                              
                                                                  placeholderColor: Colors.grey,
                                                                ),
                                                                  onCardChanged: (card) {
                                                                    setModalState(() {
                                                                      _card = card;
                                                                    });
                                                                  },
                                                                ),
                                                                const SizedBox(height: 16),
                                                                LayoutBuilder(
                                                                  builder: (context, constraints) {
                                                                  final isSmallScreen = constraints.maxWidth < 400;
                                                                  return Row(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                    Checkbox(
                                                                      value: agreeToTerms,
                                                                      onChanged: (val) => setModalState(() => agreeToTerms = val ?? false),
                                                                      activeColor: const Color.fromARGB(255, 185, 33, 33),
                                                                    ),
                                                                    Expanded(
                                                                      child: Wrap(
                                                                      alignment: WrapAlignment.start,
                                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                                      spacing: 2,
                                                                      runSpacing: isSmallScreen ? 4 : 0,
                                                                      children: [
                                                                        Text('Ich stimme den ', style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0))),
                                                                        GestureDetector(
                                                                        onTap: _showTermsDialog,
                                                                        child: Text(
                                                                          'Allgemeinen Geschäftsbedingungen',
                                                                          style: TextStyle(color: const Color.fromARGB(255, 201, 45, 45)),
                                                                        ),
                                                                        ),
                                                                        //Text(' *', style: TextStyle(color: lighterText)),
                                                                      ],
                                                                      ),
                                                                    ),
                                                                    ],
                                                                  );
                                                                  },
                                                                ),
                                                                const SizedBox(height: 8),
                                                                SizedBox(
                                                                  width: double.infinity,
                                                                  child: ElevatedButton(
                                                                    onPressed: (_card != null && _card!.complete && agreeToTerms && !_isProcessing)
                                                                        ? () async {
                                                                            Navigator.pop(context); // Close modal
                                                                            await _handleBuyMembership();
                                                                          }
                                                                        : null,
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: const Color.fromARGB(255, 185, 33, 33),
                                                                      foregroundColor: Colors.white,
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                                                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                                      elevation: 2,
                                                                    ),
                                                                    child: _isProcessing
                                                                        ? const SizedBox(
                                                                            height: 24,
                                                                            width: 24,
                                                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                                                          )
                                                                        : Text('Bezahlen ' + (initialPayment != null ? _formatPrice(initialPayment) : '')),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color.fromARGB(255, 185, 33, 33),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            elevation: 2,
                                          ),
                                          child: const Text('Jetzt kaufen'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}