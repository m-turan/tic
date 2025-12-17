import 'dart:async';
import 'package:flutter/material.dart';

class TimerWidget extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTimeout;
  final int durationSeconds;

  const TimerWidget({
    super.key,
    required this.isActive,
    required this.onTimeout,
    this.durationSeconds = 45,
  });

  @override
  State<TimerWidget> createState() => TimerWidgetState();
}

class TimerWidgetState extends State<TimerWidget> {
  // Public state class for external access

  int _remainingSeconds = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationSeconds;
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(TimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startTimer();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopTimer();
    }
  }

  void _startTimer() {
    _remainingSeconds = widget.durationSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _stopTimer();
          widget.onTimeout();
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    _stopTimer();
    setState(() {
      _remainingSeconds = widget.durationSeconds;
    });
    if (widget.isActive) {
      _startTimer();
    }
  }

  void stop() {
    _stopTimer();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remainingSeconds / widget.durationSeconds;
    final color = _remainingSeconds <= 10
        ? Colors.red
        : _remainingSeconds <= 20
            ? Colors.orange
            : Colors.green;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isActive ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        border: Border.all(
          color: widget.isActive ? color : Colors.grey,
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          '$_remainingSeconds',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: widget.isActive ? color : Colors.grey,
          ),
        ),
      ),
    );
  }
}

