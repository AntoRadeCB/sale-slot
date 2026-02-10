import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_detail_screen.dart';

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
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final reports = grouped[date]!;
              return _DaySection(date: date, reports: reports);
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
}

class _DaySection extends StatelessWidget {
  final String date;
  final List<QueryDocumentSnapshot> reports;

  const _DaySection({required this.date, required this.reports});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.white54),
              const SizedBox(width: 8),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        ...reports.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _ReportCard(docId: doc.id, data: data);
        }),
        const Divider(color: Colors.white12, height: 32),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _ReportCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'unknown';
    final totale = data['totale'];
    final nomeAzienda = data['nomeAzienda'];
    final vlt = data['vlt'] as List<dynamic>?;

    return Card(
      color: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailScreen(docId: docId, data: data),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeBadge(type: type),
                  const Spacer(),
                  if (totale != null)
                    Text(
                      '€ ${_formatNumber(totale)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                ],
              ),
              if (nomeAzienda != null) ...[
                const SizedBox(height: 8),
                Text(nomeAzienda,
                    style: const TextStyle(color: Colors.white54)),
              ],
              if (vlt != null && vlt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${vlt.length} macchine',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Dettagli →',
                      style:
                          TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatNumber(dynamic n) {
    if (n is int) return n.toStringAsFixed(2);
    if (n is double) return n.toStringAsFixed(2);
    return n.toString();
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final config = _badgeConfig(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 4),
          Text(config.label,
              style: TextStyle(color: config.color, fontSize: 12)),
        ],
      ),
    );
  }

  static ({Color color, IconData icon, String label}) _badgeConfig(
      String type) {
    switch (type) {
      case 'chiusura_pos':
        return (
          color: Colors.blueAccent,
          icon: Icons.point_of_sale,
          label: 'Chiusura POS'
        );
      case 'daily_report_spielo':
        return (
          color: Colors.orangeAccent,
          icon: Icons.casino,
          label: 'Report Spielo'
        );
      case 'report_novoline_range':
        return (
          color: Colors.purpleAccent,
          icon: Icons.analytics,
          label: 'Novoline'
        );
      default:
        return (
          color: Colors.grey,
          icon: Icons.description,
          label: type
        );
    }
  }
}
