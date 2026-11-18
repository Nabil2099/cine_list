import 'package:get_it/get_it.dart';

import '../../features/ai_chat/data/repositories/ai_chat_repository.dart';
import '../../features/ai_chat/presentation/cubit/ai_chat_cubit.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/community/data/repositories/community_repository.dart';
import '../../features/community/presentation/bloc/community_bloc.dart';
import '../../features/discover/data/datasources/tmdb_remote_data_source.dart';
import '../../features/discover/data/repositories/discover_repository.dart';
import '../../features/discover/presentation/bloc/discover_bloc.dart';
import '../../features/movie_details/data/repositories/movie_details_repository.dart';
import '../../features/movie_details/presentation/cubit/movie_details_cubit.dart';
import '../../features/watchlist/data/repositories/watchlist_repository.dart';
import '../../features/watchlist/presentation/cubit/watchlist_cubit.dart';
import '../network/dio_client.dart';
import '../storage/preferences_service.dart';

final GetIt sl = GetIt.instance;

/// Registers repositories, services, and Cubit factories with get_it.
Future<void> configureDependencies({
  required PreferencesService preferencesService,
}) async {
  if (sl.isRegistered<PreferencesService>()) return;

  sl.registerSingleton<PreferencesService>(preferencesService);

  // Networking
  sl.registerLazySingleton<DioClient>(() => DioClient());
  sl.registerLazySingleton<TmdbRemoteDataSource>(
    () => TmdbRemoteDataSource(sl<DioClient>()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  sl.registerLazySingleton<DiscoverRepository>(
    () => DiscoverRepository(sl<TmdbRemoteDataSource>()),
  );
  sl.registerLazySingleton<MovieDetailsRepository>(
    () => MovieDetailsRepository(sl<TmdbRemoteDataSource>()),
  );
  sl.registerLazySingleton<WatchlistRepository>(() => WatchlistRepository());
  sl.registerLazySingleton<AiChatRepository>(() => AiChatRepository());
  sl.registerLazySingleton<CommunityRepository>(() => CommunityRepository());

  // Cubits & BLoCs
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));
  sl.registerFactory<DiscoverBloc>(
    () => DiscoverBloc(
      sl<DiscoverRepository>(),
      preferencesService: sl<PreferencesService>(),
    ),
  );
  sl.registerFactory<MovieDetailsCubit>(
    () => MovieDetailsCubit(sl<MovieDetailsRepository>()),
  );
  sl.registerFactory<WatchlistCubit>(
    () => WatchlistCubit(sl<WatchlistRepository>()),
  );
  sl.registerFactory<AiChatCubit>(() => AiChatCubit(sl<AiChatRepository>()));
  sl.registerFactory<CommunityBloc>(
    () => CommunityBloc(sl<CommunityRepository>()),
  );
}
