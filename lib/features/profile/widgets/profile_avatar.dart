import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget que renderiza el avatar (foto de perfil) del usuario con caché.
///
/// Características:
/// - Utiliza `cached_network_image` para aplicar estrategia de caché L1/L2 (RAM y Disco)
/// - Muestra placeholder mientras se carga la imagen
/// - Muestra fallback si la imagen no puede cargarse
/// - Soporta avatar con iniciales como fallback
/// - Indicador de carga circular mientras se descarga
///
/// Dependencias requeridas en pubspec.yaml:
/// - cached_network_image: ^3.3.1
class ProfileAvatar extends StatelessWidget {
  /// URL de la foto de perfil (de Firebase Storage)
  final String? photoUrl;

  /// Nombre completo para generar iniciales si no hay foto
  final String fullName;

  /// ID del usuario (opcional). Si se provee, se usa para construir cacheKey más estable.
  final String? userId;

  /// Radius del avatar (en dp)
  final double radius;

  /// Callback cuando se toca el avatar (opcional)
  final VoidCallback? onTap;

  /// Indica si se está cargando (muestra indicador de progreso)
  final bool isLoading;

  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.fullName,
    this.userId,
    this.radius = 50,
    this.onTap,
    this.isLoading = false,
  });

  /// Genera iniciales a partir del nombre completo.
  /// Ejemplo: "Juan Pérez Rodríguez" → "JPR"
  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    // Tomar primera letra de hasta 3 palabras
    return parts
        .take(3)
        .map((part) => part[0].toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar principal con imagen o iniciales (usando CachedNetworkImage)
          if (photoUrl != null && photoUrl!.isNotEmpty)
            _buildCachedImageAvatar(context)
          else
            _buildInitialsAvatar(),

          // Indicador de carga superpuesto
          if (isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(0, 0, 0, 0.3),
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),

          // Badge de edición (ícono de cámara) si hay callback onTap
          if (onTap != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: radius * 0.42,
                  height: radius * 0.42,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: radius * 0.22,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCachedImageAvatar(BuildContext context) {
    final cacheKey = userId != null && userId!.isNotEmpty
        ? 'profile_avatar_user_$userId'
        : 'profile_avatar_${Uri.parse(photoUrl!).pathSegments.last}';

    return CachedNetworkImage(
      imageUrl: photoUrl!,
      // cacheKey opcional: puedes usar la URL o una clave derivada del userId
      cacheKey: cacheKey,
      imageBuilder: (context, imageProvider) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[300],
          backgroundImage: imageProvider,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey[400]!,
                width: 2,
              ),
            ),
          ),
        );
      },
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => _buildInitialsAvatar(),
    );
  }

  /// Construye avatar con iniciales (fallback cuando no hay foto).
  Widget _buildInitialsAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue[100],
      child: Text(
        _getInitials(fullName),
        style: TextStyle(
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
          color: Colors.blue[900],
        ),
      ),
    );
  }
}
