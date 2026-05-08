import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/pending_reviews_service.dart';

/// Tarjeta que reporta la respuesta en tiempo real a la BQ #2 del Sprint 3:
/// "What percentage of pending offline reviews sync successfully within
/// 60 seconds after reconnection?"
///
/// Se conecta a la colección Firestore `analytics_bq2_review_sync` (BD
/// central del proyecto) vía un Stream y agrega los eventos del usuario
/// actual para calcular el porcentaje. Cumple el requisito de la rúbrica
/// de que la BQ "trae datos desde el motor de analítica, está en el
/// pipeline y tiene su interfaz gráfica" — sin archivos descargados ni
/// múltiples bases de datos.
class BQ2StatsCard extends StatelessWidget {
  const BQ2StatsCard({super.key});

  Future<void> _resetStats(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PendingReviewsService.instance.resetBQ2Stats();
      messenger.showSnackBar(
        const SnackBar(content: Text('BQ #2 stats reset')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('analytics_bq2_review_sync')
          .where('uid', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        return _CardShell(
          state: _resolveState(snapshot),
          onReset: () => _resetStats(context),
        );
      },
    );
  }

  _CardState _resolveState(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const _CardState.loading();
    }
    if (snapshot.hasError) {
      return _CardState.error(snapshot.error.toString());
    }

    final docs = snapshot.data?.docs ?? const [];
    if (docs.isEmpty) {
      return const _CardState.empty();
    }

    final total = docs.length;
    final within60s = docs
        .where((d) => (d.data())['withinThreshold'] == true)
        .length;

    return _CardState.ready(total: total, syncedWithin60s: within60s);
  }
}

class _CardState {
  const _CardState._(this.kind, {this.total = 0, this.within = 0, this.error});

  const _CardState.loading() : this._(_Kind.loading);
  const _CardState.empty() : this._(_Kind.empty);
  _CardState.error(String message) : this._(_Kind.error, error: message);
  const _CardState.ready({required int total, required int syncedWithin60s})
      : this._(_Kind.ready, total: total, within: syncedWithin60s);

  final _Kind kind;
  final int total;
  final int within;
  final String? error;

  double get percentage => total == 0 ? 0 : (within * 100 / total);
}

enum _Kind { loading, empty, error, ready }

class _CardShell extends StatelessWidget {
  const _CardShell({required this.state, required this.onReset});

  final _CardState state;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.teal.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'BQ #2 · Offline review sync rate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Firestore · live',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBody(context, colorScheme),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Reset stats', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme colorScheme) {
    switch (state.kind) {
      case _Kind.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _Kind.error:
        return Text(
          "Couldn't read from Firestore: ${state.error}",
          style: TextStyle(
            color: colorScheme.error,
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
        );
      case _Kind.empty:
        return Text(
          'No data yet. Submit reviews offline and reconnect to start measuring.',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
        );
      case _Kind.ready:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${state.percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: state.percentage >= 80
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${state.within} / ${state.total} reviews ≤ 60s',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
    }
  }
}
