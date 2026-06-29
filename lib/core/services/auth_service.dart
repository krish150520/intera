import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isGoogleUser {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  bool get isVerified {
    final user = _auth.currentUser;
    if (user == null) return false;
    return isGoogleUser || user.emailVerified;
  }

  // ---------- Email / password ----------

  Future<UserCredential> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
  }

  Future<UserCredential> signUp({required String email, required String password}) {
    return _auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Re-fetches the user from Firebase so emailVerified reflects reality.
  /// Wrapped in try/catch so offline/network failures don't crash the splash
  /// screen — callers get the last-known cached state instead.
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (_) {
      // Ignore — stale cached state is fine as a fallback.
    }
  }

  /// Forces the Firebase ID token to refresh so Firestore security rules
  /// see the updated email_verified claim immediately after verification.
  /// Call this once right after reloadUser() confirms isVerified == true.
  Future<void> refreshIdToken() async {
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {
      // Non-fatal — token will refresh naturally on next request anyway.
    }
  }

  // ---------- Google ----------

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  // ---------- Shared ----------

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> ensureUserProfileExists(
    User user, {
    String? name,
    String? username,
    String? avatarUrl,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      // Resolve the username once so both the display field and the
      // lowercase search index field are always consistent with each other.
      final resolvedUsername = username ?? '@${(user.email ?? 'user').split('@')[0]}';

      await docRef.set({
        'id': user.uid,
        'name': name ?? user.displayName ?? 'New User',
        'username': resolvedUsername,
        // Stripped of '@' and lowercased — this is what search_screen.dart
        // queries against via orderBy('usernameLower').startAt([query]).
        'usernameLower': resolvedUsername.replaceFirst('@', '').toLowerCase(),
        'bio': 'Welcome to my INTERA workspace profile!',
        'avatarUrl': avatarUrl ?? user.photoURL ?? '',
        'karmaPoints': 100,
        'followersCount': 0,
        'followingCount': 0,
        'skills': [],
        'isAnonymous': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}