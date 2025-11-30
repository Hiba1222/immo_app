import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../data/models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/supabase_service.dart';

class EditProfilePage extends HookConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final supabaseService = SupabaseService();
    final currentUser = supabaseService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil',style: TextStyle(fontWeight: FontWeight.bold,),),
        backgroundColor: Colors.blue,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: userProfileAsync.when(
        loading: () => const _EditProfileLoading(),
        error: (error, stack) => _EditProfileError(
          error: error,
          onRetry: () => ref.refresh(userProfileProvider),
        ),
        data: (userProfile) {
          return _EditProfileForm(
            userProfile: userProfile,
            currentUser: currentUser,
          );
        },
      ),
    );
  }
}

class _EditProfileForm extends HookConsumerWidget {
  final UserProfile? userProfile;
  final User? currentUser;

  const _EditProfileForm({
    required this.userProfile,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstNameController = useTextEditingController();
    final lastNameController = useTextEditingController();
    final phoneController = useTextEditingController();
    
    final isLoading = useState(false);
    final hasChanges = useState(false);
    final localProfile = useState<UserProfile?>(userProfile);
    final selectedImage = useState<File?>(null); // CORRECT: File? pas Uint8List

    // Initialiser les contrôleurs avec les données existantes
    useEffect(() {
      if (userProfile != null) {
        firstNameController.text = userProfile!.firstName ?? '';
        lastNameController.text = userProfile!.lastName ?? '';
        phoneController.text = userProfile!.phone ?? '';
        localProfile.value = userProfile;
      }
      return null;
    }, [userProfile]);

    // Vérifier les changements
    useEffect(() {
      if (userProfile != null && localProfile.value != null) {
        final hasFirstNameChanged = firstNameController.text != (userProfile?.firstName ?? '');
        final hasLastNameChanged = lastNameController.text != (userProfile?.lastName ?? '');
        final hasPhoneChanged = phoneController.text != (userProfile?.phone ?? '');
        final hasAvatarChanged = selectedImage.value != null;
        
        hasChanges.value = hasFirstNameChanged || hasLastNameChanged || hasPhoneChanged || hasAvatarChanged;
      }
      return null;
    }, [firstNameController.text, lastNameController.text, phoneController.text, selectedImage.value]);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // En-tête avec avatar
              _buildAvatarSection(context, ref, localProfile.value, selectedImage),
              const SizedBox(height: 32),

              // Informations du profil
              _buildProfileForm(
                context,
                firstNameController,
                lastNameController,
                phoneController,
                currentUser?.email ?? '',
                localProfile,
              ),
              
              // Boutons
              const SizedBox(height: 32),
              _buildActionButtons(
                context,
                ref,
                localProfile.value,
                selectedImage.value,
                isLoading,
                hasChanges.value,
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),

        // Overlay de chargement
        if (isLoading.value)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Sauvegarde en cours...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarSection(
    BuildContext context, 
    WidgetRef ref, 
    UserProfile? userProfile, 
    ValueNotifier<File?> selectedImage
  ) {
    return Column(
      children: [
        // Avatar avec effet de bordure
        GestureDetector(
          onTap: () => _showAvatarOptions(context, ref, selectedImage),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 3,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade100,
                  Colors.blue.shade50,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Image sélectionnée ou image existante
                if (selectedImage.value != null)
                  ClipOval(
                    child: Image.file(
                      selectedImage.value!,
                      width: 114,
                      height: 114,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (userProfile?.avatarUrl != null)
                  ClipOval(
                    child: Image.network(
                      userProfile!.avatarUrl!,
                      width: 114,
                      height: 114,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.blue,
                        );
                      },
                    ),
                  )
                else
                  const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.blue,
                  ),
                
                // Badge de modification
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Bouton modifier la photo
        TextButton.icon(
          onPressed: () => _showAvatarOptions(context, ref, selectedImage),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Modifier la photo'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm(
    BuildContext context,
    TextEditingController firstNameController,
    TextEditingController lastNameController,
    TextEditingController phoneController,
    String email,
    ValueNotifier<UserProfile?> localProfile,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // En-tête de la section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Informations personnelles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            
            // Liste des champs
            Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                children: [
                  _buildEditableInfoItem(
                    controller: firstNameController,
                    icon: Icons.person,
                    label: 'Prénom',
                    hint: 'Entrez votre prénom',
                    onChanged: (value) {
                      _updateLocalProfile(localProfile, firstName: value);
                    },
                  ),
                  _buildEditableInfoItem(
                    controller: lastNameController,
                    icon: Icons.person_outline,
                    label: 'Nom',
                    hint: 'Entrez votre nom',
                    onChanged: (value) {
                      _updateLocalProfile(localProfile, lastName: value);
                    },
                  ),
                  _buildEditableInfoItem(
                    controller: phoneController,
                    icon: Icons.phone,
                    label: 'Téléphone',
                    hint: 'Entrez votre numéro',
                    keyboardType: TextInputType.phone,
                    onChanged: (value) {
                      _updateLocalProfile(localProfile, phone: value);
                    },
                  ),
                  _buildReadOnlyInfoItem(
                    icon: Icons.email,
                    label: 'Email',
                    value: email,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableInfoItem({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: keyboardType,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.grey,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
    File? selectedImage,
    ValueNotifier<bool> isLoading,
    bool hasChanges,
  ) {
    return Column(
      children: [
        // Bouton sauvegarder
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: hasChanges 
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.blue.shade500,
                      Colors.blue.shade600,
                    ],
                  )
                : null,
            color: hasChanges ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(16),
            boxShadow: hasChanges 
                ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: (!hasChanges || isLoading.value || profile == null)
                ? null
                : () async {
                    await _saveProfile(context, ref, profile, selectedImage, isLoading);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: isLoading.value
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save, size: 20, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        hasChanges ? 'Sauvegarder' : 'Aucune modification',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Bouton annuler
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Text(
              'Annuler',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _updateLocalProfile(
    ValueNotifier<UserProfile?> localProfile, {
    String? firstName,
    String? lastName,
    String? phone,
  }) {
    if (localProfile.value != null) {
      final updatedProfile = localProfile.value!.copyWith(
        firstName: firstName?.isNotEmpty == true ? firstName : null,
        lastName: lastName?.isNotEmpty == true ? lastName : null,
        phone: phone?.isNotEmpty == true ? phone : null,
      );
      
      localProfile.value = updatedProfile;
    }
  }

  Future<void> _saveProfile(
  BuildContext context,
  WidgetRef ref,
  UserProfile profile,
  File? selectedImage,
  ValueNotifier<bool> isLoading,
) async {
  isLoading.value = true;
  
  try {
    final supabase = Supabase.instance.client;
    final user = SupabaseService().currentUser;
    
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    String? avatarUrl = profile.avatarUrl;

    // Upload de l'image si une nouvelle image est sélectionnée
    if (selectedImage != null) {
      // Organiser par dossiers utilisateur pour respecter RLS
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      try {
        // Upload vers Supabase Storage
        await supabase.storage
            .from('avatars')
            .upload(fileName, selectedImage, fileOptions: FileOptions(upsert: true));

        // Récupérer l'URL publique
        final publicUrl = supabase.storage
            .from('avatars')
            .getPublicUrl(fileName);

        avatarUrl = publicUrl;
        print('✅ Avatar uploaded successfully: $avatarUrl');
      } catch (uploadError) {
        print('❌ Upload error: $uploadError');
        throw uploadError;
      }
    }

    // Mettre à jour le profil dans la table profiles
    final response = await supabase
        .from('profiles')
        .upsert({
          'id': user.id,
          'email': user.email,
          'first_name': profile.firstName,
          'last_name': profile.lastName,
          'phone': profile.phone,
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select();

    if (response.isNotEmpty) {
      // Rafraîchir les données
      ref.refresh(userProfileProvider);
      
      // Retour à la page précédente
      if (context.mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackbar(context, 'Profil mis à jour avec succès !');
      }
    } else {
      throw Exception('Échec de la mise à jour du profil');
    }
  } catch (e) {
    print('Erreur lors de la sauvegarde: $e');
    if (context.mounted) {
      _showErrorSnackbar(context, 'Erreur: ${e.toString()}');
    }
  } finally {
    isLoading.value = false;
  }
}

  void _showAvatarOptions(BuildContext context, WidgetRef ref, ValueNotifier<File?> selectedImage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Changer la photo de profil',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildAvatarOption(
                  context,
                  icon: Icons.photo_library,
                  title: 'Choisir depuis la galerie',
                  color: Colors.blue,
                  onTap: () => _pickImageFromGallery(context, selectedImage),
                ),
                _buildAvatarOption(
                  context,
                  icon: Icons.photo_camera,
                  title: 'Prendre une photo',
                  color: Colors.green,
                  onTap: () => _takePhotoWithCamera(context, selectedImage),
                ),
                if (userProfile?.avatarUrl != null || selectedImage.value != null)
                  _buildAvatarOption(
                    context,
                    icon: Icons.delete,
                    title: 'Supprimer la photo',
                    color: Colors.red,
                    onTap: () => _deleteAvatar(context, ref, selectedImage),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600)
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _pickImageFromGallery(BuildContext context, ValueNotifier<File?> selectedImage) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        selectedImage.value = File(image.path); // CORRECT: File from XFile
        _showSuccessSnackbar(context, 'Photo sélectionnée');
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Erreur: ${e.toString()}');
    }
  }

  Future<void> _takePhotoWithCamera(BuildContext context, ValueNotifier<File?> selectedImage) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        selectedImage.value = File(image.path); // CORRECT: File from XFile
        _showSuccessSnackbar(context, 'Photo prise');
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Erreur: ${e.toString()}');
    }
  }

  Future<void> _deleteAvatar(BuildContext context, WidgetRef ref, ValueNotifier<File?> selectedImage) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer la photo'),
          content: const Text('Êtes-vous sûr de vouloir supprimer votre photo de profil ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                selectedImage.value = null;
                _showSuccessSnackbar(context, 'Photo supprimée');
              },
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ... (les classes _EditProfileLoading et _EditProfileError restent les mêmes)

// === WIDGETS DE CHARGEMENT ET D'ERREUR ===

class _EditProfileLoading extends StatelessWidget {
  const _EditProfileLoading();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Squelette de l'en-tête
          Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade300,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 150,
                height: 16,
                color: Colors.grey.shade200,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Squelette du formulaire
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 150,
                          height: 16,
                          color: Colors.grey.shade300,
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(4, (index) => _buildInfoSkeleton(
                    isLast: index == 3,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSkeleton({bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast 
              ? BorderSide.none 
              : BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
        ),
      ),
      child: const ListTile(
        leading: CircleAvatar(backgroundColor: Colors.grey),
        title: SizedBox(
          height: 16,
          child: ColoredBox(color: Colors.grey),
        ),
        subtitle: SizedBox(
          height: 14,
          child: ColoredBox(color: Colors.grey),
        ),
      ),
    );
  }
}

class _EditProfileError extends StatelessWidget {
  final dynamic error;
  final VoidCallback onRetry;

  const _EditProfileError({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}