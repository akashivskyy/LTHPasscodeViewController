//
//  PasscodeViewController.h
//  LTHPasscodeViewController
//
//  Created by Roland Leth on 9/6/13.
//  Copyright (c) 2013 Roland Leth. All rights reserved.
//

@import LocalAuthentication;
@import UIKit;

@protocol LTHPasscodeViewControllerDataSource;
@protocol LTHPasscodeViewControllerDelegate;

/// Mode of @c LTHPasscodeViewController.
typedef NS_ENUM(NSUInteger, LTHPasscodeViewControllerMode) {
    LTHPasscodeViewControllerModeUnlock,
    LTHPasscodeViewControllerModeEnable,
    LTHPasscodeViewControllerModeChange,
    LTHPasscodeViewControllerModeDisable
};

/// The passcode view controller.
@interface LTHPasscodeViewController : UIViewController

// MARK: Initialization

/// Initialize with a mode.
- (nonnull instancetype)initWithMode:(LTHPasscodeViewControllerMode)mode NS_DESIGNATED_INITIALIZER;

/// Unavailable initializer.
- (instancetype)init NS_UNAVAILABLE;

/// Unavailable initializer.
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

/// Unavailable initializer.
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

// MARK: Configuration

/// The data source.
@property (nullable, nonatomic, weak) id<LTHPasscodeViewControllerDataSource> dataSource;

/// The delegate.
@property (nullable, nonatomic, weak) id<LTHPasscodeViewControllerDelegate> delegate;

/// The number of digits for the simple passcode. Default is @c 4, or the length of the passcode, if one exists.
@property (nonatomic, assign) NSInteger digitsCount;

/// The character for the passcode digit.
@property (nonnull, nonatomic, strong) NSString *passcodeCharacter;

/// The maximum number of failed attempts allowed.
@property (nonatomic, assign) NSInteger maxNumberOfAllowedFailedAttempts;

/// A Boolean value that indicates whether the right bar button is hidden (@c YES) or not (@c NO). Default is @c YES.
@property (nonatomic, assign) BOOL hidesCancelButton;

// MARK: Strings

/// "Enter your passcode" string.
@property (nonnull, nonatomic, strong) NSString *enterPasscodeString;

/// "Enter your old passcode" string.
@property (nonnull, nonatomic, strong) NSString *enterOldPasscodeString;

/// "Enter your new passcode" string.
@property (nonnull, nonatomic, strong) NSString *enterNewPasscodeString;

/// "Enable passcode" string.
@property (nonnull, nonatomic, strong) NSString *enablePasscodeString;

/// "Change passcode" string.
@property (nonnull, nonatomic, strong) NSString *changePasscodeString;

/// "Disable passcode" string.
@property (nonnull, nonatomic, strong) NSString *disablePasscodeString;

/// "Re-enter your passcode" string.
@property (nonnull, nonatomic, strong) NSString *reenterPasscodeString;

/// "Re-enter your new passcode" string.
@property (nonnull, nonatomic, strong) NSString *reenterNewPasscodeString;

/// "Failed attempts: %@" error string. Must include @c %\@.
@property (nonnull, nonatomic, strong) NSString *errorFailedAttemptsString;

/// "Cannot reuse" error string.
@property (nonnull, nonatomic, strong) NSString *errorCannotReuseString;

/// "Passwords dod not match" error string.
@property (nonnull, nonatomic, strong) NSString *errorMismatchString;

/// The string displayed while user unlocks with Biometrics.
@property (nonnull, nonatomic, strong) NSString *biometricsDetailsString;

// MARK: Spacing

/// The gap between the passcode digits. Default is @c 40 for iPhone, @c 60 for iPad.
@property (nonatomic, assign) CGFloat horizontalGap;

/// The gap between the top label and the passcode digits/field.
@property (nonatomic, assign) CGFloat verticalGap;

/// The offset between the top label and middle position.
@property (nonatomic, assign) CGFloat verticalOffset;

/// The gap between the passcode digits and the failed label.
@property (nonatomic, assign) CGFloat failedAttemptLabelGap;

/// The height for the complex passcode overlay.
@property (nonatomic, assign) CGFloat passcodeOverlayHeight;

// MARK: Appearance

/// The background color for the view.
@property (nonnull, nonatomic, strong) UIColor *backgroundColor;

/// The font for the top label.
@property (nonnull, nonatomic, strong) UIFont *labelFont;

/// The text color for the top label.
@property (nonnull, nonatomic, strong) UIColor *labelTextColor;

/// The font for the passcode digits.
@property (nonnull, nonatomic, strong) UIFont *passcodeFont;

/// The text color for the passcode digits.
@property (nonnull, nonatomic, strong) UIColor *passcodeTextColor;

/// The background color for the failed attempt label.
@property (nonnull, nonatomic, strong) UIColor *failedAttemptLabelBackgroundColor;

/// The text color for the failed attempt label.
@property (nonnull, nonatomic, strong) UIColor *failedAttemptLabelTextColor;

@end

/// Data source of @c LTHPasscodeViewController.
@protocol LTHPasscodeViewControllerDataSource <NSObject>
@required

- (nullable NSString *)getPasscodeValue;
- (void)setPasscodeValue:(nullable NSString *)passcode;
- (BOOL)allowsUnlockingWithBiometrics;

@end

/// Delegate of @c LTHPasscodeViewController.
@protocol LTHPasscodeViewControllerDelegate <NSObject>
@optional

/**
 @brief Called right before the passcode view controller will be dismissed or popped.
 */
- (void)passcodeViewControllerDidEnterCorrectPasscode:(nonnull LTHPasscodeViewController *)viewController;
/**
 @brief Called when the max number of failed attempts has been reached.
 */
- (void)passcodeViewControllerDidReachMaxNumberOfFailedAttempts:(nonnull LTHPasscodeViewController *)viewController;

@end
