import React from 'react';
import { StyleSheet, StatusBar } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AppProvider, useApp } from './src/context/AppContext';
import { LoginScreen } from './src/screens/LoginScreen';
import { RegisterScreen } from './src/screens/RegisterScreen';
import { HomeScreen } from './src/screens/HomeScreen';
import { DetailScreen } from './src/screens/DetailScreen';
import { MapScreen } from './src/screens/MapScreen';
import { RoutesScreen } from './src/screens/RoutesScreen';
import { ProfileScreen } from './src/screens/ProfileScreen';
import { BusinessPanelScreen } from './src/screens/BusinessPanelScreen';
import { AdminPanelScreen } from './src/screens/AdminPanelScreen';
import { colors } from './src/styles/theme';

const MainNavigator = () => {
  const { currentScreen, isAuthenticated } = useApp();

  // Si no está autenticado, muestra Login o Registro
  if (!isAuthenticated) {
    if (currentScreen === 'Register') {
      return <RegisterScreen />;
    }
    return <LoginScreen />;
  }

  // Si está autenticado, navega entre las pantallas principales y paneles especializados
  switch (currentScreen) {
    case 'Home':
      return <HomeScreen />;
    case 'Detail':
      return <DetailScreen />;
    case 'Map':
      return <MapScreen />;
    case 'Routes':
      return <RoutesScreen />;
    case 'Profile':
      return <ProfileScreen />;
    case 'BusinessPanel':
      return <BusinessPanelScreen />;
    case 'AdminPanel':
      return <AdminPanelScreen />;
    default:
      return <HomeScreen />;
  }
};

export default function App() {
  return (
    <SafeAreaProvider>
      <StatusBar barStyle="dark-content" backgroundColor={colors.background} />
      <AppProvider>
        <MainNavigator />
      </AppProvider>
    </SafeAreaProvider>
  );
}
