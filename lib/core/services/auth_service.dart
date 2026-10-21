import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;
  bool get isAuthenticated => _auth.currentUser != null;
  bool get isGoogleUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;
  bool get isPasswordUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;
  String? get userEmail => _auth.currentUser?.email;
  String? get displayName => _auth.currentUser?.displayName;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in anonymously as a guest.
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// Ensures that there is an active authenticated user session.
  Future<User> ensureAuthenticated() async {
    final user = _auth.currentUser;
    if (user != null) return user;
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  /// Signs in with Email and Password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs up with Email and Password, linking anonymous data if previously signed in as guest.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cleanEmail = email.trim();
    final user = _auth.currentUser;

    UserCredential credential;
    if (user != null && user.isAnonymous) {
      // Link guest account to email so existing logs remain attached to this user!
      final authCredential = EmailAuthProvider.credential(
        email: cleanEmail,
        password: password,
      );
      try {
        credential = await user.linkWithCredential(authCredential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          credential = await _auth.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
        } else {
          rethrow;
        }
      }
    } else {
      credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    }

    if (displayName != null && displayName.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(displayName.trim());
    }

    // Automatically send verification email upon successful sign-up
    try {
      await credential.user?.sendEmailVerification();
    } catch (_) {
      // Non-blocking in case of rate-limit/network glitch; user can resend from verification screen
    }

    return credential;
  }

  /// Whether the currently signed-in user's email is verified.
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Sends or resends email verification link to the current user.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Reloads the current user session from Firebase and returns whether email is verified.
  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Signs in with Google, linking guest data if active.
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // The user canceled the sign-in flow
      return null;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        return await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          return await _auth.signInWithCredential(credential);
        } else {
          rethrow;
        }
      }
    }

    return await _auth.signInWithCredential(credential);
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Signs out completely.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Permanently deletes the current user account and purges user documents from Firestore.
  /// Complies with Apple App Store Guideline 5.1.1(v) & Google Play User Data Policy.
  /// Throws [FirebaseAuthException] with code 'requires-recent-login' if re-authentication is required.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // Defense-in-depth: Verify recent login BEFORE touching Firestore
    final lastSignIn = user.metadata.lastSignInTime;
    final isRecent = lastSignIn != null &&
        DateTime.now().difference(lastSignIn) < const Duration(minutes: 5);
    if (!user.isAnonymous && !isRecent) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message:
            'This sensitive operation requires recent authentication. Please re-authenticate before retrying.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(uid);

    final collections = [
      'notes',
      'tasks',
      'reminders',
      'books',
      'media',
      'learning_paths',
      'workspaces',
    ];

    // Purge subcollections in Firestore in chunks of 400 to respect batch limits
    for (final col in collections) {
      try {
        final snapshots = await userDoc.collection(col).get();
        final docs = snapshots.docs;
        for (var i = 0; i < docs.length; i += 400) {
          final batch = firestore.batch();
          final chunk = docs.skip(i).take(400);
          for (final doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      } catch (_) {
        // Continue best-effort cleanup of remaining collections
      }
    }

    // Delete user profile document
    try {
      await userDoc.delete();
    } catch (_) {}

    // Delete auth account
    await user.delete();

    // Sign out from Google if applicable
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Re-authenticates the current user using their password before sensitive operations like account deletion.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No active authenticated user with email found.');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Re-authenticates the current user using Google credentials before sensitive operations like account deletion.
  Future<void> reauthenticateWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'canceled',
        message: 'Google re-authentication was canceled.',
      );
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final user = _auth.currentUser;
    if (user != null) {
      await user.reauthenticateWithCredential(credential);
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserIdProvider = StreamProvider<String?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.map((user) => user?.uid);
});
