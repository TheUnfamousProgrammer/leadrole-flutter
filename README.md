# 🎬 LeadRole Flutter

LeadRole Flutter is the **cross‑platform mobile app** for the LeadRole AI filmmaking ecosystem - built with **Flutter** to deliver lightning‑fast, beautiful, and cinematic experiences on both Android and iOS.

---

## 🧭 Overview

This app enables creators to build, monitor, and manage their AI‑generated productions from anywhere.  
It integrates directly with the LeadRole backend to handle persona setup, video scene creation, voiceover synthesis, and real‑time production tracking.

> 🔗 Backend: [LeadRole System (Node.js)](https://github.com/TheUnfamousProgrammer/leadrole-system)

---

## ⚙️ Core Stack

| Layer            | Technologies                            |
| ---------------- | --------------------------------------- |
| Framework        | **Flutter 3.22+**                       |
| State Management | **Riverpod + Provider**                 |
| Networking       | **Dio**                                 |
| Routing          | **GoRouter**                            |
| Persistence      | **Shared Preferences / Secure Storage** |
| Video Player     | **video_player**                        |
| Platform         | **Android / iOS (single codebase)**     |

---

## 🏗️ Project Structure

```
lib/
 ├── core/
 │   ├── widgets/                 # Shared widgets (neon glow, curved headers, etc.)
 │   │   ├── curved_neon_header.dart
 │   │   └── neon_glow.dart
 │   └── router.dart              # Centralized route definitions
 │
 ├── features/
 │   ├── auth/                    # Authentication flow
 │   │   ├── logic/
 │   │   │   ├── auth_providers.dart
 │   │   │   └── auth_repository.dart
 │   │   ├── auth_controller.dart
 │   │   ├── auth_email_password_screen.dart
 │   │   ├── auth_state.dart
 │   │
 │   ├── dashboard/               # Main user home/dashboard
 │   │   └── dashboard_screen.dart
 │   │
 │   ├── jobs/                    # Production jobs & monitoring
 │   │   ├── data/
 │   │   │   └── job_models.dart
 │   │   ├── logic/
 │   │   │   └── job_wizard_providers.dart
 │   │   ├── ui/
 │   │   │   ├── wizard/
 │   │   │   │   ├── scene_step.dart
 │   │   │   │   ├── narration_step.dart
 │   │   │   │   └── review_step.dart
 │   │   │   ├── job_status_screen.dart
 │   │   │   ├── job_status_mock.dart
 │   │   │   └── discover_tab.dart
 │   │   ├── jobs_repository.dart
 │   │   └── my_productions_tab.dart
 │   │
 │   ├── onboarding/
 │   │   ├── onboarding_controller.dart
 │   │   └── onboarding_screen.dart
 │   │
 │   ├── persona/                 # Persona creation wizard
 │   │   ├── scenes/
 │   │   │   ├── appearance.dart
 │   │   │   ├── consent.dart
 │   │   │   └── face_kit.dart
 │   │   ├── widgets/
 │   │   │   ├── film_notes.dart
 │   │   │   ├── inputs.dart
 │   │   │   ├── neon_glow_avatar.dart
 │   │   │   ├── wizard_footer.dart
 │   │   │   └── wizard_header.dart
 │   │   ├── persona_controller.dart
 │   │   ├── persona_form_screen.dart
 │   │   ├── persona_model.dart
 │   │   └── persona_repository.dart
 │   │
 │   ├── splash/
 │   │   └── splash_screen.dart
 │   │
 │   └── terms/
 │       └── terms_screen.dart
 │
 ├── shared/                      # Global utilities and shared logic
 │   ├── api_client.dart
 │   ├── colors.dart
 │   ├── constants.dart           # Contains AppConfig and API constants
 │
 ├── app_theme.dart               # Centralized theme (neon-based)
 ├── firebase_options.dart
 └── main.dart                    # Entry point
```

---

## 🔐 Authentication & Persistence

- Email/password authentication integrated with `/api/auth/*`
- Session state handled through Riverpod providers
- Secure token storage managed locally
- Persona verification handled via `/api/persona/get/:id`

---

## 🎞️ Guided Cinematic Creation Wizard

Four-step guided process for AI film creation:

1. **Scene Setup** - Choose your base scene and tone
2. **Narration** - Configure or auto‑generate a voiceover
3. **Review** - Final preview before rendering
4. **Creating** - Begins rendering and monitors pipeline in real time

Each step is reactive, powered by Riverpod providers and synchronized with backend job APIs.

---

## 🧩 Production Monitor

The production monitor visualizes each stage of AI video creation, including:

- 🎥 Base video (Luma)
- 🎭 Face casting
- 🎙️ Voiceover synthesis
- 🔊 Lip‑sync pass
- ✨ Final watermarking

Animated progress and dynamic log updates keep the user informed in real time.

---

## 🚀 Getting Started (Local Setup)

### 1. Clone and Install

```bash
git clone https://github.com/leadrole-ai/leadrole-flutter.git
cd leadrole-flutter
flutter pub get
```

### 2. Environment Setup

Update the constants file located at `lib/shared/constants.dart`:

```dart
class AppConfig {
  static const apiBase = 'http://localhost:3000/';
  static const cloudinaryCloudName = '';
  static const cloudinaryUnsignedPreset = '';
}
```

### 3. Run Locally

```bash
flutter run
```

---

## 🤝 Linked Repositories

| Repo                                                                                    | Description                                                           |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| [LeadRole System](https://github.com/TheUnfamousProgrammer/leadrole-system)             | Node.js + Firestore backend for persona, job, and media orchestration |
| [LeadRole React Native](https://github.com/TheUnfamousProgrammer/leadrole-react-native) | Expo-based mobile client with similar functionality                   |
| **LeadRole Flutter** (this)                                                             | Flutter-based cross-platform client                                   |

---

## 🧑‍💻 Contributor

**Mouhib Amin** - [@TheUnfamousProgrammer](https://github.com/TheUnfamousProgrammer)

---

## 🪄 License

**MIT License © 2025 LeadRole**
