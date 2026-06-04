import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/style_profile.dart';

class StyleProfilesRepository {
  final Ref ref;
  StyleProfilesRepository(this.ref);

  Future<List<StyleProfile>> fetchProfiles() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/style-profiles');
    final list = response.data['data'] as List;
    return list
        .map((json) => StyleProfile.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<StyleProfile> fetchProfile(int id) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/style-profiles/$id');
    return StyleProfile.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> createProfile(StyleProfile profile) async {
    final client = ref.read(apiClientProvider);
    await client.post('/style-profiles', data: profile.toJson());
  }

  Future<void> updateProfile(int id, StyleProfile profile) async {
    final client = ref.read(apiClientProvider);
    await client.put('/style-profiles/$id', data: profile.toJson());
  }

  Future<void> deleteProfile(int id) async {
    final client = ref.read(apiClientProvider);
    await client.delete('/style-profiles/$id');
  }
}

final styleProfilesRepositoryProvider =
    Provider<StyleProfilesRepository>((ref) => StyleProfilesRepository(ref));
final styleProfilesNotifierProvider = FutureProvider<List<StyleProfile>>(
    (ref) => ref.read(styleProfilesRepositoryProvider).fetchProfiles());
final styleProfileDetailProvider = FutureProvider.family<StyleProfile, int>(
    (ref, id) => ref.read(styleProfilesRepositoryProvider).fetchProfile(id));
final styleProfilesListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profiles = await ref.watch(styleProfilesNotifierProvider.future);
  return profiles.map((profile) => profile.toJson()).toList();
});
