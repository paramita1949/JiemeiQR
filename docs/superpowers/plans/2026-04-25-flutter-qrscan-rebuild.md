# Flutter QRSCAN Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the uni-app/HBuilderX mobile implementation with a mainstream Flutter Android app that builds fully on GitHub Actions.

**Architecture:** Build a Flutter app with two screens: scan/parse and preview list navigation. Keep business rules in pure Dart service code so it is testable. Use a Flutter GitHub Actions workflow that bootstraps Android project files via `flutter create` and produces release APK artifact.

**Tech Stack:** Flutter, Dart, mobile_scanner, qr_flutter, GitHub Actions

---

### Task 1: Bootstrap Flutter project files

**Files:**
- Create: `flutter_app/pubspec.yaml`
- Create: `flutter_app/analysis_options.yaml`
- Create: `flutter_app/.gitignore`

- [ ] **Step 1: Define dependencies and SDK constraints in pubspec**
- [ ] **Step 2: Add base lint/analysis rules**
- [ ] **Step 3: Add Flutter gitignore for generated build outputs**

### Task 2: TDD for QR parsing and record generation

**Files:**
- Test: `flutter_app/test/qr_parser_test.dart`
- Create: `flutter_app/lib/models/qr_record.dart`
- Create: `flutter_app/lib/services/qr_parser.dart`

- [ ] **Step 1: Write failing tests for valid QR parse**
- [ ] **Step 2: Write failing tests for invalid QR parse**
- [ ] **Step 3: Write failing tests for 20-record generation and scan index**
- [ ] **Step 4: Implement minimal parser/generator logic to pass tests**

### Task 3: Build app UI flow in Flutter

**Files:**
- Create: `flutter_app/lib/main.dart`
- Create: `flutter_app/lib/screens/home_screen.dart`
- Create: `flutter_app/lib/screens/preview_screen.dart`

- [ ] **Step 1: Implement home screen with scanner action and default fallback**
- [ ] **Step 2: Connect scanner result to parser and generator service**
- [ ] **Step 3: Implement preview screen with page navigation and scan badge**

### Task 4: GitHub cloud build (mainstream Flutter)

**Files:**
- Create: `.github/workflows/flutter-android-build.yml`
- Modify/Delete: remove HBuilderX workflow/script/docs from previous approach
- Create: `docs/FLUTTER_GITHUB_BUILD.md`

- [ ] **Step 1: Add workflow_dispatch Flutter Android build job**
- [ ] **Step 2: Setup Java + Flutter and run `flutter create .` to materialize android scaffold**
- [ ] **Step 3: Run pub get, analyze, test, build apk and upload artifact**
- [ ] **Step 4: Document how to run cloud build in GitHub UI**

### Task 5: Verification and delivery notes

**Files:**
- Modify: `README` docs if needed

- [ ] **Step 1: Run any local verification commands available in current environment**
- [ ] **Step 2: Explicitly report verification limits (Flutter CLI unavailable locally)**
- [ ] **Step 3: Provide next-step checklist for first GitHub run**
