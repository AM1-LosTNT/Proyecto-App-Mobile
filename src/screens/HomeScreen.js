import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  StatusBar,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useApp } from '../context/AppContext';
import { Header } from '../components/Header';
import { SearchBar } from '../components/SearchBar';
import { CategoryList } from '../components/CategoryList';
import { DestinationCard } from '../components/DestinationCard';
import { BottomNavBar } from '../components/BottomNavBar';
import { colors, spacing, typography, borderRadius } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

export const HomeScreen = () => {
  const {
    destinations,
    searchQuery,
    selectedCategory,
    user,
    setCurrentScreen,
  } = useApp();

  // Filtrado reactivo por categoría y búsqueda en tiempo real sobre lista dinámica
  const filteredDestinations = destinations.filter((item) => {
    const matchesCategory =
      selectedCategory === 'all' || item.category === selectedCategory;
    const matchesSearch =
      item.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.location.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (item.description && item.description.toLowerCase().includes(searchQuery.toLowerCase()));

    return matchesCategory && matchesSearch;
  });

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
      <StatusBar barStyle="dark-content" backgroundColor={colors.background} />
      <View style={styles.container}>
        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.scrollContent}
        >
          {/* Header con Saludo y Avatar */}
          <Header />

          {/* Banner de acceso rápido para Dueños de Negocio y Admin */}
          {(user.role === 'business' || user.role === 'admin') && (
            <TouchableOpacity
              style={styles.businessShortcut}
              onPress={() =>
                setCurrentScreen(user.role === 'admin' ? 'AdminPanel' : 'BusinessPanel')
              }
              activeOpacity={0.85}
            >
              <View style={styles.businessIconBadge}>
                <Ionicons
                  name={user.role === 'admin' ? 'shield-checkmark' : 'business'}
                  size={16}
                  color="#FFFFFF"
                />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.businessShortcutTitle}>
                  {user.role === 'admin'
                    ? 'Modo Administrador Activo'
                    : 'Modo Dueño de Negocio Activo'}
                </Text>
                <Text style={styles.businessShortcutSub}>
                  {user.role === 'admin'
                    ? 'Gestionar usuarios, métricas y lugares'
                    : 'Publicar y gestionar mis servicios'}
                </Text>
              </View>
              <Ionicons name="arrow-forward" size={16} color={colors.primary} />
            </TouchableOpacity>
          )}

          {/* Barra de Búsqueda */}
          <SearchBar />

          {/* Carrusel de Categorías */}
          <CategoryList />

          {/* Lista de Tarjetas de Destinos */}
          <View style={styles.destinationsSection}>
            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>Destinos Populares</Text>
              <Text style={styles.resultsBadge}>
                {filteredDestinations.length} lugares
              </Text>
            </View>

            {filteredDestinations.length > 0 ? (
              filteredDestinations.map((destination) => (
                <DestinationCard
                  key={destination.id}
                  destination={destination}
                />
              ))
            ) : (
              <View style={styles.emptyContainer}>
                <Ionicons name="search-outline" size={48} color={colors.textMuted} />
                <Text style={styles.emptyTitle}>No encontramos resultados</Text>
                <Text style={styles.emptySubtitle}>
                  Prueba buscando otra palabra clave o selecciona otra categoría.
                </Text>
              </View>
            )}
          </View>
        </ScrollView>

        {/* Barra de Navegación Inferior */}
        <BottomNavBar />
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
    backgroundColor: colors.background,
  },
  scrollContent: {
    paddingBottom: spacing.xxl,
  },
  businessShortcut: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#E0F2FE',
    marginHorizontal: spacing.md,
    marginTop: spacing.xs,
    padding: spacing.sm,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: '#BAE6FD',
    gap: 10,
  },
  businessIconBadge: {
    width: 32,
    height: 32,
    borderRadius: borderRadius.sm,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  businessShortcutTitle: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.primaryDark,
  },
  businessShortcutSub: {
    fontSize: 11,
    color: colors.textSecondary,
  },
  destinationsSection: {
    paddingHorizontal: spacing.md,
    marginTop: spacing.sm,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  resultsBadge: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textSecondary,
    backgroundColor: colors.surfaceSecondary,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 12,
  },
  emptyContainer: {
    backgroundColor: colors.surface,
    borderRadius: 16,
    padding: spacing.xl,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: spacing.md,
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
    marginTop: spacing.sm,
  },
  emptySubtitle: {
    fontSize: 13,
    color: colors.textSecondary,
    textAlign: 'center',
    marginTop: 4,
  },
});
