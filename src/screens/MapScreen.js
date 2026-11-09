import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  StatusBar,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { InteractiveMap } from '../components/InteractiveMap';
import { BottomNavBar } from '../components/BottomNavBar';
import { MAP_CATEGORIES } from '../data/mockData';
import { colors, spacing, borderRadius, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';
import { useApp } from '../context/AppContext';

export const MapScreen = () => {
  const [activeFilter, setActiveFilter] = useState('all');
  const { user, setCurrentScreen } = useApp();

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
      <StatusBar barStyle="dark-content" backgroundColor={colors.surface} />
      <View style={styles.container}>
        {/* Cabecera del Mapa */}
        <View style={styles.header}>
          <View style={styles.headerTextGroup}>
            <Text style={styles.title}>Mapa Turístico Interactivo</Text>
            <Text style={styles.subtitle}>Hoteles, restaurantes, salud y atracciones</Text>
          </View>

          {(user.role === 'business' || user.role === 'admin') && (
            <TouchableOpacity
              style={styles.addPointHeaderBtn}
              onPress={() => setCurrentScreen('BusinessPanel')}
              activeOpacity={0.8}
            >
              <Ionicons name="add" size={18} color="#FFFFFF" />
              <Text style={styles.addPointHeaderBtnText}>Nuevo Lugar</Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Chips de Categorías: Hotel, Rest, Hospital, Atracciones */}
        <View style={styles.filtersWrapper}>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.filtersScroll}
          >
            {MAP_CATEGORIES.map((category) => {
              const isActive = activeFilter === category.id;
              return (
                <TouchableOpacity
                  key={category.id}
                  style={[styles.filterChip, isActive && styles.filterChipActive]}
                  onPress={() => setActiveFilter(category.id)}
                  activeOpacity={0.7}
                >
                  <Text
                    style={[
                      styles.filterChipText,
                      isActive && styles.filterChipTextActive,
                    ]}
                  >
                    {category.name}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        </View>

        {/* Mapa Interactivo con Leaflet */}
        <View style={styles.mapContainer}>
          <InteractiveMap selectedFilter={activeFilter} />
        </View>

        {/* Barra de Navegación Inferior */}
        <BottomNavBar />
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: colors.surface,
  },
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingTop: spacing.xs,
    paddingBottom: spacing.xs,
    backgroundColor: colors.surface,
  },
  headerTextGroup: {
    flex: 1,
  },
  title: {
    fontSize: 19,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  subtitle: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: 2,
  },
  addPointHeaderBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.primary,
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: borderRadius.md,
    gap: 4,
    marginLeft: spacing.sm,
  },
  addPointHeaderBtnText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '700',
  },
  filtersWrapper: {
    backgroundColor: colors.surface,
    paddingBottom: spacing.xs,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  filtersScroll: {
    paddingHorizontal: spacing.md,
    gap: spacing.sm,
  },
  filterChip: {
    backgroundColor: colors.surfaceSecondary,
    paddingVertical: 6,
    paddingHorizontal: 14,
    borderRadius: borderRadius.round,
    borderWidth: 1,
    borderColor: colors.border,
  },
  filterChipActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  filterChipText: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.textSecondary,
  },
  filterChipTextActive: {
    color: colors.textLight,
  },
  mapContainer: {
    flex: 1,
  },
});
