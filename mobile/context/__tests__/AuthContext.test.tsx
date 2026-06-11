import React from 'react';
import { renderHook, act } from '@testing-library/react-native';
import { AuthProvider, useAuth } from '../AuthContext';

// Mock expo-secure-store
jest.mock('expo-secure-store', () => ({
  getItemAsync: jest.fn(),
  setItemAsync: jest.fn(),
  deleteItemAsync: jest.fn(),
}));

// Mock react-native Platform to native (non-web) para ir por SecureStore
jest.mock('react-native', () => {
  const RN = jest.requireActual('react-native');
  return { ...RN, Platform: { ...RN.Platform, OS: 'ios' } };
});

import * as SecureStore from 'expo-secure-store';

const wrapper = ({ children }: { children: React.ReactNode }) => (
  <AuthProvider>{children}</AuthProvider>
);

describe('AuthContext', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ── Estado inicial ─────────────────────────────────────────────────

  test('should start with null anonymousId and token while loading', () => {
    (SecureStore.getItemAsync as jest.Mock).mockResolvedValue(null);

    const { result } = renderHook(() => useAuth(), { wrapper });

    // isLoading = true inmediatamente antes de que resuelva el storage
    expect(result.current.isLoading).toBe(true);
  });

  test('should load anonymousId and token from storage on mount', async () => {
    (SecureStore.getItemAsync as jest.Mock)
      .mockResolvedValueOnce('anon-uuid-123')  // primera llamada → circleguard_anon_id
      .mockResolvedValueOnce('jwt-token-abc'); // segunda llamada → circleguard_token

    const { result } = renderHook(() => useAuth(), { wrapper });

    await act(async () => {});

    expect(result.current.anonymousId).toBe('anon-uuid-123');
    expect(result.current.token).toBe('jwt-token-abc');
    expect(result.current.isLoading).toBe(false);
  });

  test('should have null state when storage is empty', async () => {
    (SecureStore.getItemAsync as jest.Mock).mockResolvedValue(null);

    const { result } = renderHook(() => useAuth(), { wrapper });

    await act(async () => {});

    expect(result.current.anonymousId).toBeNull();
    expect(result.current.token).toBeNull();
    expect(result.current.isLoading).toBe(false);
  });

  // ── enroll ────────────────────────────────────────────────────────

  test('should save anonymousId and token to storage on enroll', async () => {
    (SecureStore.getItemAsync as jest.Mock).mockResolvedValue(null);
    (SecureStore.setItemAsync as jest.Mock).mockResolvedValue(undefined);

    const { result } = renderHook(() => useAuth(), { wrapper });
    await act(async () => {});

    await act(async () => {
      await result.current.enroll('new-anon-id', 'new-jwt');
    });

    expect(SecureStore.setItemAsync).toHaveBeenCalledWith('circleguard_anon_id', 'new-anon-id');
    expect(SecureStore.setItemAsync).toHaveBeenCalledWith('circleguard_token', 'new-jwt');
    expect(result.current.anonymousId).toBe('new-anon-id');
    expect(result.current.token).toBe('new-jwt');
  });

  // ── logout ────────────────────────────────────────────────────────

  test('should clear storage and reset state on logout', async () => {
    (SecureStore.getItemAsync as jest.Mock)
      .mockResolvedValueOnce('anon-uuid-123')
      .mockResolvedValueOnce('jwt-token-abc');
    (SecureStore.deleteItemAsync as jest.Mock).mockResolvedValue(undefined);

    const { result } = renderHook(() => useAuth(), { wrapper });
    await act(async () => {});

    await act(async () => {
      await result.current.logout();
    });

    expect(SecureStore.deleteItemAsync).toHaveBeenCalledWith('circleguard_anon_id');
    expect(SecureStore.deleteItemAsync).toHaveBeenCalledWith('circleguard_token');
    expect(result.current.anonymousId).toBeNull();
    expect(result.current.token).toBeNull();
  });

  // ── useAuth fuera de Provider ─────────────────────────────────────

  test('useAuth should throw when used outside AuthProvider', () => {
    // renderHook sin wrapper → contexto undefined → debe lanzar
    expect(() => {
      renderHook(() => useAuth());
    }).toThrow('useAuth must be used within an AuthProvider');
  });
});
