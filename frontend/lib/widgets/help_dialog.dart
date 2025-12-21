import 'package:flutter/material.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('How to Use Move & Draw'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('Getting Started', [
                      'Move & Draw turns your fitness journey into art!',
                      'As you move, the app draws your path on the map.',
                      'Note: if you joined as a guest, you will have limited functionality. Login to access all features.',
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Drawing on the Map', [
                      '1. Choose your color using the color picker',
                      '2. Select brush size (thickness of your drawing line)',
                      '3. Tap the play button to start drawing',
                      '4. Move around - your path will be drawn automatically',
                      '5. Tap pause to temporarily stop drawing',
                      '6. Tap stop (save drawing) when you\'re done with your route',
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Ink Points', [
                      'Each point you draw consumes ink points.',
                      'The ink counter shows your remaining points.',
                      'The ink regenerates every hour. Maximum ink capacity is 5000 points.',
                      'Make sure you have enough ink before starting a long route!',
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Saving Your Drawing', [
                      'After pressing the stop button, you can save your drawing.',
                      'Give it a title and description.',
                      'Decide if you want to share the drawing publicly and allow other artists to comment.',
                      'Your saved drawings appear in the Drawings tab.',
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Viewing Drawings', [
                      'Switch to the Drawings tab to see all saved artwork.',
                      'Search for drawings by title or description.',
                      'Tap on a drawing to view it in fullscreen.',
                      'Sort drawings by date or popularity.',
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Artist name', [
                      'If you decide to share your drawings publicly create an artist name.',
                      'If you don\'t create an artist name, your full name will be displayed.',
                      'Create an artist name by clicking on the user icon.',
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
