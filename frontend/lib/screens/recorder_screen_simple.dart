import 'package:flutter/material.dart';

class RecorderScreenSimple extends StatelessWidget {
  const RecorderScreenSimple({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('듣기 테스트')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('+듣기 버튼이 작동합니다!')),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('+듣기'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '녹음된 오디오가 없습니다\n위의 +듣기 버튼을 눌러\n첫 번째 녹음을 시작하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}