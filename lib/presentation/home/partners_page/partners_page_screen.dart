import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; 
import 'package:bauauftrage/core/network/safe_http.dart';
import 'package:bauauftrage/common/utils/auth_utils.dart';

class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  late Future<List<Partner>> _partnersFuture;

  final String _apiKey = '1234567890abcdef'; 

  @override
  void initState() {
    super.initState();
    _partnersFuture = fetchPartners();
  }

  Future<List<Partner>> fetchPartners() async {
    if (!await isUserAuthenticated()) return [];
    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/partners?per_page=100');
    final response = await SafeHttp.safeGet(context, url, headers: {
      
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to load partners: ${response.statusCode}');
    }

    final List data = jsonDecode(response.body);
    List<Partner> partners = [];

    for (var item in data) {
      final title = item['title']?['rendered'] ?? 'No Title';
      final address = item['meta']?['adresse'] ?? 'No Address';
      final logoId = item['meta']?['logo']?['id'];

      partners.add(Partner(title: title, address: address, logoId: logoId));
    }

    return partners;
  }

  Future<String?> fetchLogoUrl(int logoId) async {
    if (!await isUserAuthenticated()) return null;
    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$logoId');
    final response = await SafeHttp.safeGet(context, url, headers: {
      'X-API-Key': _apiKey,
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data != null && data['source_url'] is String) {
        return data['source_url'];
      } else {
        print('Warning: "source_url" not found or not a string for logoId: $logoId');
        return null;
      }
    } else {
      print('Failed to load logo URL for ID $logoId: Status ${response.statusCode}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(title: const Text('Partner')),
      body: FutureBuilder<List<Partner>>(
        future: _partnersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _partnersFuture = fetchPartners(); 
                      });
                    },
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Keine Partner gefunden.'));
          }

          final partners = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.2 : 0.9,
            ),
            itemCount: partners.length,
            itemBuilder: (context, index) {
              final partner = partners[index];
              return Card(
                color: const Color.fromARGB(255, 255, 253, 252),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: partner.logoId != null
                            ? FutureBuilder<String?>(
                                future: fetchLogoUrl(partner.logoId!),
                                builder: (context, logoSnapshot) {
                                  if (logoSnapshot.connectionState == ConnectionState.waiting ||
                                      logoSnapshot.hasError ||
                                      logoSnapshot.data == null) {
                                    return const SizedBox(
                                      width: 80,
                                      height: 80,
                                    );
                                  }
                                  
                                  return SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: Image.network(
                                      logoSnapshot.data!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.broken_image,
                                          size: 40,
                                          color: Colors.grey,
                                        );
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return child;
                                      },
                                    ),
                                  );
                                },
                              )
                            : const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              partner.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              partner.address,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: MediaQuery.of(context).size.width > 600 ? 14 : 12,
                                color: const Color.fromARGB(255, 129, 129, 129),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class Partner {
  final String title;
  final String address;
  final int? logoId;

  Partner({
    required this.title,
    required this.address,
    this.logoId,
  });
}
