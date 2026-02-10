import 'package:flutter/material.dart';

class ReportDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const ReportDetailScreen(
      {super.key, required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(_typeLabel(type)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            _InfoCard(data: data),
            const SizedBox(height: 16),

            // VLT table if present
            if (data['vlt'] != null && (data['vlt'] as List).isNotEmpty) ...[
              const Text('Macchine',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
              const SizedBox(height: 12),
              ...(data['vlt'] as List).map((vlt) => _VltCard(vlt: vlt)),
            ],

            // Image
            if (data['imageUrl'] != null) ...[
              const SizedBox(height: 24),
              const Text('Immagine originale',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(data['imageUrl'], fit: BoxFit.contain),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'chiusura_pos':
        return '💳 Chiusura POS';
      case 'daily_report_spielo':
        return '🎰 Report Spielo';
      case 'report_novoline_range':
        return '📊 Novoline';
      default:
        return '📄 Report';
    }
  }
}

class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _InfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'];
    final rows = <MapEntry<String, String>>[];

    if (data['data'] != null) rows.add(MapEntry('Data', data['data']));
    if (data['ora'] != null) rows.add(MapEntry('Ora', data['ora']));
    if (data['nomeAzienda'] != null)
      rows.add(MapEntry('Azienda', data['nomeAzienda']));
    if (data['from'] != null && data['to'] != null)
      rows.add(MapEntry('Periodo', '${data['from']} → ${data['to']}'));

    final totale = data['totale'];
    // For novoline, calculate total from VLT
    double? calcTotale;
    if (type == 'report_novoline_range' && data['vlt'] != null) {
      final vltList = data['vlt'] as List;
      calcTotale = 0;
      for (final v in vltList) {
        if (v['totalNetWin'] != null) {
          calcTotale = calcTotale! + (v['totalNetWin'] as num).toDouble();
        }
      }
    }

    final displayTotale = totale ?? calcTotale;

    return Card(
      color: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...rows.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key,
                          style: const TextStyle(color: Colors.white54)),
                      Text(e.value,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
            if (displayTotale != null) ...[
              const Divider(color: Colors.white12, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTALE',
                      style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(
                    '€ ${_fmt(displayTotale)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic n) {
    if (n is int) return n.toStringAsFixed(2);
    if (n is double) return n.toStringAsFixed(2);
    return n.toString();
  }
}

class _VltCard extends StatelessWidget {
  final dynamic vlt;

  const _VltCard({required this.vlt});

  @override
  Widget build(BuildContext context) {
    final map = vlt as Map<String, dynamic>;
    final id = map['id'] ?? 'N/A';
    final hasUncertain = map['hasUncertainValues'] == true;

    // Collect relevant values
    final values = <MapEntry<String, String>>[];

    void addIfPresent(String key, String label) {
      if (map[key] != null) {
        values.add(MapEntry(label, _fmt(map[key])));
      }
    }

    // Spielo fields
    addIfPresent('incasso_tot', 'Incasso Tot');
    addIfPresent('incasso_den', 'Incasso Den');
    addIfPresent('pagato', 'Pagato');

    // Novoline fields
    addIfPresent('billIn', 'Bill In');
    addIfPresent('coinIn', 'Coin In');
    addIfPresent('ticketIn', 'Ticket In');
    addIfPresent('externIn', 'Extern In');
    addIfPresent('totalIn', 'Total In');
    addIfPresent('handPays', 'Handpays');
    addIfPresent('coinOut', 'Coin Out');
    addIfPresent('ticketOut', 'Ticket Out');
    addIfPresent('externOut', 'Extern Out');
    addIfPresent('totalOut', 'Total Out');
    addIfPresent('totalNetWin', 'Net Win');

    return Card(
      color: hasUncertain
          ? Colors.amber.withOpacity(0.08)
          : Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.games, size: 16, color: Colors.white38),
                const SizedBox(width: 6),
                Text(id,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white)),
                if (hasUncertain) ...[
                  const SizedBox(width: 8),
                  const Tooltip(
                    message: 'Valori incerti',
                    child:
                        Icon(Icons.warning_amber, size: 16, color: Colors.amber),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: values
                  .map((e) => _MiniStat(label: e.key, value: e.value))
                  .toList(),
            ),
            // Show uncertain fields
            if (hasUncertain && map['uncertainFields'] != null) ...[
              const SizedBox(height: 8),
              ...(map['uncertainFields'] as List).map((uf) => Text(
                    '⚠ ${uf['field']}: ${uf['reason']}',
                    style: const TextStyle(
                        color: Colors.amber, fontSize: 11),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic n) {
    if (n is int) return n.toStringAsFixed(2);
    if (n is double) return n.toStringAsFixed(2);
    return n.toString();
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white30, fontSize: 10)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
