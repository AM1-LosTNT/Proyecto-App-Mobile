export const colors = {
  primary: '#0E7490',       // Cyan / Teal oscuro moderno para turismo
  primaryLight: '#06B6D4',  // Cyan vibrante
  primaryDark: '#155E75',
  accent: '#F59E0B',        // Ámbar para estrellas, valoraciones y badges
  accentWarm: '#EF4444',    // Rojo suave para corazones / favoritos
  
  background: '#F8FAFC',    // Fondo claro suave
  surface: '#FFFFFF',       // Superficie tarjetas
  surfaceSecondary: '#F1F5F9',
  
  textPrimary: '#0F172A',   // Títulos oscuros
  textSecondary: '#64748B', // Subtítulos y descripciones
  textMuted: '#94A3B8',     // Placeholders e iconos secundarios
  textLight: '#FFFFFF',
  
  border: '#E2E8F0',
  borderLight: '#F1F5F9',
  
  success: '#10B981',
  warning: '#F59E0B',
  danger: '#EF4444',
  
  overlay: 'rgba(0, 0, 0, 0.45)',
  shadow: '#0F172A',
};

export const typography = {
  headerTitle: {
    fontSize: 26,
    fontWeight: '800',
    color: colors.textPrimary,
    letterSpacing: -0.5,
  },
  headerSubtitle: {
    fontSize: 15,
    fontWeight: '600',
    color: colors.primary,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  body: {
    fontSize: 14,
    color: colors.textSecondary,
    lineHeight: 21,
  },
  caption: {
    fontSize: 12,
    color: colors.textMuted,
  },
  buttonText: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textLight,
  },
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 14,
  lg: 20,
  xl: 28,
  xxl: 36,
};

export const borderRadius = {
  sm: 8,
  md: 14,
  lg: 20,
  xl: 26,
  round: 9999,
};

export const shadows = {
  sm: {
    shadowColor: colors.shadow,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 3,
    elevation: 2,
  },
  md: {
    shadowColor: colors.shadow,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  lg: {
    shadowColor: colors.shadow,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.15,
    shadowRadius: 16,
    elevation: 8,
  },
};
