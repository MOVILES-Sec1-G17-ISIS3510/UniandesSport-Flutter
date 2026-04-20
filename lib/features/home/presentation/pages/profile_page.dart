import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../../core/validation/app_field_limits.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

class ProfilePage extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback? onBack;

  const ProfilePage({super.key, required this.profile, this.onBack});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _editFormKey = GlobalKey<FormState>();
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
        title: const Text('Profile'),
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
                                child: const Text('Cancel'),
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
                                child: const Text('Save'),
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
                            label: const Text('Edit'),
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
                                  'University not specified',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.profile.semester ?? 0}th Semester - ${widget.profile.role.label}',
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
                  Form(
                    key: _editFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Full name'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _fullNameController,
                          textInputAction: TextInputAction.next,
                          maxLength: AppFieldLimits.fullName,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.fullName,
                            ),
                          ],
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Full name is required';
                            if (text.length <
                                AppValidationRules.fullNameMinLength) {
                              return 'At least 3 characters';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('University'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _universityController,
                          textInputAction: TextInputAction.next,
                          maxLength: AppFieldLimits.university,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.university,
                            ),
                          ],
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isNotEmpty &&
                                text.length <
                                    AppValidationRules
                                        .shortOptionalTextMinLength) {
                              return 'University is too short';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Program'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _programController,
                          textInputAction: TextInputAction.next,
                          maxLength: AppFieldLimits.program,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.program,
                            ),
                          ],
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isNotEmpty &&
                                text.length <
                                    AppValidationRules
                                        .shortOptionalTextMinLength) {
                              return 'Program is too short';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Semester'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _semesterController,
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.number,
                          maxLength: AppFieldLimits.semesterDigits,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.semesterDigits,
                            ),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Semester is required';
                            final semester = int.tryParse(text);
                            if (semester == null ||
                                semester < AppValidationRules.semesterMin ||
                                semester > AppValidationRules.semesterMax) {
                              return 'Enter a semester between 1 and 20';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Main sport'),
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
                      ],
                    ),
                  ),
                ] else ...[
                  // Perfil Info
                  _ProfileInfoCard(
                    icon: Icons.school,
                    title: 'University',
                    value: widget.profile.university ?? 'Not specified',
                  ),
                  const SizedBox(height: 12),
                  _ProfileInfoCard(
                    icon: Icons.category,
                    title: 'Program',
                    value: widget.profile.program ?? 'Not specified',
                  ),
                  const SizedBox(height: 12),
                  _ProfileInfoCard(
                    icon: Icons.calendar_today,
                    title: 'Semester',
                    value: '${widget.profile.semester ?? 0}°',
                  ),
                  const SizedBox(height: 12),
                  _ProfileInfoCard(
                    icon: Icons.sports_soccer,
                    title: 'Main sport',
                    value:
                        AppSports.formatSportLabel(
                          widget.profile.mainSport,
                        ).isEmpty
                        ? 'Not specified'
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
                    onPressed: () => context.read<AuthViewModel>().signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
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
    if (!_editFormKey.currentState!.validate()) return;

    final repository = context.read<AuthRepository>();
    final semester = int.tryParse(_semesterController.text.trim());

    await repository.updateUserProfile(
      uid: widget.profile.uid,
      fullName: _fullNameController.text.trim(),
      university: _universityController.text.trim(),
      program: _programController.text.trim(),
      semester: semester,
      mainSport: _mainSportController.text.trim(),
    );

    setState(() => _isEditing = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
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
