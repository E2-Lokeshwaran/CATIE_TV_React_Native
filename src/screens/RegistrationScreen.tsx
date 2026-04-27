import React, {useState} from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Image,
} from 'react-native';
import {useAppStore} from '../store/appStore';
import {fetchCustomHomePage} from '../services/api/CustomHomePageApi';

/**
 * Registration screen.
 * Mirrors RegistrationViewController.swift.
 *
 * User enters:
 * - Domain (IP/DNS of CATIE server)
 * - Device Number (room number)
 *
 * On save: validates via customHomePage API, saves to MMKV on success.
 */
export function RegistrationScreen() {
  const {
    domainAddress,
    roomNumber,
    userId,
    isRegistered,
    setRegistration,
  } = useAppStore();

  const [domain, setDomain] = useState(domainAddress);
  const [room, setRoom] = useState(roomNumber);
  const [isLoading, setIsLoading] = useState(false);

  const isModifyMode = isRegistered && domainAddress.length > 0;

  const handleSave = async () => {
    if (!domain.trim() || !room.trim()) {
      Alert.alert('Error', 'Please enter both IP/DNS and Device Number');
      return;
    }

    setIsLoading(true);
    try {
      // Validate by calling customHomePage API - if it succeeds, registration is valid
      // Use room as userId initially (it will be updated after customHomePage response)
      const config = await fetchCustomHomePage(
        domain.trim(),
        room.trim(),
        room.trim()
      );

      if (config && config.tvStatus >= 1) {
        setRegistration(domain.trim(), room.trim(), room.trim());
      } else {
        Alert.alert(
          'Registration Failed',
          'Unable to connect to CATIE server. Please check your IP/DNS and Device Number.'
        );
      }
    } catch (e: any) {
      Alert.alert(
        'Connection Error',
        `Failed to reach server: ${e.message ?? 'Unknown error'}`
      );
    } finally {
      setIsLoading(false);
    }
  };

  const handleCancel = () => {
    // Reset to stored values
    setDomain(domainAddress);
    setRoom(roomNumber);
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
      <View style={styles.content}>
        {/* CATIE Logo */}
        <Text style={styles.logoText}>CATIE TV</Text>
        <Text style={styles.subtitle}>Digital Signage System</Text>

        <View style={styles.form}>
          <Text style={styles.label}>IP/DNS (Server URL)</Text>
          <TextInput
            style={styles.input}
            value={domain}
            onChangeText={setDomain}
            placeholder="e.g. catie.example.com"
            placeholderTextColor="#666"
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
          />

          <Text style={styles.label}>Device Number</Text>
          <TextInput
            style={styles.input}
            value={room}
            onChangeText={setRoom}
            placeholder="e.g. tv1_room101"
            placeholderTextColor="#666"
            autoCapitalize="none"
            autoCorrect={false}
          />

          <View style={styles.buttons}>
            <TouchableOpacity
              style={[styles.button, styles.saveButton, isLoading && styles.disabled]}
              onPress={handleSave}
              disabled={isLoading}>
              {isLoading ? (
                <ActivityIndicator color="#FFFFFF" />
              ) : (
                <Text style={styles.buttonText}>
                  {isModifyMode ? 'Modify' : 'Save'}
                </Text>
              )}
            </TouchableOpacity>

            {isModifyMode && (
              <TouchableOpacity
                style={[styles.button, styles.cancelButton]}
                onPress={handleCancel}>
                <Text style={styles.buttonText}>Cancel</Text>
              </TouchableOpacity>
            )}
          </View>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0A0A1A',
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
  },
  logoText: {
    fontSize: 48,
    fontWeight: 'bold',
    color: '#3773b3',
    marginBottom: 8,
    fontFamily: 'Poppins-Bold',
  },
  subtitle: {
    fontSize: 18,
    color: '#AAAAAA',
    marginBottom: 48,
    fontFamily: 'Poppins-Regular',
  },
  form: {
    width: '100%',
    maxWidth: 400,
  },
  label: {
    fontSize: 14,
    color: '#CCCCCC',
    marginBottom: 6,
    fontFamily: 'Poppins-Medium',
  },
  input: {
    backgroundColor: '#1A1A2E',
    borderWidth: 1,
    borderColor: '#333',
    borderRadius: 8,
    padding: 14,
    color: '#FFFFFF',
    fontSize: 16,
    marginBottom: 20,
    fontFamily: 'Poppins-Regular',
  },
  buttons: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 8,
  },
  button: {
    flex: 1,
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 52,
  },
  saveButton: {
    backgroundColor: '#3773b3',
  },
  cancelButton: {
    backgroundColor: '#444',
  },
  disabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Poppins-Bold',
  },
});
