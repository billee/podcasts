# Design Document

## Overview

The profile date formatting feature will ensure that all date fields in the user profile view display in a user-friendly format. The current implementation has a date detection mechanism that is not reliably identifying all date fields, particularly the "Created At" field.

## Architecture

The solution will enhance the existing date formatting system in the ProfileView widget by:

1. **Improved Date Field Detection**: Create a more robust mechanism to identify date fields
2. **Centralized Date Formatting**: Ensure the existing `_formatUserFriendlyDate` method is consistently applied
3. **Field Name Standardization**: Handle various field name formats and casing

## Components and Interfaces

### ProfileView Widget Enhancement

**Current Components:**
- `_buildInfoRowWithDateFormatting()` - Handles field display with date detection
- `_formatUserFriendlyDate()` - Converts dates to user-friendly format
- `_getLogicallyOrderedFields()` - Defines field display order

**Enhanced Components:**
- `_isDateField()` - New dedicated method for reliable date field detection
- `_getDateFieldNames()` - Centralized list of all date field identifiers
- Enhanced `_buildInfoRowWithDateFormatting()` - Uses improved detection logic

### Date Field Detection Strategy

**Multi-layered Detection:**
1. **Field Key Matching**: Direct comparison with known date field names
2. **Label Text Analysis**: Pattern matching on formatted field labels
3. **Value Type Inspection**: Check if value is Timestamp, DateTime, or date string
4. **Field Name Patterns**: Regex patterns for common date field naming conventions

## Data Models

### Date Field Configuration

```dart
class DateFieldConfig {
  static const List<String> dateFieldKeys = [
    'createdAt', 'created_at', 'created',
    'emailVerified', 'email_verified', 'emailVerifiedAt',
    'lastUpdated', 'last_updated', 'updatedAt'
  ];
  
  static const List<String> dateFieldPatterns = [
    'created', 'verified', 'updated', 'date', 'time', 'at'
  ];
}
```

### Date Formatting Rules

```dart
enum DateDisplayFormat {
  today,      // "Today at HH:MM"
  yesterday,  // "Yesterday at HH:MM"
  recent,     // "X days ago"
  standard    // "DD/MM/YYYY"
}
```

## Error Handling

### Date Parsing Failures
- **Fallback Strategy**: Display original value if date parsing fails
- **Logging**: Log parsing errors for debugging
- **Graceful Degradation**: Never crash the UI due to date formatting issues

### Invalid Date Values
- **Null Handling**: Display "N/A" for null or empty date values
- **Invalid Formats**: Attempt multiple parsing strategies before fallback
- **Type Safety**: Handle various input types (Timestamp, String, DateTime)

## Testing Strategy

### Unit Tests
- Test date field detection with various field names and formats
- Test date formatting with different time ranges (today, yesterday, weeks ago, months ago)
- Test error handling with invalid date values
- Test fallback behavior when date parsing fails

### Integration Tests
- Test complete profile view rendering with mixed date and non-date fields
- Test field ordering with date formatting applied
- Test user interaction scenarios (edit mode, view mode)

### Test Data Scenarios
- Recent dates (today, yesterday, this week)
- Older dates (months ago, years ago)
- Edge cases (null values, invalid formats, future dates)
- Various field naming conventions (camelCase, snake_case, mixed)

## Implementation Plan

### Phase 1: Enhanced Date Detection
1. Create `_isDateField()` method with comprehensive detection logic
2. Define centralized list of date field identifiers
3. Implement value type inspection for automatic detection

### Phase 2: Robust Date Formatting
1. Enhance `_formatUserFriendlyDate()` with better error handling
2. Add support for various input date formats
3. Implement consistent fallback behavior

### Phase 3: Integration and Testing
1. Update `_buildInfoRowWithDateFormatting()` to use new detection method
2. Add comprehensive unit tests for date detection and formatting
3. Test with real user profile data to ensure reliability

## Design Decisions

### Why Multi-layered Detection?
- **Reliability**: Different data sources may use different field naming conventions
- **Flexibility**: Handles both programmatic field names and user-friendly labels
- **Future-proof**: Can easily accommodate new date fields without code changes

### Why Centralized Configuration?
- **Maintainability**: Single source of truth for date field definitions
- **Consistency**: Ensures all date fields are handled uniformly
- **Extensibility**: Easy to add new date field types

### Why Graceful Fallback?
- **User Experience**: Never break the UI due to date formatting issues
- **Debugging**: Preserve original values for troubleshooting
- **Robustness**: Handle unexpected data formats gracefully