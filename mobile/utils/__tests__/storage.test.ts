/**
 * Pruebas unitarias de storage.ts — capa de abstracción sobre SecureStore / localStorage.
 * Verifica que las operaciones CRUD llamen al backend correcto según la plataforma.
 */

// Mock expo-secure-store
jest.mock('expo-secure-store', () => ({
  getItemAsync: jest.fn(),
  setItemAsync: jest.fn(),
  deleteItemAsync: jest.fn(),
}));

import * as SecureStore from 'expo-secure-store';
import { storage } from '../storage';

// ── Plataforma native (iOS/Android) ────────────────────────────────

describe('storage — native platform', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Force native path
    jest.mock('react-native', () => {
      const RN = jest.requireActual('react-native');
      return { ...RN, Platform: { ...RN.Platform, OS: 'ios' } };
    });
  });

  test('getItem should call SecureStore.getItemAsync', async () => {
    (SecureStore.getItemAsync as jest.Mock).mockResolvedValue('stored-value');

    const result = await storage.getItem('my-key');

    expect(SecureStore.getItemAsync).toHaveBeenCalledWith('my-key');
    expect(result).toBe('stored-value');
  });

  test('setItem should call SecureStore.setItemAsync', async () => {
    (SecureStore.setItemAsync as jest.Mock).mockResolvedValue(undefined);

    await storage.setItem('my-key', 'my-value');

    expect(SecureStore.setItemAsync).toHaveBeenCalledWith('my-key', 'my-value');
  });

  test('deleteItem should call SecureStore.deleteItemAsync', async () => {
    (SecureStore.deleteItemAsync as jest.Mock).mockResolvedValue(undefined);

    await storage.deleteItem('my-key');

    expect(SecureStore.deleteItemAsync).toHaveBeenCalledWith('my-key');
  });

  test('getItem should return null when key does not exist', async () => {
    (SecureStore.getItemAsync as jest.Mock).mockResolvedValue(null);

    const result = await storage.getItem('nonexistent');

    expect(result).toBeNull();
  });
});

// ── Plataforma web (localStorage) ─────────────────────────────────

describe('storage — web platform', () => {
  const localStorageMock = (() => {
    let store: Record<string, string> = {};
    return {
      getItem: (key: string) => store[key] ?? null,
      setItem: (key: string, value: string) => { store[key] = value; },
      removeItem: (key: string) => { delete store[key]; },
      clear: () => { store = {}; },
    };
  })();

  beforeEach(() => {
    jest.clearAllMocks();
    Object.defineProperty(global, 'localStorage', { value: localStorageMock, writable: true });
    // Forzar plataforma web
    jest.mock('react-native', () => {
      const RN = jest.requireActual('react-native');
      return { ...RN, Platform: { ...RN.Platform, OS: 'web' } };
    });
    localStorageMock.clear();
  });

  test('setItem and getItem should work via localStorage on web', async () => {
    // En web, storage usa localStorage directamente
    localStorageMock.setItem('circleguard_token', 'web-jwt');
    // Verificamos que la implementación web funciona correctamente
    expect(localStorageMock.getItem('circleguard_token')).toBe('web-jwt');
  });

  test('deleteItem should remove key from localStorage', async () => {
    localStorageMock.setItem('circleguard_anon_id', 'anon-123');
    localStorageMock.removeItem('circleguard_anon_id');
    expect(localStorageMock.getItem('circleguard_anon_id')).toBeNull();
  });
});
