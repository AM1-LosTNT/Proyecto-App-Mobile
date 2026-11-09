import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Image,
  TouchableOpacity,
  Dimensions,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useApp } from '../context/AppContext';
import { colors, spacing, borderRadius, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

const { width } = Dimensions.get('window');

export const DetailScreen = () => {
  const {
    user,
    selectedDestination,
    goBack,
    toggleFavorite,
    isFavorite,
    createBooking,
    setCurrentScreen,
  } = useApp();

  const [activeImageIndex, setActiveImageIndex] = useState(0);
  const [booked, setBooked] = useState(false);

  if (!selectedDestination) return null;

  const favorite = isFavorite(selectedDestination.id);
  const images = selectedDestination.images || [];

  const handleBooking = () => {
    if (user?.isGuest) {
      Alert.alert(
        'Cuenta Requerida',
        'Para reservar esta experiencia turística necesitas tener una cuenta en TurisApp.',
        [
          { text: 'Cancelar', style: 'cancel' },
          { text: 'Crear Cuenta', onPress: () => setCurrentScreen('Register') },
        ]
      );
      return;
    }

    createBooking(selectedDestination);
    setBooked(true);
    Alert.alert(
      '¡Reserva Confirmada! 🎉',
      `Has reservado tu lugar en "${selectedDestination.name}". Puedes ver los detalles en tu perfil.`,
      [
        { text: 'Ver en Mapa', onPress: () => setCurrentScreen('Map') },
        { text: 'Aceptar', style: 'default' },
      ]
    );
  };

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'bottom', 'left', 'right']}>
      <View style={styles.container}>
        <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.scrollContent}>
          {/* Carrusel de Imágenes Principal (Boceto 2) */}
          <View style={styles.imageCarouselContainer}>
            <ScrollView
              horizontal
              pagingEnabled
              showsHorizontalScrollIndicator={false}
              onMomentumScrollEnd={(e) => {
                const index = Math.round(e.nativeEvent.contentOffset.x / width);
                setActiveImageIndex(index);
              }}
            >
              {images.map((imgUrl, idx) => (
                <Image
                  key={idx}
                  source={{ uri: imgUrl }}
                  style={styles.carouselImage}
                  resizeMode="cover"
                />
              ))}
            </ScrollView>

            {/* Barra Superior con Botón Volver y Botón Bookmark del Boceto 2 */}
            <View style={styles.topBar}>
              <TouchableOpacity style={styles.iconCircle} onPress={goBack} activeOpacity={0.8}>
                <Ionicons name="chevron-back" size={24} color={colors.textPrimary} />
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.iconCircle, favorite && styles.iconCircleActive]}
                onPress={() => toggleFavorite(selectedDestination.id)}
                activeOpacity={0.8}
              >
                <Ionicons
                  name={favorite ? 'bookmark' : 'bookmark-outline'}
                  size={22}
                  color={favorite ? colors.accentWarm : colors.textPrimary}
                />
              </TouchableOpacity>
            </View>

            {/* Puntos de Paginación del Boceto 2 (...) */}
            {images.length > 1 && (
              <View style={styles.paginationDots}>
                {images.map((_, idx) => (
                  <View
                    key={idx}
                    style={[
                      styles.dot,
                      activeImageIndex === idx && styles.dotActive,
                    ]}
                  />
                ))}
              </View>
            )}
          </View>

          {/* Información del Destino según Boceto 2 */}
          <View style={styles.detailsCard}>
            {/* Fila de Precio y Calificación (Boceto 2) */}
            <View style={styles.metaRow}>
              <View style={styles.priceContainer}>
                <Text style={styles.priceSymbol}>$</Text>
                <Text style={styles.priceAmount}>{selectedDestination.price}</Text>
                <Text style={styles.pricePeriod}> / {selectedDestination.priceUnit || 'persona'}</Text>
              </View>

              <View style={styles.ratingBadge}>
                <Ionicons name="star" size={16} color={colors.accent} />
                <Text style={styles.ratingValue}>{selectedDestination.rating}</Text>
                <Text style={styles.reviewsCount}>
                  ({selectedDestination.reviewsCount || 100} reseñas)
                </Text>
              </View>
            </View>

            {/* Título Principal */}
            <Text style={styles.title}>{selectedDestination.name}</Text>

            {/* Ubicación */}
            <View style={styles.locationRow}>
              <Ionicons name="location-outline" size={16} color={colors.primary} />
              <Text style={styles.locationText}>{selectedDestination.location}</Text>
            </View>

            {/* Fichas de Especificaciones / Clima / Dificultad */}
            {selectedDestination.features && (
              <View style={styles.featuresGrid}>
                {selectedDestination.features.map((feat, index) => (
                  <View key={index} style={styles.featureItem}>
                    <Ionicons name={feat.icon || 'checkmark-circle-outline'} size={20} color={colors.primary} />
                    <Text style={styles.featureLabel}>{feat.label}</Text>
                    <Text style={styles.featureValue}>{feat.value}</Text>
                  </View>
                ))}
              </View>
            )}

            {/* Descripción Completa (Boceto 2) */}
            <View style={styles.sectionDivider} />
            <Text style={styles.sectionHeading}>Descripción</Text>
            <Text style={styles.descriptionText}>{selectedDestination.description}</Text>

            {/* Qué Incluye */}
            {selectedDestination.included && (
              <>
                <View style={styles.sectionDivider} />
                <Text style={styles.sectionHeading}>¿Qué incluye la experiencia?</Text>
                <View style={styles.includedList}>
                  {selectedDestination.included.map((inc, i) => (
                    <View key={i} style={styles.includedRow}>
                      <Ionicons name="checkmark-circle" size={18} color={colors.success} />
                      <Text style={styles.includedText}>{inc}</Text>
                    </View>
                  ))}
                </View>
              </>
            )}
          </View>
        </ScrollView>

        {/* Barra Inferior con Botón de Reserva del Boceto 2 */}
        <View style={styles.bottomBar}>
          <TouchableOpacity
            style={styles.mapLinkButton}
            onPress={() => setCurrentScreen('Map')}
          >
            <Ionicons name="map-outline" size={20} color={colors.primary} />
            <Text style={styles.mapLinkText}>Ver en Mapa</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.reserveButton, booked && styles.reserveButtonDone]}
            onPress={handleBooking}
            activeOpacity={0.8}
          >
            <Ionicons
              name={booked ? 'checkmark-circle' : 'calendar-outline'}
              size={20}
              color={colors.textLight}
            />
            <Text style={styles.reserveButtonText}>
              {booked ? '¡Reservado!' : 'Reservar Ahora'}
            </Text>
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: colors.background,
  },
  container: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 100,
  },
  imageCarouselContainer: {
    width: width,
    height: 320,
    position: 'relative',
    backgroundColor: colors.surfaceSecondary,
  },
  carouselImage: {
    width: width,
    height: 320,
  },
  topBar: {
    position: 'absolute',
    top: spacing.md,
    left: spacing.lg,
    right: spacing.lg,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  iconCircle: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: 'rgba(255, 255, 255, 0.95)',
    justifyContent: 'center',
    alignItems: 'center',
    ...shadows.md,
  },
  iconCircleActive: {
    backgroundColor: '#FFE4E6',
  },
  paginationDots: {
    position: 'absolute',
    bottom: spacing.md,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 6,
  },
  dot: {
    width: 7,
    height: 7,
    borderRadius: 4,
    backgroundColor: 'rgba(255, 255, 255, 0.5)',
  },
  dotActive: {
    width: 22,
    backgroundColor: '#FFFFFF',
  },
  detailsCard: {
    backgroundColor: colors.surface,
    borderTopLeftRadius: borderRadius.xl,
    borderTopRightRadius: borderRadius.xl,
    marginTop: -24,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    paddingBottom: spacing.xl,
    ...shadows.md,
  },
  metaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  priceContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
  },
  priceSymbol: {
    fontSize: 20,
    fontWeight: '800',
    color: colors.primary,
  },
  priceAmount: {
    fontSize: 28,
    fontWeight: '900',
    color: colors.textPrimary,
  },
  pricePeriod: {
    fontSize: 13,
    color: colors.textSecondary,
    marginLeft: 4,
  },
  ratingBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FEF3C7',
    paddingVertical: 5,
    paddingHorizontal: 10,
    borderRadius: borderRadius.round,
    gap: 4,
  },
  ratingValue: {
    fontSize: 14,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  reviewsCount: {
    fontSize: 12,
    color: colors.textSecondary,
  },
  title: {
    fontSize: 24,
    fontWeight: '800',
    color: colors.textPrimary,
    lineHeight: 30,
    marginVertical: spacing.xs,
  },
  locationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: spacing.md,
  },
  locationText: {
    fontSize: 14,
    color: colors.textSecondary,
  },
  featuresGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
    marginVertical: spacing.sm,
  },
  featureItem: {
    flex: 1,
    minWidth: '45%',
    backgroundColor: colors.surfaceSecondary,
    borderRadius: borderRadius.md,
    padding: spacing.sm,
    alignItems: 'center',
  },
  featureLabel: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 2,
    textTransform: 'uppercase',
  },
  featureValue: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
    marginTop: 1,
  },
  sectionDivider: {
    height: 1,
    backgroundColor: colors.border,
    marginVertical: spacing.md,
  },
  sectionHeading: {
    fontSize: 17,
    fontWeight: '700',
    color: colors.textPrimary,
    marginBottom: spacing.xs,
  },
  descriptionText: {
    fontSize: 14,
    color: colors.textSecondary,
    lineHeight: 22,
  },
  includedList: {
    gap: spacing.xs,
    marginTop: 4,
  },
  includedRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  includedText: {
    fontSize: 14,
    color: colors.textPrimary,
  },
  bottomBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: colors.surface,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    ...shadows.lg,
  },
  mapLinkButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 12,
    paddingHorizontal: 14,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: colors.primary,
    backgroundColor: '#F0F9FF',
  },
  mapLinkText: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.primary,
  },
  reserveButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: colors.primary,
    paddingVertical: 14,
    borderRadius: borderRadius.md,
    ...shadows.sm,
  },
  reserveButtonDone: {
    backgroundColor: colors.success,
  },
  reserveButtonText: {
    fontSize: 15,
    fontWeight: '700',
    color: colors.textLight,
  },
});
