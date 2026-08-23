import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Small gray uppercase label above a form field, matching the reference
/// app's KATEGORI/REKENING/JUMLAH caption style.
class FormCaption extends StatelessWidget {
  final String text;
  const FormCaption(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class DateField extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const DateField({super.key, required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(DateFormat('EEE, d MMM yyyy').format(date)),
      ),
    );
  }
}

class TimeField extends StatelessWidget {
  final DateTime date;
  final ValueChanged<TimeOfDay> onChanged;
  const TimeField({super.key, required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(date),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.access_time, size: 18),
        ),
        child: Text(DateFormat('HH:mm').format(date)),
      ),
    );
  }
}
