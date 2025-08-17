/// Comprehensive input validation service for the application
class ValidationService {
  
  // Common validation patterns
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
  );
  
  static final RegExp _passwordPattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');
  
  static final RegExp _namePattern = RegExp(r'^[a-zA-ZäöüÄÖÜßñçéàè\s\-\.]{1,50}$');
  
  static final RegExp _durationPattern = RegExp(r'^\d+$');
  
  // Text length limits
  static const int maxNameLength = 50;
  static const int maxBioLength = 500;
  static const int maxNotesLength = 2000;
  static const int maxActivityNameLength = 100;
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  
  /// Validate email address
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Email address is required';
    }
    
    final trimmed = email.trim();
    if (trimmed.length > 254) {
      return 'Email address is too long';
    }
    
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Invalid email address';
    }
    
    return null;
  }
  
  /// Validate password
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters long';
    }
    
    if (password.length > maxPasswordLength) {
      return 'Password is too long (max. $maxPasswordLength characters)';
    }
    
    if (!_passwordPattern.hasMatch(password)) {
      return 'Password must contain at least one letter and one number';
    }
    
    return null;
  }
  
  /// Validate confirm password
  static String? validateConfirmPassword(String? password, String? confirmPassword) {
    final passwordError = validatePassword(password);
    if (passwordError != null) return passwordError;
    
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Password confirmation is required';
    }
    
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    
    return null;
  }
  
  /// Validate name (user names, activity names, etc.)
  static String? validateName(String? name, {String fieldName = 'Name'}) {
    if (name == null || name.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    final trimmed = name.trim();
    if (trimmed.length > maxNameLength) {
      return '$fieldName is too long (max. $maxNameLength characters)';
    }
    
    if (!_namePattern.hasMatch(trimmed)) {
      return '$fieldName contains invalid characters';
    }
    
    return null;
  }
  
  /// Validate bio text
  static String? validateBio(String? bio) {
    if (bio == null) return null; // Bio is optional
    
    final trimmed = bio.trim();
    if (trimmed.length > maxBioLength) {
      return 'Bio is too long (max. $maxBioLength characters)';
    }
    
    return null;
  }
  
  /// Validate notes text
  static String? validateNotes(String? notes) {
    if (notes == null) return null; // Notes are optional
    
    final trimmed = notes.trim();
    if (trimmed.length > maxNotesLength) {
      return 'Notes too long (max. $maxNotesLength characters)';
    }
    
    return null;
  }
  
  /// Validate activity name
  static String? validateActivityName(String? activityName) {
    if (activityName == null || activityName.trim().isEmpty) {
      return 'Activity name is required';
    }
    
    final trimmed = activityName.trim();
    if (trimmed.length > maxActivityNameLength) {
      return 'Activity name is too long (max. $maxActivityNameLength characters)';
    }
    
    // Allow more characters for activity names
    if (trimmed.contains(RegExp(r'[<>&\\]'))) {
      return 'Activity name contains invalid characters';
    }
    
    return null;
  }
  
  /// Validate duration (in minutes)
  static String? validateDuration(String? duration) {
    if (duration == null || duration.trim().isEmpty) {
      return null; // Duration is optional
    }
    
    final trimmed = duration.trim();
    if (!_durationPattern.hasMatch(trimmed)) {
      return 'Duration must be a whole number';
    }
    
    final value = int.tryParse(trimmed);
    if (value == null) {
      return 'Invalid duration';
    }
    
    if (value < 0) {
      return 'Duration cannot be negative';
    }
    
    if (value > 1440) { // 24 hours in minutes
      return 'Duration cannot exceed 24 hours';
    }
    
    return null;
  }
  
  /// Validate required field (generic)
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
  
  /// Validate text length
  static String? validateLength(String? value, {
    required int maxLength,
    int minLength = 0,
    String fieldName = 'Field'
  }) {
    if (value == null) return null;
    
    final trimmed = value.trim();
    if (trimmed.length < minLength) {
      return '$fieldName must be at least $minLength characters long';
    }
    
    if (trimmed.length > maxLength) {
      return '$fieldName is too long (max. $maxLength characters)';
    }
    
    return null;
  }
  
  /// Sanitize input text (remove potentially dangerous characters)
  static String sanitizeInput(String? input) {
    if (input == null) return '';
    
    return input
        .trim()
        .replaceAll(RegExp(r'[<>&\\]'), '') // Remove HTML/JS injection chars
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
  }
  
  /// Validate and sanitize input in one step
  static ValidationResult validateAndSanitize(String? input, {
    required int maxLength,
    int minLength = 0,
    String fieldName = 'Field',
    bool required = false,
  }) {
    if (required) {
      final requiredError = validateRequired(input, fieldName);
      if (requiredError != null) {
        return ValidationResult(error: requiredError);
      }
    }
    
    final lengthError = validateLength(input, 
      maxLength: maxLength, 
      minLength: minLength, 
      fieldName: fieldName
    );
    if (lengthError != null) {
      return ValidationResult(error: lengthError);
    }
    
    final sanitized = sanitizeInput(input);
    return ValidationResult(value: sanitized);
  }
  
  /// Create form validator function for TextFormField
  static String? Function(String?) createValidator({
    required String fieldName,
    bool required = false,
    int? maxLength,
    int? minLength,
    String? Function(String?)? customValidator,
  }) {
    return (String? value) {
      if (required) {
        final requiredError = validateRequired(value, fieldName);
        if (requiredError != null) return requiredError;
      }
      
      if (maxLength != null || minLength != null) {
        final lengthError = validateLength(
          value,
          maxLength: maxLength ?? 1000,
          minLength: minLength ?? 0,
          fieldName: fieldName,
        );
        if (lengthError != null) return lengthError;
      }
      
      if (customValidator != null) {
        return customValidator(value);
      }
      
      return null;
    };
  }
}

/// Result of validation and sanitization
class ValidationResult {
  final String? value;
  final String? error;
  
  ValidationResult({this.value, this.error});
  
  bool get isValid => error == null;
  bool get hasError => error != null;
}