import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';

class SimulationDashboardScreen extends StatefulWidget {
  const SimulationDashboardScreen({super.key});

  @override
  State<SimulationDashboardScreen> createState() => _SimulationDashboardScreenState();
}

class _SimulationDashboardScreenState extends State<SimulationDashboardScreen> {
  final _lang = LanguageService();

  void _showSimulationSnackBar(String title, String message, IconData icon, Color color) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(message, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
      duration: const Duration(seconds: 4),
    ));
  }

  void _simulateSms() {
    _showSimulationSnackBar(
      'SMS / WhatsApp Simulation',
      'Booking Confirmed! Provider is assigned to your job.',
      Icons.message_rounded,
      AppTheme.tealDark,
    );
  }

  void _simulateEnRoute() {
    _showSimulationSnackBar(
      'Service-Quality Loop',
      'Provider is en route! ETA: 15 mins.',
      Icons.directions_car_rounded,
      AppTheme.blueInfo,
    );
  }

  void _simulateCompletion() {
    _showSimulationSnackBar(
      'Service-Quality Loop',
      'Job Completed! Please leave a photo evidence and a rating.',
      Icons.check_circle_rounded,
      AppTheme.greenSuccess,
    );
  }

  void _simulateDispute() {
    _showSimulationSnackBar(
      'Dispute & Escalation Workflow',
      'Dispute filed: Price disagreement. System issued partial refund based on Provider DNA.',
      Icons.gavel_rounded,
      AppTheme.redAlert,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = _lang.isUrdu;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(isUrdu ? 'ہیکاتھون سمیلیٹر' : 'Hackathon Simulator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'System Requirements Simulator',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use these buttons during the hackathon pitch to demonstrate background workflows like SMS routing, live updates, and dispute handling.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 32),
          _buildActionCard(
            title: '1. Booking Simulation',
            subtitle: 'Triggers WhatsApp/SMS confirmation, calendar sync, and database update.',
            icon: Icons.send_to_mobile_rounded,
            color: AppTheme.tealPrimary,
            onTap: _simulateSms,
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            title: '2. En-Route Simulation',
            subtitle: 'Triggers live tracking update and ETA computation.',
            icon: Icons.map_rounded,
            color: AppTheme.blueInfo,
            onTap: _simulateEnRoute,
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            title: '3. Quality Loop (Completion)',
            subtitle: 'Simulates job completion, prompting photo evidence and rating adjustment.',
            icon: Icons.camera_alt_rounded,
            color: AppTheme.greenSuccess,
            onTap: _simulateCompletion,
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            title: '4. Dispute Workflow',
            subtitle: 'Simulates AI handling a price disagreement and applying DNA-based penalties.',
            icon: Icons.shield_rounded,
            color: AppTheme.redAlert,
            onTap: _simulateDispute,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
