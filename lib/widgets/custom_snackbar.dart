import 'package:flutter/material.dart';

class CustomSnackBar {
  static void showTimeoutMessage(BuildContext context, String message) {
    _show(context, message, Colors.orange, Icons.timer_off);
  }

  static void showErrorMessage(BuildContext context, String message) {
    _show(context, message, Colors.pink, Icons.error);
  }

  static void showInfoMessage(BuildContext context, String message) {
    _show(context, message, Colors.blue, Icons.info);
  }

  static void _show(BuildContext context, String message, Color borderColor, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: borderColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

