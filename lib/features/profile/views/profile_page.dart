import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user_profile.dart';
import '../../auth/models/user_role.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_picture_dialog.dart';

/// Página de perfil del usuario que integra la funcionalidad de edición de foto.
///
/// Arquitectura MVVM:
/// - Vista (esta página) consume el ViewModel mediante Provider
/// - ViewModel orquesta el flujo de cambio de foto
/// - No hay importes de Firebase directamente en esta página
class ProfilePage extends StatefulWidget {
  final UserProfile profile;

  const ProfilePage({
    super.key,
    required this.profile,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Inicializar el ViewModel con el perfil actual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileViewModel>().initialize(widget.profile.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
      ),
      body: Consumer<ProfileViewModel>(
        builder: (context, viewModel, child) {
          final profile = viewModel.profile ?? widget.profile;

          // Mostrar mensaje de error si existe
          if (viewModel.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(viewModel.errorMessage!),
                  action: SnackBarAction(
                    label: 'Close',
                    onPressed: viewModel.clearError,
                  ),
                ),
              );
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Sección: Avatar con foto de perfil
                _buildProfileAvatarSection(context, viewModel, profile),

                const SizedBox(height: 24),

                // Sección: Información del usuario
                _buildUserInfoSection(profile),

                const SizedBox(height: 32),

                // Botón: Editar foto de perfil
                ElevatedButton.icon(
                  onPressed: viewModel.isLoading
                      ? null
                      : () => _showProfilePictureOptions(context, viewModel),
                  icon: const Icon(Icons.edit),
                  label: const Text('Change profile picture'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Construye la sección del avatar con foto de perfil.
  Widget _buildProfileAvatarSection(
    BuildContext context,
    ProfileViewModel viewModel,
    UserProfile profile,
  ) {
    return Column(
      children: [
        // Avatar con indicador de carga
        ProfileAvatar(
          photoUrl: profile.photoUrl,
          fullName: profile.fullName,
          radius: 64,
          isLoading: viewModel.isLoading,
          onTap: viewModel.isLoading
              ? null
              : () => _showProfilePictureOptions(context, viewModel),
        ),

        const SizedBox(height: 16),

        // Nombre del usuario
        Text(
          profile.fullName,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),

        // Email del usuario
        Text(
          profile.email,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Construye la sección de información del usuario.
  Widget _buildUserInfoSection(UserProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('University', profile.university ?? 'Not specified'),
            if (profile.program != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildInfoRow('Program', profile.program!),
              ),
            if (profile.mainSport != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildInfoRow('Main sport', profile.mainSport!),
              ),
            // Mostrar el rol del usuario usando la extensión UserRoleX.label
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildInfoRow('Role', profile.role.label),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper para mostrar filas de información.
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// Muestra las opciones para seleccionar la fuente de la foto.
  Future<void> _showProfilePictureOptions(
    BuildContext context,
    ProfileViewModel viewModel,
  ) async {
    // Usar BottomSheet para una UX más moderna
    final imageSource = await ProfilePictureDialog.showPictureSourcePicker(context);

    if (imageSource == null) return;

    // Llamar al ViewModel para cambiar la foto
    await viewModel.changeProfilePicture(
      source: imageSource,
      userId: widget.profile.uid,
    );

    // Mostrar confirmación
    if (mounted && viewModel.errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

