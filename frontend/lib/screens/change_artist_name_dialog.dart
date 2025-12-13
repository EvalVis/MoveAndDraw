import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../services/google_auth_service.dart';

class ChangeArtistNameDialog extends StatefulWidget {
  final String? currentName;

  const ChangeArtistNameDialog({super.key, this.currentName});

  @override
  State<ChangeArtistNameDialog> createState() => _ChangeArtistNameDialogState();
}

class _ChangeArtistNameDialogState extends State<ChangeArtistNameDialog> {
  late final TextEditingController _controller;
  final _authService = GoogleAuthService();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty) {
      setState(() => _errorMessage = 'Name cannot be empty');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = await _authService.getIdToken();
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    final response = await http.put(
      Uri.parse('${dotenv.env['BACKEND_URL']}/user/artist-name'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'artistName': newName}),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      Navigator.pop(context, newName);
    } else if (response.statusCode == 409) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Name already taken';
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Artist Name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Artist Name',
              errorText: _errorMessage,
            ),
            maxLength: 100,
            enabled: !_isLoading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

