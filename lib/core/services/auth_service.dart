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

  /// True if the account is a Google account — Google already verified
  /// ownership of the email, so we don't need our own verification step.
  bool get isGoogleUser {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  /// True if the user is allowed past the "verify your email" gate.
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

  /// Re-fetches the user from Firebase so emailVerified reflects reality
  /// (it's a snapshot value, so it won't update on its own).
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // ---------- Google ----------

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // User backed out of the Google account picker.
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
      await docRef.set({
        'id': user.uid,
        'name': name ?? user.displayName ?? 'New User',
        'username': username ?? '@${(user.email ?? 'user').split('@')[0]}',
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