# Campus Swap & Freecycle ♻️

## Project Overview

**Property Pulse** is a Flutter application that transforms traditional real estate browsing into an interactive exploration platform, enabling personalized property shortlisting and direct communication with sellers.

***

## ✨ Features

### Core Functionality
* **User Authentication:** Secure user sign-up and login using **Firebase Authentication**.
* **Item Listings:** Users can list items with a name, description, token cost, and image.
* **Transaction Tracking:** Mark items as "Bought" or "Sold" to automatically deduct/add tokens to user accounts and log transactions.

### Engagement & Safety
* **Item Geolocation:** Items are tagged with latitude/longitude coordinates upon listing using `geolocator`.
* **Filter & Search:** Filter listings by name, minimum/maximum token cost, and **distance in miles** from the user's current location.
* **Wishlist:** Users can add and remove items to a personal wishlist.
* **Reviews & Ratings:** Users can leave reviews and star ratings on item listings.
* **Flagging:** Users can flag inappropriate listings for review (listings are hidden if `flagCount >= 10`).

### Technical & UI
* **Cloud Storage:** Item images are uploaded and managed via **Cloudinary**.
* **Modern UI:** Clean, material-based design with a focus on readability and clear action buttons.

### Push Notifications: 
* Real-time alerts sent via **Firebase Cloud Messaging (FCM)**. Sellers receive instant notifications when a buyer "Likes" their property or interacts with their listing.

### Device Token Management: 
* Automatic registration of **unique FCM device tokens** stored in Firestore to ensure targeted message delivery.


***

## 🛠️ Tech Stack

* **Framework:** Flutter
* **Language:** Dart
* **Backend:** Google Firebase
    * **Authentication:** `firebase_auth`
    * **Database:** `cloud_firestore`
* **Third-Party APIs:**
    * **Geolocation:** `geolocator`
    * **Image Uploads:** Cloudinary (using `http` package for REST calls)
    * **Image Handling:** `image_picker`

***

## 🚀 Getting Started

### Prerequisites

Before running the app, ensure you have the following installed:

1.  **Flutter SDK** (3.0.0 or higher is recommended)
2.  **Dart SDK**
3.  **Firebase CLI**
4.  A **Firebase Project**

### 1. Project Setup

1.  Clone this repository:
    ```bash
    git clone [Your Repository URL]
    cd mad_demo_project
    ```
2.  Run `flutter pub get` to install all dependencies listed in `pubspec.yaml`.
    ```bash
    flutter pub get
    ```

### 2. Firebase & Cloudinary Configuration

1.  **Firebase Project:**
    * Create a new project in the Firebase Console.
    * Add Android, iOS, and Web apps, following the setup instructions.
    * Generate your `firebase_options.dart` file using the FlutterFire CLI:
        ```bash
        flutterfire configure
        ```
    * Enable **Firestore** and **Firebase Authentication** (Email/Password provider).

2.  **Cloud Firestore Rules:**
    Ensure your Firestore security rules allow read/write access for authenticated users to the `users`, `items`, `transactions`, and `notifications` collections. (Example simple rule for development):
    ```json
    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        match /{document=**} {
          allow read, write: if request.auth != null;
        }
      }
    }
    ```

3.  **Cloudinary:**
    * Create a Cloudinary account.
    * Replace the placeholder values in `lib/screens/add_item_screen.dart` with your actual configuration:
        ```dart
        const String CLOUDINARY_CLOUD_NAME = 'dvdfvxphf'; // Replace with your Cloud Name
        const String CLOUDINARY_UPLOAD_PRESET = 'flutter_upload'; // Replace with your Upload Preset
        ```

### 3. Run the App

Execute the following command in the project root directory:

```bash
flutter run


### Presentation link
https://docs.google.com/presentation/d/1nsXDPJfmiFyTMLDKH9bqDQsCT74UogyaeJ5lqbK6rgI/edit?slide=id.p1#slide=id.p1