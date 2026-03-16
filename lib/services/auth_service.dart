import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firestore_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirestoreService _firestore = FirestoreService();
  bool _isInitialized = false;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      // For Android 14+ Credential Manager compatibility, we must provide the serverClientId (Web Client ID)
      await _googleSignIn.initialize(
        serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
        clientId: dotenv.env['GOOGLE_CLIENT_ID'],
      );
      _isInitialized = true;
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      await _ensureInitialized();

      // 1. Try Native Google Sign-In first (Premium Experience)
      try {
        final googleUser = await _googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        
        final credential = GoogleAuthProvider.credential(
          accessToken:
              (await googleUser.authorizationClient.authorizationForScopes([
                'email',
                'profile',
                'openid',
              ]))?.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
        notifyListeners();
        return null;
      } catch (e) {
        // Only ignore if it's the specific "No credentials" emulator issue
        // or if the user canceled (we'll handle cancel in the fallback too)
        final errorStr = e.toString();
        if (!errorStr.contains('No credentials available')) {
          rethrow; // Rethrow other errors to be handled normally
        }
        // If "No credentials available", we proceed to the browser fallback
      }

      // 2. Fallback to Browser-based Sign-In (Reliability for Emulators)
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      await _auth.signInWithProvider(googleProvider);

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled') return 'Sign in aborted by user.';
      return 'Firebase Auth Error: ${e.message}';
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('No credentials available')) {
        return 'Google Sign-In requires a synced account. Please check Emulator Settings -> Accounts and ensure sync is active, or "Wipe Data" on the emulator.';
      }
      return errorStr;
    }
  }

  Future<void> logout() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }

  Future<String?> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user is currently signed in.';

      // 1. Delete data from Firestore
      await _firestore.deleteUserAccountData(user.uid);

      // 2. Delete from Firebase Auth
      await user.delete();

      // 3. Cleanup local sign-in states
      await _ensureInitialized();
      await _googleSignIn.signOut();

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Please sign out and sign back in to delete your account for security reasons.';
      }
      return e.message ?? 'An error occurred during account deletion.';
    } catch (e) {
      return e.toString();
    }
  }
}
