class AppFieldLimits {
  const AppFieldLimits._();

  static const int email = 80;
  static const int password = 64;
  static const int fullName = 60;
  static const int username = 30;
  static const int program = 80;
  static const int university = 80;
  static const int semesterDigits = 2;

  static const int challengeTitle = 60;
  static const int challengeDescription = 240;
  static const int challengeGoal = 80;
  static const int challengeReward = 80;
  static const int challengeReview = 400;
}

class AppValidationRules {
  const AppValidationRules._();

  static const int passwordMinLength = 6;
  static const int fullNameMinLength = 3;
  static const int usernameMinLength = 3;
  static const int shortOptionalTextMinLength = 2;

  static const int semesterMin = 1;
  static const int semesterMax = 20;

  static const int challengeTitleMinLength = 3;
  static const int challengeDescriptionMinLength = 8;
  static const int challengeGoalMinLength = 4;
  static const int challengeRewardMinLength = 4;
  static const int challengeReviewMinLength = 8;
}
