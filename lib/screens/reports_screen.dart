import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'day_detail_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  /// Normalize any date string to DD/MM/YYYY only
  static String normalizeDate(String raw) {
    // Remove time portion if present (e.g. "10/02/2026 17:07:37" -> "10/02/2026")
    final trimmed = raw.trim();
    // Match DD/MM/YYYY at start
    final match = RegExp(r'(\d{1,2}/\d{1,2}/\d{4})').firstMatch(trimmed);
    if (match != null) return match.group(1)!;
    // Try DD/MM/YY
    final match2 = RegExp(r'(\d{1,2}/\d{1,2}/\d{2})$').firstMatch(trimmed);
    if (match2 != null) {
      final parts = match2.group(1)!.split('/');
      return '${parts[0]}/${parts[1]}/20${parts[2]}';
    }
    return trimmed;
  }

  static String extractDate(Map<String, dynamic> data) {
    if (data['data'] != null) return normalizeDate(data['data']);
    if (data['from'] != null) return normalizeDate(data['from']);
    return 'Senza data';
  }

  static DateTime? parseDate(String dateStr) {
    try {
      final p = dateStr.split('/');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

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
        builder: (context, reportSnap) {
          if (reportSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Also listen to days collection for apertura/spese
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('days')
                .snapshots(),
            builder: (context, daySnap) {
              final reports = reportSnap.data?.docs ?? [];
              final dayDocs = daySnap.data?.docs ?? [];

              if (reports.isEmpty) {
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

              // Group reports by normalized date
              final grouped = <String, List<QueryDocumentSnapshot>>{};
              for (final doc in reports) {
                final data = doc.data() as Map<String, dynamic>;
                final dateStr = extractDate(data);
                grouped.putIfAbsent(dateStr, () => []).add(doc);
              }

              // Build days data map keyed by DD/MM/YYYY
              final daysData = <String, Map<String, dynamic>>{};
              for (final doc in dayDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final dateKey = (data['date'] as String?) ?? '';
                if (dateKey.isNotEmpty) {
                  daysData[dateKey] = data;
                }
              }

              final sortedDates = grouped.keys.toList()
                ..sort((a, b) {
                  final da = parseDate(a);
                  final db = parseDate(b);
                  if (da == null || db == null) return a.compareTo(b);
                  return db.compareTo(da); // descending
                });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  final date = sortedDates[index];
                  final dayReports = grouped[date]!;
                  final dayData = daysData[date];

                  // Calculate totals for the day
                  double dayTotals = 0;
                  for (final doc in dayReports) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['totale'] != null) {
                      dayTotals += (data['totale'] as num).toDouble();
                    }
                  }

                  // Get apertura/spese
                  final apertura = (dayData?['aperturaCassa'] as num?)?.toDouble() ?? 0;
                  final spese = (dayData?['speseExtra'] as num?)?.toDouble() ?? 0;

                  // Calculate prev day apertura for display
                  // Find previous day
                  String? prevDate;
                  if (index + 1 < sortedDates.length) {
                    prevDate = sortedDates[index + 1];
                  }

                  double? prevApertura;
                  if (prevDate != null) {
                    final prevDayData = daysData[prevDate];
                    final prevApert = (prevDayData?['aperturaCassa'] as num?)?.toDouble() ?? 0;
                    double prevTotals = 0;
                    for (final doc in (grouped[prevDate] ?? [])) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['totale'] != null) {
                        prevTotals += (data['totale'] as num).toDouble();
                      }
                    }
                    final prevSpese = (prevDayData?['speseExtra'] as num?)?.toDouble() ?? 0;
                    prevApertura = prevApert + prevTotals - prevSpese;
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
                          builder: (_) => DayDetailScreen(
                            date: date,
                            reports: dayReports,
                            aperturaCassa: apertura,
                            speseExtra: spese,
                            calcoloApertura: prevApertura,
                          ),
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
                                    '${dayReports.length} report',
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (dayTotals != 0)
                                  Text(
                                    '€ ${dayTotals.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                              ],
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
          );
        },
      ),
    );
  }
}
