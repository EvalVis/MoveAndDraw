import 'package:flutter/material.dart';

class BrushSizePicker extends StatefulWidget {
  final int selectedSize;
  final ValueChanged<int> onSizeChanged;

  const BrushSizePicker({
    super.key,
    required this.selectedSize,
    required this.onSizeChanged,
  });

  @override
  State<BrushSizePicker> createState() => _BrushSizePickerState();
}

class _BrushSizePickerState extends State<BrushSizePicker> {
  OverlayEntry? _overlayEntry;
  final _buttonKey = GlobalKey();

  void _showSlider() {
    if (_overlayEntry != null) {
      _hideSlider();
      return;
    }

    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideSlider,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: position.dy + size.height + 8,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Brush Size: ${widget.selectedSize}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setSliderState) {
                        void updateSize(int newSize) {
                          final clamped = newSize.clamp(1, 100);
                          widget.onSizeChanged(clamped);
                          setSliderState(() {});
                          _overlayEntry?.markNeedsBuild();
                        }

                        return Row(
                          children: [
                            IconButton(
                              onPressed: widget.selectedSize > 1
                                  ? () => updateSize(widget.selectedSize - 1)
                                  : null,
                              icon: const Icon(Icons.remove),
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Expanded(
                              child: Slider(
                                value: widget.selectedSize.toDouble(),
                                min: 1,
                                max: 100,
                                divisions: 99,
                                label: widget.selectedSize.toString(),
                                onChanged: (value) => updateSize(value.toInt()),
                              ),
                            ),
                            IconButton(
                              onPressed: widget.selectedSize < 100
                                  ? () => updateSize(widget.selectedSize + 1)
                                  : null,
                              icon: const Icon(Icons.add),
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSlider() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideSlider();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _buttonKey,
      onPressed: _showSlider,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.brush),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                '${widget.selectedSize}',
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
