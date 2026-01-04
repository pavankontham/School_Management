import 'package:flutter/material.dart';

class TextbookScreen extends StatelessWidget {
  const TextbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Textbooks'),
      ),
      body: const Center(
        child: Text('Textbook Screen - Coming Soon'),
      ),
    );
  }
}

