import 'package:flutter/material.dart';

class ConsentDialog extends StatefulWidget {
  final bool showGoogleDataConsent;
  final bool showLocationDataConsent;

  const ConsentDialog({
    super.key,
    this.showGoogleDataConsent = true,
    this.showLocationDataConsent = true,
  });

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _googleDataConsent = false;
  bool _locationDataConsent = false;

  @override
  Widget build(BuildContext context) {
    final hasBoth =
        widget.showGoogleDataConsent && widget.showLocationDataConsent;

    return AlertDialog(
      title: const Text('Data and Location Consent'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showGoogleDataConsent) ...[
              const Text(
                'Google Services Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'This app uses Google services (Google Maps and Google Sign-In) which may collect and process data according to Google\'s Privacy Policy. By using these services, you agree to Google\'s data collection practices.',
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _googleDataConsent,
                onChanged: (value) {
                  setState(() {
                    _googleDataConsent = value ?? false;
                  });
                },
                title: const Text('I consent to Google data collection'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (hasBoth) const SizedBox(height: 24),
            ],
            if (widget.showLocationDataConsent) ...[
              const Text(
                'Location Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'This app collects your location data to enable drawing on the map as you move. Your location data is stored locally on your device however it is published to our servers when you save the drawing.',
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _locationDataConsent,
                onChanged: (value) {
                  setState(() {
                    _locationDataConsent = value ?? false;
                  });
                },
                title: const Text('I consent to location data collection'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop({'googleDataConsent': false, 'locationDataConsent': false}),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: _canProceed()
              ? () => Navigator.of(context).pop({
                  'googleDataConsent': _googleDataConsent,
                  'locationDataConsent': _locationDataConsent,
                })
              : null,
          child: const Text('Accept'),
        ),
      ],
    );
  }

  bool _canProceed() {
    bool canProceed = true;
    if (widget.showGoogleDataConsent && !_googleDataConsent) {
      canProceed = false;
    }
    if (widget.showLocationDataConsent && !_locationDataConsent) {
      canProceed = false;
    }
    return canProceed;
  }
}
