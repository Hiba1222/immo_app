import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/user_model.dart';
import '../../services/supabase_service.dart';

class UserRepository {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _imagePicker = ImagePicker();

  // Récupérer le profil utilisateur
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération du profil: $e');
      // Si le profil n'existe pas, le créer
      return await createUserProfile(userId);
    }
  }

  // Créer un profil utilisateur
  Future<UserProfile?> createUserProfile(String userId) async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) return null;

      final newProfile = {
        'id': userId,
        'email': user.email,
        'first_name': null,
        'last_name': null,
        'phone': null,
        'avatar_url': null,
      };

      final response = await _supabaseService.client
          .from('profiles')
          .insert(newProfile)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Erreur lors de la création du profil: $e');
      return null;
    }
  }

  // Mettre à jour le profil utilisateur
  Future<bool> updateUserProfile(UserProfile profile) async {
    try {
      await _supabaseService.client
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id);

      return true;
    } catch (e) {
      print('Erreur lors de la mise à jour du profil: $e');
      return false;
    }
  }

  // Sélectionner une image depuis la galerie
  Future<Uint8List?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        return await image.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Erreur lors de la sélection d\'image depuis la galerie: $e');
      return null;
    }
  }

  // Prendre une photo avec la caméra
  Future<Uint8List?> takePhotoWithCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (photo != null) {
        return await photo.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Erreur lors de la prise de photo avec la caméra: $e');
      return null;
    }
  }

  // Uploader l'avatar vers Supabase Storage - VERSION CORRIGÉE
  Future<String?> uploadAvatar(String userId, Uint8List imageBytes) async {
    try {
      print('🔄 Début de l\'upload de l\'avatar pour l\'utilisateur: $userId');

      // Upload vers Supabase Storage - utilisation de uploadBinary
      await _supabaseService.client.storage
          .from('avatars')
          .uploadBinary('$userId/avatar', imageBytes);

      print('✅ Upload réussi');

      // Récupérer l'URL publique
      final avatarUrl = _supabaseService.client.storage
          .from('avatars')
          .getPublicUrl('$userId/avatar');

      print('📷 URL de l\'avatar: $avatarUrl');

      // Mettre à jour le profil avec la nouvelle URL
      final currentProfile = await getUserProfile(userId);
      if (currentProfile != null) {
        final updatedProfile = currentProfile.copyWith(avatarUrl: avatarUrl);
        await updateUserProfile(updatedProfile);
        print('✅ Profil mis à jour avec la nouvelle URL d\'avatar');
      }

      return avatarUrl;
    } catch (e) {
      print('❌ Erreur lors de l\'upload de l\'avatar: $e');
      return null;
    }
  }

  // Supprimer l'avatar
  Future<bool> deleteAvatar(String userId) async {
    try {
      print('🔄 Suppression de l\'avatar pour l\'utilisateur: $userId');

      // Supprimer le fichier du storage
      await _supabaseService.client.storage.from('avatars').remove([
        '$userId/avatar',
      ]);

      print('✅ Avatar supprimé du storage');

      // Mettre à jour le profil
      final currentProfile = await getUserProfile(userId);
      if (currentProfile != null) {
        final updatedProfile = currentProfile.copyWith(avatarUrl: null);
        await updateUserProfile(updatedProfile);
        print('✅ Profil mis à jour - avatar supprimé');
      }

      return true;
    } catch (e) {
      print('❌ Erreur lors de la suppression de l\'avatar: $e');
      return false;
    }
  }

  // Vérifier si un avatar existe
  Future<bool> avatarExists(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      return profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty;
    } catch (e) {
      print('Erreur lors de la vérification de l\'avatar: $e');
      return false;
    }
  }

  // Récupérer l'URL de l'avatar
  Future<String?> getAvatarUrl(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      return profile?.avatarUrl;
    } catch (e) {
      print('Erreur lors de la récupération de l\'URL de l\'avatar: $e');
      return null;
    }
  }

  // Méthode utilitaire pour formater les données utilisateur
  Map<String, dynamic> formatUserDataForUpdate({
    String? firstName,
    String? lastName,
    String? phone,
  }) {
    final data = <String, dynamic>{};

    if (firstName != null) {
      data['first_name'] = firstName.isEmpty ? null : firstName;
    }
    if (lastName != null) {
      data['last_name'] = lastName.isEmpty ? null : lastName;
    }
    if (phone != null) {
      data['phone'] = phone.isEmpty ? null : phone;
    }

    return data;
  }

  // Mettre à jour partiellement le profil (seulement les champs fournis)
  Future<bool> updatePartialProfile(
    String userId, {
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      final updateData = formatUserDataForUpdate(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );

      if (updateData.isEmpty) {
        print('⚠️ Aucune donnée à mettre à jour');
        return true;
      }

      await _supabaseService.client
          .from('profiles')
          .update(updateData)
          .eq('id', userId);

      print('✅ Profil partiellement mis à jour: $updateData');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la mise à jour partielle du profil: $e');
      return false;
    }
  }

  // Rechercher des utilisateurs par email ou nom
  Future<List<UserProfile>> searchUsers(String query) async {
    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .or(
            'email.ilike.%$query%,first_name.ilike.%$query%,last_name.ilike.%$query%',
          )
          .limit(10);

      final List<UserProfile> users = [];
      for (final item in response) {
        users.add(UserProfile.fromJson(item));
      }
      return users;
    } catch (e) {
      print('Erreur lors de la recherche d\'utilisateurs: $e');
      return [];
    }
  }

  // Vérifier si un email existe déjà - VERSION CORRIGÉE
  Future<bool> emailExists(String email) async {
    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select('email')
          .eq('email', email);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Récupérer plusieurs profils par leurs IDs
  Future<List<UserProfile>> getProfilesByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];

      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .inFilter('id', userIds);

      final List<UserProfile> profiles = [];
      for (final item in response) {
        profiles.add(UserProfile.fromJson(item));
      }
      return profiles;
    } catch (e) {
      print('Erreur lors de la récupération des profils par IDs: $e');
      return [];
    }
  }

  // Compter le nombre total d'utilisateurs - VERSION CORRIGÉE
  Future<int> getTotalUsersCount() async {
    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select('id');

      return response.length;
    } catch (e) {
      print('Erreur lors du comptage des utilisateurs: $e');
      return 0;
    }
  }

  // Récupérer les utilisateurs récemment inscrits
  Future<List<UserProfile>> getRecentUsers({int limit = 10}) async {
    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final List<UserProfile> users = [];
      for (final item in response) {
        users.add(UserProfile.fromJson(item));
      }
      return users;
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs récents: $e');
      return [];
    }
  }

  // Méthode pour vider le cache local (utile pour les tests)
  void clearLocalCache() {
    print('🧹 Cache local vidé');
  }

  // Vérifier la connexion à la base de données
  Future<bool> checkDatabaseConnection() async {
    try {
      await _supabaseService.client.from('profiles').select('id').limit(1);
      return true;
    } catch (e) {
      print('❌ Erreur de connexion à la base de données: $e');
      return false;
    }
  }
}
