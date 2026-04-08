import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/models/user_profile.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class ProfilePage extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback? onBack;

  const ProfilePage({super.key, required this.profile, this.onBack});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _fullNameController;
  late TextEditingController _universityController;
  late TextEditingController _programController;
  late TextEditingController _semesterController;
  late TextEditingController _mainSportController;
  bool _isEditing = false;

  String _buildInitials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _universityController = TextEditingController(
      text: widget.profile.university ?? '',
    );
    _programController = TextEditingController(
      text: widget.profile.program ?? '',
    );
    _semesterController = TextEditingController(
      text: widget.profile.semester?.toString() ?? '',
    );
    _mainSportController = TextEditingController(
      text: widget.profile.mainSport ?? '',
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _universityController.dispose();
    _programController.dispose();
    _semesterController.dispose();
    _mainSportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMainSportKey = _mainSportController.text.trim().isEmpty
        ? null
        : AppSports.normalizeSportKey(_mainSportController.text);
    final selectedMainSportForDropdown =
        AppSports.sportKeys.contains(selectedMainSportKey)
        ? selectedMainSportKey
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Perfil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _isEditing
                        ? Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    setState(() => _isEditing = false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text('Guardar'),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: () => setState(() => _isEditing = true),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar'),
                          ),
                  ],
                ),
                const SizedBox(height: 24),

                // Profile Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.teal,
                        child: Text(
                          _buildInitials(widget.profile.fullName),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_isEditing)
                        Column(
                          children: [
                            Text(
                              widget.profile.fullName.toUpperCase(),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.profile.university ??
                                  'Universidad no especificada',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.profile.semester ?? 0}º Semestre - ${widget.profile.role.label}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Stats
                if (!_isEditing)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatBox(label: 'MATCHES', value: '34'),
                      _StatBox(label: 'WIN RATE', value: '66%'),
                      _StatBox(label: 'AVG PACE', value: '5:23 min/km'),
                      _StatBox(label: 'STREAK', value: '7d'),
                    ],
                  ),
                if (!_isEditing) const SizedBox(height: 32),

                // Form
                if (_isEditing) ...[
                  const Text('Nombre completo'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Universidad'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _universityController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Programa'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _programController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Semestre'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _semesterController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Deporte principal'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMainSportForDropdown,
                    items: AppSports.sportKeys
                        .map(
                          (key) => DropdownMenuItem(
                            value: key,
                            child: Text(AppSports.getSport(key).name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      _mainSportController.text = value ?? '';
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  // Perfil Info
                  _ProfileInfoCard(
                    icon: Icons.school,
                    title: 'Universidad',
                    value: widget.profile.university ?? 'No especificada',
                  ),
                  const SizedBox(height: 12),
                  _ProfileInfoCard(
                    icon: Icons.category,
                    title: 'Programa',
                    value: widget.profile.program ?? 'No especificado',
                  ),
                  const SizedBox(height: 12),
                  _ProfileInfoCard(
                    icon: Icons.calendar_today,
                    title: 'Semestre',
                    value: '${widget.profile.semester ?? 0}°',
                  ),
                  const SizedBox(height: 12),
                  _ProfileInfoCard(
                    icon: Icons.sports_soccer,
                    title: 'Deporte Principal',
                    value:
                        AppSports.formatSportLabel(
                          widget.profile.mainSport,
                        ).isEmpty
                        ? 'No especificado'
                        : AppSports.formatSportLabel(widget.profile.mainSport),
                  ),
                  const SizedBox(height: 12),
                  _ProfileInfoCard(
                    icon: Icons.email,
                    title: 'Email',
                    value: widget.profile.email,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => context.read<AuthController>().signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveProfile() async {
    final repository = context.read<AuthRepository>();
    final semester = int.tryParse(_semesterController.text);

    await repository.updateUserProfile(
      uid: widget.profile.uid,
      fullName: _fullNameController.text,
      university: _universityController.text,
      program: _programController.text,
      semester: semester,
      mainSport: _mainSportController.text,
    );

    setState(() => _isEditing = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
