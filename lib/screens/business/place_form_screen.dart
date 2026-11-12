import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/place_model.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import 'map_picker_screen.dart';

class PlaceFormScreen extends StatefulWidget {
  final DestinoLugar? existing;

  const PlaceFormScreen({super.key, this.existing});

  @override
  State<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends State<PlaceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _direccion;
  late final TextEditingController _telefono;
  late final TextEditingController _precio;
  late final TextEditingController _precioTexto;
  final _servicioController = TextEditingController();

  late String _tipo;
  int? _categoriaId;
  late double _lat;
  late double _lng;
  late bool _activo;
  late List<String> _servicios;
  late List<String> _existingGallery;
  String _existingMain = '';

  XFile? _newMain;
  final List<XFile> _newGallery = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final place = widget.existing;
    _nombre = TextEditingController(text: place?.nombre ?? '');
    _descripcion = TextEditingController(text: place?.descripcion ?? '');
    _direccion = TextEditingController(text: place?.direccion ?? '');
    _telefono = TextEditingController(text: place?.telefono ?? '');
    _precio = TextEditingController(
        text: place == null || place.precio == 0 ? '' : place.precio.toStringAsFixed(2));
    _precioTexto = TextEditingController(text: place?.precioTexto ?? '');
    _tipo = place?.tipo ?? 'attraction';
    _categoriaId = place?.idCategoria;
    _lat = place?.latitud ?? -17.7833;
    _lng = place?.longitud ?? -63.1821;
    _activo = place?.activo ?? true;
    _servicios = [...?place?.serviciosIncluidos];
    _existingMain = place?.imagenPrincipal ?? '';
    _existingGallery = [
      if (place != null)
        ...place.imagenes.where((image) => image != place.imagenPrincipal)
    ];
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _direccion.dispose();
    _telefono.dispose();
    _precio.dispose();
    _precioTexto.dispose();
    _servicioController.dispose();
    super.dispose();
  }

  Future<void> _chooseAndPickMain() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file != null) setState(() => _newMain = file);
  }

  Future<void> _pickGallery() async {
    final files = await _imagePicker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (files.isNotEmpty) {
      setState(() => _newGallery.addAll(files));
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initial: LatLng(_lat, _lng)),
      ),
    );
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
      });
    }
  }

  void _addServicio() {
    final value = _servicioController.text.trim();
    if (value.isEmpty) return;
    if (!_servicios.contains(value)) {
      setState(() => _servicios.add(value));
    }
    _servicioController.clear();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaId == null) {
      _snack('Selecciona una categoría para tu lugar.');
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final appState = context.read<AppState>();
      final user = appState.user;
      if (user == null) throw 'Debes iniciar sesión.';

      var mainImage = _existingMain;
      if (_newMain != null) {
        final bytes = await _newMain!.readAsBytes();
        mainImage = await appState.service.uploadImage(
          bucket: 'business-images',
          folder: '${user.id}/lugares',
          bytes: bytes,
          fileName: _newMain!.name,
        );
      }

      final gallery = [..._existingGallery];
      for (final file in _newGallery) {
        final bytes = await file.readAsBytes();
        final url = await appState.service.uploadImage(
          bucket: 'business-images',
          folder: '${user.id}/lugares',
          bytes: bytes,
          fileName: file.name,
        );
        gallery.add(url);
      }

      if (mainImage.isEmpty && gallery.isNotEmpty) mainImage = gallery.first;

      final place = DestinoLugar(
        id: widget.existing?.id ?? '',
        idUsuario: widget.existing?.idUsuario ?? user.id,
        idCategoria: _categoriaId,
        nombre: _nombre.text.trim(),
        tipo: _tipo,
        descripcion: _descripcion.text.trim(),
        direccion: _direccion.text.trim(),
        telefono: _telefono.text.trim(),
        precio: double.tryParse(_precio.text.replaceAll(',', '.')) ?? 0,
        precioTexto: _precioTexto.text.trim(),
        rating: widget.existing?.rating ?? 0,
        totalReviews: widget.existing?.totalReviews ?? 0,
        imagenPrincipal: mainImage,
        imagenes: gallery,
        serviciosIncluidos: _servicios,
        latitud: _lat,
        longitud: _lng,
        activo: _activo,
      );

      final saved = widget.existing == null
          ? await appState.service.createPlace(place)
          : await appState.service.updatePlace(place);

      appState.upsertPlace(saved);

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.existing == null
              ? '¡Tu lugar ya está publicado!'
              : 'Los cambios se guardaron correctamente.'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categorias = context.watch<AppState>().categoriasSinTodo;
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar lugar' : 'Nuevo lugar'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _sectionTitle('Foto principal'),
              const SizedBox(height: 8),
              _MainImagePicker(
                existingUrl: _existingMain,
                newFile: _newMain,
                onPick: _chooseAndPickMain,
                onRemove: () => setState(() {
                  _newMain = null;
                  _existingMain = '';
                }),
              ),
              const SizedBox(height: 18),

              _sectionTitle('Información del lugar'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del lugar *',
                  hintText: 'Ej. Café 24',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Ingresa el nombre del lugar'
                        : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _categoriaId,
                decoration: const InputDecoration(
                  labelText: 'Categoría *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: categorias
                    .map((c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.nombre),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _categoriaId = value),
                validator: (value) =>
                    value == null ? 'Selecciona una categoría' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de lugar',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'attraction', child: Text('Atracción turística')),
                  DropdownMenuItem(value: 'restaurant', child: Text('Restaurante')),
                  DropdownMenuItem(value: 'hotel', child: Text('Hotel')),
                  DropdownMenuItem(value: 'hospital', child: Text('Salud')),
                ],
                onChanged: (value) => setState(() => _tipo = value ?? 'attraction'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcion,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Describe tu lugar para los turistas...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccion,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  hintText: 'Calle, zona o referencia',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono de contacto',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _precio,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Precio (Bs.)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _precioTexto,
                      decoration: const InputDecoration(
                        labelText: 'Texto de precio',
                        hintText: 'Ej. Bs. 25 promedio',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _sectionTitle('Ubicación'),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 160,
                  child: FlutterMap(
                    key: ValueKey('$_lat,$_lng'),
                    options: MapOptions(
                      initialCenter: LatLng(_lat, _lng),
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.turisapp.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_lat, _lng),
                            width: 42,
                            height: 42,
                            child: const Icon(Icons.location_on_rounded,
                                color: AppTheme.secondaryColor, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Elegir ubicación en el mapa'),
              ),
              Text(
                'Lat ${_lat.toStringAsFixed(6)} · Lng ${_lng.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),

              _sectionTitle('Galería de fotos'),
              const SizedBox(height: 8),
              _GalleryEditor(
                existing: _existingGallery,
                newFiles: _newGallery,
                onAdd: _pickGallery,
                onRemoveExisting: (index) =>
                    setState(() => _existingGallery.removeAt(index)),
                onRemoveNew: (index) => setState(() => _newGallery.removeAt(index)),
              ),
              const SizedBox(height: 20),

              _sectionTitle('Servicios incluidos'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _servicioController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _addServicio(),
                      decoration: const InputDecoration(
                        hintText: 'Ej. WiFi, parqueo, desayuno',
                        prefixIcon: Icon(Icons.check_circle_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addServicio,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (_servicios.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _servicios
                      .map((servicio) => Chip(
                            label: Text(servicio),
                            onDeleted: () =>
                                setState(() => _servicios.remove(servicio)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lugar visible para turistas'),
                subtitle: const Text(
                    'Puedes ocultarlo temporalmente sin eliminarlo.'),
                value: _activo,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) => setState(() => _activo = value),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(isEditing ? 'Guardar cambios' : 'Publicar lugar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _MainImagePicker extends StatelessWidget {
  final String existingUrl;
  final XFile? newFile;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _MainImagePicker({
    required this.existingUrl,
    required this.newFile,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = existingUrl.isNotEmpty || newFile != null;

    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (newFile != null)
              _LocalImageFile(file: newFile!)
            else if (existingUrl.isNotEmpty)
              Image.network(
                existingUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            else
              _placeholder(),
            if (hasImage)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_a_photo_outlined,
              size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Agregar foto principal',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _GalleryEditor extends StatelessWidget {
  final List<String> existing;
  final List<XFile> newFiles;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveExisting;
  final ValueChanged<int> onRemoveNew;

  const _GalleryEditor({
    required this.existing,
    required this.newFiles,
    required this.onAdd,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.add_photo_alternate_outlined,
                  color: Colors.grey.shade500),
            ),
          ),
          for (var i = 0; i < existing.length; i++)
            _GalleryThumb(
              onRemove: () => onRemoveExisting(i),
              child: Image.network(existing[i], fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined)),
            ),
          for (var i = 0; i < newFiles.length; i++)
            _GalleryThumb(
              onRemove: () => onRemoveNew(i),
              child: _LocalImageFile(file: newFiles[i]),
            ),
        ],
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;

  const _GalleryThumb({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalImageFile extends StatelessWidget {
  final XFile file;

  const _LocalImageFile({required this.file});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(
          color: Colors.grey.shade100,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
