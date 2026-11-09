import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Image,
  TouchableOpacity,
  StatusBar,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useApp } from '../context/AppContext';
import { BottomNavBar } from '../components/BottomNavBar';
import { DestinationCard } from '../components/DestinationCard';
import { colors, spacing, borderRadius, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

export const ProfileScreen = () => {
  const {
    user,
    logout,
    favorites,
    bookings,
    destinations,
    setCurrentScreen,
  } = useApp();

  // Filtrar los destinos que el usuario guardó como favoritos
  const favoriteDestinations = destinations.filter((item) =>
    favorites.includes(item.id)
  );

  const roleConfig = {
    admin: {
      label: 'Administrador General',
      color: '#7C3AED',
      bgColor: '#F3E8FF',
      icon: 'shield-checkmark',
    },
    business: {
      label: 'Dueño de Negocio',
      color: '#0E7490',
      bgColor: '#E0F2FE',
      icon: 'business',
    },
    user: {
      label: 'Turista / Usuario',
      color: '#475569',
      bgColor: '#F1F5F9',
      icon: 'compass',
    },
  };

  const currentRoleInfo = user?.isGuest
    ? {
        label: 'Invitado',
        color: '#64748B',
        bgColor: '#F1F5F9',
        icon: 'person-outline',
      }
    : roleConfig[user?.role] || roleConfig.user;

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
      <StatusBar barStyle="dark-content" backgroundColor={colors.surface} />
      <View style={styles.container}>
        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.scrollContent}
        >
          {/* Header del Perfil de Usuario */}
          <View style={styles.profileHeader}>
            <Image
              source={{
                uri:
                  user?.avatar ||
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
              }}
              style={styles.avatarLarge}
            />
            <Text style={styles.userName}>{user?.name || 'Viajero TurisApp'}</Text>
            <Text style={styles.userEmail}>{user?.email}</Text>

            {/* Badge Oficial de Rol */}
            <View style={[styles.roleBadge, { backgroundColor: currentRoleInfo.bgColor }]}>
              <Ionicons
                name={currentRoleInfo.icon}
                size={14}
                color={currentRoleInfo.color}
              />
              <Text style={[styles.roleBadgeText, { color: currentRoleInfo.color }]}>
                {currentRoleInfo.label}
              </Text>
            </View>

            {user?.businessName ? (
              <Text style={styles.businessSub}>Empresa: {user.businessName}</Text>
            ) : null}

            {/* Fila de Estadísticas */}
            <View style={styles.statsCard}>
              <View style={styles.statCol}>
                <Text style={styles.statNumber}>{favorites.length}</Text>
                <Text style={styles.statLabel}>Favoritos</Text>
              </View>
              <View style={styles.statDivider} />
              <View style={styles.statCol}>
                <Text style={styles.statNumber}>{bookings.length}</Text>
                <Text style={styles.statLabel}>Reservas</Text>
              </View>
              <View style={styles.statDivider} />
              <View style={styles.statCol}>
                <Text style={styles.statNumber}>{user?.isGuest ? '0' : '12'}</Text>
                <Text style={styles.statLabel}>Visitados</Text>
              </View>
            </View>
          </View>

          {/* BANNER PARA USUARIO INVITADO */}
          {user?.isGuest ? (
            <View style={styles.section}>
              <View style={styles.guestCtaCard}>
                <Ionicons name="sparkles" size={24} color={colors.primary} />
                <Text style={styles.guestCtaTitle}>Crea tu cuenta en TurisApp</Text>
                <Text style={styles.guestCtaDesc}>
                  Regístrate para guardar tus lugares favoritos de forma permanente, reservar experiencias y desbloquear las rutas turísticas.
                </Text>
                <TouchableOpacity
                  style={styles.guestRegisterBtn}
                  onPress={() => setCurrentScreen('Register')}
                  activeOpacity={0.85}
                >
                  <Text style={styles.guestRegisterBtnText}>Crear Cuenta Gratis</Text>
                </TouchableOpacity>
              </View>
            </View>
          ) : null}

          {/* ACCESOS DIRECTOS SEGÚN ROL REAL */}
          {!user?.isGuest && (user.role === 'business' || user.role === 'admin') && (
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Gestión Especializada</Text>

              {/* Botón Panel de Negocio */}
              <TouchableOpacity
                style={styles.panelActionCard}
                onPress={() => setCurrentScreen('BusinessPanel')}
                activeOpacity={0.85}
              >
                <View style={[styles.actionIconBox, { backgroundColor: '#E0F2FE' }]}>
                  <Ionicons name="business" size={24} color="#0E7490" />
                </View>
                <View style={styles.actionTextBox}>
                  <Text style={styles.actionTitle}>Panel de Negocio</Text>
                  <Text style={styles.actionDesc}>
                    Publicar hoteles, restaurantes, atracciones y revisar reservas recibidas.
                  </Text>
                </View>
                <Ionicons name="chevron-forward" size={20} color={colors.textMuted} />
              </TouchableOpacity>

              {/* Botón Panel de Administrador */}
              {user.role === 'admin' && (
                <TouchableOpacity
                  style={[styles.panelActionCard, { marginTop: spacing.sm }]}
                  onPress={() => setCurrentScreen('AdminPanel')}
                  activeOpacity={0.85}
                >
                  <View style={[styles.actionIconBox, { backgroundColor: '#F3E8FF' }]}>
                    <Ionicons name="shield-checkmark" size={24} color="#7C3AED" />
                  </View>
                  <View style={styles.actionTextBox}>
                    <Text style={[styles.actionTitle, { color: '#7C3AED' }]}>
                      Panel de Administración
                    </Text>
                    <Text style={styles.actionDesc}>
                      Gestionar usuarios, roles de la plataforma y moderar lugares globales.
                    </Text>
                  </View>
                  <Ionicons name="chevron-forward" size={20} color={colors.textMuted} />
                </TouchableOpacity>
              )}
            </View>
          )}

          {/* Sección de Reservas Activas */}
          {bookings.length > 0 && !user?.isGuest && (
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Tus Reservas Activas</Text>
              {bookings.map((booking) => (
                <View key={booking.id} style={styles.bookingCard}>
                  <View style={styles.bookingIcon}>
                    <Ionicons name="calendar" size={24} color={colors.primary} />
                  </View>
                  <View style={styles.bookingDetails}>
                    <Text style={styles.bookingDestName}>{booking.destinationName}</Text>
                    <Text style={styles.bookingDate}>
                      {booking.date} • {booking.guests} personas
                    </Text>
                    <Text style={styles.bookingTotal}>Total: ${booking.total}</Text>
                  </View>
                  <View style={styles.statusBadge}>
                    <Text style={styles.statusText}>{booking.status}</Text>
                  </View>
                </View>
              ))}
            </View>
          )}

          {/* Sección de Favoritos Guardados */}
          <View style={styles.section}>
            <View style={styles.sectionTitleRow}>
              <Text style={styles.sectionTitle}>Mis Lugares Guardados</Text>
              <Text style={styles.savedCountText}>{favoriteDestinations.length} guardados</Text>
            </View>

            {favoriteDestinations.length > 0 ? (
              favoriteDestinations.map((dest) => (
                <DestinationCard key={dest.id} destination={dest} />
              ))
            ) : (
              <View style={styles.emptyFavorites}>
                <Ionicons name="bookmark-outline" size={48} color={colors.textMuted} />
                <Text style={styles.emptyTitle}>No tienes lugares guardados</Text>
                <Text style={styles.emptySubtitle}>
                  Toca el icono de marcador en cualquier destino para guardarlo aquí.
                </Text>
              </View>
            )}
          </View>

          {/* Botón de Cerrar Sesión / Salir */}
          <View style={styles.section}>
            <TouchableOpacity
              style={styles.logoutButton}
              onPress={logout}
              activeOpacity={0.8}
            >
              <Ionicons name="log-out-outline" size={20} color={colors.danger} />
              <Text style={styles.logoutButtonText}>
                {user?.isGuest ? 'Salir del Modo Invitado' : 'Cerrar Sesión'}
              </Text>
            </TouchableOpacity>
          </View>
        </ScrollView>

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
  scrollContent: {
    paddingBottom: spacing.xxl,
  },
  profileHeader: {
    alignItems: 'center',
    paddingVertical: spacing.lg,
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  avatarLarge: {
    width: 86,
    height: 86,
    borderRadius: 43,
    borderWidth: 3,
    borderColor: colors.surface,
    ...shadows.md,
  },
  userName: {
    fontSize: 20,
    fontWeight: '800',
    color: colors.textPrimary,
    marginTop: spacing.sm,
  },
  userEmail: {
    fontSize: 13,
    color: colors.textSecondary,
    marginTop: 2,
  },
  businessSub: {
    fontSize: 12,
    color: colors.primaryDark,
    fontWeight: '600',
    marginTop: 3,
  },
  roleBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderRadius: borderRadius.full,
    marginTop: 8,
  },
  roleBadgeText: {
    fontSize: 12,
    fontWeight: '700',
  },
  statsCard: {
    flexDirection: 'row',
    backgroundColor: colors.surfaceSecondary,
    borderRadius: borderRadius.md,
    marginTop: spacing.md,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.lg,
    alignItems: 'center',
  },
  statCol: {
    alignItems: 'center',
    paddingHorizontal: spacing.sm,
  },
  statNumber: {
    fontSize: 18,
    fontWeight: '800',
    color: colors.primary,
  },
  statLabel: {
    fontSize: 11,
    color: colors.textSecondary,
    marginTop: 2,
  },
  statDivider: {
    width: 1,
    height: 25,
    backgroundColor: colors.border,
    marginHorizontal: spacing.sm,
  },
  section: {
    marginTop: spacing.md,
    paddingHorizontal: spacing.md,
  },
  sectionTitleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  sectionTitle: {
    fontSize: 17,
    fontWeight: '800',
    color: colors.textPrimary,
    marginBottom: spacing.xs,
  },
  savedCountText: {
    fontSize: 13,
    color: colors.textSecondary,
    fontWeight: '600',
  },
  guestCtaCard: {
    backgroundColor: '#F0F9FF',
    borderRadius: borderRadius.lg,
    padding: spacing.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#BAE6FD',
    ...shadows.sm,
  },
  guestCtaTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: colors.primaryDark,
    marginTop: 6,
  },
  guestCtaDesc: {
    fontSize: 13,
    color: colors.textSecondary,
    textAlign: 'center',
    marginVertical: 8,
    lineHeight: 18,
  },
  guestRegisterBtn: {
    backgroundColor: colors.primary,
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: borderRadius.md,
    marginTop: 4,
  },
  guestRegisterBtnText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: '700',
  },
  panelActionCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surface,
    padding: spacing.md,
    borderRadius: borderRadius.lg,
    ...shadows.sm,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  actionIconBox: {
    width: 46,
    height: 46,
    borderRadius: borderRadius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  actionTextBox: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  actionTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  actionDesc: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: 2,
  },
  bookingCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surface,
    padding: spacing.md,
    borderRadius: borderRadius.md,
    marginBottom: spacing.xs,
    ...shadows.sm,
  },
  bookingIcon: {
    width: 44,
    height: 44,
    borderRadius: borderRadius.sm,
    backgroundColor: colors.surfaceSecondary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  bookingDetails: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  bookingDestName: {
    fontSize: 14,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  bookingDate: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: 2,
  },
  bookingTotal: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.primary,
    marginTop: 2,
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
  emptyFavorites: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.lg,
    padding: spacing.xl,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
    marginTop: spacing.sm,
  },
  emptySubtitle: {
    fontSize: 12,
    color: colors.textSecondary,
    textAlign: 'center',
    marginTop: 4,
  },
  logoutButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#FEE2E2',
    paddingVertical: 14,
    borderRadius: borderRadius.md,
    gap: 8,
    marginBottom: spacing.md,
  },
  logoutButtonText: {
    color: colors.danger,
    fontSize: 15,
    fontWeight: '700',
  },
});
