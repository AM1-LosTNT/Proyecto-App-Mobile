import React, { useState } from 'react';
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
import { BottomNavBar } from '../components/BottomNavBar';
import { ROUTES } from '../data/mockData';
import { colors, spacing, borderRadius, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';
import { useApp } from '../context/AppContext';

export const RoutesScreen = () => {
  const { user, setCurrentScreen, logout } = useApp();
  const [expandedRouteId, setExpandedRouteId] = useState('route-1');

  const toggleExpand = (id) => {
    setExpandedRouteId((prev) => (prev === id ? null : id));
  };

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
      <StatusBar barStyle="dark-content" backgroundColor={colors.surface} />
      <View style={styles.container}>
        <View style={styles.header}>
          <Text style={styles.title}>Rutas e Itinerarios</Text>
          <Text style={styles.subtitle}>
            Planes recomendados paso a paso para tus viajes
          </Text>
        </View>

        {/* Si el usuario es invitado, mostrar pantalla de bloqueo con llamado al registro */}
        {user?.isGuest ? (
          <ScrollView
            showsVerticalScrollIndicator={false}
            contentContainerStyle={styles.guestContainer}
          >
            <View style={styles.lockBadge}>
              <Ionicons name="lock-closed" size={38} color={colors.primary} />
            </View>

            <Text style={styles.guestTitle}>
              Rutas exclusivas para usuarios registrados
            </Text>

            <Text style={styles.guestDescription}>
              Como invitado puedes explorar todos los lugares en el Inicio y el Mapa.
              Para acceder a los itinerarios guiados paso a paso, tiempos de recorrido y paradas detalladas, por favor regístrate o inicia sesión.
            </Text>

            <View style={styles.perksCard}>
              <View style={styles.perkItem}>
                <Ionicons name="checkmark-circle" size={20} color={colors.primary} />
                <Text style={styles.perkText}>
                  Itinerarios de 1 a 3 días con horarios sugeridos
                </Text>
              </View>

              <View style={styles.perkItem}>
                <Ionicons name="checkmark-circle" size={20} color={colors.primary} />
                <Text style={styles.perkText}>
                  Tiempos de traslado y nivel de dificultad técnica
                </Text>
              </View>

              <View style={styles.perkItem}>
                <Ionicons name="checkmark-circle" size={20} color={colors.primary} />
                <Text style={styles.perkText}>
                  Recomendaciones de paradas gastronómicas y miradores
                </Text>
              </View>
            </View>

            {/* Botón de Registro */}
            <TouchableOpacity
              style={styles.registerCtaBtn}
              onPress={() => setCurrentScreen('Register')}
              activeOpacity={0.85}
            >
              <Text style={styles.registerCtaBtnText}>Crear Cuenta Gratis</Text>
              <Ionicons name="arrow-forward" size={18} color="#FFFFFF" />
            </TouchableOpacity>

            {/* Botón Iniciar Sesión */}
            <TouchableOpacity
              style={styles.loginCtaBtn}
              onPress={() => {
                logout();
              }}
              activeOpacity={0.8}
            >
              <Text style={styles.loginCtaBtnText}>
                ¿Ya tienes una cuenta? Iniciar Sesión
              </Text>
            </TouchableOpacity>
          </ScrollView>
        ) : (
          /* Vista completa para usuarios registrados */
          <ScrollView
            showsVerticalScrollIndicator={false}
            contentContainerStyle={styles.scrollContent}
          >
            {ROUTES.map((route) => {
              const isExpanded = expandedRouteId === route.id;

              return (
                <View key={route.id} style={styles.routeCard}>
                  <Image source={{ uri: route.coverImage }} style={styles.coverImage} />

                  <View style={styles.cardHeader}>
                    <View style={styles.badgesRow}>
                      <View style={styles.badge}>
                        <Ionicons name="time-outline" size={13} color={colors.primary} />
                        <Text style={styles.badgeText}>{route.duration}</Text>
                      </View>
                      <View style={styles.badge}>
                        <Ionicons name="speedometer-outline" size={13} color={colors.accent} />
                        <Text style={styles.badgeText}>{route.difficulty}</Text>
                      </View>
                      <View style={styles.badge}>
                        <Ionicons name="navigate-outline" size={13} color={colors.textSecondary} />
                        <Text style={styles.badgeText}>{route.distance}</Text>
                      </View>
                    </View>

                    <Text style={styles.routeTitle}>{route.title}</Text>

                    <TouchableOpacity
                      style={styles.expandButton}
                      onPress={() => toggleExpand(route.id)}
                      activeOpacity={0.7}
                    >
                      <Text style={styles.expandButtonText}>
                        {isExpanded ? 'Ocultar Itinerario' : 'Ver Itinerario Completo'}
                      </Text>
                      <Ionicons
                        name={isExpanded ? 'chevron-up' : 'chevron-down'}
                        size={18}
                        color={colors.primary}
                      />
                    </TouchableOpacity>
                  </View>

                  {/* Línea de Tiempo del Itinerario Desplegable */}
                  {isExpanded && (
                    <View style={styles.timelineContainer}>
                      <Text style={styles.timelineHeader}>Paradas del Recorrido:</Text>
                      {route.stops.map((stop, index) => {
                        const isLast = index === route.stops.length - 1;
                        return (
                          <View key={index} style={styles.timelineItem}>
                            <View style={styles.timelineLeft}>
                              <View style={styles.timelineDot}>
                                <Text style={styles.timelineDotNumber}>{index + 1}</Text>
                              </View>
                              {!isLast && <View style={styles.timelineLine} />}
                            </View>

                            <View style={styles.timelineContent}>
                              <Text style={styles.timelineTime}>{stop.time}</Text>
                              <Text style={styles.timelineName}>{stop.name}</Text>
                            </View>
                          </View>
                        );
                      })}
                    </View>
                  )}
                </View>
              );
            })}
          </ScrollView>
        )}

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
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: spacing.sm,
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  title: {
    fontSize: 22,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  subtitle: {
    fontSize: 13,
    color: colors.textSecondary,
    marginTop: 2,
  },
  scrollContent: {
    padding: spacing.lg,
    paddingBottom: spacing.xxl,
  },
  guestContainer: {
    padding: spacing.xl,
    alignItems: 'center',
    justifyContent: 'center',
    flexGrow: 1,
  },
  lockBadge: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#E0F2FE',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.md,
    ...shadows.sm,
  },
  guestTitle: {
    fontSize: 20,
    fontWeight: '800',
    color: colors.textPrimary,
    textAlign: 'center',
    marginBottom: spacing.sm,
  },
  guestDescription: {
    fontSize: 14,
    color: colors.textSecondary,
    textAlign: 'center',
    lineHeight: 21,
    marginBottom: spacing.lg,
  },
  perksCard: {
    width: '100%',
    backgroundColor: colors.surface,
    borderRadius: borderRadius.lg,
    padding: spacing.md,
    gap: spacing.sm,
    marginBottom: spacing.xl,
    ...shadows.sm,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  perkItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  perkText: {
    flex: 1,
    fontSize: 13,
    color: colors.textPrimary,
    fontWeight: '600',
  },
  registerCtaBtn: {
    width: '100%',
    backgroundColor: colors.primary,
    paddingVertical: 14,
    borderRadius: borderRadius.md,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    ...shadows.md,
  },
  registerCtaBtnText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '800',
  },
  loginCtaBtn: {
    marginTop: spacing.md,
    paddingVertical: 8,
  },
  loginCtaBtnText: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.primary,
  },
  routeCard: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.lg,
    overflow: 'hidden',
    marginBottom: spacing.lg,
    borderWidth: 1,
    borderColor: colors.border,
    ...shadows.md,
  },
  coverImage: {
    width: '100%',
    height: 150,
    backgroundColor: colors.surfaceSecondary,
  },
  cardHeader: {
    padding: spacing.md,
  },
  badgesRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
    marginBottom: spacing.xs,
  },
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: colors.surfaceSecondary,
    paddingVertical: 3,
    paddingHorizontal: 8,
    borderRadius: borderRadius.sm,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: '600',
    color: colors.textSecondary,
  },
  routeTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: colors.textPrimary,
    marginVertical: spacing.xs,
  },
  expandButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: spacing.xs,
    marginTop: 4,
  },
  expandButtonText: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.primary,
  },
  timelineContainer: {
    backgroundColor: '#F8FAFC',
    borderTopWidth: 1,
    borderTopColor: colors.border,
    padding: spacing.md,
  },
  timelineHeader: {
    fontSize: 14,
    fontWeight: '700',
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  timelineItem: {
    flexDirection: 'row',
    minHeight: 50,
  },
  timelineLeft: {
    alignItems: 'center',
    width: 30,
  },
  timelineDot: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 2,
  },
  timelineDotNumber: {
    color: colors.textLight,
    fontSize: 11,
    fontWeight: '800',
  },
  timelineLine: {
    width: 2,
    flex: 1,
    backgroundColor: colors.border,
    marginVertical: 2,
  },
  timelineContent: {
    flex: 1,
    marginLeft: spacing.sm,
    paddingBottom: spacing.sm,
  },
  timelineTime: {
    fontSize: 11,
    fontWeight: '700',
    color: colors.primary,
  },
  timelineName: {
    fontSize: 13,
    fontWeight: '600',
    color: colors.textPrimary,
    marginTop: 2,
  },
});
