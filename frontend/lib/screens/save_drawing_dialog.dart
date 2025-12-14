import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../services/google_auth_service.dart';
import '../services/guest_service.dart';

class SaveDrawingResult {
  final bool saved;
  final bool discarded;
  final int? inkRemaining;

  SaveDrawingResult({
    this.saved = false,
    this.discarded = false,
    this.inkRemaining,
  });
}

class SaveDrawingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> segments;
  final bool isGuest;

  const SaveDrawingDialog({
    super.key,
    required this.segments,
    required this.isGuest,
  });

  @override
  State<SaveDrawingDialog> createState() => _SaveDrawingDialogState();
}

class _SaveDrawingDialogState extends State<SaveDrawingDialog> {
  final _nameController = TextEditingController();
  final _authService = GoogleAuthService();
  final _guestService = GuestService();
  bool _commentsEnabled = true;
  bool _isPublic = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    if (widget.isGuest) {
      await _saveAsGuest();
    } else {
      await _saveAsUser();
    }
  }

  Future<void> _saveAsGuest() async {
    final success = await _guestService.saveDrawing(
      title: _nameController.text,
      segments: widget.segments,
    );

    if (success) {
      if (mounted) {
        Navigator.of(context).pop(
          SaveDrawingResult(saved: true, inkRemaining: _guestService.ink),
        );
      }
    } else {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough ink!')),
        );
      }
    }
  }

  Future<void> _saveAsUser() async {
    final token = await _authService.getIdToken();
    if (token == null) {
      setState(() => _isSaving = false);
      return;
    }

    final response = await http.post(
      Uri.parse('${dotenv.env['BACKEND_URL']}/drawings/save'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': _nameController.text,
        'segments': widget.segments,
        'commentsEnabled': _commentsEnabled,
        'isPublic': _isPublic,
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      Navigator.of(context).pop(
        SaveDrawingResult(saved: true, inkRemaining: data['inkRemaining']),
      );
    } else if (response.statusCode == 400) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough ink!')),
      );
    } else {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Drawing?'),
        content: const Text('Are you sure? Your drawing will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.of(context).pop(SaveDrawingResult(discarded: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Drawing'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Drawing Name',
              hintText: 'Enter a name for your drawing',
            ),
            autofocus: true,
            enabled: !_isSaving,
          ),
          if (widget.isGuest) ...[
            const SizedBox(height: 8),
            Text(
              'Guest drawings are saved locally only',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Public'),
              subtitle: const Text('Visible to everyone'),
              value: _isPublic,
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _isPublic = value ?? true),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Allow comments'),
              value: _commentsEnabled,
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _commentsEnabled = value ?? true),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: _isSaving
          ? [const Center(child: CircularProgressIndicator())]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: _confirmDiscard,
                child: const Text('Discard'),
              ),
              ElevatedButton(
                onPressed: _save,
                child: Text(widget.isGuest ? 'Save' : 'Submit'),
              ),
            ],
    );
  }
}

