import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DayDetailScreen extends StatelessWidget {
  final String date;
  final List<QueryDocumentSnapshot> reports;

  const DayDetailScreen(
      {super.key, required this.date, required this.reports});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📅 $date'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final data = reports[index].data() as Map<String, dynamic>;
          return _ReportSection(data: data);
        },
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReportSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'unknown';
    final imageUrl = data['imageUrl'] as String?;
    final vlt = data['vlt'] as List<dynamic>?;
    final totale = data['totale'];
    final nomeAzienda = data['nomeAzienda'];
    final isWide = MediaQuery.of(context).size.width > 600;

    return Card(
      color: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _TypeBadge(type: type),
                if (nomeAzienda != null) ...[
                  const SizedBox(width: 12),
                  Text(nomeAzienda,
                      style: const TextStyle(color: Colors.white54)),
                ],
                const Spacer(),
                if (totale != null)
                  Text(
                    '€ ${_fmt(totale)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Photo + Data side by side on wide, stacked on narrow
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    Expanded(
                      flex: 2,
                      child: _ImageSection(imageUrl: imageUrl),
                    ),
                  if (imageUrl != null) const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _VltTable(vlt: vlt, type: type),
                  ),
                ],
              )
            else ...[
              if (imageUrl != null) ...[
                _ImageSection(imageUrl: imageUrl),
                const SizedBox(height: 16),
              ],
              _VltTable(vlt: vlt, type: type),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(dynamic n) {
    if (n is int) return n.toStringAsFixed(2);
    if (n is double) return n.toStringAsFixed(2);
    return n.toString();
  }
}

class _ImageSection extends StatelessWidget {
  final String imageUrl;

  const _ImageSection({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.broken_image, color: Colors.white24, size: 48),
        ),
      ),
    );
  }
}

class _VltTable extends StatelessWidget {
  final List<dynamic>? vlt;
  final String type;

  const _VltTable({required this.vlt, required this.type});

  @override
  Widget build(BuildContext context) {
    if (vlt == null || vlt!.isEmpty) {
      return const Text('Nessun dato macchina',
          style: TextStyle(color: Colors.white38));
    }

    if (type == 'daily_report_spielo') {
      return _buildSpieloTable();
    } else if (type == 'report_novoline_range') {
      return _buildNovolineTable();
    }

    return _buildGenericList();
  }

  Widget _buildSpieloTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Macchine VLT',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white70)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withOpacity(0.03),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                  Colors.white.withOpacity(0.05)),
              dataRowColor:
                  WidgetStateProperty.all(Colors.transparent),
              columns: const [
                DataColumn(
                    label: Text('ID',
                        style: TextStyle(
                            color: Colors.white54, fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Inc. Tot',
                        style: TextStyle(
                            color: Colors.white54, fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Inc. Den',
                        style: TextStyle(
                            color: Colors.white54, fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Pagato',
                        style: TextStyle(
                            color: Colors.white54, fontWeight: FontWeight.bold)),
                    numeric: true),
              ],
              rows: vlt!.map((v) {
                final m = v as Map<String, dynamic>;
                return DataRow(cells: [
                  DataCell(Text(m['id'] ?? '-',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text(_fmt(m['incasso_tot']),
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text(_fmt(m['incasso_den']),
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text(_fmt(m['pagato']),
                      style: const TextStyle(color: Colors.amber))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNovolineTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Macchine VLT',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white70)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withOpacity(0.03),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                  Colors.white.withOpacity(0.05)),
              dataRowColor:
                  WidgetStateProperty.all(Colors.transparent),
              columnSpacing: 16,
              columns: const [
                DataColumn(
                    label: Text('ID',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11))),
                DataColumn(
                    label: Text('Bill In',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    numeric: true),
                DataColumn(
                    label: Text('Coin In',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    numeric: true),
                DataColumn(
                    label: Text('Total In',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    numeric: true),
                DataColumn(
                    label: Text('Total Out',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    numeric: true),
                DataColumn(
                    label: Text('Net Win',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    numeric: true),
              ],
              rows: vlt!.map((v) {
                final m = v as Map<String, dynamic>;
                final hasUncertain = m['hasUncertainValues'] == true;
                return DataRow(
                  color: hasUncertain
                      ? WidgetStateProperty.all(
                          Colors.amber.withOpacity(0.06))
                      : null,
                  cells: [
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m['id'] ?? '-',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        if (hasUncertain)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.warning_amber,
                                size: 12, color: Colors.amber),
                          ),
                      ],
                    )),
                    DataCell(Text(_fmt(m['billIn']),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12))),
                    DataCell(Text(_fmt(m['coinIn']),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12))),
                    DataCell(Text(_fmt(m['totalIn']),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12))),
                    DataCell(Text(_fmt(m['totalOut']),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12))),
                    DataCell(Text(_fmt(m['totalNetWin']),
                        style: TextStyle(
                            color: _netWinColor(m['totalNetWin']),
                            fontSize: 12,
                            fontWeight: FontWeight.bold))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenericList() {
    return Column(
      children: vlt!
          .map((v) => Card(
                color: Colors.white.withOpacity(0.04),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(v.toString(),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ))
          .toList(),
    );
  }

  Color _netWinColor(dynamic val) {
    if (val == null) return Colors.white;
    final n = (val as num).toDouble();
    if (n > 0) return Colors.greenAccent;
    if (n < 0) return Colors.redAccent;
    return Colors.white;
  }

  String _fmt(dynamic n) {
    if (n == null) return '-';
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
        return (color: Colors.grey, icon: Icons.description, label: type);
    }
  }
}
