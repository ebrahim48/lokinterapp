# QA Flutter App Template

A production-grade Flutter food delivery application demonstrating **offline-first architecture**, **clean code patterns**, and **real-world API integration**. Use this project as a learning resource or as a **template** to kick-start your own Flutter app.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Screenshots & UI Flow](#screenshots--ui-flow)
- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Data Flow](#data-flow)
- [Core Services](#core-services)
  - [ApiService](#1-apiservice)
  - [CacheService](#2-cacheservice)
  - [ConnectivityService](#3-connectivityservice)
  - [StorageService](#4-storageservice)
- [Navigation System](#navigation-system)
  - [AppRoutes](#approutes)
  - [AppPages & Bindings](#apppages--bindings)
  - [Activating Named Routing](#activating-named-routing)
  - [Navigation Examples](#navigation-examples)
- [Dependency Injection](#dependency-injection)
- [Exception Handling](#exception-handling)
- [Feature: Home](#feature-home)
  - [Data Models](#data-models)
  - [Repository Layer](#repository-layer)
  - [Service Layer (Domain)](#service-layer-domain)
  - [Controller (Presentation)](#controller-presentation)
  - [Widgets](#widgets)
- [API Reference](#api-reference)
- [Using This Project as a Template](#using-this-project-as-a-template)
- [Dependencies](#dependencies)
- [Platform Configuration](#platform-configuration)
- [Troubleshooting](#troubleshooting)
- [Future Enhancements](#future-enhancements)

---

## Quick Start

### Prerequisites

- Flutter SDK **3.9.0** or higher
- Dart SDK (comes with Flutter)
- Android Studio / VS Code / Xcode
- A physical device or emulator

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/sparktechagency/QA-Flutter-Template.git

# 2. Navigate to project directory
cd QA-Flutter-Template

# 3. Install dependencies
flutter pub get

# 4. Run the app
flutter run
```

### Verify Everything Works

```bash
# Check for issues
flutter analyze

# Run on a specific device
flutter run -d ios      # iOS simulator
flutter run -d android  # Android emulator
flutter run -d chrome   # Web (if supported)
```

---

## Screenshots & UI Flow

```
+-------------------------------------------+
|  [Home Icon] 76A eight avenue, New York  [Bell]  <-- HomeAppBar (slides out on scroll)
+-------------------------------------------+
|  [Search food or restaurant here...   Q]  <-- SearchBarWidget (becomes sticky on scroll)
+-------------------------------------------+
|  +-------+  +-------+  +-------+         |
|  | Banner|  | Banner|  | Banner|         |  <-- BannerCarousel (auto-play, infinite)
|  +-------+  +-------+  +-------+         |
|         o  o  (o)  o  o                   |  <-- Page indicators
+-------------------------------------------+
|  Categories                    View All > |  <-- SectionHeader
|  [Cat1] [Cat2] [Cat3] [Cat4] ...         |  <-- CategoryItem (horizontal scroll)
+-------------------------------------------+
|  Popular Food Nearby           View All > |
|  +--------+ +--------+ +--------+        |
|  |  img   | |  img   | |  img   |        |
|  | Name   | | Name   | | Name   |        |  <-- FoodCard (horizontal scroll)
|  | $12.99 | | $8.50  | | $15.00 |        |
|  +--------+ +--------+ +--------+        |
+-------------------------------------------+
|  Food Campaign                 View All > |
|  +-------------------+ +----------------+|
|  | [img] Name        | | [img] Name     ||  <-- FoodCampaign (horizontal scroll)
|  |       Restaurant  | |      Restaurant||
|  |       **** $12.99 | |      *** $8.50 ||
|  +-------------------+ +----------------+|
+-------------------------------------------+
|  Restaurants                              |
|  [logo]  Restaurant Name         *** 4.5 |  <-- RestaurantCard (vertical, paginated)
|  [logo]  Restaurant Name         **** 4.8|
|  [logo]  Restaurant Name         ** 3.2  |
|  ...                                      |
|  [Loading more...]                        |  <-- Infinite scroll pagination
+-------------------------------------------+
```

### State Transitions

```
App Launch
    |
    v
+----------+     Has Cache?     +-----------+
| initial  | ----Yes----------> |  loaded   |  (show cached data immediately)
+----------+     |               +-----------+
    |            No                  |
    v            |                   v
+----------+    |            Fetch fresh data
| loading  | <--+            in background
| (shimmer)|                     |
+----------+               Success? --> Update UI
    |                           |
    v                       Fail + Has Cache? --> Keep showing cache
Fetch data                      |
    |                       Fail + No Cache?
    +--Success--> loaded            |
    |                               v
    +--No Internet--> offline  +---------+
    |                          | error   |
    +--Server Error--> error   | (retry) |
                               +---------+
```

---

## Architecture Overview

This project follows **Clean Architecture** with a **Repository Pattern** and uses **GetX** for state management and dependency injection.

### Layer Diagram

```
+------------------------------------------------------------------+
|                     PRESENTATION LAYER                            |
|  +--------------------+    +----------------------------------+  |
|  |  HomeController    |    |  Widgets                         |  |
|  |  (GetxController)  |    |  - HomePage, HomeContent         |  |
|  |  - State (Rx)      |    |  - FoodCard, RestaurantCard      |  |
|  |  - UI Logic        |    |  - BannerCarousel, CategoryItem  |  |
|  +--------+-----------+    +----------------+-----------------+  |
|           |                                 |                    |
|           | uses                            | observes (Obx)     |
+-----------|------- -------------------------+--------------------+
            |
+-----------v--------------------------------------------------+
|                      DOMAIN LAYER                            |
|  +--------------------+                                      |
|  |  HomeService       |  Business logic:                     |
|  |  - fetchAllHomeData|  - Connectivity check before fetch   |
|  |  - getCachedData   |  - Parallel API calls                |
|  |  - hasOfflineData  |  - Cache fallback decisions          |
|  +--------+-----------+                                      |
|           |                                                  |
+-----------|--------------------------------------------------+
            |
+-----------v--------------------------------------------------+
|                       DATA LAYER                             |
|  +--------------------+    +-----------------------------+   |
|  |  HomeRepository    |    |  Models                     |   |
|  |  - getBanners()    |    |  - BannerModel              |   |
|  |  - getCategories() |    |  - CategoryModel            |   |
|  |  - getPopularFoods |    |  - ProductModel             |   |
|  |  - getRestaurants  |    |  - RestaurantModel          |   |
|  |  - getCached*()    |    |  - RestaurantsResponse      |   |
|  +--------+-----------+    +-----------------------------+   |
|           |                                                  |
+-----------|--------------------------------------------------+
            |
+-----------v--------------------------------------------------+
|                    CORE / INFRASTRUCTURE                     |
|  +-------------+  +---------------+  +-------------------+  |
|  | ApiService  |  | CacheService  |  |ConnectivityService|  |
|  | (Dio HTTP)  |  | (Hive local)  |  |(connectivity_plus)|  |
|  +-------------+  +---------------+  +-------------------+  |
|                                                              |
|  +--------------------+  +--------------------+              |
|  | AppExceptions      |  | ApiConstants       |              |
|  | (typed errors)     |  | (endpoints, keys)  |              |
|  +--------------------+  +--------------------+              |
+--------------------------------------------------------------+
```

### Design Patterns Used

| Pattern | Where | Purpose |
|---------|-------|---------|
| **Singleton** | ApiService, CacheService, ConnectivityService | Single instance across app |
| **Repository** | HomeRepository | Abstract data source (API + Cache) |
| **Service Layer** | HomeService | Business logic separate from data access |
| **Observer** | GetX Rx/Obx | Reactive UI updates |
| **Factory** | Model.fromJson() | Object creation from JSON |
| **Dependency Injection** | DependencyInjection class | Loose coupling via GetX |

---

## Project Structure

```
lib/
├── main.dart                              # Entry point: init services, run app
├── app.dart                               # MaterialApp config, theme, ScreenUtil
│
├── core/                                  # Shared infrastructure
│   ├── constants/
│   │   ├── api_constants.dart             # Base URL, endpoints, headers, cache keys
│   │   └── app_strings.dart               # All user-facing strings
│   ├── di/
│   │   └── dependency_injection.dart      # GetX service registration
│   ├── exceptions/
│   │   └── app_exceptions.dart            # Typed exception hierarchy
│   ├── services/
│   │   ├── api_service.dart               # Dio HTTP client (GET/POST/PUT/PATCH/DELETE/Upload)
│   │   ├── cache_service.dart             # Hive local storage wrapper
│   │   └── connectivity_service.dart      # Network status monitoring
│   └── utils/
│       └── app_colors.dart                # Color palette constants
│
└── features/                              # Feature modules
    └── home/
        ├── data/
        │   ├── models/                    # JSON-serializable data classes
        │   │   ├── banner_model.dart
        │   │   ├── category_model.dart
        │   │   ├── product_model.dart
        │   │   └── restaurant_model.dart
        │   └── repositories/
        │       └── home_repository.dart   # API calls + caching logic
        ├── domain/
        │   └── services/
        │       └── home_service.dart      # Business logic + HomeData DTO
        └── presentation/
            ├── controllers/
            │   └── home_controller.dart   # GetX controller (state + scroll + pagination)
            ├── home_page.dart             # Main screen scaffold
            └── widgets/                   # UI components
                ├── banner_carousel.dart
                ├── category_item.dart
                ├── diagonal_strikethrough_painter.dart
                ├── food_campaign.dart
                ├── food_card.dart
                ├── half_clipper.dart
                ├── home_app_bar.dart
                ├── home_content.dart
                ├── price_display_widget.dart
                ├── product_image_with_badge.dart
                ├── restaurant_card.dart
                ├── retry_widget.dart
                ├── search_bar_widget.dart
                ├── section_header.dart
                ├── shimmer_widgets.dart
                └── star_rating_widget.dart
```

---

## Data Flow

### Startup Sequence

```
main()
  |
  +--> WidgetsFlutterBinding.ensureInitialized()
  +--> CacheService().init()              // Open Hive box
  +--> DependencyInjection.init()         // Register all services
  +--> GoogleFonts pre-cache             // Pre-load Roboto font
  +--> Set orientation (portrait only)
  +--> Set status bar style (transparent)
  +--> runApp(MyApp())
         |
         +--> ScreenUtilInit(375x812)     // Responsive sizing
         +--> GetMaterialApp              // GetX navigation + theme
         +--> HomePage                    // Initial screen
```

### Data Loading Flow

```
HomeController.onInit()
        |
        v
    loadData()
        |
        +-- Check: hasCache?
        |       |
        |      YES --> _loadFromCache() --> setState(loaded)
        |       |                               |
        |      NO  --> setState(loading)        |
        |                                       |
        +-- Check: isOnline?                    |
                |                               |
               YES --> HomeService.fetchAllHomeData()
                |          |
                |          +--> Future.wait([     <-- All 5 calls run in PARALLEL
                |          |      getBanners(),
                |          |      getCategories(),
                |          |      getPopularFoods(),
                |          |      getFoodCampaigns(),
                |          |      getRestaurants(0, 10)
                |          |    ])
                |          |
                |          +--> Each repo method:
                |                 1. Call API via ApiService
                |                 2. Parse JSON -> Model
                |                 3. Cache via CacheService
                |                 4. Return models
                |                 (on error: return cached data)
                |
                +--> _loadFromCache()  --> setState(loaded)
                |
               NO --> hasCache?
                       YES --> setState(loaded)  (show stale data)
                       NO  --> setState(offline) (show retry UI)
```

### Pagination Flow (Restaurants)

```
User scrolls near bottom (within 200px of maxScrollExtent)
        |
        v
_onScroll() detects near-end
        |
        v
loadMoreRestaurants()
        |
        +-- _currentPage++
        +-- homeService.fetchMoreRestaurants(offset, limit)
        |       |
        |       +--> repository.fetchMoreRestaurants()
        |               |
        |               +--> API call for next page
        |               +--> Append new items to cache
        |               +--> Return new items
        |
        +-- _restaurants.addAll(newItems)  --> UI auto-updates via Obx
        |
        +-- On error: _currentPage-- (rollback), show Snackbar
```

### Connectivity Recovery Flow

```
ConnectivityService emits: isConnected = true
        |
        v
HomeController._listenToConnectivity()
        |
        +-- Skip first event (avoids duplicate initial load)
        +-- If reconnected AND hasCache:
                |
                v
            loadData(forceRefresh: true)
                |
                +--> Fetch fresh data from API
                +--> Update cache
                +--> Update UI seamlessly
```

---

## Core Services

### 1. ApiService

**File:** `lib/core/services/api_service.dart`

A singleton HTTP client built on [Dio](https://pub.dev/packages/dio) with automatic error mapping.

#### How It Works

```
Your Code --> ApiService.get/post/... --> Dio --> Server
                                          |
                                     DioException?
                                          |
                                     _handleDioError()
                                          |
                                     Typed AppException
                                     (TimeoutException,
                                      NoInternetException,
                                      ServerException, etc.)
```

#### Initialization

```dart
// Option 1: Direct singleton access
final apiService = ApiService();

// Option 2: Via GetX dependency injection (recommended)
final apiService = Get.find<ApiService>();

// Option 3: Injected into a repository/service class
class MyRepository {
  final ApiService _apiService;
  MyRepository({required ApiService apiService}) : _apiService = apiService;
}
```

#### GET Requests

```dart
// --- Basic GET ---
Future<List<User>> fetchUsers() async {
  try {
    final response = await _apiService.get('/api/users');
    final users = (response.data as List)
        .map((json) => User.fromJson(json))
        .toList();
    return users;
  } on NoInternetException {
    print('No internet - show offline UI');
    return [];
  } on ServerException catch (e) {
    print('Server error ${e.statusCode}: ${e.message}');
    return [];
  }
}

// --- GET with Query Parameters ---
Future<List<Product>> searchProducts(String query, {int page = 1}) async {
  final response = await _apiService.get(
    '/api/products',
    queryParameters: {
      'search': query,
      'page': page,
      'limit': 20,
    },
  );
  return (response.data['products'] as List)
      .map((json) => Product.fromJson(json))
      .toList();
}

// --- GET with Custom Headers (e.g., Auth Token) ---
Future<UserProfile> getProfile(String token) async {
  final response = await _apiService.get(
    '/api/user/profile',
    options: Options(
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
  return UserProfile.fromJson(response.data);
}

// --- GET with CancelToken (cancellable request) ---
final _cancelToken = CancelToken();

Future<void> fetchLargeData() async {
  try {
    final response = await _apiService.get(
      '/api/large-dataset',
      cancelToken: _cancelToken,
    );
    // process response.data
  } catch (e) {
    if (CancelToken.isCancel(e)) {
      print('Request was cancelled by user');
    }
  }
}

// Call this to cancel the above request
void cancelFetch() {
  _cancelToken.cancel('User navigated away');
}
```

#### POST Requests

```dart
// --- Create a Resource ---
Future<User> createUser(String name, String email) async {
  final response = await _apiService.post(
    '/api/users',
    data: {
      'name': name,
      'email': email,
      'role': 'customer',
    },
  );
  return User.fromJson(response.data);
}

// --- POST with Auth Header ---
Future<Order> placeOrder(String token, Map<String, dynamic> orderData) async {
  final response = await _apiService.post(
    '/api/orders',
    data: orderData,
    options: Options(
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
  return Order.fromJson(response.data);
}

// --- POST with Query Parameters ---
Future<void> submitForm(Map<String, dynamic> formData) async {
  final response = await _apiService.post(
    '/api/forms/submit',
    data: formData,
    queryParameters: {'version': 'v2', 'locale': 'en'},
  );
  print('Submitted: ${response.data}');
}
```

#### PUT Requests (Full Resource Replacement)

```dart
// --- Replace Entire User Profile ---
Future<User> replaceUser(int userId, User user) async {
  final response = await _apiService.put(
    '/api/users/$userId',
    data: user.toJson(),
  );
  return User.fromJson(response.data);
}

// --- PUT with Auth ---
Future<void> updateProduct(int productId, Map<String, dynamic> data, String token) async {
  await _apiService.put(
    '/api/products/$productId',
    data: data,
    options: Options(
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
}
```

#### PATCH Requests (Partial Update)

```dart
// --- Update Single Field ---
Future<void> updateUserName(int userId, String newName) async {
  await _apiService.patch(
    '/api/users/$userId',
    data: {'name': newName},
  );
}

// --- Update Order Status ---
Future<void> updateOrderStatus(int orderId, String status, String token) async {
  await _apiService.patch(
    '/api/orders/$orderId',
    data: {'status': status},
    options: Options(
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
}
```

#### DELETE Requests

```dart
// --- Delete a Resource ---
Future<void> deleteUser(int userId) async {
  await _apiService.delete('/api/users/$userId');
}

// --- Delete with Confirmation Body ---
Future<void> deleteAccount(String token, String reason) async {
  await _apiService.delete(
    '/api/account',
    data: {'reason': reason},
    options: Options(
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
}
```

#### File Uploads

```dart
import 'dart:io';
import 'package:dio/dio.dart';

// --- Upload Single File ---
Future<String> uploadProfileImage(File imageFile) async {
  final multipartFile = await MultipartFile.fromFile(
    imageFile.path,
    filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );

  final response = await _apiService.uploadFile(
    '/api/users/avatar',
    file: multipartFile,
    fieldName: 'image',  // must match server's expected field name
  );

  return response.data['image_url'];  // server returns the uploaded URL
}

// --- Upload File with Extra Form Data ---
Future<void> uploadDocument(File docFile, int userId, String docType) async {
  final multipartFile = await MultipartFile.fromFile(
    docFile.path,
    filename: 'document.pdf',
  );

  await _apiService.uploadFile(
    '/api/users/$userId/documents',
    file: multipartFile,
    fieldName: 'document',
    data: {
      'document_type': docType,
      'user_id': userId.toString(),
    },
  );
}

// --- Upload Multiple Files ---
Future<void> uploadGalleryImages(List<File> imageFiles) async {
  final multipartFiles = <MultipartFile>[];
  for (int i = 0; i < imageFiles.length; i++) {
    multipartFiles.add(
      await MultipartFile.fromFile(
        imageFiles[i].path,
        filename: 'image_$i.jpg',
      ),
    );
  }

  await _apiService.uploadMultipleFiles(
    '/api/gallery/upload',
    files: multipartFiles,
    fieldName: 'images',
    data: {
      'gallery_name': 'My Photos',
      'category': 'travel',
    },
  );
}

// --- Upload with Progress Tracking ---
Future<void> uploadLargeFile(File file, Function(double) onProgress) async {
  final multipartFile = await MultipartFile.fromFile(
    file.path,
    filename: 'large_file.zip',
  );

  await _apiService.uploadFileWithProgress(
    '/api/files/upload',
    file: multipartFile,
    onSendProgress: (int sent, int total) {
      final percent = (sent / total) * 100;
      onProgress(percent);
      print('Upload progress: ${percent.toStringAsFixed(1)}%');
    },
  );
}
```

#### Error Handling (All Methods)

```dart
Future<void> safeApiCall() async {
  try {
    final response = await _apiService.get('/api/data');
    // Success - process response.data

  } on TimeoutException {
    // Request took longer than 30 seconds
    // Show: "Request timed out. Please try again."

  } on NoInternetException {
    // Device is offline or server unreachable
    // Show: "No internet connection."

  } on ServerException catch (e) {
    // HTTP 4xx or 5xx response
    // e.statusCode  -> 404, 500, etc.
    // e.message     -> "Not Found", "Internal Server Error"
    print('Server error ${e.statusCode}: ${e.message}');

  } on UnknownException catch (e) {
    // Unexpected error (cancelled, bad cert, etc.)
    print('Unknown error: ${e.message}');

  } catch (e) {
    // Catch-all for truly unexpected errors
    print('Unexpected: $e');
  }
}
```

---

### 2. CacheService

**File:** `lib/core/services/cache_service.dart`

A singleton wrapper around [Hive](https://pub.dev/packages/hive) for local key-value storage. All data is persisted on disk and survives app restarts.

#### How It Works

```
Your Code --> CacheService.put(key, value) --> Hive Box (disk)
Your Code <-- CacheService.get<T>(key)    <-- Hive Box (disk)
```

#### Usage Examples

```dart
final cacheService = CacheService();

// --- IMPORTANT: Must be initialized before use (done in main.dart) ---
await cacheService.init();

// --- Store data ---
await cacheService.put('username', 'john_doe');
await cacheService.put('user_age', 25);
await cacheService.put('is_premium', true);
await cacheService.put('settings', {'theme': 'dark', 'lang': 'en'});

// Store a list of maps (common pattern for caching API responses)
final bannerJsonList = banners.map((b) => b.toJson()).toList();
await cacheService.put('banners', bannerJsonList);

// --- Read data (with type safety) ---
final username = cacheService.get<String>('username');                    // 'john_doe'
final age = cacheService.get<int>('user_age');                           // 25
final isPremium = cacheService.get<bool>('is_premium');                  // true
final settings = cacheService.get<Map>('settings');                      // {'theme': 'dark', ...}

// With default values (returned if key doesn't exist)
final theme = cacheService.get<String>('theme', defaultValue: 'light');  // 'light' (key missing)

// --- Check if key exists ---
if (cacheService.containsKey('username')) {
  print('User is logged in');
}

// --- Delete specific key ---
await cacheService.delete('username');

// --- Clear all cache ---
await cacheService.clear();

// --- Cleanup when app closes ---
await cacheService.dispose();
```

#### Real-World Pattern: Cache-First Data Loading

```dart
class ProductRepository {
  final ApiService _api;
  final CacheService _cache;

  Future<List<Product>> getProducts() async {
    try {
      // 1. Try to fetch from API
      final response = await _api.get('/api/products');
      final products = (response.data as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // 2. Cache the successful response
      await _cache.put('products', products.map((p) => p.toJson()).toList());

      return products;
    } on AppException {
      // 3. On any error, fall back to cache
      return _getCachedProducts();
    }
  }

  List<Product> _getCachedProducts() {
    final jsonList = _cache.get<List>('products', defaultValue: []) ?? [];
    return jsonList
        .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}
```

> **Note:** Hive stores `Map` as `Map<dynamic, dynamic>`. When reading cached maps, always convert them back using `Map<String, dynamic>.from(map)` before passing to `fromJson()`.

---

### 3. ConnectivityService

**File:** `lib/core/services/connectivity_service.dart`

A singleton that monitors network connectivity using [connectivity_plus](https://pub.dev/packages/connectivity_plus). Provides both one-shot checks and a reactive stream.

#### How It Works

```
+------------------+      +-----------------------+     +---------------+
| WiFi / Mobile /  | ---> | connectivity_plus     | --> | Connectivity  |
| Ethernet changes |      | (platform listeners)  |     | Service       |
+------------------+      +-----------------------+     +-------+-------+
                                                                |
                                           +--------------------+--------------------+
                                           |                                         |
                                    Stream<bool>                              checkConnectivity()
                                    (reactive)                                 (one-shot)
                                           |                                         |
                                           v                                         v
                                   HomeController                             HomeService
                                   (auto-refresh)                         (before API calls)
```

#### Usage Examples

```dart
final connectivityService = ConnectivityService();

// --- One-Shot Check ---
// Use this before making API calls
Future<void> fetchDataSafely() async {
  final isOnline = await connectivityService.checkConnectivity();
  if (!isOnline) {
    print('No internet - loading from cache');
    return;
  }
  // proceed with API call...
}

// --- Reactive Stream ---
// Use this to auto-react to connectivity changes
StreamSubscription<bool>? _subscription;

void startMonitoring() {
  _subscription = connectivityService.connectivityStream.listen((isConnected) {
    if (isConnected) {
      print('Back online! Refreshing data...');
      refreshData();
    } else {
      print('Went offline. Showing cached data.');
      showOfflineBanner();
    }
  });
}

// Always clean up subscriptions
void stopMonitoring() {
  _subscription?.cancel();
  _subscription = null;
}
```

#### In the Home Feature (Real Usage)

```dart
// In HomeController - auto-refresh when reconnected:
void _listenToConnectivity() {
  bool isFirstEvent = true;

  _connectivitySubscription = _connectivityService.connectivityStream.listen((isConnected) {
    _isConnected.value = isConnected;

    // Skip first event to avoid duplicate initial load
    if (isFirstEvent) {
      isFirstEvent = false;
      return;
    }

    // Auto-refresh when connection is restored
    if (isConnected && _repository.hasCache()) {
      loadData(forceRefresh: true);
    }
  });
}
```

---

## 4. StorageService

**File:** `lib/core/services/storage_service.dart`

A lightweight, typed wrapper around Flutter's `shared_preferences` package for storing simple persistent key-value data (tokens, flags, user preferences, etc.).

> **Difference from CacheService:** `CacheService` (Hive) is designed for caching structured API response objects. `StorageService` (SharedPreferences) is for small, primitive values like auth tokens, settings flags, and user identifiers.

### Accessing StorageService

```dart
final storage = Get.find<StorageService>();
```

### Writing Data

```dart
await storage.setString(StorageKeys.authToken, 'your_jwt_token');
await storage.setBool(StorageKeys.isLoggedIn, true);
await storage.setInt(StorageKeys.userId, 42);
await storage.setDouble('discount_rate', 0.15);
await storage.setStringList('recent_searches', ['pizza', 'burger']);
```

### Reading Data

```dart
final token   = storage.getString(StorageKeys.authToken);     // String?
final isLoggedIn = storage.getBool(StorageKeys.isLoggedIn) ?? false;
final userId  = storage.getInt(StorageKeys.userId);           // int?
final recent  = storage.getStringList('recent_searches');     // List<String>?
```

### Removing Data

```dart
// Remove one key
await storage.remove(StorageKeys.authToken);

// Wipe everything (e.g. on logout)
await storage.clear();
```

### StorageKeys

All storage keys live in the `StorageKeys` abstract class in the same file. Always use these constants — never hard-code raw strings.

```dart
abstract class StorageKeys {
  // Auth
  static const String authToken      = 'auth_token';
  static const String refreshToken   = 'refresh_token';
  static const String isLoggedIn     = 'is_logged_in';

  // User
  static const String userId         = 'user_id';
  static const String userName       = 'user_name';
  static const String userEmail      = 'user_email';

  // App Settings
  static const String isDarkMode        = 'is_dark_mode';
  static const String selectedLanguage  = 'selected_language';
  static const String isFirstLaunch     = 'is_first_launch';
}
```

To add a new key, simply add a constant to `StorageKeys`:

```dart
static const String fcmToken = 'fcm_token';
```

### Initialization

`StorageService` is initialized eagerly in `DependencyInjection.init()` before the app starts. No manual setup is required.

---

## Navigation System

**Files:**
- `lib/core/routes/app_routes.dart` — route name constants
- `lib/core/routes/app_pages.dart` — `GetPage` definitions and `Bindings`

This template uses **GetX named routing**, which gives you URL-like navigation, automatic dependency injection per route, and easy deep-link support.

### AppRoutes

`AppRoutes` holds all route name constants. Never use raw strings for navigation.

```dart
// lib/core/routes/app_routes.dart
abstract class AppRoutes {
  static const String initial = '/';
  static const String home    = '/home';

  // Add your routes here:
  // static const String login    = '/login';
  // static const String profile  = '/profile';
  // static const String settings = '/settings';
}
```

### AppPages & Bindings

`AppPages.routes` maps each route name to a page widget and a `Bindings` class. The binding provides the controller/service dependencies for that page via `Get.lazyPut`.

```dart
// lib/core/routes/app_pages.dart
abstract class AppPages {
  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),
    // Add more pages here
  ];
}
```

**Adding a new page + binding:**

```dart
// 1. Add route constant in AppRoutes
static const String profile = '/profile';

// 2. Add GetPage in AppPages.routes
GetPage(
  name: AppRoutes.profile,
  page: () => const ProfilePage(),
  binding: ProfileBinding(),
),

// 3. Create the binding class
class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileRepository>(
      () => ProfileRepository(
        apiService: Get.find<ApiService>(),
        cacheService: Get.find<CacheService>(),
      ),
    );
    Get.lazyPut<ProfileService>(
      () => ProfileService(repository: Get.find<ProfileRepository>()),
    );
    Get.lazyPut<ProfileController>(
      () => ProfileController(service: Get.find<ProfileService>()),
    );
  }
}
```

### Activating Named Routing

The routes are ready to use. To switch from the current `home:` approach to full named routing, make the following change in `lib/app.dart`:

```dart
// lib/app.dart — inside GetMaterialApp(...)

// Add these two imports at the top of the file:
import 'core/routes/app_routes.dart';
import 'core/routes/app_pages.dart';

// Replace:
//   home: child,
// With:
  initialRoute: AppRoutes.home,
  getPages: AppPages.routes,
```

> The existing `home: child` (used by ScreenUtilInit) still works perfectly for single-screen apps. Switch to `initialRoute` + `getPages` only when you start adding multiple screens.

### Navigation Examples

```dart
// ─── Basic navigation ──────────────────────────────────────────────────────

// Push a new screen
Get.toNamed(AppRoutes.profile);

// Push and remove the current screen
Get.offNamed(AppRoutes.home);

// Push and clear the entire back-stack (e.g. after login)
Get.offAllNamed(AppRoutes.home);

// Go back
Get.back();

// ─── With arguments ────────────────────────────────────────────────────────

// Pass data
Get.toNamed(AppRoutes.profile, arguments: {'userId': '42'});

// Receive data inside the destination page/controller
final args = Get.arguments as Map<String, dynamic>;
final userId = args['userId'];

// ─── With query parameters ─────────────────────────────────────────────────

Get.toNamed('${AppRoutes.profile}?tab=orders');

// Receive inside the controller
final tab = Get.parameters['tab']; // 'orders'
```

---

## Dependency Injection

**File:** `lib/core/di/dependency_injection.dart`

All services, repositories, and controllers are registered via GetX's `Get.lazyPut()`. This ensures:
- **Lazy initialization** - created only when first accessed
- **Singleton behavior** - `fenix: true` recreates if disposed
- **Testability** - swap implementations easily

### Registration Order

```
DependencyInjection.init()
        |
        |  1. Core Services (no dependencies)
        +-----> CacheService     (singleton, fenix: true)
        +-----> ApiService       (singleton, fenix: true)
        +-----> ConnectivityService (singleton, fenix: true)
        |
        |  2. Repositories (depend on core services)
        +-----> HomeRepository(apiService, cacheService, connectivityService)
        |
        |  3. Domain Services (depend on repositories)
        +-----> HomeService(repository, connectivityService)
        |
        |  4. Controllers (depend on services)
        +-----> HomeController(homeService, repository, connectivityService)
```

### How to Add a New Feature

```dart
// In dependency_injection.dart, add:

static Future<void> init() async {
  // ... existing registrations ...

  // Your new feature:
  Get.lazyPut<ProfileRepository>(
    () => ProfileRepository(
      apiService: Get.find<ApiService>(),
      cacheService: Get.find<CacheService>(),
    ),
    fenix: true,
  );

  Get.lazyPut<ProfileService>(
    () => ProfileService(repository: Get.find<ProfileRepository>()),
    fenix: true,
  );

  Get.lazyPut<ProfileController>(
    () => ProfileController(profileService: Get.find<ProfileService>()),
  );
}
```

### Accessing Dependencies

```dart
// In a widget or anywhere:
final controller = Get.find<HomeController>();
final apiService = Get.find<ApiService>();

// In a class constructor (preferred - explicit dependencies):
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    return Obx(() => Text('${controller.banners.length} banners'));
  }
}
```

---

## Exception Handling

**File:** `lib/core/exceptions/app_exceptions.dart`

A typed exception hierarchy that replaces generic `Exception` with meaningful error types.

### Exception Hierarchy

```
AppException (abstract base)
  |
  +-- NoInternetException    "No internet connection"
  +-- TimeoutException       "Request timeout"
  +-- ServerException        "Server error" (includes statusCode: int?)
  +-- ParsingException       "Failed to parse data"
  +-- CacheException         "Cache operation failed"
  +-- NotFoundException      "Data not found"
  +-- UnknownException       "An unknown error occurred"
```

### Mapping from Dio to App Exceptions

| Dio Error Type | App Exception |
|---|---|
| `connectionTimeout`, `sendTimeout`, `receiveTimeout` | `TimeoutException` |
| `connectionError` | `NoInternetException` |
| `badResponse` (4xx, 5xx) | `ServerException` |
| `cancel` | `UnknownException` |
| `badCertificate` | `ServerException` |
| `unknown` + SocketException | `NoInternetException` |
| `unknown` (other) | `UnknownException` |

### Usage in Controllers

```dart
try {
  await someApiCall();
} on NoInternetException {
  // Show offline UI / load from cache
} on TimeoutException {
  // Show "Request timed out, please retry"
} on ServerException catch (e) {
  if (e.statusCode == 404) {
    // Resource not found
  } else if (e.statusCode == 401) {
    // Unauthorized - redirect to login
  } else {
    // Generic server error
  }
} on ParsingException {
  // API response format changed - log to analytics
} on CacheException {
  // Cache corrupted - clear and re-fetch
} on AppException catch (e) {
  // Catch-all for any typed exception
  showError(e.message);
}
```

### Creating Custom Exceptions

```dart
// Add to app_exceptions.dart:
class AuthenticationException extends AppException {
  AuthenticationException([String? details])
      : super('Authentication failed', details);
}

class RateLimitException extends AppException {
  final Duration retryAfter;
  RateLimitException(this.retryAfter, [String? details])
      : super('Rate limit exceeded', details);
}
```

---

## Feature: Home

### Data Models

All models live in `lib/features/home/data/models/` and follow these conventions:
- Nullable fields (API may omit them)
- `factory fromJson()` constructor for deserialization
- `toJson()` method for serialization (needed for caching)
- `safe*` getters that return defaults instead of null

#### BannerModel

```dart
// JSON from API:
// { "id": 1, "image": "banner.jpg", "image_full_url": "https://...", "title": "50% Off" }

final banner = BannerModel.fromJson(json);
print(banner.safeImageUrl);  // "https://..." (falls back to image, then "")
print(banner.safeTitle);     // "50% Off"

// For caching:
final jsonMap = banner.toJson();
```

#### CategoryModel

```dart
// JSON from API:
// { "id": 1, "name": "Pizza", "image_full_url": "https://...", "childes": [...] }

final category = CategoryModel.fromJson(json);
print(category.safeName);        // "Pizza"
print(category.safeImageUrl);    // "https://..."
print(category.safeChildes);     // [] or List<CategoryModel>

// Recursive - child categories have the same structure:
for (final child in category.safeChildes) {
  print('  Sub-category: ${child.safeName}');
}
```

#### ProductModel

```dart
// JSON from API:
// {
//   "id": 1, "name": "Burger", "price": 12.99,
//   "image_full_url": "https://...",
//   "avg_rating": 4.5, "restaurant_name": "Joe's Diner",
//   "discount": 10.0, "discount_type": "percent",
//   "min_delivery_time": 20, "max_delivery_time": 30
// }

final product = ProductModel.fromJson(json);
print(product.safeName);             // "Burger"
print(product.safePrice);            // 12.99
print(product.safeRating);           // 4.5
print(product.safeRestaurantName);   // "Joe's Diner"
print(product.safeDiscount);         // 10.0
print(product.safeDiscountType);     // "percent"

// Calculate discounted price:
double finalPrice;
if (product.safeDiscountType == 'percent') {
  finalPrice = product.safePrice * (1 - product.safeDiscount / 100);  // 11.69
} else {
  finalPrice = product.safePrice - product.safeDiscount;  // fixed amount off
}
```

#### RestaurantModel & RestaurantsResponse

```dart
// Single restaurant JSON:
// { "id": 1, "name": "Pizza Place", "logo_full_url": "https://...", "avg_rating": 4.2 }

final restaurant = RestaurantModel.fromJson(json);
print(restaurant.safeName);     // "Pizza Place"
print(restaurant.safeLogoUrl);  // "https://..."
print(restaurant.safeRating);   // 4.2

// Paginated response JSON:
// { "total_size": 50, "data": [ {...}, {...}, ... ] }

final response = RestaurantsResponse.fromJson(json);
print(response.totalSize);           // 50
print(response.data?.length);        // 10 (current page)

// Pagination check:
if (loadedRestaurants.length < response.totalSize!) {
  print('More restaurants available');
}
```

### Creating a New Model (Step-by-Step)

```dart
// 1. Create the file: lib/features/home/data/models/review_model.dart

class ReviewModel {
  int? id;
  String? userName;
  String? comment;
  double? rating;
  String? createdAt;

  ReviewModel({this.id, this.userName, this.comment, this.rating, this.createdAt});

  // 2. Factory constructor to parse API JSON
  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: json['id'],
    userName: json['user_name'],
    comment: json['comment'],
    rating: json['rating']?.toDouble(),
    createdAt: json['created_at'],
  );

  // 3. toJson for caching
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_name': userName,
    'comment': comment,
    'rating': rating,
    'created_at': createdAt,
  };

  // 4. Safe getters
  String get safeName => userName ?? 'Anonymous';
  String get safeComment => comment ?? '';
  double get safeRating => rating ?? 0.0;
}
```

---

### Repository Layer

**File:** `lib/features/home/data/repositories/home_repository.dart`

The repository is the **single source of truth** for data. It decides whether to fetch from the API or return cached data.

#### Pattern: Fetch, Cache, Fallback

Every fetch method follows this pattern:

```dart
Future<List<Model>> getData() async {
  try {
    // 1. Fetch from API
    final response = await _apiService.get('/endpoint');

    // 2. Parse response
    final items = (response.data as List)
        .map((e) => Model.fromJson(e))
        .toList();

    // 3. Cache the result
    await _cacheService.put('cacheKey', items.map((e) => e.toJson()).toList());

    return items;
  } on AppException {
    // 4. On error: return cached data
    return getCachedData();
  }
}
```

#### Adding a New Endpoint to the Repository

```dart
// 1. Add endpoint to ApiConstants:
static const String reviews = '/api/v1/reviews';
static const String cacheReviews = 'reviews';

// 2. Add fetch method to HomeRepository:
Future<List<ReviewModel>> getReviews(int productId) async {
  try {
    final response = await _apiService.get(
      ApiConstants.reviews,
      queryParameters: {'product_id': productId},
    );
    final reviews = (response.data as List)
        .map((e) => ReviewModel.fromJson(e))
        .toList();

    await _cacheService.put(
      '${ApiConstants.cacheReviews}_$productId',
      reviews.map((e) => e.toJson()).toList(),
    );

    return reviews;
  } on AppException {
    return getCachedReviews(productId);
  }
}

// 3. Add cache getter:
List<ReviewModel> getCachedReviews(int productId) {
  try {
    final jsonList = _cacheService.get<List>(
      '${ApiConstants.cacheReviews}_$productId',
      defaultValue: [],
    ) ?? [];
    return jsonList
        .map((json) => ReviewModel.fromJson(_convertMap(json)))
        .toList();
  } catch (_) {
    return [];
  }
}
```

---

### Service Layer (Domain)

**File:** `lib/features/home/domain/services/home_service.dart`

The service layer contains **business logic** and coordinates multiple repository calls.

#### Key Responsibilities

```
HomeService
    |
    +--> Check connectivity BEFORE making requests
    +--> Run multiple fetches in PARALLEL (Future.wait)
    +--> Decide whether to throw or swallow errors (cache fallback)
    +--> Provide aggregated data via HomeData DTO
```

#### Usage Examples

```dart
final homeService = Get.find<HomeService>();

// --- Fetch All Data (used on initial load and refresh) ---
try {
  await homeService.fetchAllHomeData(0, 10);  // page 0, 10 items
  print('Data loaded and cached!');
} on NoInternetException {
  if (homeService.hasOfflineData()) {
    final data = await homeService.getCachedHomeData();
    print('Showing ${data.banners.length} cached banners');
  } else {
    print('No internet and no cache - show retry UI');
  }
}

// --- Pagination ---
final moreRestaurants = await homeService.fetchMoreRestaurants(10, 10);
print('Loaded ${moreRestaurants.length} more restaurants');

// --- Check Offline Capability ---
if (homeService.hasOfflineData()) {
  final data = await homeService.getCachedHomeData();
  print('Banners: ${data.banners.length}');
  print('Categories: ${data.categories.length}');
  print('Popular Foods: ${data.popularFoods.length}');
  print('Campaigns: ${data.foodCampaigns.length}');
  print('Restaurants: ${data.restaurants.length}/${data.totalRestaurants}');
}
```

---

### Controller (Presentation)

**File:** `lib/features/home/presentation/controllers/home_controller.dart`

The GetX controller manages all UI state, scroll behavior, pagination, and connectivity reactions.

#### State Machine

```dart
enum LoadingState { initial, loading, loaded, error, offline }
```

| State | UI Shows | When |
|-------|----------|------|
| `initial` | Nothing (brief) | App just opened |
| `loading` | Shimmer skeleton | No cache, fetching data |
| `loaded` | Full content | Data available (from cache or API) |
| `error` | Error + Retry button | API failed, no cache |
| `offline` | Offline icon + Retry | No internet, no cache |

#### Reactive Properties

```dart
// In widgets, observe these with Obx():

Obx(() => Text('${controller.banners.length} banners'));
Obx(() => controller.isLoadingMore
    ? CircularProgressIndicator()
    : SizedBox.shrink());

Obx(() {
  switch (controller.loadingState) {
    case LoadingState.loading:
      return ShimmerWidget();
    case LoadingState.loaded:
      return ContentWidget();
    case LoadingState.error:
      return RetryWidget(message: controller.errorMessage);
    case LoadingState.offline:
      return OfflineWidget();
    default:
      return SizedBox.shrink();
  }
});
```


### Widgets

#### Widget Hierarchy

```
HomePage (Scaffold)
  |
  +-- Stack
       |
       +-- Padding (content area, below header)
       |     |
       |     +-- Obx (switch on LoadingState)
       |           |
       |           +-- ShimmerWidgets.buildLoadingShimmer()  [loading]
       |           +-- RetryWidget                           [error/offline]
       |           +-- HomeContent                           [loaded]
       |                 |
       |                 +-- RefreshIndicator
       |                       |
       |                       +-- CustomScrollView (with scroll controller)
       |                             |
       |                             +-- SearchBarWidget (inline, hidden when overlay active)
       |                             +-- BannerCarousel
       |                             +-- SectionHeader ("Categories") + CategoryItem list
       |                             +-- SectionHeader ("Popular Food") + FoodCard list
       |                             +-- SectionHeader ("Food Campaign") + FoodCampaign list
       |                             +-- SectionHeader ("Restaurants") + RestaurantCard list
       |                             +-- Loading indicator (pagination)
       |
       +-- Animated HomeAppBar (slides in/out)
       |
       +-- Animated SearchBarWidget overlay (slides in/out, inverse of AppBar)
```

#### Key Widget Examples

**SectionHeader** - Reusable section title with optional "View All" button:
```dart
SectionHeader(
  title: 'Popular Food Nearby',
  onViewAll: () {
    // Navigate to full list screen
    Get.to(() => AllPopularFoodsPage());
  },
)

// Without "View All":
SectionHeader(title: 'Restaurants')
```

**FoodCard** - Vertical card for product display:
```dart
FoodCard(product: productModel)
// Displays: image (120h), name, restaurant name, price, star rating
// Price automatically hides ".00" for whole numbers ($12 instead of $12.00)
```

**PriceDisplayWidget** - Smart price with discount:
```dart
PriceDisplayWidget(
  originalPrice: 15.99,
  discount: 10.0,
  discountType: 'percent',  // Shows: $̶1̶5̶.̶9̶9̶  $14.39
)
```

**StarRatingWidget** - Fractional star display:
```dart
StarRatingWidget(rating: 4.5)
// Renders: ★ ★ ★ ★ ½ (4 full + 1 half star)
```

**BannerCarousel** - Auto-playing, infinite-scroll carousel:
```dart
BannerCarousel(banners: controller.banners)
// Features:
// - Auto-play every 3 seconds
// - Infinite scroll (wraps around)
// - Page indicators (green active, peach inactive)
// - 75% viewport fraction (peek at adjacent banners)
```

**ShimmerWidgets** - Loading skeletons:
```dart
// Full page shimmer (used during initial load):
ShimmerWidgets.buildLoadingShimmer()

// Individual shimmers (for custom layouts):
ShimmerWidgets.buildBannerShimmer()
ShimmerWidgets.buildCategoryShimmer()
ShimmerWidgets.buildFoodCardShimmer()
ShimmerWidgets.buildRestaurantCardShimmer()
```

**RetryWidget** - Error/offline screen:
```dart
RetryWidget(
  message: 'No internet connection. Please try again.',
  onRetry: () => controller.retry(),
  isOffline: true,   // true = wifi_off icon, false = error_outline icon
)
```

---


## Using This Project as a Template

### Step 1: Clone and Rename

```bash
git clone https://github.com/sparktechagency/QA-Flutter-Template
cd my_app

# Update package name in pubspec.yaml
# name: my_app
```

### Step 2: Update API Configuration

Edit `lib/core/constants/api_constants.dart`:

```dart
class ApiConstants {
  // Change to your API
  static const String baseUrl = 'https://your-api.example.com';

  // Define your endpoints
  static const String login = '/api/auth/login';
  static const String products = '/api/products';
  static const String orders = '/api/orders';

  // Update headers for your API
  static Map<String, String> headers = {
    'Content-Type': 'application/json',
    // Add your API key, etc.
  };

  // Define cache keys for your data
  static const String cacheProducts = 'products';
  static const String cacheOrders = 'orders';
}
```

### Step 3: Create Your Data Models

Create models in `lib/features/your_feature/data/models/`:

```dart
class OrderModel {
  int? id;
  String? status;
  double? total;
  List<OrderItemModel>? items;

  OrderModel({this.id, this.status, this.total, this.items});

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
    id: json['id'],
    status: json['status'],
    total: json['total']?.toDouble(),
    items: json['items'] != null
        ? (json['items'] as List).map((i) => OrderItemModel.fromJson(i)).toList()
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'total': total,
    'items': items?.map((e) => e.toJson()).toList(),
  };

  String get safeStatus => status ?? 'pending';
  double get safeTotal => total ?? 0.0;
}
```

### Step 4: Create Your Repository

```dart
class OrderRepository {
  final ApiService _apiService;
  final CacheService _cacheService;

  OrderRepository({
    required ApiService apiService,
    required CacheService cacheService,
  }) : _apiService = apiService, _cacheService = cacheService;

  Future<List<OrderModel>> getOrders() async {
    try {
      final response = await _apiService.get(ApiConstants.orders);
      final orders = (response.data['orders'] as List)
          .map((e) => OrderModel.fromJson(e))
          .toList();

      await _cacheService.put('orders', orders.map((e) => e.toJson()).toList());
      return orders;
    } on AppException {
      return _getCachedOrders();
    }
  }

  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async {
    final response = await _apiService.post(
      ApiConstants.orders,
      data: orderData,
    );
    return OrderModel.fromJson(response.data);
  }

  List<OrderModel> _getCachedOrders() {
    final jsonList = _cacheService.get<List>('orders', defaultValue: []) ?? [];
    return jsonList
        .map((json) => OrderModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}
```

### Step 5: Create Your Service

```dart
class OrderService {
  final OrderRepository _repository;
  final ConnectivityService _connectivityService;

  OrderService({
    required OrderRepository repository,
    required ConnectivityService connectivityService,
  }) : _repository = repository, _connectivityService = connectivityService;

  Future<List<OrderModel>> getOrders() async {
    final isOnline = await _connectivityService.checkConnectivity();
    if (!isOnline) throw NoInternetException();
    return await _repository.getOrders();
  }

  Future<OrderModel> placeOrder(Map<String, dynamic> data) async {
    final isOnline = await _connectivityService.checkConnectivity();
    if (!isOnline) throw NoInternetException();
    return await _repository.createOrder(data);
  }
}
```

### Step 6: Create Your Controller

```dart
class OrderController extends GetxController {
  final OrderService _orderService;

  OrderController({required OrderService orderService})
      : _orderService = orderService;

  final RxList<OrderModel> orders = <OrderModel>[].obs;
  final Rx<LoadingState> state = LoadingState.initial.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadOrders();
  }

  Future<void> loadOrders() async {
    try {
      state.value = LoadingState.loading;
      orders.value = await _orderService.getOrders();
      state.value = LoadingState.loaded;
    } on NoInternetException {
      state.value = LoadingState.offline;
      error.value = 'No internet connection';
    } on AppException catch (e) {
      state.value = LoadingState.error;
      error.value = e.message;
    }
  }

  Future<void> placeOrder(Map<String, dynamic> data) async {
    try {
      final order = await _orderService.placeOrder(data);
      orders.add(order);
      Get.snackbar('Success', 'Order placed!');
    } on AppException catch (e) {
      Get.snackbar('Error', e.message);
    }
  }
}
```

### Step 7: Register in DI

```dart
// In dependency_injection.dart, add:
Get.lazyPut<OrderRepository>(
  () => OrderRepository(
    apiService: Get.find<ApiService>(),
    cacheService: Get.find<CacheService>(),
  ),
  fenix: true,
);

Get.lazyPut<OrderService>(
  () => OrderService(
    repository: Get.find<OrderRepository>(),
    connectivityService: Get.find<ConnectivityService>(),
  ),
  fenix: true,
);

Get.lazyPut<OrderController>(
  () => OrderController(orderService: Get.find<OrderService>()),
);
```

### Step 8: Build Your UI

```dart
class OrdersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OrderController>();

    return Scaffold(
      appBar: AppBar(title: Text('My Orders')),
      body: Obx(() {
        switch (controller.state.value) {
          case LoadingState.loading:
            return ShimmerWidgets.buildLoadingShimmer();
          case LoadingState.error:
          case LoadingState.offline:
            return RetryWidget(
              message: controller.error.value,
              onRetry: controller.loadOrders,
              isOffline: controller.state.value == LoadingState.offline,
            );
          case LoadingState.loaded:
            return ListView.builder(
              itemCount: controller.orders.length,
              itemBuilder: (context, index) {
                final order = controller.orders[index];
                return ListTile(
                  title: Text('Order #${order.id}'),
                  subtitle: Text(order.safeStatus),
                  trailing: Text('\$${order.safeTotal.toStringAsFixed(2)}'),
                );
              },
            );
          default:
            return SizedBox.shrink();
        }
      }),
    );
  }
}
```

### Checklist for New Features

- [ ] Create model class with `fromJson()`, `toJson()`, safe getters
- [ ] Add API endpoint to `ApiConstants`
- [ ] Add cache key to `ApiConstants`
- [ ] Create repository with fetch + cache + fallback pattern
- [ ] Create service with connectivity check + business logic
- [ ] Create GetX controller with `LoadingState` management
- [ ] Register all new classes in `DependencyInjection`
- [ ] Build UI widgets using `Obx()` for reactivity
- [ ] Handle all error states (loading, error, offline, loaded)

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `get` | ^4.6.6 | State management, DI, navigation, snackbars |
| `dio` | ^5.7.0 | HTTP client with interceptors, multipart uploads |
| `cached_network_image` | ^3.4.1 | Image loading with disk/memory cache |
| `shimmer` | ^3.0.0 | Skeleton loading animations |
| `flutter_screenutil` | ^5.9.3 | Responsive sizing (base: 375x812) |
| `hive` | ^2.2.3 | Fast local key-value storage |
| `hive_flutter` | ^1.1.0 | Flutter bindings for Hive |
| `connectivity_plus` | ^6.0.5 | Network connectivity monitoring |
| `path_provider` | ^2.1.4 | Platform file paths (used by Hive) |
| `google_fonts` | ^6.2.1 | Google Fonts (Roboto) |

### Responsive Sizing with ScreenUtil

```dart
// This project uses 375x812 (iPhone X) as the design base.
// All dimensions should use ScreenUtil extensions:

SizedBox(width: 16.w)   // Scales width proportionally
SizedBox(height: 16.h)  // Scales height proportionally
Text('Hello', style: TextStyle(fontSize: 14.sp))  // Scales font size
BorderRadius.circular(8.r)  // Scales radius
```

---

## Platform Configuration

### Android

Permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
```

### iOS

Configuration in `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

---

## Troubleshooting

### App not fetching data

```bash
# 1. Check Flutter logs
flutter run --verbose

# 2. Check for analysis issues
flutter analyze
```

### Images not loading
- Verify the device has internet
- Check that `NSAllowsArbitraryLoads` is `true` in Info.plist (iOS)
- Clear cached images: uninstall and reinstall the app

### Offline mode not working
- The app needs to fetch data **at least once** while online to populate the cache
- If cache appears corrupted, clear app data and re-launch online

### Build failures

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# iOS-specific
cd ios && pod install && cd ..
flutter run -d ios
```

### "Cache service not initialized" error
- Ensure `await CacheService().init()` is called in `main()` before `runApp()`
- This is already handled in `main.dart` but may be missed if you modify the startup sequence

---

