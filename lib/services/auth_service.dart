import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();
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
      return e.message ?? 'An unknown error occurred.';
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

      // Proactive check for recent login (within last 5 minutes)
      // This prevents the "partial delete" scenario where Firestore/Cloudinary data is wiped 
      // but user.delete() fails later due to an old session.
      final lastSignIn = user.metadata.lastSignInTime;
      if (lastSignIn != null) {
        final difference = DateTime.now().difference(lastSignIn);
        if (difference.inMinutes > 5) {
          debugPrint('Proactive check: Session too old (${difference.inMinutes} mins).');
          return 'requires-recent-login';
        }
      }

      // 1. Delete data from Firestore and get associated video URLs
      final videoUrls = await _firestore.deleteUserAccountData(user.uid);

      // 2. Delete videos from Cloudinary
      for (final url in videoUrls) {
        try {
          await _storage.deleteVideo(url);
        } catch (e) {
          debugPrint('Error deleting video from Cloudinary: $e');
          // We continue anyway to ensure account deletion proceeds
        }
      }

      // 3. Delete user's Cloudinary folder (recursive force-delete)
      try {
        await _storage.deleteFolderRecursive('movie_tracker/users/${user.uid}');
      } catch (e) {
        debugPrint('Error deleting folder from Cloudinary: $e');
      }

      // 4. Delete from Firebase Auth
      await user.delete();

      // 5. Cleanup local sign-in states
      await _ensureInitialized();
      await _googleSignIn.signOut();

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during account deletion: ${e.code} - ${e.message}');
      if (e.code == 'requires-recent-login') {
        return 'requires-recent-login'; // Return code for SnackbarUtils to handle
      }
      return e.message ?? 'An error occurred during account deletion.';
    } catch (e) {
      debugPrint('Error during account deletion: $e');
      return e.toString();
    }
  }
}
