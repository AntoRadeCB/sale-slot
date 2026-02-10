import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/cached_storage_image.dart';

class DayDetailScreen extends StatefulWidget {
  final String date;
  final List<QueryDocumentSnapshot> reports;
  final double aperturaCassa;
  final double speseExtra;
  final double? calcoloApertura; // calculated from prev day

  const DayDetailScreen({
    super.key,
    required this.date,
    required this.reports,
    required this.aperturaCassa,
    required this.speseExtra,
    this.calcoloApertura,
  });

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  late TextEditingController _aperturaCtrl;
  late TextEditingController _speseCtrl;

  @override
  void initState() {
    super.initState();
    _aperturaCtrl = TextEditingController();
    _speseCtrl = TextEditingController();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    final doc = await FirebaseFirestore.instance
        .collection('days')
        .doc(_docId)
        .get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      final ap = (data['aperturaCassa'] as num?)?.toDouble() ?? 0;
      final sp = (data['speseExtra'] as num?)?.toDouble() ?? 0;
      setState(() {
        _aperturaCtrl.text = ap != 0 ? ap.toStringAsFixed(2) : '';
        _speseCtrl.text = sp != 0 ? sp.toStringAsFixed(2) : '';
      });
    }
  }

  @override
  void dispose() {
    _aperturaCtrl.dispose();
    _speseCtrl.dispose();
    super.dispose();
  }

  /// DD/MM/YYYY -> DDMMYY
  String get _docId {
    final parts = widget.date.split('/');
    if (parts.length == 3) {
      final yy = parts[2].length == 4 ? parts[2].substring(2) : parts[2];
      return '${parts[0].padLeft(2, '0')}${parts[1].padLeft(2, '0')}$yy';
    }
    return widget.date.replaceAll('/', '');
  }

  Future<void> _save() async {
    final apertura = double.tryParse(_aperturaCtrl.text) ?? 0;
    final spese = double.tryParse(_speseCtrl.text) ?? 0;
    await FirebaseFirestore.instance
        .collection('days')
        .doc(_docId)
        .set({
      'date': widget.date,
      'aperturaCassa': apertura,
      'speseExtra': spese,
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Salvato'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate day totals
    double dayTotals = 0;
    for (final doc in widget.reports) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['totale'] != null) {
        dayTotals += (data['totale'] as num).toDouble();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('📅 ${widget.date}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Apertura Cassa section
          _CassaCard(
            aperturaCtrl: _aperturaCtrl,
            speseCtrl: _speseCtrl,
            calcoloApertura: widget.calcoloApertura,
            dayTotals: dayTotals,
            onSave: _save,
          ),
          const SizedBox(height: 20),

          // Reports
          ...widget.reports.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _ReportSection(data: data);
          }),
        ],
      ),
    );
  }
}

class _CassaCard extends StatelessWidget {
  final TextEditingController aperturaCtrl;
  final TextEditingController speseCtrl;
  final double? calcoloApertura;
  final double dayTotals;
  final VoidCallback onSave;

  const _CassaCard({
    required this.aperturaCtrl,
    required this.speseCtrl,
    required this.calcoloApertura,
    required this.dayTotals,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💰 Cassa',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),

            if (calcoloApertura != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Apertura calcolata (da ieri):',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                  Text('€ ${calcoloApertura!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.amberAccent, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: aperturaCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Apertura Cassa',
                      prefixText: '€ ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: speseCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Spese Extra',
                      prefixText: '€ ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Salva'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            const Divider(color: Colors.white12, height: 24),

            // Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Totale report:',
                    style: TextStyle(color: Colors.white54)),
                Text('€ ${dayTotals.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
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
    final imagePath = data['imagePath'] as String?;
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
            Row(
              children: [
                _TypeBadge(type: type),
                if (nomeAzienda != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(nomeAzienda,
                        style: const TextStyle(color: Colors.white54),
                        overflow: TextOverflow.ellipsis),
                  ),
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

            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imagePath != null || imageUrl != null)
                    Expanded(
                      flex: 2,
                      child: CachedStorageImage(
                          imagePath: imagePath, imageUrl: imageUrl),
                    ),
                  if (imagePath != null || imageUrl != null)
                    const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _VltTable(vlt: vlt, type: type),
                  ),
                ],
              )
            else ...[
              if (imagePath != null || imageUrl != null) ...[
                CachedStorageImage(imagePath: imagePath, imageUrl: imageUrl),
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

class _VltTable extends StatelessWidget {
  final List<dynamic>? vlt;
  final String type;

  const _VltTable({required this.vlt, required this.type});

  @override
  Widget build(BuildContext context) {
    if (vlt == null || vlt!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (type == 'daily_report_spielo') return _buildSpieloTable();
    if (type == 'report_novoline_range') return _buildNovolineTable();
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
              headingRowColor:
                  WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
              columns: const [
                DataColumn(
                    label: Text('ID',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Inc. Tot',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Inc. Den',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Pagato',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold)),
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
              headingRowColor:
                  WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
              columnSpacing: 16,
              columns: const [
                DataColumn(label: _ColHead('ID')),
                DataColumn(label: _ColHead('Bill In'), numeric: true),
                DataColumn(label: _ColHead('Coin In'), numeric: true),
                DataColumn(label: _ColHead('Total In'), numeric: true),
                DataColumn(label: _ColHead('Total Out'), numeric: true),
                DataColumn(label: _ColHead('Net Win'), numeric: true),
              ],
              rows: vlt!.map((v) {
                final m = v as Map<String, dynamic>;
                final hasUncertain = m['hasUncertainValues'] == true;
                return DataRow(
                  color: hasUncertain
                      ? WidgetStateProperty.all(Colors.amber.withOpacity(0.06))
                      : null,
                  cells: [
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(m['id'] ?? '-',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                      if (hasUncertain)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.warning_amber,
                              size: 12, color: Colors.amber),
                        ),
                    ])),
                    DataCell(Text(_fmt(m['billIn']),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12))),
                    DataCell(Text(_fmt(m['coinIn']),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12))),
                    DataCell(Text(_fmt(m['totalIn']),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12))),
                    DataCell(Text(_fmt(m['totalOut']),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12))),
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
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
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

class _ColHead extends StatelessWidget {
  final String text;
  const _ColHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 11));
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
