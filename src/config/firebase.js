import { initializeApp, getApps, getApp } from 'firebase/app';
import {
  getAuth,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  updateProfile,
  signOut,
  onAuthStateChanged,
} from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

/**
 * Configuración oficial de Firebase para TurisApp
 * Package Name: com.x_christo_x.TurisApp
 * Project ID: turisapp-79f3e
 */
export const firebaseConfig = {
  apiKey: "AIzaSyDgEYZfUGwEjUvkPV44B7tDux77WI4SSUI",
  authDomain: "turisapp-79f3e.firebaseapp.com",
  projectId: "turisapp-79f3e",
  storageBucket: "turisapp-79f3e.firebasestorage.app",
  messagingSenderId: "846386476048",
  appId: "1:846386476048:android:f65a8b8a4f2dda0a9cc695",
};

// Inicialización de la aplicación
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApp();
const auth = getAuth(app);
const db = getFirestore(app);

// Funciones auxiliares de autenticación
export const loginWithFirebase = async (email, password) => {
  return await signInWithEmailAndPassword(auth, email, password);
};

export const registerWithFirebase = async (name, email, password) => {
  const credential = await createUserWithEmailAndPassword(auth, email, password);
  if (credential.user) {
    await updateProfile(credential.user, { displayName: name });
  }
  return credential.user;
};

export const logoutWithFirebase = async () => {
  return await signOut(auth);
};

export const subscribeToAuthChanges = (callback) => {
  return onAuthStateChanged(auth, callback);
};

export { app, auth, db };
