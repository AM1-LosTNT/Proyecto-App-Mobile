import React from 'react';
import { View, Text, StyleSheet, Image, TouchableOpacity } from 'react-native';
import { useApp } from '../context/AppContext';
import { colors, spacing, borderRadius, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

export const DestinationCard = ({ destination, style }) => {
  const { navigateToDetail, toggleFavorite, isFavorite } = useApp();
  const favorite = isFavorite(destination.id);

  return (
    <TouchableOpacity
      style={[styles.card, style]}
      onPress={() => navigateToDetail(destination)}
      activeOpacity={0.9}
    >
      <View style={styles.imageContainer}>
        <Image
          source={{ uri: destination.images[0] }}
          style={styles.image}
          resizeMode="cover"
        />

        {/* Badge de Rating */}
        <View style={styles.ratingBadge}>
          <Ionicons name="star" size={14} color={colors.accent} />
          <Text style={styles.ratingText}>{destination.rating}</Text>
        </View>

        {/* Botón Bookmark / Favorito (Boceto 1) */}
        <TouchableOpacity
          style={[styles.bookmarkButton, favorite && styles.bookmarkButtonActive]}
          onPress={() => toggleFavorite(destination.id)}
          activeOpacity={0.8}
        >
          <Ionicons
            name={favorite ? 'bookmark' : 'bookmark-outline'}
            size={18}
            color={favorite ? colors.accentWarm : colors.textPrimary}
          />
        </TouchableOpacity>
      </View>

      <View style={styles.content}>
        <View style={styles.headerRow}>
          <Text style={styles.categoryTag}>{destination.categoryName}</Text>
          <Text style={styles.priceText}>
            ${destination.price}
            <Text style={styles.priceUnitText}> / pers.</Text>
          </Text>
        </View>

        <Text style={styles.title} numberOfLines={1}>
          {destination.name}
        </Text>

        <View style={styles.locationRow}>
          <Ionicons name="location-outline" size={14} color={colors.primary} />
          <Text style={styles.locationText} numberOfLines={1}>
            {destination.location}
          </Text>
        </View>
      </View>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.lg,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: colors.border,
    marginBottom: spacing.md,
    ...shadows.md,
  },
  imageContainer: {
    width: '100%',
    height: 190,
    position: 'relative',
    backgroundColor: colors.surfaceSecondary,
  },
  image: {
    width: '100%',
    height: '100%',
  },
  ratingBadge: {
    position: 'absolute',
    top: spacing.md,
    left: spacing.md,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.92)',
    paddingVertical: 4,
    paddingHorizontal: 8,
    borderRadius: borderRadius.round,
    gap: 4,
  },
  ratingText: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  bookmarkButton: {
    position: 'absolute',
    top: spacing.md,
    right: spacing.md,
    backgroundColor: 'rgba(255, 255, 255, 0.92)',
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
    ...shadows.sm,
  },
  bookmarkButtonActive: {
    backgroundColor: '#FFE4E6',
  },
  content: {
    padding: spacing.md,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  categoryTag: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.primary,
    textTransform: 'uppercase',
  },
  priceText: {
    fontSize: 16,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  priceUnitText: {
    fontSize: 12,
    fontWeight: '500',
    color: colors.textSecondary,
  },
  title: {
    fontSize: 17,
    fontWeight: '700',
    color: colors.textPrimary,
    marginBottom: 6,
  },
  locationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  locationText: {
    fontSize: 13,
    color: colors.textSecondary,
    flex: 1,
  },
});
