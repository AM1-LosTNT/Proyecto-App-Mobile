import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useApp } from '../context/AppContext';
import { colors, spacing, borderRadius, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

export const AdminPanelScreen = () => {
  const {
    goBack,
    usersList,
    updateUserRole,
    destinations,
    mapPoints,
    bookings,
    deleteBusinessPlace,
  } = useApp();

  const [activeTab, setActiveTab] = useState('users'); // 'users' | 'places' | 'stats'

  const roles = [
    { id: 'user', label: 'Turista', color: '#64748B' },
    { id: 'business', label: 'Dueño', color: '#0E7490' },
    { id: 'admin', label: 'Admin', color: '#7C3AED' },
  ];

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
      {/* Cabecera */}
      <View style={styles.header}>
        <TouchableOpacity onPress={goBack} style={styles.backButton}>
          <Ionicons name="arrow-back" size={24} color={colors.textPrimary} />
        </TouchableOpacity>
        <View style={styles.headerTitles}>
          <Text style={styles.title}>Panel Administrador</Text>
          <Text style={styles.subtitle}>Control Global de Plataforma y Roles</Text>
        </View>
        <View style={styles.adminBadge}>
          <Ionicons name="shield-checkmark" size={14} color="#FFFFFF" />
          <Text style={styles.adminBadgeText}>ADMIN</Text>
        </View>
      </View>

      {/* Pestañas Superiores */}
      <View style={styles.tabsContainer}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'users' && styles.tabActive]}
          onPress={() => setActiveTab('users')}
        >
          <Ionicons
            name="people"
            size={16}
            color={activeTab === 'users' ? '#7C3AED' : colors.textMuted}
          />
          <Text style={[styles.tabText, activeTab === 'users' && styles.tabTextActive]}>
            Usuarios ({usersList.length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.tab, activeTab === 'places' && styles.tabActive]}
          onPress={() => setActiveTab('places')}
        >
          <Ionicons
            name="map"
            size={16}
            color={activeTab === 'places' ? '#7C3AED' : colors.textMuted}
          />
          <Text style={[styles.tabText, activeTab === 'places' && styles.tabTextActive]}>
            Lugares ({mapPoints.length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.tab, activeTab === 'stats' && styles.tabActive]}
          onPress={() => setActiveTab('stats')}
        >
          <Ionicons
            name="stats-chart"
            size={16}
            color={activeTab === 'stats' ? '#7C3AED' : colors.textMuted}
          />
          <Text style={[styles.tabText, activeTab === 'stats' && styles.tabTextActive]}>
            Métricas
          </Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentContainer}>
        {/* TAB 1: GESTIÓN DE USUARIOS Y ASIGNACIÓN DE ROLES */}
        {activeTab === 'users' && (
          <View>
            <Text style={styles.sectionHeading}>Control de Roles de Usuarios</Text>
            <Text style={styles.sectionSub}>
              Cambia en tiempo real los permisos de cualquier usuario registrado.
            </Text>

            {usersList.map((usr) => (
              <View key={usr.id} style={styles.userCard}>
                <View style={styles.userHeader}>
                  <Image source={{ uri: usr.avatar }} style={styles.userAvatar} />
                  <View style={styles.userInfo}>
                    <Text style={styles.userName}>{usr.name}</Text>
                    <Text style={styles.userEmail}>{usr.email}</Text>
                    <Text style={styles.userDate}>Registrado: {usr.createdAt || '2026'}</Text>
                  </View>
                </View>

                {/* Selector de Rol */}
                <View style={styles.roleSelector}>
                  <Text style={styles.roleLabel}>Rol asignado:</Text>
                  <View style={styles.roleButtonsRow}>
                    {roles.map((r) => {
                      const isCurrent = usr.role === r.id;
                      return (
                        <TouchableOpacity
                          key={r.id}
                          style={[
                            styles.roleBtn,
                            isCurrent && { backgroundColor: r.color, borderColor: r.color },
                          ]}
                          onPress={() => updateUserRole(usr.id, r.id)}
                        >
                          <Text
                            style={[
                              styles.roleBtnText,
                              isCurrent && styles.roleBtnTextActive,
                            ]}
                          >
                            {r.label}
                          </Text>
                        </TouchableOpacity>
                      );
                    })}
                  </View>
                </View>
              </View>
            ))}
          </View>
        )}

        {/* TAB 2: GESTIÓN DE LUGARES */}
        {activeTab === 'places' && (
          <View>
            <Text style={styles.sectionHeading}>Moderación de Lugares y Negocios</Text>
            <Text style={styles.sectionSub}>
              Supervisa todos los puntos visibles en el mapa de TurisApp.
            </Text>

            {mapPoints.map((place) => (
              <View key={place.id} style={styles.placeItem}>
                <Image source={{ uri: place.image }} style={styles.placeImage} />
                <View style={styles.placeContent}>
                  <View style={styles.typeBadge}>
                    <Text style={styles.typeText}>{place.typeName}</Text>
                  </View>
                  <Text style={styles.placeTitle}>{place.name}</Text>
                  <Text style={styles.placeSubtitle}>{place.address}</Text>
                  <Text style={styles.placeOwner}>
                    Dueño: {place.ownerEmail || 'admin@turisapp.com'}
                  </Text>
                </View>

                <TouchableOpacity
                  style={styles.trashBtn}
                  onPress={() => {
                    Alert.alert(
                      'Eliminar lugar',
                      `¿Eliminar definitivamente "${place.name}"?`,
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
            ))}
          </View>
        )}

        {/* TAB 3: MÉTRICAS Y ESTADÍSTICAS */}
        {activeTab === 'stats' && (
          <View>
            <Text style={styles.sectionHeading}>Resumen General del Sistema</Text>
            <Text style={styles.sectionSub}>Actividad global en TurisApp</Text>

            <View style={styles.statsGrid}>
              <View style={[styles.statBox, { borderLeftColor: '#7C3AED' }]}>
                <Ionicons name="people" size={28} color="#7C3AED" />
                <Text style={styles.statNumber}>{usersList.length}</Text>
                <Text style={styles.statLabel}>Usuarios Totales</Text>
              </View>

              <View style={[styles.statBox, { borderLeftColor: colors.primary }]}>
                <Ionicons name="business" size={28} color={colors.primary} />
                <Text style={styles.statNumber}>
                  {usersList.filter((u) => u.role === 'business').length}
                </Text>
                <Text style={styles.statLabel}>Dueños de Negocio</Text>
              </View>

              <View style={[styles.statBox, { borderLeftColor: '#059669' }]}>
                <Ionicons name="location" size={28} color="#059669" />
                <Text style={styles.statNumber}>{mapPoints.length}</Text>
                <Text style={styles.statLabel}>Puntos en Mapa</Text>
              </View>

              <View style={[styles.statBox, { borderLeftColor: '#F59E0B' }]}>
                <Ionicons name="calendar" size={28} color="#F59E0B" />
                <Text style={styles.statNumber}>{bookings.length}</Text>
                <Text style={styles.statLabel}>Reservas Registradas</Text>
              </View>
            </View>

            <View style={styles.infoBanner}>
              <Ionicons name="shield-checkmark-outline" size={24} color="#7C3AED" />
              <View style={{ flex: 1, marginLeft: 10 }}>
                <Text style={styles.infoBannerTitle}>Seguridad y Moderación</Text>
                <Text style={styles.infoBannerText}>
                  Como administrador tienes control sobre los accesos y los contenidos publicados por los dueños de negocios en la comunidad.
                </Text>
              </View>
            </View>
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
  adminBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#7C3AED',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: borderRadius.sm,
  },
  adminBadgeText: {
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
    backgroundColor: '#F3E8FF',
  },
  tabText: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textMuted,
  },
  tabTextActive: {
    color: '#7C3AED',
    fontWeight: '700',
  },
  content: {
    flex: 1,
  },
  contentContainer: {
    padding: spacing.md,
    paddingBottom: 40,
  },
  sectionHeading: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  sectionSub: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: 2,
    marginBottom: spacing.md,
  },
  userCard: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm,
    ...shadows.sm,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  userHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  userAvatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  userInfo: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  userName: {
    fontSize: 14,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  userEmail: {
    fontSize: 12,
    color: colors.textSecondary,
  },
  userDate: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 2,
  },
  roleSelector: {
    marginTop: spacing.sm,
    paddingTop: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.borderLight,
  },
  roleLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textSecondary,
    marginBottom: 6,
  },
  roleButtonsRow: {
    flexDirection: 'row',
    gap: 8,
  },
  roleBtn: {
    flex: 1,
    paddingVertical: 6,
    borderRadius: borderRadius.sm,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: 'center',
    backgroundColor: colors.surfaceSecondary,
  },
  roleBtnText: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textSecondary,
  },
  roleBtnTextActive: {
    color: '#FFFFFF',
    fontWeight: '700',
  },
  placeItem: {
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
    width: 60,
    height: 60,
    borderRadius: borderRadius.sm,
  },
  placeContent: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  typeBadge: {
    alignSelf: 'flex-start',
    backgroundColor: '#F1F5F9',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: borderRadius.xs,
    marginBottom: 2,
  },
  typeText: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.primary,
  },
  placeTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  placeSubtitle: {
    fontSize: 11,
    color: colors.textSecondary,
  },
  placeOwner: {
    fontSize: 10,
    color: colors.textMuted,
    marginTop: 2,
  },
  trashBtn: {
    padding: spacing.sm,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  statBox: {
    width: '48%',
    backgroundColor: colors.surface,
    padding: spacing.md,
    borderRadius: borderRadius.md,
    ...shadows.sm,
    borderLeftWidth: 4,
  },
  statNumber: {
    fontSize: 22,
    fontWeight: '800',
    color: colors.textPrimary,
    marginTop: 4,
  },
  statLabel: {
    fontSize: 12,
    color: colors.textSecondary,
    fontWeight: '600',
  },
  infoBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FAF5FF',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: '#E9D5FF',
  },
  infoBannerTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#6B21A8',
  },
  infoBannerText: {
    fontSize: 12,
    color: '#7E22CE',
    marginTop: 2,
  },
});
