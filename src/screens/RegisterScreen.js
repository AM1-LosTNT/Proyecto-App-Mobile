import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useApp } from '../context/AppContext';
import { colors, spacing, borderRadius, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';

export const RegisterScreen = () => {
  const { register, authLoading, setCurrentScreen } = useApp();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [role, setRole] = useState('user'); // 'user' | 'business' | 'admin'
  const [businessName, setBusinessName] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  const handleRegister = async () => {
    if (!name.trim() || !email.trim() || !password.trim()) {
      setErrorMessage('Por favor completa todos los campos requeridos');
      return;
    }
    if (password.length < 6) {
      setErrorMessage('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (password !== confirmPassword) {
      setErrorMessage('Las contraseñas no coinciden');
      return;
    }
    if (role === 'business' && !businessName.trim()) {
      setErrorMessage('Por favor ingresa el nombre de tu empresa o negocio');
      return;
    }

    setErrorMessage('');
    const result = await register(
      name.trim(),
      email.trim(),
      password,
      role,
      businessName.trim()
    );
    if (!result.success) {
      setErrorMessage(result.error);
    }
  };

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'bottom', 'left', 'right']}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.container}
      >
        <ScrollView
          contentContainerStyle={styles.scrollContent}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {/* Botón Volver */}
          <TouchableOpacity
            style={styles.backButton}
            onPress={() => setCurrentScreen('Login')}
            activeOpacity={0.7}
          >
            <Ionicons name="arrow-back" size={24} color={colors.textPrimary} />
          </TouchableOpacity>

          {/* Logo y Branding */}
          <View style={styles.brandContainer}>
            <Image
              source={require('../../assets/logo.png')}
              style={styles.logoImage}
              resizeMode="contain"
            />
          </View>

          {/* Formulario */}
          <View style={styles.formCard}>
            <Text style={styles.formTitle}>Crear Cuenta</Text>

            {errorMessage ? (
              <View style={styles.errorBox}>
                <Ionicons name="alert-circle" size={18} color={colors.danger} />
                <Text style={styles.errorText}>{errorMessage}</Text>
              </View>
            ) : null}

            {/* SELECCIÓN DE ROL */}
            <Text style={styles.label}>¿Cómo usarás TurisApp?</Text>
            <View style={styles.roleSelectionContainer}>
              <TouchableOpacity
                style={[
                  styles.roleCard,
                  role === 'user' && styles.roleCardActive,
                ]}
                onPress={() => setRole('user')}
              >
                <Ionicons
                  name="compass"
                  size={22}
                  color={role === 'user' ? colors.primary : colors.textMuted}
                />
                <Text
                  style={[
                    styles.roleCardTitle,
                    role === 'user' && styles.roleCardTitleActive,
                  ]}
                >
                  Turista
                </Text>
                <Text style={styles.roleCardDesc}>Explorar & Reservar</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[
                  styles.roleCard,
                  role === 'business' && styles.roleCardActive,
                ]}
                onPress={() => setRole('business')}
              >
                <Ionicons
                  name="business"
                  size={22}
                  color={role === 'business' ? colors.primary : colors.textMuted}
                />
                <Text
                  style={[
                    styles.roleCardTitle,
                    role === 'business' && styles.roleCardTitleActive,
                  ]}
                >
                  Dueño Negocio
                </Text>
                <Text style={styles.roleCardDesc}>Publicar Locales</Text>
              </TouchableOpacity>
            </View>

            {/* Si es Dueño de Negocio, pide el nombre de la empresa */}
            {role === 'business' && (
              <View style={styles.inputGroup}>
                <Text style={styles.label}>Nombre de tu Negocio / Empresa *</Text>
                <View style={styles.inputContainer}>
                  <Ionicons
                    name="storefront-outline"
                    size={20}
                    color={colors.primary}
                    style={styles.inputIcon}
                  />
                  <TextInput
                    style={styles.input}
                    placeholder="Ej: Posada Las Cumbres o Tour Andes"
                    placeholderTextColor={colors.textMuted}
                    value={businessName}
                    onChangeText={setBusinessName}
                  />
                </View>
              </View>
            )}

            {/* Nombre Completo */}
            <View style={styles.inputGroup}>
              <Text style={styles.label}>Nombre Completo *</Text>
              <View style={styles.inputContainer}>
                <Ionicons
                  name="person-outline"
                  size={20}
                  color={colors.textMuted}
                  style={styles.inputIcon}
                />
                <TextInput
                  style={styles.input}
                  placeholder="Tu nombre y apellido"
                  placeholderTextColor={colors.textMuted}
                  value={name}
                  onChangeText={(text) => {
                    setName(text);
                    setErrorMessage('');
                  }}
                />
              </View>
            </View>

            {/* Correo Electrónico */}
            <View style={styles.inputGroup}>
              <Text style={styles.label}>Correo Electrónico *</Text>
              <View style={styles.inputContainer}>
                <Ionicons
                  name="mail-outline"
                  size={20}
                  color={colors.textMuted}
                  style={styles.inputIcon}
                />
                <TextInput
                  style={styles.input}
                  placeholder="ejemplo@correo.com"
                  placeholderTextColor={colors.textMuted}
                  keyboardType="email-address"
                  autoCapitalize="none"
                  value={email}
                  onChangeText={(text) => {
                    setEmail(text);
                    setErrorMessage('');
                  }}
                />
              </View>
            </View>

            {/* Contraseña */}
            <View style={styles.inputGroup}>
              <Text style={styles.label}>Contraseña *</Text>
              <View style={styles.inputContainer}>
                <Ionicons
                  name="lock-closed-outline"
                  size={20}
                  color={colors.textMuted}
                  style={styles.inputIcon}
                />
                <TextInput
                  style={styles.input}
                  placeholder="Mínimo 6 caracteres"
                  placeholderTextColor={colors.textMuted}
                  secureTextEntry={!showPassword}
                  value={password}
                  onChangeText={(text) => {
                    setPassword(text);
                    setErrorMessage('');
                  }}
                />
                <TouchableOpacity
                  onPress={() => setShowPassword(!showPassword)}
                  style={styles.eyeButton}
                >
                  <Ionicons
                    name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                    size={20}
                    color={colors.textMuted}
                  />
                </TouchableOpacity>
              </View>
            </View>

            {/* Confirmar Contraseña */}
            <View style={styles.inputGroup}>
              <Text style={styles.label}>Confirmar Contraseña *</Text>
              <View style={styles.inputContainer}>
                <Ionicons
                  name="shield-checkmark-outline"
                  size={20}
                  color={colors.textMuted}
                  style={styles.inputIcon}
                />
                <TextInput
                  style={styles.input}
                  placeholder="Repite tu contraseña"
                  placeholderTextColor={colors.textMuted}
                  secureTextEntry={!showPassword}
                  value={confirmPassword}
                  onChangeText={(text) => {
                    setConfirmPassword(text);
                    setErrorMessage('');
                  }}
                />
              </View>
            </View>

            {/* Botón de Registro */}
            <TouchableOpacity
              style={styles.registerButton}
              onPress={handleRegister}
              disabled={authLoading}
              activeOpacity={0.8}
            >
              {authLoading ? (
                <ActivityIndicator color={colors.textLight} />
              ) : (
                <Text style={styles.registerButtonText}>Registrarme</Text>
              )}
            </TouchableOpacity>

            {/* Link a Login */}
            <View style={styles.loginContainer}>
              <Text style={styles.loginText}>¿Ya tienes una cuenta? </Text>
              <TouchableOpacity onPress={() => setCurrentScreen('Login')}>
                <Text style={styles.loginLink}>Iniciar Sesión</Text>
              </TouchableOpacity>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  container: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.surfaceSecondary,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  brandContainer: {
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  logoImage: {
    width: 190,
    height: 140,
  },
  formCard: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.xl,
    padding: spacing.lg,
    ...shadows.md,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  formTitle: {
    fontSize: 20,
    fontWeight: '800',
    color: colors.textPrimary,
    marginBottom: spacing.md,
  },
  errorBox: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FEE2E2',
    padding: spacing.sm,
    borderRadius: borderRadius.sm,
    marginBottom: spacing.md,
    gap: 8,
  },
  errorText: {
    color: colors.danger,
    fontSize: 13,
    fontWeight: '600',
    flex: 1,
  },
  label: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
    marginBottom: 6,
  },
  roleSelectionContainer: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  roleCard: {
    flex: 1,
    backgroundColor: colors.surfaceSecondary,
    borderRadius: borderRadius.md,
    paddingVertical: 12,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: colors.border,
  },
  roleCardActive: {
    borderColor: colors.primary,
    backgroundColor: '#E0F2FE',
  },
  roleCardTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textSecondary,
    marginTop: 4,
  },
  roleCardTitleActive: {
    color: colors.primary,
  },
  roleCardDesc: {
    fontSize: 10,
    color: colors.textMuted,
    marginTop: 2,
  },
  inputGroup: {
    marginBottom: spacing.sm,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surfaceSecondary,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: colors.border,
    paddingHorizontal: spacing.sm,
  },
  inputIcon: {
    marginRight: 6,
  },
  input: {
    flex: 1,
    paddingVertical: 10,
    fontSize: 14,
    color: colors.textPrimary,
  },
  eyeButton: {
    padding: 6,
  },
  registerButton: {
    backgroundColor: colors.primary,
    borderRadius: borderRadius.md,
    paddingVertical: 14,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: spacing.md,
    ...shadows.sm,
  },
  registerButtonText: {
    color: colors.textLight,
    fontSize: 15,
    fontWeight: '700',
  },
  loginContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: spacing.md,
  },
  loginText: {
    fontSize: 13,
    color: colors.textSecondary,
  },
  loginLink: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.primary,
  },
});
