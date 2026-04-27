import React from 'react';
import {NavigationContainer} from '@react-navigation/native';
import {createNativeStackNavigator} from '@react-navigation/native-stack';
import {useAppStore} from '../store/appStore';
import {RegistrationScreen} from '../screens/RegistrationScreen';
import {HomeScreen} from '../screens/HomeScreen';

const Stack = createNativeStackNavigator();

/**
 * App navigation - mirrors UINavigationController flow.
 * Checks registration state to determine initial screen.
 * On detach WS event, isRegistered becomes false → navigator shows Registration.
 */
export function AppNavigator() {
  const {isRegistered} = useAppStore();

  return (
    <NavigationContainer>
      <Stack.Navigator
        screenOptions={{
          headerShown: false,
          animation: 'fade',
          contentStyle: {backgroundColor: '#000'},
        }}>
        {isRegistered ? (
          <Stack.Screen name="Home" component={HomeScreen} />
        ) : (
          <Stack.Screen name="Registration" component={RegistrationScreen} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
}
