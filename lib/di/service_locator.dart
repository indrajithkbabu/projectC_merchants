import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:project_c/services/catalog_direct_upload_service.dart';
import 'package:project_c/services/product_details_preferences.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/services/product_view_preferences.dart';
import 'package:project_c/services/screenshot_protection_service.dart';
import 'package:project_c/services/search_recent_preferences.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/storage/app_settings_storage.dart';
import 'package:project_c/storage/session_storage.dart';
import 'package:project_c/webservice/auth/auth_repository.dart';
import 'package:project_c/webservice/auth/auth_request.dart';
import 'package:project_c/webservice/catalog_api_client.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/collection/collection_request.dart';
import 'package:project_c/webservice/import/import_repository.dart';
import 'package:project_c/webservice/import/import_request.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';
import 'package:project_c/webservice/profile/profile_request.dart';
import 'package:project_c/webservice/search/search_repository.dart';
import 'package:project_c/webservice/search/search_request.dart';
import 'package:project_c/webservice/store/store_repository.dart';
import 'package:project_c/webservice/store/store_request.dart';

/// Application service locator. Call [configureDependencies] once at startup.
class ServiceLocator {
  ServiceLocator._();

  static final Injector injector = Injector();

  static bool _configured = false;

  static void configureDependencies() {
    if (_configured) return;
    _configured = true;

    final storage = SessionStorage();
    final appSettings = AppSettingsStorage();
    final screenshotProtection = ScreenshotProtectionService(
      storage: appSettings,
    );
    final productViewPreferences = ProductViewPreferences(
      storage: appSettings,
    );
    final productDetailsPreferences = ProductDetailsPreferences(
      storage: appSettings,
    );
    final searchRecentPreferences = SearchRecentPreferences(
      storage: appSettings,
    );
    final apiClient = CatalogApiClient(sessionStorage: storage);
    final session = CatalogSession(storage: storage, apiClient: apiClient);

    injector.map<SessionStorage>((_) => storage, isSingleton: true);
    injector.map<AppSettingsStorage>((_) => appSettings, isSingleton: true);
    injector.map<ScreenshotProtectionService>(
      (_) => screenshotProtection,
      isSingleton: true,
    );
    injector.map<ProductViewPreferences>(
      (_) => productViewPreferences,
      isSingleton: true,
    );
    injector.map<ProductDetailsPreferences>(
      (_) => productDetailsPreferences,
      isSingleton: true,
    );
    injector.map<SearchRecentPreferences>(
      (_) => searchRecentPreferences,
      isSingleton: true,
    );
    injector.map<CatalogApiClient>((_) => apiClient, isSingleton: true);
    injector.map<CatalogSession>((_) => session, isSingleton: true);

    injector.map<AuthRequest>(
      (i) => AuthRequest(apiClient: i.get<CatalogApiClient>()),
      isSingleton: true,
    );
    injector.map<AuthRepository>(
      (i) => AuthRepositoryImpl(
        request: i.get<AuthRequest>(),
        session: i.get<CatalogSession>(),
        apiClient: i.get<CatalogApiClient>(),
      ),
      isSingleton: true,
    );

    injector.map<ProfileRequest>(
      (i) => ProfileRequest(apiClient: i.get<CatalogApiClient>()),
      isSingleton: true,
    );
    injector.map<ProfileRepository>(
      (i) => ProfileRepositoryImpl(
        request: i.get<ProfileRequest>(),
        session: i.get<CatalogSession>(),
      ),
      isSingleton: true,
    );

    injector.map<StoreRequest>(
      (i) => StoreRequest(apiClient: i.get<CatalogApiClient>()),
      isSingleton: true,
    );
    injector.map<StoreRepository>(
      (i) => StoreRepositoryImpl(
        request: i.get<StoreRequest>(),
        session: i.get<CatalogSession>(),
      ),
      isSingleton: true,
    );

    injector.map<CollectionRequest>(
      (i) => CollectionRequest(apiClient: i.get<CatalogApiClient>()),
      isSingleton: true,
    );
    injector.map<CollectionRepository>(
      (i) => CollectionRepositoryImpl(request: i.get<CollectionRequest>()),
      isSingleton: true,
    );
    injector.map<CatalogDirectUploadService>(
      (i) => CatalogDirectUploadService(
        collectionRepository: i.get<CollectionRepository>(),
      ),
      isSingleton: true,
    );
    injector.map<ProductUploadCoordinator>(
      (i) => ProductUploadCoordinator(
        collectionRepository: i.get<CollectionRepository>(),
        directUploadService: i.get<CatalogDirectUploadService>(),
      ),
      isSingleton: true,
    );

    injector.map<ImportApiRequest>(
      (i) => ImportApiRequest(apiClient: i.get<CatalogApiClient>()),
      isSingleton: true,
    );
    injector.map<ImportRepository>(
      (i) => ImportRepositoryImpl(request: i.get<ImportApiRequest>()),
      isSingleton: true,
    );

    injector.map<SearchRequest>(
      (i) => SearchRequest(apiClient: i.get<CatalogApiClient>()),
      isSingleton: true,
    );
    injector.map<SearchRepository>(
      (i) => SearchRepositoryImpl(request: i.get<SearchRequest>()),
      isSingleton: true,
    );
  }

  static T get<T>() => injector.get<T>();
}
