# Invoice Report - Flutter App

A Flutter application for scanning and managing invoices for ice cream parlours with automated data extraction and reporting features.

## Architecture Overview

### Frontend (Flutter)
- **Authentication**: Firebase Auth
- **Database**: Firestore (offline enabled)
- **File Storage**: Firebase Storage
- **State Management**: Provider pattern
- **UI**: Material Design 3

### Backend Integration
- **AI Processing**: Azure Document Intelligence via Azure Functions (.NET isolated)
- **Flow**: Upload → get downloadURL → call Azure Function → watch Firestore doc status update

### Azure Function (.NET isolated)
- **HTTP endpoint**: `/extract`
- **Input**: `{ tenantId, invoiceId, downloadUrl }`
- **Steps**: download image → call Azure Document Intelligence (Invoice) → normalize fields → write back to Firestore

## Features

- 📷 **Invoice Scanning**: Camera integration with image cropping
- 🔍 **AI Data Extraction**: Automated invoice data extraction using Azure Document Intelligence
- 📊 **Real-time Status Updates**: Watch invoice processing status in real-time
- 📈 **Day/Month Reports**: Comprehensive reporting with charts and analytics
- 🔒 **Secure Authentication**: Firebase Auth with multi-tenant support
- 💾 **Offline Support**: Firestore offline capability for continued usage
- 🎨 **Modern UI**: Clean Material Design interface

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models
│   ├── invoice.dart         # Invoice and related models
│   └── user.dart            # User model
├── providers/               # State management
│   ├── auth_provider.dart   # Authentication state
│   └── invoice_provider.dart # Invoice management state
├── services/                # Business logic services
│   ├── auth_service.dart    # Authentication service
│   ├── firestore_service.dart # Database operations
│   ├── storage_service.dart # File storage operations
│   ├── camera_service.dart  # Camera and image operations
│   └── azure_function_service.dart # Azure Function integration
├── screens/                 # UI screens
│   ├── auth_wrapper.dart    # Authentication routing
│   ├── auth/               # Authentication screens
│   ├── home/               # Main navigation
│   ├── invoice/            # Invoice management screens
│   └── reports/            # Analytics and reporting
└── widgets/                # Reusable UI components
```

## Getting Started

### Prerequisites

1. **Flutter SDK** (3.8.1 or higher)
2. **Firebase Project** with Authentication, Firestore, and Storage enabled
3. **Azure Account** with Document Intelligence service
4. **VS Code** with Flutter extension (recommended)

### Setup Instructions

1. **Clone and Setup Project**
   ```bash
   git clone <repository-url>
   cd invoicereport
   flutter pub get
   ```

2. **Firebase Configuration**
   - Create a new Firebase project
   - Enable Authentication (Email/Password)
   - Enable Firestore Database
   - Enable Storage
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update `firebase_options.dart` with your project configuration

3. **Azure Function Setup**
   - Create Azure Function App
   - Enable Document Intelligence service
   - Deploy the .NET isolated function
   - Update `azure_function_service.dart` with your function URL and key

4. **Run the Application**
   ```bash
   flutter run
   ```

### Firebase Configuration

Update `lib/firebase_options.dart` with your Firebase project details:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'your-android-api-key',
  appId: 'your-android-app-id',
  messagingSenderId: 'your-messaging-sender-id',
  projectId: 'your-project-id',
  storageBucket: 'your-project-id.appspot.com',
);
```

### Azure Function Configuration

Update the Azure Function service configuration in `lib/services/azure_function_service.dart`:

```dart
final AzureFunctionService _azureFunctionService = AzureFunctionService(
  baseUrl: 'https://your-function-app.azurewebsites.net/api',
  functionKey: 'your-function-key',
);
```

## Usage

1. **Registration**: Create an account with your ice cream parlour's tenant ID
2. **Login**: Sign in with your credentials
3. **Scan Invoices**: Use the camera to scan invoice images
4. **View Processing**: Watch real-time status updates as AI extracts data
5. **Review Data**: View extracted invoice information and make corrections if needed
6. **Generate Reports**: Access day-wise and month-wise financial reports

## Data Flow

1. User scans invoice with camera
2. Image is uploaded to Firebase Storage
3. Invoice document created in Firestore with "pending" status
4. Azure Function is called with image URL
5. Azure Document Intelligence processes the image
6. Extracted data is written back to Firestore
7. App watches for status updates and displays results
8. Reports aggregate completed invoice data

## Dependencies

### Core Dependencies
- `firebase_core` - Firebase SDK initialization
- `firebase_auth` - User authentication
- `cloud_firestore` - NoSQL database
- `firebase_storage` - File storage
- `provider` - State management
- `camera` - Camera functionality
- `image_picker` - Image selection
- `image_cropper` - Image editing
- `http` - HTTP client for API calls

### UI Dependencies
- `fl_chart` - Charts and graphs
- `cached_network_image` - Image caching
- `flutter_spinkit` - Loading animations
- `intl` - Internationalization

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the Flutter and Firebase documentation
