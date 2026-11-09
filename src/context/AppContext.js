import React, { createContext, useContext, useState, useEffect } from 'react';
import { INITIAL_DESTINATIONS, INITIAL_MAP_POINTS } from '../data/mockData';
import {
  loginWithFirebase,
  registerWithFirebase,
  logoutWithFirebase,
  subscribeToAuthChanges,
} from '../config/firebase';

const AppContext = createContext();

export const AppProvider = ({ children }) => {
  // Lista de usuarios registrados para administración
  const [usersList, setUsersList] = useState([
    {
      id: 'usr-1',
      name: 'Christopher Admin',
      email: 'christopher@turisapp.com',
      role: 'admin',
      roleName: 'Administrador',
      avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      createdAt: '2026-01-10',
    },
    {
      id: 'usr-2',
      name: 'Valeria Dueña (Restaurante y Cabañas)',
      email: 'negocio@turisapp.com',
      role: 'business',
      roleName: 'Dueño de Negocio',
      avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
      createdAt: '2026-02-14',
    },
    {
      id: 'usr-3',
      name: 'Carlos Viajero',
      email: 'carlos@turisapp.com',
      role: 'user',
      roleName: 'Turista / Usuario',
      avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      createdAt: '2026-03-01',
    },
  ]);

  // Usuario y autenticación actual
  const [user, setUser] = useState({
    id: 'usr-1',
    name: 'Christopher',
    email: 'christopher@turisapp.com',
    avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    isGuest: false,
    role: 'admin', // Inicia por defecto con rol admin para acceso completo
    businessName: 'Turismo Aventura Andes',
  });
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authLoading, setAuthLoading] = useState(false);

  // Destinos y Puntos de Mapa dinámicos
  const [destinations, setDestinations] = useState(INITIAL_DESTINATIONS);
  const [mapPoints, setMapPoints] = useState(INITIAL_MAP_POINTS);

  // Navegación interna y pantallas
  const [currentScreen, setCurrentScreen] = useState('Login');
  const [selectedDestination, setSelectedDestination] = useState(INITIAL_DESTINATIONS[0]);
  const [previousScreen, setPreviousScreen] = useState('Home');

  // Filtros y búsqueda
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');

  // Favoritos
  const [favorites, setFavorites] = useState(['dest-1', 'dest-3']);

  // Reservas activas
  const [bookings, setBookings] = useState([
    {
      id: 'book-1',
      destinationId: 'dest-1',
      destinationName: 'Cerro El Mirador y Cordillera',
      userEmail: 'carlos@turisapp.com',
      userName: 'Carlos Viajero',
      ownerEmail: 'admin@turisapp.com',
      date: '15 de Diciembre, 2026',
      guests: 2,
      total: 70,
      status: 'Confirmada',
    },
    {
      id: 'book-2',
      destinationId: 'point-2',
      destinationName: 'Restaurante Sabor de la Cumbre',
      userEmail: 'carlos@turisapp.com',
      userName: 'Carlos Viajero',
      ownerEmail: 'negocio@turisapp.com',
      date: '20 de Diciembre, 2026',
      guests: 4,
      total: 120,
      status: 'Pendiente',
    },
  ]);

  // Coordenadas seleccionadas desde el mapa al tocar (para crear nuevo negocio)
  const [selectedMapCoords, setSelectedMapCoords] = useState(null);

  // Escuchar cambios de sesión en Firebase Auth
  useEffect(() => {
    try {
      const unsubscribe = subscribeToAuthChanges((firebaseUser) => {
        if (firebaseUser) {
          // Si el correo coincide con alguno existente en usersList, hereda su rol
          const matchedUser = usersList.find((u) => u.email.toLowerCase() === firebaseUser.email?.toLowerCase());
          setUser({
            id: firebaseUser.uid,
            name: firebaseUser.displayName || firebaseUser.email?.split('@')[0] || 'Viajero',
            email: firebaseUser.email,
            avatar: firebaseUser.photoURL || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
            isGuest: false,
            uid: firebaseUser.uid,
            role: matchedUser ? matchedUser.role : 'user',
            businessName: matchedUser?.businessName || '',
          });
          setIsAuthenticated(true);
          setCurrentScreen('Home');
        }
      });
      return () => unsubscribe && unsubscribe();
    } catch (e) {
      console.warn('Error al suscribir auth listener:', e);
    }
  }, [usersList]);

  // Cambiar rol de usuario activo
  const switchRole = (newRole) => {
    setUser((prev) => ({
      ...prev,
      role: newRole,
    }));
  };

  // Actualizar rol de cualquier usuario (Función exclusiva de Admin)
  const updateUserRole = (userId, newRole) => {
    setUsersList((prev) =>
      prev.map((u) =>
        u.id === userId
          ? {
              ...u,
              role: newRole,
              roleName:
                newRole === 'admin'
                  ? 'Administrador'
                  : newRole === 'business'
                  ? 'Dueño de Negocio'
                  : 'Turista / Usuario',
            }
          : u
      )
    );

    // Si el usuario modificado es el que está en sesión
    if (user.id === userId) {
      setUser((prev) => ({ ...prev, role: newRole }));
    }
  };

  // Función de Login
  const login = async (email, password) => {
    setAuthLoading(true);
    try {
      const credential = await loginWithFirebase(email, password);
      const fbUser = credential.user;
      const matched = usersList.find((u) => u.email.toLowerCase() === email.toLowerCase());

      setUser({
        id: fbUser.uid,
        name: fbUser.displayName || email.split('@')[0],
        email: fbUser.email,
        avatar: fbUser.photoURL || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        isGuest: false,
        role: matched ? matched.role : 'user',
        businessName: matched?.businessName || '',
      });
      setIsAuthenticated(true);
      setCurrentScreen('Home');
      return { success: true };
    } catch (error) {
      // Fallback: si el usuario existe en mock usersList (para pruebas sin conexión Firebase obligatoria)
      const mockUser = usersList.find((u) => u.email.toLowerCase() === email.toLowerCase());
      if (mockUser) {
        setUser({
          ...mockUser,
          isGuest: false,
        });
        setIsAuthenticated(true);
        setCurrentScreen('Home');
        return { success: true };
      }

      return {
        success: false,
        error: error?.code === 'auth/invalid-credential' || error?.code === 'auth/wrong-password'
          ? 'Correo o contraseña incorrectos'
          : error.message || 'Error al iniciar sesión',
      };
    } finally {
      setAuthLoading(false);
    }
  };

  // Función de Registro con selección de Rol
  const register = async (name, email, password, role = 'user', businessName = '') => {
    setAuthLoading(true);
    try {
      let fbUser;
      try {
        fbUser = await registerWithFirebase(name, email, password);
      } catch (fbErr) {
        // En caso de que Firebase falle por reglas o offline, permitimos registro local
        console.warn('Firebase register notice:', fbErr);
      }

      const newUserObj = {
        id: fbUser?.uid || `usr-${Date.now()}`,
        name: name || 'Nuevo Usuario',
        email: fbUser?.email || email,
        avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        isGuest: false,
        role: role,
        roleName: role === 'admin' ? 'Administrador' : role === 'business' ? 'Dueño de Negocio' : 'Turista / Usuario',
        businessName: businessName,
        createdAt: new Date().toISOString().split('T')[0],
      };

      setUsersList((prev) => [...prev, newUserObj]);
      setUser(newUserObj);
      setIsAuthenticated(true);
      setCurrentScreen('Home');
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: error?.code === 'auth/email-already-in-use'
          ? 'Este correo ya está registrado'
          : error.message || 'Error al registrar usuario',
      };
    } finally {
      setAuthLoading(false);
    }
  };

  // Entrar como invitado
  const loginAsGuest = (guestRole = 'user') => {
    setUser({
      id: 'guest',
      name: 'Invitado Viajero',
      email: 'invitado@turisapp.com',
      avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80',
      isGuest: true,
      role: guestRole,
      businessName: '',
    });
    setIsAuthenticated(true);
    setCurrentScreen('Home');
  };

  // Cerrar sesión
  const logout = async () => {
    try {
      await logoutWithFirebase();
    } catch (e) {
      console.warn(e);
    }
    setIsAuthenticated(false);
    setCurrentScreen('Login');
  };

  // Agregar nuevo negocio / punto turístico (Para Dueños de Negocio y Admin)
  const addBusinessPlace = (placeData) => {
    const id = `point-${Date.now()}`;
    const newPoint = {
      id,
      name: placeData.name,
      type: placeData.type || 'attraction',
      typeName:
        placeData.type === 'hotel'
          ? 'Hotel'
          : placeData.type === 'restaurant'
          ? 'Restaurante'
          : placeData.type === 'hospital'
          ? 'Hospital'
          : 'Atracción',
      rating: 5.0,
      price: placeData.price || 'Consultar',
      lat: placeData.lat || -33.4372,
      lng: placeData.lng || -70.6506,
      x: 50,
      y: 50,
      image: placeData.image || 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80',
      address: placeData.address || 'Ubicación turística',
      phone: placeData.phone || '+56 9 0000 0000',
      ownerEmail: user.email,
      description: placeData.description || 'Nuevo punto turístico registrado.',
    };

    setMapPoints((prev) => [newPoint, ...prev]);

    // También creamos un destino correspondiente para que aparezca en el feed principal
    const newDestination = {
      id: `dest-${Date.now()}`,
      name: placeData.name,
      category: placeData.category || 'lugares',
      categoryName: placeData.categoryName || 'Lugares',
      type: placeData.type || 'attraction',
      rating: 5.0,
      reviewsCount: 1,
      price: parseFloat(placeData.numericPrice) || 30,
      priceUnit: 'por persona',
      location: placeData.address || 'Zona Turística',
      coordinates: { x: 50, y: 50, lat: newPoint.lat, lng: newPoint.lng },
      ownerEmail: user.email,
      images: [newPoint.image],
      description: newPoint.description,
      features: [
        { label: 'Servicio', value: newPoint.typeName, icon: 'checkmark-circle-outline' },
        { label: 'Atención', value: 'Personalizada', icon: 'person-outline' },
      ],
      included: ['Atención directa', 'Garantía TurisApp'],
    };

    setDestinations((prev) => [newDestination, ...prev]);
    return true;
  };

  // Eliminar un lugar (Dueño para sus locales, Admin para cualquiera)
  const deleteBusinessPlace = (pointId) => {
    setMapPoints((prev) => prev.filter((p) => p.id !== pointId));
    setDestinations((prev) => prev.filter((d) => d.id !== pointId));
  };

  // Favoritos
  const toggleFavorite = (destinationId) => {
    setFavorites((prev) =>
      prev.includes(destinationId)
        ? prev.filter((id) => id !== destinationId)
        : [...prev, destinationId]
    );
  };

  const isFavorite = (destinationId) => favorites.includes(destinationId);

  // Navegación a detalle
  const navigateToDetail = (destination) => {
    setPreviousScreen(currentScreen);
    setSelectedDestination(destination);
    setCurrentScreen('Detail');
  };

  const goBack = () => {
    setCurrentScreen(previousScreen || 'Home');
  };

  // Crear una reserva
  const createBooking = (destination) => {
    const newBooking = {
      id: `book-${Date.now()}`,
      destinationId: destination.id,
      destinationName: destination.name,
      userEmail: user.email,
      userName: user.name,
      ownerEmail: destination.ownerEmail || 'negocio@turisapp.com',
      date: 'Próximo Fin de Semana',
      guests: 2,
      total: (destination.price || 30) * 2,
      status: 'Confirmada',
    };
    setBookings((prev) => [newBooking, ...prev]);
  };

  return (
    <AppContext.Provider
      value={{
        user,
        isAuthenticated,
        authLoading,
        login,
        register,
        loginAsGuest,
        logout,
        switchRole,
        usersList,
        updateUserRole,
        currentScreen,
        setCurrentScreen,
        selectedDestination,
        setSelectedDestination,
        navigateToDetail,
        goBack,
        searchQuery,
        setSearchQuery,
        selectedCategory,
        setSelectedCategory,
        favorites,
        toggleFavorite,
        isFavorite,
        bookings,
        createBooking,
        destinations,
        setDestinations,
        mapPoints,
        addBusinessPlace,
        deleteBusinessPlace,
        selectedMapCoords,
        setSelectedMapCoords,
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useApp debe ser usado dentro de un AppProvider');
  }
  return context;
};
