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

  // Email / password 

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

  
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (_) {
      
    }
  }


  Future<void> refreshIdToken() async {
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {
      
    }
  }

  //  Google 

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

  // Shared 

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
      final resolvedUsername = username ?? '';
      final usernameLower = resolvedUsername.isNotEmpty
          ? resolvedUsername.replaceFirst('@', '').toLowerCase()
          : '';

      await docRef.set({
        'id': user.uid,
        'name': name ?? user.displayName ?? 'New User',
        'username': resolvedUsername,

        'usernameLower': usernameLower,
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

  Future<bool> hasUsername(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final username = doc.data()?['username'] as String? ?? '';
      return username.isNotEmpty && username != '@';
    } catch (_) {
      return false;
    }
  }
}
