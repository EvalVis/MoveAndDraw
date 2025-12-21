import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'drawings_screen.dart';
import '../services/consent_service.dart';
import '../widgets/consent_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _drawingsKey = 0;
  bool _consentChecked = false;
  bool _hasConsent = false;
  final _consentService = ConsentService();

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    final hasAllConsents = await _consentService.hasAllConsents();
    
    if (!hasAllConsents && mounted) {
      final result = await showDialog<Map<String, bool>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ConsentDialog(),
      );

      if (result != null && mounted) {
        await _consentService.setGoogleDataConsent(result['googleDataConsent'] ?? false);
        await _consentService.setLocationDataConsent(result['locationDataConsent'] ?? false);
        
        final newConsent = (result['googleDataConsent'] ?? false) && 
                          (result['locationDataConsent'] ?? false);
        
        setState(() {
          _hasConsent = newConsent;
          _consentChecked = true;
        });

        if (!newConsent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Consent is required to use location and Google services.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _hasConsent = false;
          _consentChecked = true;
        });
      }
    } else {
      setState(() {
        _hasConsent = hasAllConsents;
        _consentChecked = true;
      });
    }
  }

  void _onTabTapped(int index) {
    if (index == 1) {
      _drawingsKey++;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (!_consentChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasConsent) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Consent Required',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please provide consent to use location and Google services.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _checkConsent,
                child: const Text('Review Consent'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const MapScreen(),
          DrawingsScreen(key: ValueKey(_drawingsKey)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.brush),
            label: 'Drawings',
          ),
        ],
      ),
    );
  }
}



