import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'day_detail_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Report'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('Nessun report ancora',
                      style: TextStyle(color: Colors.white38, fontSize: 16)),
                ],
              ),
            );
          }

          // Group by date
          final grouped = <String, List<QueryDocumentSnapshot>>{};
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final dateStr = _extractDate(data);
            grouped.putIfAbsent(dateStr, () => []).add(doc);
          }

          final sortedDates = grouped.keys.toList()
            ..sort((a, b) => _compareDates(b, a));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final reports = grouped[date]!;

              // Calculate day total
              double dayTotal = 0;
              for (final doc in reports) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['totale'] != null) {
                  dayTotal += (data['totale'] as num).toDouble();
                }
              }

              return Card(
                color: Colors.white.withOpacity(0.06),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DayDetailScreen(date: date, reports: reports),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.calendar_today,
                                color: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                date,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${reports.length} report',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (dayTotal != 0)
                          Text(
                            '€ ${dayTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.white24),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _extractDate(Map<String, dynamic> data) {
    if (data['data'] != null) return data['data'];
    if (data['from'] != null) return data['from'];
    return 'Senza data';
  }

  static int _compareDates(String a, String b) {
    // Format DD/MM/YYYY
    try {
      final pa = a.split('/');
      final pb = b.split('/');
      final da = DateTime(int.parse(pa[2]), int.parse(pa[1]), int.parse(pa[0]));
      final db = DateTime(int.parse(pb[2]), int.parse(pb[1]), int.parse(pb[0]));
      return da.compareTo(db);
    } catch (_) {
      return a.compareTo(b);
    }
  }
}
