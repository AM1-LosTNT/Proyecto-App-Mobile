import React from 'react';
import { ScrollView, TouchableOpacity, Text, StyleSheet } from 'react-native';
import { useApp } from '../context/AppContext';
import { CATEGORIES } from '../data/mockData';
import { colors, spacing, borderRadius } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

export const CategoryList = () => {
  const { selectedCategory, setSelectedCategory } = useApp();

  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.container}
    >
      {CATEGORIES.map((cat) => {
        const isSelected = selectedCategory === cat.id;
        return (
          <TouchableOpacity
            key={cat.id}
            style={[styles.categoryChip, isSelected && styles.categoryChipActive]}
            onPress={() => setSelectedCategory(cat.id)}
            activeOpacity={0.7}
          >
            {cat.icon && (
              <Ionicons
                name={cat.icon}
                size={16}
                color={isSelected ? colors.textLight : colors.textSecondary}
                style={styles.icon}
              />
            )}
            <Text style={[styles.categoryText, isSelected && styles.categoryTextActive]}>
              {cat.name}
            </Text>
          </TouchableOpacity>
        );
      })}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
  },
  categoryChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surface,
    paddingVertical: 9,
    paddingHorizontal: 16,
    borderRadius: borderRadius.round,
    borderWidth: 1,
    borderColor: colors.border,
  },
  categoryChipActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  icon: {
    marginRight: 6,
  },
  categoryText: {
    fontSize: 14,
    fontWeight: '600',
    color: colors.textSecondary,
  },
  categoryTextActive: {
    color: colors.textLight,
  },
});
