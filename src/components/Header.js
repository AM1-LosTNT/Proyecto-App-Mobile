import React from 'react';
import { View, Text, StyleSheet, Image, TouchableOpacity } from 'react-native';
import { useApp } from '../context/AppContext';
import { colors, spacing, borderRadius } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

export const Header = () => {
  const { user, setCurrentScreen } = useApp();

  const roleLabels = {
    admin: { label: 'Admin', color: '#7C3AED', bg: '#F3E8FF' },
    business: { label: 'Dueño', color: '#0E7490', bg: '#E0F2FE' },
    user: { label: 'Turista', color: '#64748B', bg: '#F1F5F9' },
  };

  const role = user?.isGuest
    ? { label: 'Invitado', color: '#0E7490', bg: '#E0F2FE' }
    : roleLabels[user?.role] || roleLabels.user;

  return (
    <View style={styles.container}>
      <View style={styles.textContainer}>
        <View style={styles.greetingRow}>
          <Text style={styles.greeting} numberOfLines={1}>
            Hola, {user?.name?.split(' ')[0] || 'Viajero'}!
          </Text>
          <View style={[styles.roleBadge, { backgroundColor: role.bg }]}>
            <Text style={[styles.roleBadgeText, { color: role.color }]}>
              {role.label}
            </Text>
          </View>
        </View>
        <Text style={styles.subtitle}>Explora tu próxima aventura</Text>
      </View>

      <TouchableOpacity
        style={styles.avatarButton}
        onPress={() => setCurrentScreen('Profile')}
        activeOpacity={0.8}
      >
        {user?.avatar ? (
          <Image source={{ uri: user.avatar }} style={styles.avatarImage} />
        ) : (
          <View style={styles.avatarPlaceholder}>
            <Ionicons name="person" size={20} color={colors.primary} />
          </View>
        )}
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingTop: spacing.xs,
    paddingBottom: spacing.xs,
  },
  textContainer: {
    flex: 1,
    marginRight: spacing.sm,
  },
  greetingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  greeting: {
    fontSize: 20,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  roleBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: borderRadius.sm,
  },
  roleBadgeText: {
    fontSize: 10,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  subtitle: {
    fontSize: 13,
    fontWeight: '600',
    color: colors.primary,
    marginTop: 2,
  },
  avatarButton: {
    padding: 3,
    borderRadius: borderRadius.full,
    borderWidth: 2,
    borderColor: colors.border,
  },
  avatarImage: {
    width: 44,
    height: 44,
    borderRadius: 22,
  },
  avatarPlaceholder: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.surfaceSecondary,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
