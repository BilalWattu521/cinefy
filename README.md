# Cinefy 🎬

A premium Flutter application designed to help cinema enthusiasts track their favorite movies and TV shows, manage watched history, and even upload personal video edits associated with their favorite titles.

---

## ✨ Features

- **Global Movie Discovery**: Powered by the [TMDB API](https://www.themoviedb.org/documentation/api), explore thousands of movies and TV shows with rich metadata, posters, and season details.
- **Secure Authentication**: Seamless login via **Google Sign-In**.
- **Personalized Lists**: 
  - **Favorites**: Mark movies you love for quick access.
  - **Watched History**: Keep track of every movie you've seen.
  - **Custom Lists**: Create and manage your own themed collections.
- **Video Edits Collection**: 
  - Upload personal video clips/edits for specific movies.
  - **Real-Time Progress**: Sleek SnackBars showing live upload percentage (0-100%).
  - Secure storage powered by **Cloudinary**.
- **Premium UI/UX**:
  - **Subtle Animations**: Smooth entry and transition effects.
  - **User-Friendly Errors**: Clear, non-technical error messages for a polished feel.
  - **Responsive Design**: Optimized for a stunning look on Android.

---

## 🛠️ Tech Stack

- **Framework**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore)
- **Storage**: Cloudinary (Video hosting)
- **State Management**: Provider
- **Network**: `http`, `cached_network_image`

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- A Firebase project (with Firestore and Google Sign-In enabled)
- A Cloudinary account
- A TMDB API Key

### Configuration

1. **Clone the repository**:
   ```bash
   git clone https://github.com/BilalWattu521/cinefy.git
   cd cinefy
   ```

2. **Setup Firebase**:
   - Add your `google-services.json` (Android) to the `android/app` folder.

3. **Environment Variables**:
   Create a `.env` file in the root directory and add the following keys:
   ```env
   # TMDB Configuration
   TMDB_API_KEY=your_tmdb_api_key

   # Cloudinary Configuration
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_API_KEY=your_api_key
   CLOUDINARY_API_SECRET=your_api_secret

   # Google Auth Configuration
   GOOGLE_CLIENT_ID=your_android_client_id
   GOOGLE_SERVER_CLIENT_ID=your_web_server_client_id
   ```

4. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

5. **Run the App**:
   ```bash
   flutter run
   ```

---

## 📂 Project Structure

```text
lib/
├── models/         # Data models (Movie, VideoEdit, CustomList, etc.)
├── providers/      # State management (UserDataProvider, CatalogProvider)
├── screens/        # UI screens (Home, MovieDetail, Profile, Login, etc.)
├── services/       # API Services (Auth, Firestore, TMDB, Storage)
├── utils/          # Helper utilities (SnackbarUtils)
└── widgets/        # Reusable UI components (MovieCard, etc.)
```

---

## 🤝 Contributing

Contributions are welcome! If you have suggestions for improvements or find any issues, feel free to open a pull request or file an issue.

## Made with ❤️ by Muhammad Bilal Ahmed

This project is licensed under the MIT License - see the LICENSE file for details.
