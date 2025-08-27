# Requirements Document

## Introduction

This feature addresses the critical backend issue where the violation detection system is not returning proper FLAG patterns to the Flutter app, preventing violations from being logged to Firestore. The backend server detects violations but fails to communicate them properly to the client, breaking the entire violation tracking and user ban workflow.

## Requirements

### Requirement 1

**User Story:** As a system administrator, I want the backend server to properly return FLAG patterns when violations are detected, so that the Flutter app can log violations to Firestore and trigger appropriate user warnings.

#### Acceptance Criteria

1. WHEN the backend detects a violation in user messages THEN the system SHALL return a response containing "FLAG:" followed by the violation type
2. WHEN a violation is detected THEN the backend SHALL include the FLAG pattern in the chat response body
3. WHEN the Flutter app receives a response with FLAG patterns THEN the violation logging service SHALL successfully extract and process the violation

### Requirement 2

**User Story:** As a developer, I want to identify and fix the root cause of why FLAG patterns are not being returned, so that the violation system works as designed.

#### Acceptance Criteria

1. WHEN investigating the backend code THEN the system SHALL identify where FLAG patterns should be generated
2. WHEN violations are detected by the AI model THEN the backend SHALL ensure FLAG patterns are included in the response
3. WHEN the backend processes violation responses THEN the system SHALL not strip or filter out FLAG patterns

### Requirement 3

**User Story:** As a user, I want violations to be properly detected and logged, so that the system can track my behavior and apply appropriate consequences when necessary.

#### Acceptance Criteria

1. WHEN I send a message that violates community guidelines THEN the system SHALL log the violation to Firestore
2. WHEN violations are logged THEN the system SHALL include proper metadata (timestamp, user ID, violation type)
3. WHEN multiple violations occur THEN the system SHALL track them cumulatively for ban threshold calculations

### Requirement 4

**User Story:** As a system administrator, I want the violation system to work consistently across all deployment environments, so that user behavior is properly monitored in production.

#### Acceptance Criteria

1. WHEN the app is deployed to Render THEN the violation detection SHALL work the same as in development
2. WHEN testing the backend endpoints THEN the FLAG patterns SHALL be returned consistently
3. WHEN violations are detected in production THEN the system SHALL log them to Firestore without errors