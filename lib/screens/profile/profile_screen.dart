import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_dashboard_screen.dart';
import '../business/business_dashboard_screen.dart';
import 'my_reservations_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _imagePicker = ImagePicker();
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  Future<void> _pickAvatar() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final appState = context.read<AppState>();
      final bytes = await file.readAsBytes();
      final url = await appState.service.uploadImage(
        bucket: 'avatars',
        folder: appState.user!.id,
        bytes: bytes,
        fileName: file.name,
      );
      await appState.saveProfile(avatarUrl: url);
      _snack('Foto de perfil actualizada.', success: true);
    } catch (e) {
      _snack('No se pudo subir la foto: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _pickCover() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _uploadingCover = true);
    try {
      final appState = context.read<AppState>();
      final bytes = await file.readAsBytes();
      final url = await appState.service.uploadImage(
        bucket: 'business-images',
        folder: '${appState.user!.id}/portada',
        bytes: bytes,
        fileName: file.name,
      );
      await appState.saveProfile(portadaUrl: url);
      _snack('Foto del negocio actualizada.', success: true);
    } catch (e) {
      _snack('No se pudo subir la portada: $e');
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.primaryColor : Colors.redAccent,
      ),
    );
  }

  void _openEditProfile() {
    final appState = context.read<AppState>();
    final profile = appState.profile;
    final nombreController = TextEditingController(text: profile?.nombre ?? '');
    final telefonoController = TextEditingController(text: profile?.telefono ?? '');
    final negocioController =
        TextEditingController(text: profile?.nombreNegocio ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Editar perfil',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nombreController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa tu nombre'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telefonoController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    if (appState.isBusiness) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: negocioController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del negocio',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => saving = true);
                              try {
                                await appState.saveProfile(
                                  nombre: nombreController.text,
                                  telefono: telefonoController.text,
                                  nombreNegocio: appState.isBusiness
                                      ? negocioController.text
                                      : null,
                                );
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                                _snack('Perfil actualizado.', success: true);
                              } catch (e) {
                                _snack('No se pudo guardar: $e');
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.profile;
    final displayName = appState.displayName;
    final email = profile?.email ?? appState.user?.email ?? '';
    final rol = profile?.rolLabel ?? 'Turista';
    final telefono = profile?.telefono.isNotEmpty == true
        ? profile!.telefono
        : 'Sin registrar';
    final isBusiness = appState.isBusiness;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.refreshProfile();
          await appState.refreshReservas();
        },
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _ProfileHeader(
                profileName: displayName,
                roleLabel: rol,
                email: email,
                avatarUrl: profile?.avatarUrl ?? '',
                coverUrl: profile?.portadaUrl ?? '',
                inicial: profile?.inicial ?? 'T',
                isBusiness: isBusiness,
                uploadingAvatar: _uploadingAvatar,
                uploadingCover: _uploadingCover,
                onPickAvatar: _pickAvatar,
                onPickCover: _pickCover,
              ),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.bookmark_rounded,
                              color: AppTheme.secondaryColor,
                              label: 'Favoritos',
                              value: '${appState.favoritos.length}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.phone_android_rounded,
                              color: AppTheme.primaryColor,
                              label: 'Teléfono',
                              value: telefono,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (isBusiness)
                        _OptionTile(
                          icon: Icons.storefront_rounded,
                          color: AppTheme.secondaryColor,
                          title: 'Panel de mi negocio',
                          subtitle: 'Lugares, imágenes y reservas',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BusinessDashboardScreen(),
                              ),
                            );
                          },
                        ),
                      if (appState.isAdmin)
                        _OptionTile(
                          icon: Icons.admin_panel_settings_rounded,
                          color: Colors.indigo,
                          title: 'Panel de administración',
                          subtitle: 'Usuarios, negocios, categorías y reservas',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminDashboardScreen(),
                              ),
                            );
                          },
                        ),
                      _OptionTile(
                        icon: Icons.receipt_long_rounded,
                        color: AppTheme.primaryColor,
                        title: 'Mis reservas',
                        subtitle: 'Consulta el estado de tus reservas',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyReservationsScreen(),
                            ),
                          );
                        },
                      ),
                      _OptionTile(
                        icon: Icons.edit_outlined,
                        color: Colors.blueGrey,
                        title: 'Editar perfil',
                        subtitle: 'Actualiza tus datos personales',
                        onTap: _openEditProfile,
                      ),
                      _OptionTile(
                        icon: Icons.directions_bus_rounded,
                        color: Colors.teal,
                        title: 'Transporte en Santa Cruz',
                        subtitle: 'Consulta líneas y cómo llegar desde el mapa',
                        onTap: () {
                          _snack(
                            'Abre el mapa y toca "Cómo llegar" en cualquier lugar.',
                            success: true,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: const Text('¿Cerrar sesión?'),
                                content: const Text(
                                    'Tendrás que iniciar sesión nuevamente para acceder a tu cuenta.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Cerrar sesión'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await appState.signOut();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String profileName;
  final String roleLabel;
  final String email;
  final String avatarUrl;
  final String coverUrl;
  final String inicial;
  final bool isBusiness;
  final bool uploadingAvatar;
  final bool uploadingCover;
  final VoidCallback onPickAvatar;
  final VoidCallback onPickCover;

  const _ProfileHeader({
    required this.profileName,
    required this.roleLabel,
    required this.email,
    required this.avatarUrl,
    required this.coverUrl,
    required this.inicial,
    required this.isBusiness,
    required this.uploadingAvatar,
    required this.uploadingCover,
    required this.onPickAvatar,
    required this.onPickCover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryColor, AppTheme.primaryLight],
            ),
          ),
          child: coverUrl.isNotEmpty
              ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                )
              : null,
        ),
        if (coverUrl.isNotEmpty)
          Positioned.fill(
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
        if (isBusiness)
          Positioned(
            top: 80,
            right: 16,
            child: _CircleAction(
              loading: uploadingCover,
              icon: Icons.photo_camera_back_rounded,
              onTap: onPickCover,
              tooltip: 'Cambiar portada',
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 70),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl.isNotEmpty
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _initialAvatar(),
                          )
                        : _initialAvatar(),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _CircleAction(
                      loading: uploadingAvatar,
                      icon: Icons.photo_camera_rounded,
                      onTap: onPickAvatar,
                      tooltip: 'Cambiar foto',
                      small: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                profileName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _initialAvatar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
        ),
      ),
      child: Center(
        child: Text(
          inicial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool loading;
  final bool small;

  const _CircleAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.loading = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 32.0 : 40.0;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
              ),
            ],
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(9),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon,
                  size: small ? 16 : 20, color: AppTheme.primaryColor),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style:
              const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: AppTheme.textSecondary),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
