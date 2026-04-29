import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../models/smart_recommendation.dart';

class SmartRecommendationCard extends StatelessWidget {
  final SmartRecommendation recommendation;
  final VoidCallback onPressed;

  const SmartRecommendationCard({
    super.key,
    required this.recommendation,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isJoin = recommendation.type == RecommendationType.join;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isJoin
            ? null
            : const LinearGradient(
                colors: [Color(0xFF2D7CFF), Color(0xFFFF9C48)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isJoin ? const Color(0xFFE9F8F1) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isJoin ? const Color(0xFFBFE8D4) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isJoin ? Icons.group_add : Icons.auto_awesome,
                color: isJoin ? Colors.green.shade700 : Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation.uiTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isJoin ? AppTheme.navy : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (!isJoin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'Suggested for you',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.uiBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isJoin ? AppTheme.navy : Colors.white,
                  height: 1.3,
                ),
          ),
          if (isJoin && recommendation.eventId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Event: ${recommendation.eventId}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isJoin ? const Color(0xFF14A86B) : Colors.white,
                foregroundColor: isJoin ? Colors.white : const Color(0xFF2D7CFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(recommendation.ctaText),
            ),
          ),
        ],
      ),
    );
  }
}

