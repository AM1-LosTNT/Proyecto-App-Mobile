import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Alert,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useApp } from '../context/AppContext';
import { colors, spacing, borderRadius, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

export const BusinessPanelScreen = () => {
  const {
    user,
    goBack,
    addBusinessPlace,
    deleteBusinessPlace,
    mapPoints,
    bookings,
    selectedMapCoords,
    setCurrentScreen,
  } = useApp();

  const [activeTab, setActiveTab] = useState('add'); // 'add' | 'my-places' | 'bookings'

  // Formulario para nuevo negocio
  const [name, setName] = useState('');
  const [type, setType] = useState('hotel'); // 'hotel' | 'restaurant' | 'hospital' | 'attraction'
  const [address, setAddress] = useState('');
  const [phone, setPhone] = useState('');
  const [price, setPrice] = useState('');
  const [description, setDescription] = useState('');
  const [imageUrl, setImageUrl] = useState('');

  // Negocios de este dueño
  const myPlaces = mapPoints.filter(
    (p) => user.role === 'admin' || p.ownerEmail === user.email
  );

  // Reservas dirigidas a este negocio
  const receivedBookings = bookings.filter(
    (b) => user.role === 'admin' || b.ownerEmail === user.email
  );

  const handleSavePlace = () => {
    if (!name.trim()) {
      Alert.alert('Campo requerido', 'Por favor ingresa el nombre de tu negocio.');
      return;
    }

    const newPlace = {
      name,
      type,
      address: address || 'Zona Turística Central',
      phone: phone || '+56 9 1234 5678',
      price: price ? `$${price}` : '$25 / persona',
      numericPrice: price || '25',
      description: description || 'Servicio turístico de calidad garantizada.',
      image:
        imageUrl.trim() ||
        (type === 'hotel'
          ? 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=600&q=80'
          : type === 'restaurant'
          ? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=600&q=80'
          : type === 'hospital'
          ? 'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80'
          : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80'),
      lat: selectedMapCoords ? parseFloat(selectedMapCoords.lat) : -33.4372,
      lng: selectedMapCoords ? parseFloat(selectedMapCoords.lng) : -70.6506,
    };

    addBusinessPlace(newPlace);
    Alert.alert('¡Éxito!', 'Tu negocio ha sido publicado en el mapa y catálogo de TurisApp.');
    setName('');
    setAddress('');
    setPhone('');
    setPrice('');
    setDescription('');
    setImageUrl('');
    setActiveTab('my-places');
  };

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
      {/* Cabecera */}
      <View style={styles.header}>
        <TouchableOpacity onPress={goBack} style={styles.backButton}>
          <Ionicons name="arrow-back" size={24} color={colors.textPrimary} />
        </TouchableOpacity>
        <View style={styles.headerTitles}>
          <Text style={styles.title}>Panel de Negocio</Text>
          <Text style={styles.subtitle}>Gestor de Servicios & Atracciones</Text>
        </View>
        <View style={styles.badge}>
          <Text style={styles.badgeText}>DUEÑO</Text>
        </View>
      </View>

      {/* Pestañas del Panel */}
      <View style={styles.tabsContainer}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'add' && styles.tabActive]}
          onPress={() => setActiveTab('add')}
        >
          <Ionicons
            name="add-circle"
            size={16}
            color={activeTab === 'add' ? colors.primary : colors.textMuted}
          />
          <Text style={[styles.tabText, activeTab === 'add' && styles.tabTextActive]}>
            Publicar
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.tab, activeTab === 'my-places' && styles.tabActive]}
          onPress={() => setActiveTab('my-places')}
        >
          <Ionicons
            name="business"
            size={16}
            color={activeTab === 'my-places' ? colors.primary : colors.textMuted}
          />
          <Text style={[styles.tabText, activeTab === 'my-places' && styles.tabTextActive]}>
            Mis Locales ({myPlaces.length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.tab, activeTab === 'bookings' && styles.tabActive]}
          onPress={() => setActiveTab('bookings')}
        >
          <Ionicons
            name="calendar"
            size={16}
            color={activeTab === 'bookings' ? colors.primary : colors.textMuted}
          />
          <Text style={[styles.tabText, activeTab === 'bookings' && styles.tabTextActive]}>
            Reservas ({receivedBookings.length})
          </Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentContainer}>
        {/* TAB 1: FORMULARIO PUBLICAR LUGAR */}
        {activeTab === 'add' && (
          <View style={styles.formCard}>
            <Text style={styles.sectionTitle}>Registrar Nuevo Negocio / Atracción</Text>
            <Text style={styles.sectionSubtitle}>
              Aparecerá en el mapa interactivo y en la pantalla principal para todos los turistas.
            </Text>

            {/* Aviso de Coordenadas del Mapa */}
            {selectedMapCoords ? (
              <View style={styles.coordsAlert}>
                <Ionicons name="location" size={18} color={colors.primary} />
                <Text style={styles.coordsAlertText}>
                  Ubicación seleccionada en el mapa: {selectedMapCoords.lat}, {selectedMapCoords.lng}
                </Text>
              </View>
            ) : (
              <TouchableOpacity
                style={styles.pickCoordsBtn}
                onPress={() => setCurrentScreen('Map')}
              >
                <Ionicons name="map-outline" size={16} color={colors.primary} />
                <Text style={styles.pickCoordsText}>
                  Tocar en el mapa para marcar ubicación exacta
                </Text>
              </TouchableOpacity>
            )}

            {/* Selector de Tipo de Negocio */}
            <Text style={styles.label}>Tipo de Establecimiento</Text>
            <View style={styles.typeSelector}>
              {[
                { id: 'hotel', label: 'Hotel', icon: 'bed' },
                { id: 'restaurant', label: 'Restaurante', icon: 'restaurant' },
                { id: 'attraction', label: 'Atracción', icon: 'star' },
                { id: 'hospital', label: 'Hospital / Salud', icon: 'medkit' },
              ].map((t) => (
                <TouchableOpacity
                  key={t.id}
                  style={[styles.typeOption, type === t.id && styles.typeOptionActive]}
                  onPress={() => setType(t.id)}
                >
                  <Ionicons
                    name={t.icon}
                    size={18}
                    color={type === t.id ? '#FFFFFF' : colors.textSecondary}
                  />
                  <Text
                    style={[
                      styles.typeOptionText,
                      type === t.id && styles.typeOptionTextActive,
                    ]}
                  >
                    {t.label}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text style={styles.label}>Nombre del Negocio o Destino *</Text>
            <TextInput
              style={styles.input}
              placeholder="Ej: Posada Las Nubes / Mirador Andino"
              placeholderTextColor={colors.textMuted}
              value={name}
              onChangeText={setName}
            />

            <Text style={styles.label}>Dirección o Referencia</Text>
            <TextInput
              style={styles.input}
              placeholder="Ej: Av. Las Cumbres 450, Centro Histórico"
              placeholderTextColor={colors.textMuted}
              value={address}
              onChangeText={setAddress}
            />

            <View style={styles.rowInputs}>
              <View style={styles.halfInput}>
                <Text style={styles.label}>Teléfono / WhatsApp</Text>
                <TextInput
                  style={styles.input}
                  placeholder="+56 9 8765 4321"
                  placeholderTextColor={colors.textMuted}
                  value={phone}
                  onChangeText={setPhone}
                  keyboardType="phone-pad"
                />
              </View>

              <View style={styles.halfInput}>
                <Text style={styles.label}>Precio Base ($USD)</Text>
                <TextInput
                  style={styles.input}
                  placeholder="Ej: 45"
                  placeholderTextColor={colors.textMuted}
                  value={price}
                  onChangeText={setPrice}
                  keyboardType="numeric"
                />
              </View>
            </View>

            <Text style={styles.label}>URL de Foto (opcional)</Text>
            <TextInput
              style={styles.input}
              placeholder="https://..."
              placeholderTextColor={colors.textMuted}
              value={imageUrl}
              onChangeText={setImageUrl}
            />

            <Text style={styles.label}>Descripción de Servicios</Text>
            <TextInput
              style={[styles.input, styles.textArea]}
              placeholder="Detalla lo que ofreces: horarios, comodidades, especialidades..."
              placeholderTextColor={colors.textMuted}
              value={description}
              onChangeText={setDescription}
              multiline
              numberOfLines={3}
            />

            <TouchableOpacity style={styles.submitBtn} onPress={handleSavePlace}>
              <Ionicons name="checkmark-circle" size={20} color="#FFFFFF" />
              <Text style={styles.submitBtnText}>Publicar en TurisApp</Text>
            </TouchableOpacity>
          </View>
        )}

        {/* TAB 2: MIS LOCALES REGISTRADOS */}
        {activeTab === 'my-places' && (
          <View>
            {myPlaces.length === 0 ? (
              <View style={styles.emptyBox}>
                <Ionicons name="business-outline" size={48} color={colors.textMuted} />
                <Text style={styles.emptyTitle}>No tienes negocios registrados aún</Text>
                <Text style={styles.emptySub}>
                  Utiliza la pestaña "Publicar" para dar de alta tu primer hotel, restaurante o atracción.
                </Text>
              </View>
            ) : (
              myPlaces.map((place) => (
                <View key={place.id} style={styles.placeCard}>
                  <Image source={{ uri: place.image }} style={styles.placeImage} />
                  <View style={styles.placeInfo}>
                    <View style={styles.typeTag}>
                      <Text style={styles.typeTagText}>{place.typeName}</Text>
                    </View>
                    <Text style={styles.placeName}>{place.name}</Text>
                    <Text style={styles.placeAddress}>{place.address}</Text>
                    <Text style={styles.placePrice}>{place.price}</Text>
                  </View>
                  <TouchableOpacity
                    style={styles.deleteBtn}
                    onPress={() => {
                      Alert.alert(
                        'Eliminar negocio',
                        `¿Estás seguro de retirar "${place.name}" del catálogo?`,
                        [
                          { text: 'Cancelar', style: 'cancel' },
                          {
                            text: 'Eliminar',
                            style: 'destructive',
                            onPress: () => deleteBusinessPlace(place.id),
                          },
                        ]
                      );
                    }}
                  >
                    <Ionicons name="trash-outline" size={20} color={colors.danger} />
                  </TouchableOpacity>
                </View>
              ))
            )}
          </View>
        )}

        {/* TAB 3: RESERVAS RECIBIDAS */}
        {activeTab === 'bookings' && (
          <View>
            {receivedBookings.length === 0 ? (
              <View style={styles.emptyBox}>
                <Ionicons name="calendar-outline" size={48} color={colors.textMuted} />
                <Text style={styles.emptyTitle}>Sin reservas todavía</Text>
                <Text style={styles.emptySub}>
                  Las reservas que los turistas realicen para tus locales aparecerán aquí en tiempo real.
                </Text>
              </View>
            ) : (
              receivedBookings.map((b) => (
                <View key={b.id} style={styles.bookingCard}>
                  <View style={styles.bookingHeader}>
                    <Text style={styles.bookingDestName}>{b.destinationName}</Text>
                    <View style={styles.statusBadge}>
                      <Text style={styles.statusText}>{b.status}</Text>
                    </View>
                  </View>
                  <Text style={styles.bookingClient}>
                    Cliente: <Text style={{ fontWeight: '700' }}>{b.userName || b.userEmail}</Text>
                  </Text>
                  <Text style={styles.bookingDate}>Fecha: {b.date}</Text>
                  <View style={styles.bookingFooter}>
                    <Text style={styles.bookingGuests}>{b.guests} personas</Text>
                    <Text style={styles.bookingTotal}>Total: ${b.total} USD</Text>
                  </View>
                </View>
              ))
            )}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: colors.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  backButton: {
    padding: spacing.xs,
    marginRight: spacing.sm,
  },
  headerTitles: {
    flex: 1,
  },
  title: {
    fontSize: 20,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  subtitle: {
    fontSize: 12,
    color: colors.textSecondary,
  },
  badge: {
    backgroundColor: '#0E7490',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: borderRadius.sm,
  },
  badgeText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '800',
  },
  tabsContainer: {
    flexDirection: 'row',
    backgroundColor: colors.surface,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    gap: spacing.xs,
    borderBottomWidth: 1,
    borderBottomColor: colors.borderLight,
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
    borderRadius: borderRadius.sm,
    backgroundColor: colors.surfaceSecondary,
    gap: 5,
  },
  tabActive: {
    backgroundColor: '#E0F2FE',
  },
  tabText: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textMuted,
  },
  tabTextActive: {
    color: colors.primary,
    fontWeight: '700',
  },
  content: {
    flex: 1,
  },
  contentContainer: {
    padding: spacing.md,
    paddingBottom: 40,
  },
  formCard: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.lg,
    padding: spacing.md,
    ...shadows.sm,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  sectionSubtitle: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: 2,
    marginBottom: spacing.md,
  },
  coordsAlert: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#E0F2FE',
    padding: spacing.sm,
    borderRadius: borderRadius.md,
    gap: 8,
    marginBottom: spacing.md,
  },
  coordsAlertText: {
    fontSize: 12,
    color: colors.primaryDark,
    fontWeight: '600',
    flex: 1,
  },
  pickCoordsBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surfaceSecondary,
    padding: spacing.sm,
    borderRadius: borderRadius.md,
    gap: 8,
    marginBottom: spacing.md,
    borderWidth: 1,
    borderStyle: 'dashed',
    borderColor: colors.primaryLight,
  },
  pickCoordsText: {
    fontSize: 12,
    color: colors.primary,
    fontWeight: '600',
  },
  label: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
    marginBottom: 6,
    marginTop: 10,
  },
  typeSelector: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 8,
  },
  typeOption: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: colors.surfaceSecondary,
    paddingVertical: 7,
    paddingHorizontal: 12,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: colors.border,
  },
  typeOptionActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  typeOptionText: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textSecondary,
  },
  typeOptionTextActive: {
    color: '#FFFFFF',
    fontWeight: '700',
  },
  input: {
    backgroundColor: colors.surfaceSecondary,
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: 10,
    fontSize: 14,
    color: colors.textPrimary,
    borderWidth: 1,
    borderColor: colors.border,
  },
  textArea: {
    minHeight: 70,
    textAlignVertical: 'top',
  },
  rowInputs: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  halfInput: {
    flex: 1,
  },
  submitBtn: {
    backgroundColor: colors.primary,
    borderRadius: borderRadius.md,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    marginTop: spacing.lg,
    ...shadows.md,
  },
  submitBtnText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '800',
  },
  emptyBox: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 50,
    paddingHorizontal: spacing.xl,
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
    marginTop: 12,
  },
  emptySub: {
    fontSize: 13,
    color: colors.textSecondary,
    textAlign: 'center',
    marginTop: 6,
  },
  placeCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderRadius: borderRadius.md,
    padding: spacing.sm,
    marginBottom: spacing.sm,
    ...shadows.sm,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  placeImage: {
    width: 65,
    height: 65,
    borderRadius: borderRadius.sm,
  },
  placeInfo: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  typeTag: {
    alignSelf: 'flex-start',
    backgroundColor: '#E0F2FE',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: borderRadius.xs,
    marginBottom: 2,
  },
  typeTagText: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.primary,
  },
  placeName: {
    fontSize: 14,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  placeAddress: {
    fontSize: 12,
    color: colors.textSecondary,
  },
  placePrice: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.primary,
    marginTop: 2,
  },
  deleteBtn: {
    padding: spacing.sm,
  },
  bookingCard: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    marginBottom: spacing.sm,
    ...shadows.sm,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  bookingHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  bookingDestName: {
    fontSize: 15,
    fontWeight: '700',
    color: colors.textPrimary,
    flex: 1,
  },
  statusBadge: {
    backgroundColor: '#DCFCE7',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: borderRadius.sm,
  },
  statusText: {
    color: '#166534',
    fontSize: 11,
    fontWeight: '700',
  },
  bookingClient: {
    fontSize: 13,
    color: colors.textSecondary,
    marginTop: 6,
  },
  bookingDate: {
    fontSize: 13,
    color: colors.textSecondary,
    marginTop: 2,
  },
  bookingFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 8,
    borderTopWidth: 1,
    borderTopColor: colors.borderLight,
    paddingTop: 8,
  },
  bookingGuests: {
    fontSize: 13,
    color: colors.textSecondary,
  },
  bookingTotal: {
    fontSize: 14,
    fontWeight: '800',
    color: colors.primary,
  },
});
