import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_exception.dart';

/// Repository encapsulating Firebase Authentication operations.
class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  GoogleSignIn get _resolvedGoogleSignIn => GoogleSignIn();

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Unable to sign in. Please try again.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
        'Unexpected error during sign in. Please try again.',
      );
    }
  }

  Future<User> signInWithGoogle() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        credential = await _firebaseAuth.signInWithPopup(provider);
      } else {
        final googleSignIn = _resolvedGoogleSignIn;
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw const AuthException('Google sign-in was canceled.');
        }
        final googleAuth = await googleUser.authentication;
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await _firebaseAuth.signInWithCredential(oauthCredential);
      }

      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          'Unable to sign in with Google. Please try again.',
        );
      }

      try {
        final userDoc = _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid);
        final snap = await userDoc.get();
        if (!snap.exists) {
          final rawName = user.displayName?.trim() ?? '';
          final safeName = rawName.isEmpty
              ? 'Movie Fan'
              : (rawName.length > 40 ? rawName.substring(0, 40) : rawName);
          await userDoc.set({
            'displayName': safeName,
            'bio': '',
            'avatarKey': 'cinema',
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
        'Google sign-in was canceled or failed. Please try again.',
      );
    }
  }

  Future<User> registerWithEmail({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          'Unable to create account. Please try again.',
        );
      }
      final trimmedName = displayName.trim();
      if (trimmedName.isNotEmpty) {
        await user.updateDisplayName(trimmedName);
        await user.reload();
        try {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(user.uid)
              .set({
                'displayName': trimmedName,
                'bio': '',
                'avatarKey': 'cinema',
                'updatedAt': Timestamp.fromDate(DateTime.now()),
              }, SetOptions(merge: true));
        } catch (_) {}
        final reloaded = _firebaseAuth.currentUser ?? user;
        try {
          await reloaded.sendEmailVerification();
        } catch (_) {}
        return reloaded;
      }
      try {
        await user.sendEmailVerification();
      } catch (_) {}
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
        'Unexpected error during registration. Please try again.',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } catch (_) {
      throw const AuthException('Could not send password reset email.');
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthException('No signed-in user found.');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } catch (_) {
      throw const AuthException('Could not send verification email.');
    }
  }

  Future<User?> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
      return _firebaseAuth.currentUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } catch (_) {
      throw const AuthException('Could not refresh verification status.');
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _resolvedGoogleSignIn.signOut();
      } catch (_) {}
    }
    await _firebaseAuth.signOut();
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Console.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-canceled':
        return 'Google sign-in was canceled.';
      case 'popup-blocked':
        return 'Sign-in popup was blocked by your browser. Please allow popups and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
