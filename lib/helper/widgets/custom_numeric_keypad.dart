import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

class CustomNumericKeypad extends StatelessWidget {
  const CustomNumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F7F8),
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset * 0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KeyRow(
            children: [
              _DigitKey(label: '1', onTap: () => onDigit('1')),
              _DigitKey(label: '2', onTap: () => onDigit('2')),
              _DigitKey(label: '3', onTap: () => onDigit('3')),
            ],
          ),
          const SizedBox(height: 8),
          _KeyRow(
            children: [
              _DigitKey(label: '4', onTap: () => onDigit('4')),
              _DigitKey(label: '5', onTap: () => onDigit('5')),
              _DigitKey(label: '6', onTap: () => onDigit('6')),
            ],
          ),
          const SizedBox(height: 8),
          _KeyRow(
            children: [
              _DigitKey(label: '7', onTap: () => onDigit('7')),
              _DigitKey(label: '8', onTap: () => onDigit('8')),
              _DigitKey(label: '9', onTap: () => onDigit('9')),
            ],
          ),
          const SizedBox(height: 8),
          _KeyRow(
            children: [
              const _EmptyKey(),
              _DigitKey(label: '0', onTap: () => onDigit('0')),
              _ActionKey(icon: Icons.backspace_outlined, onTap: onBackspace),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0.5,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Center(child: Text(label, style: AppTextStyles.keypad())),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Icon(icon, color: AppColors.textSecondary, size: 24),
          ),
        ),
      ),
    );
  }
}

class _EmptyKey extends StatelessWidget {
  const _EmptyKey();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 52);
  }
}
