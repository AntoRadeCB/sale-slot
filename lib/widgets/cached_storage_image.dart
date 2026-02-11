import 'package:flutter/material.dart';

const _proxyBase =
    'https://europe-west1-saleslot-app.cloudfunctions.net/imageProxy';

class CachedStorageImage extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;
  final Map<String, dynamic>? reportData;
  final String? reportType;

  const CachedStorageImage({
    super.key,
    this.imageUrl,
    this.imagePath,
    this.reportData,
    this.reportType,
  });

  String? get _url {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return '$_proxyBase?path=${Uri.encodeComponent(imagePath!)}';
    }
    return imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null || url.isEmpty) return _placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullscreenImageView(
              url: url,
              reportData: reportData,
              reportType: reportType,
            ),
          ),
        ),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 200,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.broken_image, color: Colors.white24, size: 48),
    );
  }
}

class _FullscreenImageView extends StatefulWidget {
  final String url;
  final Map<String, dynamic>? reportData;
  final String? reportType;

  const _FullscreenImageView({
    required this.url,
    this.reportData,
    this.reportType,
  });

  @override
  State<_FullscreenImageView> createState() => _FullscreenImageViewState();
}

class _FullscreenImageViewState extends State<_FullscreenImageView> {
  bool _showOverlay = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Zoomable image
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.network(widget.url, fit: BoxFit.contain),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Toggle overlay button
          if (widget.reportData != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  _showOverlay ? Icons.visibility_off : Icons.table_chart,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => _showOverlay = !_showOverlay),
              ),
            ),

          // Data overlay
          if (_showOverlay && widget.reportData != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {}, // prevent tap-through
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _buildOverlayContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlayContent() {
    final data = widget.reportData!;
    final type = widget.reportType ?? '';

    List<dynamic>? items;
    if (type == 'CSMFG1_Snai_report') {
      items = data['terminali'] is List ? data['terminali'] : null;
    } else {
      items = data['vlt'] is List ? data['vlt'] : null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        if (data['totale'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['nomeAzienda'] ?? type,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '€ ${_fmt(data['totale'])}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

        // Table
        if (items != null && items.isNotEmpty) _buildTable(items, type),

        // Extra Playtech
        if (type == 'daily_playtech_report') ...[
          _row('Banconote', data['banconote']),
          _row('Ticket Incassati', data['ticketIncassati']),
        ],

        // Extra Snai
        if (type == 'CSMFG1_Snai_report') ...[
          _row('Pag. Prelievo Voucher', data['pagamentoPrelievoVoucher']),
          _row('Vers. FaiConMe', data['versamentoFaiConMeEmissione']),
          _row('Prel. FaiConMe/Fastbet', data['prelievoFaiConMeFastbet']),
        ],
      ],
    );
  }

  Widget _buildTable(List<dynamic> items, String type) {
    if (type == 'daily_report_spielo') {
      return _dataTable(
        columns: ['ID', 'Inc. Tot', 'Inc. Den', 'Pagato'],
        rows: items.map((v) {
          final m = v as Map<String, dynamic>;
          return [
            m['id'] ?? '-',
            _fmt(m['incasso_tot']),
            _fmt(m['incasso_den']),
            _fmt(m['pagato']),
          ];
        }).toList(),
      );
    }

    if (type == 'report_novoline_range') {
      return _dataTable(
        columns: ['ID', 'Bill In', 'Total In', 'Total Out', 'Net Win'],
        rows: items.map((v) {
          final m = v as Map<String, dynamic>;
          return [
            m['id'] ?? '-',
            _fmt(m['billIn']),
            _fmt(m['totalIn']),
            _fmt(m['totalOut']),
            _fmt(m['totalNetWin']),
          ];
        }).toList(),
      );
    }

    if (type == 'CSMFG1_Snai_report') {
      return _dataTable(
        columns: ['N°', 'Tipo', 'Netto Cassa'],
        rows: items.map((v) {
          final m = v as Map<String, dynamic>;
          return [m['number'] ?? '-', m['type'] ?? '-', _fmt(m['total'])];
        }).toList(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _dataTable({
    required List<String> columns,
    required List<List<dynamic>> rows,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
        columns: columns
            .map((c) => DataColumn(
                label: Text(c,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 11))))
            .toList(),
        rows: rows
            .map((r) => DataRow(
                cells: r
                    .map((c) => DataCell(Text(c.toString(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12))))
                    .toList()))
            .toList(),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value != null ? '€ ${_fmt(value)}' : '-',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  String _fmt(dynamic n) {
    if (n == null) return '-';
    if (n is int) return n.toStringAsFixed(2);
    if (n is double) return n.toStringAsFixed(2);
    return n.toString();
  }
}
