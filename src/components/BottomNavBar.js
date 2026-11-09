import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useApp } from '../context/AppContext';
import { colors, spacing, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

export const BottomNavBar = () => {
  const { currentScreen, setCurrentScreen } = useApp();
  const insets = useSafeAreaInsets();

  const tabs = [
    {
      id: 'Home',
      label: 'Home',
      iconActive: 'home',
      iconInactive: 'home-outline',
    },
    {
      id: 'Map',
      label: 'Mapa',
      iconActive: 'location',
      iconInactive: 'location-outline',
    },
    {
      id: 'Routes',
      label: 'Rutas',
      iconActive: 'git-network',
      iconInactive: 'git-network-outline',
    },
    {
      id: 'Profile',
      label: 'Perfil',
      iconActive: 'person',
      iconInactive: 'person-outline',
    },
  ];

  return (
    <View style={[styles.container, { paddingBottom: Math.max(insets.bottom, 8) }]}>
      <View style={styles.navBar}>
        {tabs.map((tab) => {
          const isActive = currentScreen === tab.id;
          return (
            <TouchableOpacity
              key={tab.id}
              style={styles.tabButton}
              onPress={() => setCurrentScreen(tab.id)}
              activeOpacity={0.7}
            >
              <View style={[styles.iconWrapper, isActive && styles.iconWrapperActive]}>
                <Ionicons
                  name={isActive ? tab.iconActive : tab.iconInactive}
                  size={24}
                  color={isActive ? colors.primary : colors.textMuted}
                />
              </View>
              <Text style={[styles.tabLabel, isActive && styles.tabLabelActive]}>
                {tab.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    paddingTop: 6,
    ...shadows.lg,
  },
  navBar: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
    paddingHorizontal: spacing.sm,
  },
  tabButton: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 4,
    paddingHorizontal: 12,
  },
  iconWrapper: {
    padding: 4,
    borderRadius: 12,
  },
  iconWrapperActive: {
    backgroundColor: '#E0F2FE',
  },
  tabLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: colors.textMuted,
    marginTop: 2,
  },
  tabLabelActive: {
    color: colors.primary,
    fontWeight: '700',
  },
});
