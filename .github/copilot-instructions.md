# Copilot Instructions for Invoice Report Flutter App

<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

## Project Overview
This is a Flutter application for scanning invoices in an ice cream parlour. The app converts scanned images to structured data and stores information in a database with day-wise and month-wise reporting capabilities.

## Architecture
- **Frontend**: Flutter app with camera integration
- **Authentication**: Firebase Auth
- **Database**: Firestore (offline enabled)
- **File Storage**: Firebase Storage
- **AI Processing**: Azure Document Intelligence via Azure Functions (.NET isolated)
- **Flow**: Upload → get downloadURL → call Azure Function → watch Firestore doc status update

## Key Features
- Invoice scanning with camera
- Firebase authentication
- Offline-first data storage with Firestore
- Image upload to Firebase Storage
- Integration with Azure Functions for AI processing
- Day-wise and month-wise reporting
- Real-time status updates

## Development Guidelines
- Follow Flutter best practices and Material Design
- Use proper state management (Provider/Riverpod/Bloc)
- Implement proper error handling for network operations
- Ensure offline functionality works correctly
- Use proper image handling and optimization
- Implement proper security for Firebase integration
- Follow clean architecture principles

## Dependencies
- Firebase SDK (auth, firestore, storage)
- Camera/Image picker packages
- HTTP client for Azure Function calls
- State management solution
- UI components and styling packages
