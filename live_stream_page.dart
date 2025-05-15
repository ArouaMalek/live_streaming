import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class LiveStreamPage extends StatefulWidget {
  const LiveStreamPage({super.key});

  @override
  _LiveStreamPageState createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  final _logger = Logger('LiveStreamPage');
  final String _streamUrl = 'http://192.168.222.213:5000/video_feed';
  bool _isLoading = true;
  bool _isOnline = false;
  String _errorMessage = '';
  String _currentTime = '';
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _logger.info('Initialisation de LiveStreamPage');
    _checkStreamStatus();
    // Mettre à jour l'heure toutes les secondes
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime =
              DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _checkStreamStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final statusUrl = 'http://192.168.222.213:5000/status';
      _logger.info('Tentative de connexion à $statusUrl');
      final response =
          await http.get(Uri.parse(statusUrl)).timeout(Duration(seconds: 10));
      _logger.info('Code de réponse : ${response.statusCode}');
      _logger.info('Corps de la réponse : ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _isOnline = true;
          _isLoading = false;
          _logger.info('Caméra en ligne : _isOnline = true');
        });
      } else {
        setState(() {
          _isOnline = false;
          _isLoading = false;
          _errorMessage = 'Erreur : Aucun signal';
          _logger.warning('Caméra hors ligne ou non alimentée');
        });
      }
    } catch (e) {
      _logger.warning('Erreur détaillée : $e');

      if (!mounted) return;

      setState(() {
        _isOnline = false;
        _isLoading = false;
        _errorMessage = 'Erreur : Aucun signal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.info(
        'Construction de l\'interface : _isOnline = $_isOnline, _errorMessage = $_errorMessage');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Surveillance Ferme'),
        backgroundColor: const Color(0xFFDF8800),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkStreamStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: _isOnline ? Colors.green[100] : Colors.red[100],
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.videocam : Icons.signal_wifi_off,
                  color: _isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  _isOnline
                      ? 'Caméra active - Diffusion en direct'
                      : 'Caméra hors ligne',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isOnline ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Text(
              'Date et heure: $_currentTime',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isOnline
                    ? Mjpeg(
                        isLive: _isOnline,
                        stream: _streamUrl,
                        fit: BoxFit.contain,
                        error: (context, error, stack) {
                          _logger.warning('Mjpeg erreur : $error');
                          setState(() {
                            _isOnline = false;
                            _errorMessage = 'Erreur : Aucun signal';
                          });
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.videocam_off,
                                    size: 80, color: Colors.grey),
                                const SizedBox(height: 20),
                                const Text(
                                  'Erreur : Aucun signal',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _checkStreamStatus,
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_off,
                                size: 80, color: Colors.grey),
                            const SizedBox(height: 20),
                            Text(
                              _errorMessage,
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _checkStreamStatus,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
