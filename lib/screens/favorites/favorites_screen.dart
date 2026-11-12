import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/place_model.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../details/details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final favorites = appState.favoriteDestinos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis lugares guardados'),
      ),
      body: RefreshIndicator(
        onRefresh: appState.refreshAll,
        color: AppTheme.primaryColor,
        child: appState.loadingData && favorites.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : favorites.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                      Icon(Icons.bookmark_border_rounded,
                          size: 72, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'Aún no tienes lugares guardados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Toca el marcador en cualquier lugar para encontrarlo aquí al instante.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      return _FavoriteTile(destino: favorites[index]);
                    },
                  ),
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final DestinoLugar destino;

  const _FavoriteTile({required this.destino});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailsScreen(destino: destino)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: destino.imagenPrincipal.isEmpty
                    ? Container(
                        width: 85,
                        height: 85,
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        child: const Icon(Icons.landscape_rounded,
                            color: AppTheme.primaryColor),
                      )
                    : Image.network(
                        destino.imagenPrincipal,
                        width: 85,
                        height: 85,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 85,
                          height: 85,
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.landscape_rounded,
                              color: AppTheme.primaryColor),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destino.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destino.direccion.isNotEmpty
                          ? destino.direccion
                          : 'Santa Cruz de la Sierra',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          destino.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${destino.totalReviews})',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.bookmark_remove_rounded,
                              color: Colors.redAccent),
                          onPressed: () async {
                            try {
                              await context
                                  .read<AppState>()
                                  .toggleFavorite(destino);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
