import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:bauauftrage/core/network/safe_http.dart';
import 'package:bauauftrage/common/utils/auth_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'membership_form_page_screen.dart'; 

class MyMembershipPageScreen extends StatefulWidget {
  const MyMembershipPageScreen({super.key});

  @override
  State<MyMembershipPageScreen> createState() => _MyMembershipPageScreenState();
}

class _MyMembershipPageScreenState extends State<MyMembershipPageScreen> {
  bool _isLoading = true;
  bool _isActiveMembership = false;
  String _membershipTypeName = 'N/A';
  String _startDate = 'N/A'; // To store start date
  String _expiryDate = 'N/A';
  String _errorMessage = '';

  final String _membershipEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/user-membership';
  final String _cancelMembershipEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/cancel-membership'; 
  final String _apiKey = '1234567890abcdef'; 

  @override
  void initState() {
    super.initState();
    _fetchMembershipDetails();
  }

  Future<void> _fetchMembershipDetails() async {
    if (!await isUserAuthenticated()) return;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = ''; 
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Authentifizierungstoken nicht gefunden. Bitte melden Sie sich erneut an.';
            _isActiveMembership = false; 
          });
        }
        return;
      }

      final response = await SafeHttp.safeGet(context, Uri.parse(_membershipEndpoint), headers: {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        'Authorization': 'Bearer $authToken', 
      });

      if (!mounted) return; 

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        
        if (data['success'] == true && data['active'] == true) {
          final level = data['level'];
          final int? startDateTimestamp = int.tryParse(level['startdate'].toString());

          String formattedStartDate = 'N/A';
          if (startDateTimestamp != null) {
            final DateTime startDateTime = DateTime.fromMillisecondsSinceEpoch(startDateTimestamp * 1000);
            formattedStartDate = DateFormat('MMMM d, yyyy').format(startDateTime);
          }

          // Prefer the new 'expires' field if present
          String formattedExpiryDate = 'N/A';
          if (data['expires'] != null && data['expires'].toString().isNotEmpty) {
            try {
              formattedExpiryDate = DateFormat('MMMM d, yyyy').format(DateTime.parse(data['expires']));
            } catch (e) {
              formattedExpiryDate = data['expires'].toString();
            }
          } else if (level['enddate'] != null) {
            final int? endDateTimestamp = int.tryParse(level['enddate'].toString());
            if (endDateTimestamp != null) {
              final DateTime expiryDateTime = DateTime.fromMillisecondsSinceEpoch(endDateTimestamp * 1000);
              formattedExpiryDate = DateFormat('MMMM d, yyyy').format(expiryDateTime);
            }
          }

          setState(() {
            _isActiveMembership = true;
            _membershipTypeName = level['name'] ?? 'N/A';
            _startDate = formattedStartDate; 
            _expiryDate = formattedExpiryDate;
          });
        } else {
          
          setState(() {
            _isActiveMembership = false;
            _membershipTypeName = 'No active membership'; 
            _startDate = 'N/A';
            _expiryDate = 'N/A';
          });
        }
      } else {
        // API returned an error status code
        _errorMessage = 'Mitgliedschaft konnte nicht geladen werden: ${response.statusCode} - ${response.body}';
        debugPrint(_errorMessage);
        if (mounted) {
          setState(() {
            _isActiveMembership = false; 
          });
        }
      }
    } catch (e) {
      
      _errorMessage = 'Fehler beim Laden der Mitgliedschaft: $e';
      debugPrint(_errorMessage);
      if (mounted) {
        setState(() {
          _isActiveMembership = false; 
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to hit the cancel membership endpoint
  Future<void> _cancelMembershipApiCall(String jwtToken) async {
    if (!await isUserAuthenticated()) return;
    try {
      final response = await SafeHttp.safePost(context, Uri.parse(_cancelMembershipEndpoint), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwtToken',
      });

      final data = jsonDecode(response.body);

      if (!mounted) return; 

      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint('Mitgliedschaft gekündigt: ${data['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mitgliedschaft gekündigt: ${data['message']}'),
            backgroundColor: const Color.fromARGB(129, 0, 0, 0),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      
        _fetchMembershipDetails();
      } else {
        debugPrint('Kündigung der Mitgliedschaft fehlgeschlagen: ${data['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kündigung der Mitgliedschaft fehlgeschlagen: ${data['message']}'),
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
      debugPrint('Fehler beim Kündigen der Mitgliedschaft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Kündigen der Mitgliedschaft: $e'),
            backgroundColor: const Color.fromARGB(160, 244, 67, 54),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    }
  }

  // Method to show confirmation dialog
  void _confirmCancelMembership() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel, size: 48, color: const Color.fromARGB(255, 185, 7, 7)),
          const SizedBox(height: 16),
          const Text(
            'Mitgliedschaft kündigen',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sind Sie sicher, dass Sie Ihre Mitgliedschaft kündigen möchten? Diese Aktion kann nicht rückgängig gemacht werden.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
            'Nein',
            style: TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 185, 7, 7),
            ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 185, 7, 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
            'Ja, kündigen',
            style: TextStyle(fontSize: 16, color: Colors.white),
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

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken != null) {
        _cancelMembershipApiCall(authToken);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Kein Authentifizierungstoken gefunden. Bitte melden Sie sich an.'),
              backgroundColor: const Color.fromARGB(160, 244, 67, 54),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255), // White background
     
      body: _isLoading
          ? _buildMembershipShimmer()
          : _errorMessage.isNotEmpty // Show error message if present
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchMembershipDetails, // Retry button
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      
                      if (_isActiveMembership)
                        // Active Membership Card
                        _buildMembershipCard(
                          context,
                          membershipType: _membershipTypeName,
                          startDate: _startDate, 
                          expiryDate: _expiryDate,
                          showActions: true,
                        )
                      else
                        // Inactive Membership Card (Get Membership)
                        _buildInactiveMembershipCard(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMembershipShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 150, height: 20, color: Colors.white),
                      Container(width: 50, height: 12, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 50, height: 14, color: Colors.white),
                          const SizedBox(height: 4),
                          Container(width: 100, height: 16, color: Colors.white),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 50, height: 14, color: Colors.white),
                          const SizedBox(height: 4),
                          Container(width: 100, height: 16, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(width: 60, height: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Container(width: 120, height: 16, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipCard(
    BuildContext context, {
    required String membershipType,
    required String startDate,
    required String expiryDate,
    bool showActions = false,
  }) {
    return Card(
      elevation: 0, 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              spreadRadius: 1.5,
              blurRadius: 10,
              offset: const Offset(0, 0), 
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    membershipType,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Colors.green,
                        size: 10,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Aktive Mitgliedschaft',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                          color: Color.fromARGB(255, 46, 46, 46),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beginnt',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        startDate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Läuft ab',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expiryDate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (showActions) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Renew button pressed!'),
                            backgroundColor: const Color.fromARGB(129, 0, 0, 0),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.all(10),
                          ),
                        );
                        // TODO: Implement actual renew logic here 
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color.fromARGB(255, 185, 33, 33),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Erneuern',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 20,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _confirmCancelMembership,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color.fromARGB(255, 185, 33, 33),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Mitgliedschaft kündigen',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInactiveMembershipCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, 
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Keine aktive Mitgliedschaft gefunden.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Es sieht so aus, als wäre Ihre Mitgliedschaft abgelaufen oder Sie haben noch keine. Erwerben Sie eine Mitgliedschaft, um alle Funktionen freizuschalten!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, 
              child: ElevatedButton(
                onPressed: () async {
                  // Navigate to the membership form page
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MembershipFormPageScreen(),
                    ),
                  );

                  // If the result is true, it means the purchase was successful.
                  if (result == true && mounted) {
                    _fetchMembershipDetails();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 185, 33, 33), 
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Mitgliedschaft erwerben',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}