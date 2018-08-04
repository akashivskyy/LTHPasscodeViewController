//
//  PasscodeViewController.m
//  LTHPasscodeViewController
//
//  Created by Roland Leth on 9/6/13.
//  Copyright (c) 2013 Roland Leth. All rights reserved.
//

#import "LTHPasscodeViewController.h"

@interface LTHPasscodeViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIView      *coverView;
@property (nonatomic, strong) UIView      *animatingView;
@property (nonatomic, strong) UIView      *complexPasscodeOverlayView;
@property (nonatomic, strong) UIView      *simplePasscodeView;
@property (nonatomic, strong) UIImageView *backgroundImageView;

@property (nonatomic, strong) UITextField *passcodeTextField;
@property (nonatomic, strong) UILabel     *enterPasscodeInfoLabel;

@property (nonatomic, strong) NSMutableArray<UITextField *> *digitTextFieldsArray;

@property (nonatomic, strong) UILabel     *failedAttemptLabel;
@property (nonatomic, strong) UILabel     *enterPasscodeLabel;
@property (nonatomic, strong) UIButton    *OKButton;

@property (nonatomic, strong) NSString    *tempPasscode;
@property (nonatomic, assign) NSInteger   failedAttempts;

@property (nonatomic, assign) CGFloat     modifierForBottomVerticalGap;
@property (nonatomic, assign) CGFloat     fontSizeModifier;

@property (nonatomic, assign) BOOL        newPasscodeEqualsOldPasscode;
@property (nonatomic, assign) BOOL        passcodeAlreadyExists;
@property (nonatomic, assign) BOOL        usesKeychain;
@property (nonatomic, assign) BOOL        displayedAsModal;
@property (nonatomic, assign) BOOL        displayedAsLockScreen;
@property (nonatomic, assign) BOOL        isUsingNavBar;
@property (nonatomic, assign) BOOL        isCurrentlyOnScreen;
@property (nonatomic, assign) BOOL        isSimple; // YES by default
@property (nonatomic, assign) BOOL        isUserConfirmingPasscode;
@property (nonatomic, assign) BOOL        isUserBeingAskedForNewPasscode;
@property (nonatomic, assign) BOOL        isUserTurningPasscodeOff;
@property (nonatomic, assign) BOOL        isUserChangingPasscode;
@property (nonatomic, assign) BOOL        isUserEnablingPasscode;
@property (nonatomic, assign) BOOL        isUserSwitchingBetweenPasscodeModes; // simple/complex
@property (nonatomic, assign) BOOL        timerStartInSeconds;
@property (nonatomic, assign) BOOL        isUsingBiometrics;
@property (nonatomic, assign) BOOL        useFallbackPasscode;
@property (nonatomic, assign) BOOL        isAppNotificationsObserved;
@property (nonatomic, strong) LAContext   *biometricsContext;

@property (nonatomic, assign) NSInteger coverViewTag;
@property (nonatomic, strong) UIColor *coverViewBackgroundColor;
@property (nonatomic, strong) UIColor *enterPasscodeLabelBackgroundColor;
@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, assign) BOOL displayAdditionalInfoDuringSettingPasscode;
@property (nonatomic, strong) UIColor *passcodeBackgroundColor;
@property (nonatomic, assign) NSTimeInterval slideAnimationDuration;
@property (nonatomic, assign) NSTimeInterval lockAnimationDuration;
@property (nonatomic, assign) BOOL hidesBackButton;

@property (nonatomic, assign) LTHPasscodeViewControllerMode mode;

@end

@implementation LTHPasscodeViewController

static const NSInteger LTHMinPasscodeDigits = 4;
static const NSInteger LTHMaxPasscodeDigits = 10;

#pragma mark - Private methods
- (void)_close {
    if (_displayedAsLockScreen) [self _dismissMe];
    else [self _cancelAndDismissMe];
}

- (BOOL)_doesPasscodeExist {
    return [self _passcode].length > 0;
}

- (void)_deletePasscode {
    [self.dataSource setPasscodeValue:nil];
}

- (void)_savePasscode:(NSString *)passcode {
    [self.dataSource setPasscodeValue:passcode];
}

- (NSString *)_passcode {
    return [self.dataSource getPasscodeValue];
}


- (void)resetPasscode {
    if ([self _doesPasscodeExist]) {
        NSString *passcode = [self _passcode];
        [self _deletePasscode];
        [self _savePasscode:passcode];
    }
}

- (void)_handleBiometricsFailureAndDisableIt:(BOOL)disableBiometrics {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (disableBiometrics) {
            self.isUsingBiometrics = NO;
        }
        
        self.useFallbackPasscode = YES;
        self.animatingView.hidden = NO;

        [self _resetUI];

    });
    
    self.biometricsContext = nil;
}

- (void)_setupFingerPrint {
    if (!self.biometricsContext && [self _allowUnlockWithBiometrics] && !_useFallbackPasscode) {
        self.biometricsContext = [[LAContext alloc] init];
        
        LAPolicy policy = LAPolicyDeviceOwnerAuthenticationWithBiometrics;
        if (@available(iOS 9.0, *)) {
            policy = LAPolicyDeviceOwnerAuthentication;
        }
        
        NSError *error = nil;
        if ([self.biometricsContext canEvaluatePolicy:policy error:&error]) {
            if (error) {
                return;
            }
            
            _isUsingBiometrics = YES;
            [_passcodeTextField resignFirstResponder];
            _animatingView.hidden = YES;
            
            // Authenticate User
            [self.biometricsContext evaluatePolicy:policy
                                localizedReason:self.biometricsDetailsString
                                          reply:^(BOOL success, NSError *error) {
                                              
                                              if (error || !success) {
                                                  [self _handleBiometricsFailureAndDisableIt:false];

                                                  return;
                                              }
                                              
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  [self _dismissMe];

                                                  if ([self.delegate respondsToSelector:@selector(passcodeViewControllerDidEnterCorrectPasscode:)]) {
                                                      [self.delegate passcodeViewControllerDidEnterCorrectPasscode:self];
                                                  }

                                              });
                                              
                                              self.biometricsContext = nil;
                                          }];
        }
        else {
            [self _handleBiometricsFailureAndDisableIt:true];
        }
    }
    else {
        [self _handleBiometricsFailureAndDisableIt:true];
    }
}

- (BOOL)_allowUnlockWithBiometrics {
    return [self.dataSource allowsUnlockingWithBiometrics];
}

- (void)setDigitsCount:(NSInteger)digitsCount {
    // If a passcode exists, don't allow the changing of the number of digits.
    if ([self _doesPasscodeExist]) { return; }
    
    if (digitsCount < LTHMinPasscodeDigits) {
        digitsCount = LTHMinPasscodeDigits;
    }
    else if (digitsCount > LTHMaxPasscodeDigits) {
        digitsCount = LTHMaxPasscodeDigits;
    }
    
    _digitsCount = digitsCount;
    
    // If we haven't loaded yet, do nothing,
    // _setupDigitFields will be called in viewDidLoad.
    if (!self.isViewLoaded) { return; }
    [self _setupDigitFields];
}


#pragma mark - View life
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = _backgroundColor;
    
    _backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:_backgroundImageView];

    _failedAttempts = 0;
    _animatingView = [[UIView alloc] initWithFrame: self.view.frame];
    [self.view addSubview: _animatingView];
    
    [self _setupViews];
    [self _setupLabels];
    [self _setupOKButton];
    
    // If on first launch we have a passcode, the number of digits should equal that.
    if ([self _doesPasscodeExist]) {
        _digitsCount = [self _passcode].length;
    }
    [self _setupDigitFields];
    
    _passcodeTextField = [[UITextField alloc] initWithFrame: CGRectZero];
    _passcodeTextField.delegate = self;
    _passcodeTextField.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view setNeedsUpdateConstraints];

    switch (self.mode) {
        case LTHPasscodeViewControllerModeUnlock:
            [self _prepareAsLockScreen];
            break;
        case LTHPasscodeViewControllerModeEnable:
            [self _prepareForEnablingPasscode];
            break;
        case LTHPasscodeViewControllerModeChange:
            [self _prepareForChangingPasscode];
            break;
        case LTHPasscodeViewControllerModeDisable:
            [self _prepareForTurningOffPasscode];
            break;
    }

}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (!self.isAppNotificationsObserved) {
//        [self _addObservers];
        self.isAppNotificationsObserved = YES;
    }
    
    _animatingView.hidden = NO;

    if (!_passcodeTextField.isFirstResponder && (!_isUsingBiometrics || _isUserChangingPasscode || _isUserBeingAskedForNewPasscode || _isUserConfirmingPasscode || _isUserEnablingPasscode || _isUserSwitchingBetweenPasscodeModes || _isUserTurningPasscodeOff)) {
        [_passcodeTextField becomeFirstResponder];
        _animatingView.hidden = NO;
    }
    if (_isUsingBiometrics && !_isUserChangingPasscode && !_isUserBeingAskedForNewPasscode && !_isUserConfirmingPasscode && !_isUserEnablingPasscode && !_isUserSwitchingBetweenPasscodeModes && !_isUserTurningPasscodeOff) {
        [_passcodeTextField resignFirstResponder];
        _animatingView.hidden = _isUsingBiometrics;
    }
}


- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    _animatingView.frame = self.view.bounds;
}


- (void)viewWillDisappear:(BOOL)animated {
    // If _isCurrentlyOnScreen is true at this point,
    // it means the back button was tapped, so we need to reset.
    if ([self isMovingFromParentViewController] && _isCurrentlyOnScreen) {
        [self _close];
        return;
    }
    
    [super viewWillDisappear:animated];
    
    if (!_displayedAsModal && !_displayedAsLockScreen) {
        [self textFieldShouldEndEditing:_passcodeTextField];
    }
}


- (void)_cancelAndDismissMe {
    _isCurrentlyOnScreen = NO;
    _isUserBeingAskedForNewPasscode = NO;
    _isUserChangingPasscode = NO;
    _isUserConfirmingPasscode = NO;
    _isUserEnablingPasscode = NO;
    _isUserTurningPasscodeOff = NO;
    _isUserSwitchingBetweenPasscodeModes = NO;
    [self _resetUI];
    [_passcodeTextField resignFirstResponder];
}


- (void)_dismissMe {
    _failedAttempts = 0;
    _isCurrentlyOnScreen = NO;
    [self _resetUI];
    [_passcodeTextField resignFirstResponder];
    if (!self.displayedAsLockScreen) {
        if (self.isUserTurningPasscodeOff) {
            [self _deletePasscode];
        }
        else {
            [self _savePasscode:self.tempPasscode];
        }
    }

}

- (void)_setupViews {
    _coverView = [[UIView alloc] initWithFrame: CGRectZero];
    _coverView.backgroundColor = _coverViewBackgroundColor;
    _coverView.frame = self.view.frame;
    _coverView.userInteractionEnabled = NO;
    _coverView.tag = _coverViewTag;
    _coverView.hidden = YES;

    _complexPasscodeOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
    _complexPasscodeOverlayView.backgroundColor = [UIColor whiteColor];
    _complexPasscodeOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    
    _simplePasscodeView = [[UIView alloc] initWithFrame:CGRectZero];
    _simplePasscodeView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [_animatingView addSubview:_complexPasscodeOverlayView];
    [_animatingView addSubview:_simplePasscodeView];
}


- (void)_setupLabels {
    _enterPasscodeLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    _enterPasscodeLabel.backgroundColor = _enterPasscodeLabelBackgroundColor;
    _enterPasscodeLabel.numberOfLines = 0;
    _enterPasscodeLabel.textColor = _labelTextColor;
    _enterPasscodeLabel.font = _labelFont;
    _enterPasscodeLabel.textAlignment = NSTextAlignmentCenter;
    [_animatingView addSubview: _enterPasscodeLabel];
    
    _enterPasscodeInfoLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    _enterPasscodeInfoLabel.backgroundColor = _enterPasscodeLabelBackgroundColor;
    _enterPasscodeInfoLabel.numberOfLines = 0;
    _enterPasscodeInfoLabel.textColor = _labelTextColor;
    _enterPasscodeInfoLabel.font = _labelFont;
    _enterPasscodeInfoLabel.textAlignment = NSTextAlignmentCenter;
    _enterPasscodeInfoLabel.hidden = !_displayAdditionalInfoDuringSettingPasscode;
    [_animatingView addSubview: _enterPasscodeInfoLabel];
    
    // It is also used to display the "Passcodes did not match" error message
    // if the user fails to confirm the passcode.
    _failedAttemptLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    _failedAttemptLabel.text = @"";
    _failedAttemptLabel.numberOfLines = 0;
    _failedAttemptLabel.backgroundColor	= _failedAttemptLabelBackgroundColor;
    _failedAttemptLabel.hidden = YES;
    _failedAttemptLabel.textColor = _failedAttemptLabelTextColor;
    _failedAttemptLabel.font = _labelFont;
    _failedAttemptLabel.textAlignment = NSTextAlignmentCenter;
    [_animatingView addSubview: _failedAttemptLabel];
    
    _enterPasscodeLabel.text = _isUserChangingPasscode ? self.enterOldPasscodeString : self.enterPasscodeString;

    _enterPasscodeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _enterPasscodeInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _failedAttemptLabel.translatesAutoresizingMaskIntoConstraints = NO;
}


- (void)_setupDigitFields {
    [_digitTextFieldsArray enumerateObjectsUsingBlock:^(UITextField * _Nonnull textField, NSUInteger idx, BOOL * _Nonnull stop) {
        [textField removeFromSuperview];
    }];
    [_digitTextFieldsArray removeAllObjects];
    
    for (int i = 0; i < _digitsCount; i++) {
        UITextField *digitTextField = [self _makeDigitField];
        [_digitTextFieldsArray addObject:digitTextField];
        [_simplePasscodeView addSubview:digitTextField];
    }
    
    [self.view setNeedsUpdateConstraints];
}


- (UITextField *)_makeDigitField{
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
    field.backgroundColor = _passcodeBackgroundColor;
    field.textAlignment = NSTextAlignmentCenter;
    field.text = _passcodeCharacter;
    field.textColor = _passcodeTextColor;
    field.font = _passcodeFont;
    field.delegate = self;
    field.secureTextEntry = NO;
    field.tintColor = [UIColor clearColor];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [field setBorderStyle:UITextBorderStyleNone];
    return field;
}


- (void)_setupOKButton {
    _OKButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_OKButton setTitle:@"OK"
               forState:UIControlStateNormal];
    _OKButton.titleLabel.font = _labelFont;
    _OKButton.backgroundColor = _enterPasscodeLabelBackgroundColor;
    [_OKButton setTitleColor:_labelTextColor forState:UIControlStateNormal];
    [_OKButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    [_OKButton addTarget:self
                  action:@selector(_validateComplexPasscode)
        forControlEvents:UIControlEventTouchUpInside];
    [_complexPasscodeOverlayView addSubview:_OKButton];
    
    _OKButton.hidden = YES;
    _OKButton.translatesAutoresizingMaskIntoConstraints = NO;
}


- (void)updateViewConstraints {
    [super updateViewConstraints];
    [self.view removeConstraints:self.view.constraints];
    [_animatingView removeConstraints:_animatingView.constraints];
    
    _simplePasscodeView.hidden = !self.isSimple;
    
    _complexPasscodeOverlayView.hidden = self.isSimple;
    _passcodeTextField.hidden = self.isSimple;
    // This would make the existing text to be cleared after dismissing
    // the keyboard, then focusing the text field again.
    // When simple, the text field only acts as a proxy and is hidden anyway.
    _passcodeTextField.secureTextEntry = !self.isSimple;
    _passcodeTextField.keyboardType = self.isSimple ? UIKeyboardTypeNumberPad : UIKeyboardTypeASCIICapable;
    [_passcodeTextField reloadInputViews];
    
    if (self.isSimple) {
        [_animatingView addSubview:_passcodeTextField];
    }
    else {
        [_complexPasscodeOverlayView addSubview:_passcodeTextField];
        
        // If we come from simple state some constraints are added even if
        // translatesAutoresizingMaskIntoConstraints = NO,
        // because no constraints are added manually in that case
        [_passcodeTextField removeConstraints:_passcodeTextField.constraints];
    }
    
    // MARK: Please read
    // The controller works properly on all devices and orientations, but looks odd on iPhone's landscape.
    // Usually, lockscreens on iPhone are kept portrait-only, though. It also doesn't fit inside a modal when landscape.
    // That's why only portrait is selected for iPhone's supported orientations.
    // Modify this to fit your needs.
    
    CGFloat yOffsetFromCenter = -self.view.frame.size.height * 0.24 + _verticalOffset;
    NSLayoutConstraint *enterPasscodeConstraintCenterX =
    [NSLayoutConstraint constraintWithItem: _enterPasscodeLabel
                                 attribute: NSLayoutAttributeCenterX
                                 relatedBy: NSLayoutRelationEqual
                                    toItem: _animatingView
                                 attribute: NSLayoutAttributeCenterX
                                multiplier: 1.0f
                                  constant: 0.0f];
    NSLayoutConstraint *enterPasscodeConstraintCenterY =
    [NSLayoutConstraint constraintWithItem: _enterPasscodeLabel
                                 attribute: NSLayoutAttributeCenterY
                                 relatedBy: NSLayoutRelationEqual
                                    toItem: _animatingView
                                 attribute: NSLayoutAttributeCenterY
                                multiplier: 1.0f
                                  constant: yOffsetFromCenter];
    [self.view addConstraint: enterPasscodeConstraintCenterX];
    [self.view addConstraint: enterPasscodeConstraintCenterY];
    
    NSLayoutConstraint *enterPasscodeInfoConstraintCenterX =
    [NSLayoutConstraint constraintWithItem: _enterPasscodeInfoLabel
                                 attribute: NSLayoutAttributeCenterX
                                 relatedBy: NSLayoutRelationEqual
                                    toItem: _animatingView
                                 attribute: NSLayoutAttributeCenterX
                                multiplier: 1.0f
                                  constant: 0.0f];
    NSLayoutConstraint *enterPasscodeInfoConstraintCenterY =
    [NSLayoutConstraint constraintWithItem: _enterPasscodeInfoLabel
                                 attribute: NSLayoutAttributeCenterY
                                 relatedBy: NSLayoutRelationEqual
                                    toItem: _simplePasscodeView
                                 attribute: NSLayoutAttributeCenterY
                                multiplier: 1.0f
                                  constant: 50];
    [self.view addConstraint: enterPasscodeInfoConstraintCenterX];
    [self.view addConstraint: enterPasscodeInfoConstraintCenterY];
    
    if (self.isSimple) {
        [_digitTextFieldsArray enumerateObjectsUsingBlock:^(UITextField * _Nonnull textField, NSUInteger idx, BOOL * _Nonnull stop) {
            CGFloat constant = idx == 0 ? 0 : self.horizontalGap;
            UIView *toItem = idx == 0 ? self.simplePasscodeView : self.digitTextFieldsArray[idx - 1];
            
            NSLayoutConstraint *digitX =
            [NSLayoutConstraint constraintWithItem: textField
                                         attribute: NSLayoutAttributeLeft
                                         relatedBy: NSLayoutRelationEqual
                                            toItem: toItem
                                         attribute: NSLayoutAttributeLeft
                                        multiplier: 1.0f
                                          constant: constant];
            
            NSLayoutConstraint *top =
            [NSLayoutConstraint constraintWithItem: textField
                                         attribute: NSLayoutAttributeTop
                                         relatedBy: NSLayoutRelationEqual
                                            toItem: self.simplePasscodeView
                                         attribute: NSLayoutAttributeTop
                                        multiplier: 1.0f
                                          constant: 0];
            
            NSLayoutConstraint *bottom =
            [NSLayoutConstraint constraintWithItem: textField
                                         attribute: NSLayoutAttributeBottom
                                         relatedBy: NSLayoutRelationEqual
                                            toItem: self.simplePasscodeView
                                         attribute: NSLayoutAttributeBottom
                                        multiplier: 1.0f
                                          constant: 0];
            
            [self.view addConstraint:digitX];
            [self.view addConstraint:top];
            [self.view addConstraint:bottom];
            
            if (idx == self.digitTextFieldsArray.count - 1) {
                NSLayoutConstraint *trailing =
                [NSLayoutConstraint constraintWithItem: textField
                                             attribute: NSLayoutAttributeTrailing
                                             relatedBy: NSLayoutRelationEqual
                                                toItem: self.simplePasscodeView
                                             attribute: NSLayoutAttributeTrailing
                                            multiplier: 1.0f
                                              constant: 0];
                
                [self.view addConstraint:trailing];
            }
        }];
        
        NSLayoutConstraint *simplePasscodeViewX =
        [NSLayoutConstraint constraintWithItem: _simplePasscodeView
                                     attribute: NSLayoutAttributeCenterX
                                     relatedBy: NSLayoutRelationEqual
                                        toItem: _animatingView
                                     attribute: NSLayoutAttributeCenterX
                                    multiplier: 1.0
                                      constant: 0];
        
        NSLayoutConstraint *simplePasscodeViewY =
        [NSLayoutConstraint constraintWithItem: _simplePasscodeView
                                     attribute: NSLayoutAttributeCenterY
                                     relatedBy: NSLayoutRelationEqual
                                        toItem: _enterPasscodeLabel
                                     attribute: NSLayoutAttributeBottom
                                    multiplier: 1.0
                                      constant: _verticalGap];
        
        
        [self.view addConstraint:simplePasscodeViewX];
        [self.view addConstraint:simplePasscodeViewY];
        
    }
    else {
        NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(_passcodeTextField, _OKButton);
        
        //TODO: specify different offsets through metrics
        NSArray *constraints =
        [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-10-[_passcodeTextField]-5-[_OKButton]-10-|"
                                                options:0
                                                metrics:nil
                                                  views:viewsDictionary];
        
        [self.view addConstraints:constraints];
        
        constraints =
        [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-5-[_passcodeTextField]-5-|"
                                                options:0
                                                metrics:nil
                                                  views:viewsDictionary];
        
        [self.view addConstraints:constraints];
        
        NSLayoutConstraint *buttonY =
        [NSLayoutConstraint constraintWithItem: _OKButton
                                     attribute: NSLayoutAttributeCenterY
                                     relatedBy: NSLayoutRelationEqual
                                        toItem: _passcodeTextField
                                     attribute: NSLayoutAttributeCenterY
                                    multiplier: 1.0f
                                      constant: 0.0f];
        
        [self.view addConstraint:buttonY];
        
        NSLayoutConstraint *buttonHeight =
        [NSLayoutConstraint constraintWithItem: _OKButton
                                     attribute: NSLayoutAttributeHeight
                                     relatedBy: NSLayoutRelationEqual
                                        toItem: _passcodeTextField
                                     attribute: NSLayoutAttributeHeight
                                    multiplier: 1.0f
                                      constant: 0.0f];
        
        [self.view addConstraint:buttonHeight];
        
        NSLayoutConstraint *overlayViewLeftConstraint =
        [NSLayoutConstraint constraintWithItem: _complexPasscodeOverlayView
                                     attribute: NSLayoutAttributeLeft
                                     relatedBy: NSLayoutRelationEqual
                                        toItem: _animatingView
                                     attribute: NSLayoutAttributeLeft
                                    multiplier: 1.0f
                                      constant: 0.0f];
        
        NSLayoutConstraint *overlayViewY =
        [NSLayoutConstraint constraintWithItem: _complexPasscodeOverlayView
                                     attribute: NSLayoutAttributeCenterY
                                     relatedBy: NSLayoutRelationEqual
                                        toItem: _enterPasscodeLabel
                                     attribute: NSLayoutAttributeBottom
                                    multiplier: 1.0f
                                      constant: _verticalGap];
        
        NSLayoutConstraint *overlayViewHeight =
        [NSLayoutConstraint constraintWithItem: _complexPasscodeOverlayView
                                     attribute: NSLayoutAttributeHeight
                                     relatedBy: NSLayoutRelationEqual
                                        toItem: nil
                                     attribute: NSLayoutAttributeNotAnAttribute
                                    multiplier: 1.0f
                                      constant: _passcodeOverlayHeight];
        
        NSLayoutConstraint *overlayViewWidth =
        [NSLayoutConstraint constraintWithItem: _complexPasscodeOverlayView
                                     attribute: NSLayoutAttributeWidth
                                     relatedBy: NSLayoutRelationEqual
                                        toItem: _animatingView
                                     attribute: NSLayoutAttributeWidth
                                    multiplier: 1.0f
                                      constant: 0.0f];
        [self.view addConstraints:@[overlayViewLeftConstraint, overlayViewY, overlayViewHeight, overlayViewWidth]];
    }
    
    NSLayoutConstraint *failedAttemptLabelCenterX =
    [NSLayoutConstraint constraintWithItem: _failedAttemptLabel
                                 attribute: NSLayoutAttributeCenterX
                                 relatedBy: NSLayoutRelationEqual
                                    toItem: _animatingView
                                 attribute: NSLayoutAttributeCenterX
                                multiplier: 1.0f
                                  constant: 0.0f];
    NSLayoutConstraint *failedAttemptLabelCenterY =
    [NSLayoutConstraint constraintWithItem: _failedAttemptLabel
                                 attribute: NSLayoutAttributeCenterY
                                 relatedBy: NSLayoutRelationEqual
                                    toItem: _enterPasscodeLabel
                                 attribute: NSLayoutAttributeBottom
                                multiplier: 1.0f
                                  constant: _failedAttemptLabelGap];
    NSLayoutConstraint *failedAttemptLabelHeight =
    [NSLayoutConstraint constraintWithItem: _failedAttemptLabel
                                 attribute: NSLayoutAttributeHeight
                                 relatedBy: NSLayoutRelationEqual
                                    toItem: nil
                                 attribute: NSLayoutAttributeNotAnAttribute
                                multiplier: 1.0f
                                  constant: [_failedAttemptLabel.text sizeWithAttributes: @{NSFontAttributeName : _labelFont}].height + 6.0f];
    [self.view addConstraint:failedAttemptLabelCenterX];
    [self.view addConstraint:failedAttemptLabelCenterY];
    [self.view addConstraint:failedAttemptLabelHeight];
}

- (void)_prepareAsLockScreen {
    // In case the user leaves the app while changing/disabling Passcode.
    if (_isCurrentlyOnScreen && !_displayedAsLockScreen) {
        [self _cancelAndDismissMe];
    }
    _displayedAsLockScreen = YES;
    _isUserTurningPasscodeOff = NO;
    _isUserChangingPasscode = NO;
    _isUserConfirmingPasscode = NO;
    _isUserEnablingPasscode = NO;
    _isUserSwitchingBetweenPasscodeModes = NO;

    [self _resetUI];
    [self _setupFingerPrint];

    self.title = @"";
}


- (void)_prepareForChangingPasscode {
    _isCurrentlyOnScreen = YES;
    _displayedAsLockScreen = NO;
    _isUserTurningPasscodeOff = NO;
    _isUserChangingPasscode = YES;
    _isUserConfirmingPasscode = NO;
    _isUserEnablingPasscode = NO;

    [self _resetUI];

    self.title = self.changePasscodeString;
}


- (void)_prepareForTurningOffPasscode {
    _isCurrentlyOnScreen = YES;
    _displayedAsLockScreen = NO;
    _isUserTurningPasscodeOff = YES;
    _isUserChangingPasscode = NO;
    _isUserConfirmingPasscode = NO;
    _isUserEnablingPasscode = NO;
    _isUserSwitchingBetweenPasscodeModes = NO;

    [self _resetUI];

    self.title = self.disablePasscodeString;
}


- (void)_prepareForEnablingPasscode {
    _passcodeAlreadyExists = NO;
    _isCurrentlyOnScreen = YES;
    _displayedAsLockScreen = NO;
    _isUserTurningPasscodeOff = NO;
    _isUserChangingPasscode = NO;
    _isUserConfirmingPasscode = NO;
    _isUserEnablingPasscode = YES;
    _isUserSwitchingBetweenPasscodeModes = NO;

    [self _resetUI];

    self.title = self.enablePasscodeString;
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == _passcodeTextField) { return true; }
    
    [_passcodeTextField becomeFirstResponder];
    
    UITextPosition *end = _passcodeTextField.endOfDocument;
    UITextRange *range = [_passcodeTextField textRangeFromPosition:end toPosition:end];
    
    [_passcodeTextField setSelectedTextRange:range];
    
    return false;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    if ((!_displayedAsLockScreen && !_displayedAsModal) || (_isUsingBiometrics || !_useFallbackPasscode)) {
        return YES;
    }
    return !_isCurrentlyOnScreen;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    if ([string isEqualToString: @"\n"]) return NO;
    
    NSString *typedString = [textField.text stringByReplacingCharactersInRange: range
                                                                    withString: string];
    
    if (self.isSimple) {
        
        [_digitTextFieldsArray enumerateObjectsUsingBlock:^(UITextField * _Nonnull textField, NSUInteger idx, BOOL * _Nonnull stop) {
            textField.secureTextEntry = typedString.length > idx;
        }];
        
        if (typedString.length == _digitsCount) {
            // Make the last bullet show up
            [self performSelector: @selector(_validatePasscode:)
                       withObject: typedString
                       afterDelay: 0.15];
        }
        
        if (typedString.length > _digitsCount) return NO;
    }
    else {
        _OKButton.hidden = [typedString length] == 0;
    }
    
    return YES;
}

#pragma mark - Validation
- (void)_validateComplexPasscode {
    [self _validatePasscode:_passcodeTextField.text];
}


- (BOOL)_validatePasscode:(NSString *)typedString {
    NSString *savedPasscode = [self _passcode];
    // Entering from Settings. If savedPasscode is empty, it means
    // the user is setting a new Passcode now, or is changing his current Passcode.
    if ((_isUserChangingPasscode  || savedPasscode.length == 0) && !_isUserTurningPasscodeOff) {
        // Either the user is being asked for a new passcode, confirmation comes next,
        // either he is setting up a new passcode, confirmation comes next, still.
        // We need the !_isUserConfirmingPasscode condition, because if he's adding a new Passcode,
        // then savedPasscode is still empty and the condition will always be true, not passing this point.
        if ((_isUserBeingAskedForNewPasscode || savedPasscode.length == 0) && !_isUserConfirmingPasscode) {
            _tempPasscode = typedString;
            // The delay is to give time for the last bullet to appear
            [self performSelector:@selector(_askForConfirmationPasscode)
                       withObject:nil
                       afterDelay:0.15f];
        }
        // User entered his Passcode correctly and we are at the confirming screen.
        else if (_isUserConfirmingPasscode) {
            // User entered the confirmation Passcode incorrectly, or the passcode is the same as the old one, start over.
            _newPasscodeEqualsOldPasscode = [typedString isEqualToString:savedPasscode];
            if (![typedString isEqualToString:_tempPasscode] || _newPasscodeEqualsOldPasscode) {
                [self performSelector:@selector(_reAskForNewPasscode)
                           withObject:nil
                           afterDelay:_slideAnimationDuration];
            }
            // User entered the confirmation Passcode correctly.
            else {
                [self _dismissMe];
                if ([self.delegate respondsToSelector:@selector(passcodeViewControllerDidEnterCorrectPasscode:)]) {
                    [self.delegate passcodeViewControllerDidEnterCorrectPasscode:self];
                }
            }
        }
        // Changing Passcode and the entered Passcode is correct.
        else if ([typedString isEqualToString:savedPasscode]){
            [self performSelector:@selector(_askForNewPasscode)
                       withObject:nil
                       afterDelay:_slideAnimationDuration];
            _failedAttempts = 0;
        }
        // Acting as lockscreen and the entered Passcode is incorrect.
        else {
            [self performSelector: @selector(_denyAccess)
                       withObject: nil
                       afterDelay: _slideAnimationDuration];
            return NO;
        }
    }
    // App launch/Turning passcode off: Passcode OK -> dismiss, Passcode incorrect -> deny access.
    else {
        if ([typedString isEqualToString: savedPasscode]) {
            [self _dismissMe];
            _useFallbackPasscode = NO;
            if ([self.delegate respondsToSelector:@selector(passcodeViewControllerDidEnterCorrectPasscode:)]) {
                [self.delegate passcodeViewControllerDidEnterCorrectPasscode:self];
            }
        }
        else {
            [self performSelector: @selector(_denyAccess)
                       withObject: nil
                       afterDelay: _slideAnimationDuration];
            return NO;
        }
    }
    
    return YES;
}


#pragma mark - Actions
- (void)_askForNewPasscode {
    _isUserBeingAskedForNewPasscode = YES;
    _isUserConfirmingPasscode = NO;
    
    // Update layout considering type
    [self.view setNeedsUpdateConstraints];
    
    _failedAttemptLabel.hidden = YES;
    
    CATransition *transition = [CATransition animation];
    [self performSelector: @selector(_resetUI) withObject: nil afterDelay: 0.1f];
    [transition setType: kCATransitionPush];
    [transition setSubtype: kCATransitionFromRight];
    [transition setDuration: _slideAnimationDuration];
    [transition setTimingFunction:
     [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut]];
    [[_animatingView layer] addAnimation: transition forKey: @"swipe"];
}


- (void)_reAskForNewPasscode {
    _isUserBeingAskedForNewPasscode = YES;
    _isUserConfirmingPasscode = NO;
    _tempPasscode = @"";
    
    CATransition *transition = [CATransition animation];
    [self performSelector: @selector(_resetUIForReEnteringNewPasscode)
               withObject: nil
               afterDelay: 0.1f];
    [transition setType: kCATransitionPush];
    [transition setSubtype: kCATransitionFromRight];
    [transition setDuration: _slideAnimationDuration];
    [transition setTimingFunction:
     [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut]];
    [[_animatingView layer] addAnimation: transition forKey: @"swipe"];
}


- (void)_askForConfirmationPasscode {
    _isUserBeingAskedForNewPasscode = NO;
    _isUserConfirmingPasscode = YES;
    _failedAttemptLabel.hidden = YES;
    
    CATransition *transition = [CATransition animation];
    [self performSelector: @selector(_resetUI) withObject: nil afterDelay: 0.1f];
    [transition setType: kCATransitionPush];
    [transition setSubtype: kCATransitionFromRight];
    [transition setDuration: _slideAnimationDuration];
    [transition setTimingFunction:
     [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut]];
    [[_animatingView layer] addAnimation: transition forKey: @"swipe"];
}


- (void)_denyAccess {
    [self _resetTextFields];
    _passcodeTextField.text = @"";
    _OKButton.hidden = YES;
    
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath: @"transform.translation.x"];
    animation.duration = 0.6;
    animation.timingFunction = [CAMediaTimingFunction functionWithName: kCAAnimationLinear];
    animation.values = @[@-12, @12, @-12, @12, @-6, @6, @-3, @3, @0];
    
    [_digitTextFieldsArray enumerateObjectsUsingBlock:^(UITextField * _Nonnull textField, NSUInteger idx, BOOL * _Nonnull stop) {
        [textField.layer addAnimation:animation forKey:@"shake"];
    }];
    
    _failedAttempts++;
    
    if (_maxNumberOfAllowedFailedAttempts > 0 &&
        _failedAttempts >= _maxNumberOfAllowedFailedAttempts &&
        [self.delegate respondsToSelector:@selector(passcodeViewControllerDidReachMaxNumberOfFailedAttempts:)]) {
        [self.delegate passcodeViewControllerDidReachMaxNumberOfFailedAttempts:self];
    }
    
    NSString *translationText = [NSString stringWithFormat:self.errorFailedAttemptsString, _failedAttempts];

    // To give it some padding. Since it's center-aligned,
    // it will automatically distribute the extra space.
    // Ironically enough, I found 5 spaces to be the best looking.
    _failedAttemptLabel.text = [NSString stringWithFormat:@"%@     ", translationText];
    
    _failedAttemptLabel.layer.cornerRadius = [_failedAttemptLabel systemLayoutSizeFittingSize:CGSizeZero].height / 2;
    _failedAttemptLabel.clipsToBounds = true;
    _failedAttemptLabel.hidden = NO;
}

- (void)_resetTextFields {
    // If _allowUnlockWithBiometrics == true, but _isUsingBiometrics == false,
    // it means we're just launching, and we don't want the keyboard to show.
    if (![_passcodeTextField isFirstResponder]
        && (!([self _allowUnlockWithBiometrics] || _isUsingBiometrics) || _useFallbackPasscode)) {
        // It seems like there's a glitch with how the alert gets removed when hitting
        // cancel in the Touch ID prompt. In some cases, the keyboard is present, but invisible
        // after dismissing the alert unless we call becomeFirstResponder with a short delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.passcodeTextField becomeFirstResponder];
        });
    }
    
    [_digitTextFieldsArray enumerateObjectsUsingBlock:^(UITextField * _Nonnull textField, NSUInteger idx, BOOL * _Nonnull stop) {
        textField.secureTextEntry = NO;
    }];
}


- (void)_resetUI {
    [self _resetTextFields];
    _failedAttemptLabel.backgroundColor	= _failedAttemptLabelBackgroundColor;
    _failedAttemptLabel.textColor = _failedAttemptLabelTextColor;
    if (_failedAttempts == 0) _failedAttemptLabel.hidden = YES;
    
    _passcodeTextField.text = @"";
    if (_isUserConfirmingPasscode) {
        if (_isUserEnablingPasscode) {
            _enterPasscodeLabel.text = self.reenterPasscodeString;
            _enterPasscodeInfoLabel.hidden = YES;
        }
        else if (_isUserChangingPasscode) {
            _enterPasscodeLabel.text = self.reenterNewPasscodeString;
            _enterPasscodeInfoLabel.hidden = YES;
        }
    }
    else if (_isUserBeingAskedForNewPasscode) {
        if (_isUserEnablingPasscode || _isUserChangingPasscode) {
            _enterPasscodeLabel.text = self.enterNewPasscodeString;
            _enterPasscodeInfoLabel.hidden = YES; //hidden for changing PIN
        }
    }
    else {
        if (_isUserChangingPasscode) {
            _enterPasscodeLabel.text = self.enterOldPasscodeString;
            _enterPasscodeInfoLabel.hidden = YES;
        } else {
            _enterPasscodeLabel.text = self.enterPasscodeString;
            //hidden for enabling PIN
            _enterPasscodeInfoLabel.hidden = !(_isUserEnablingPasscode && _displayAdditionalInfoDuringSettingPasscode);
        }
    }
    
//    _enterPasscodeInfoLabel.text = LTHPasscodeViewControllerStrings(self.enterPasscodeInfoString);

    // Make sure nav bar for logout is off the screen
    if (_isUsingNavBar) {
        [self.navBar removeFromSuperview];
        self.navBar = nil;
    }
    _isUsingNavBar = NO;
    
    _OKButton.hidden = YES;
}


- (void)_resetUIForReEnteringNewPasscode {
    [self _resetTextFields];
    _passcodeTextField.text = @"";
    NSString *savedPasscode = [self _passcode];
    _enterPasscodeLabel.text = savedPasscode.length == 0
            ? self.enterPasscodeString
            : self.enterNewPasscodeString;
    _failedAttemptLabel.hidden = NO;
    _failedAttemptLabel.text = _newPasscodeEqualsOldPasscode
            ? self.errorCannotReuseString
            : self.errorMismatchString;
    _newPasscodeEqualsOldPasscode = NO;
    _failedAttemptLabel.backgroundColor = [UIColor clearColor];
    _failedAttemptLabel.layer.borderWidth = 0;
    _failedAttemptLabel.layer.borderColor = [UIColor clearColor].CGColor;
    _failedAttemptLabel.textColor = _labelTextColor;
}

- (BOOL)isSimple {
    return YES;
}

- (void)_commonInit {
    [self _loadDefaults];
}


- (void)_loadDefaults {
    [self _loadMiscDefaults];
    [self _loadStringDefaults];
    [self _loadGapDefaults];
    [self _loadFontDefaults];
    [self _loadColorDefaults];
}


- (void)_loadMiscDefaults {
    _digitsCount = LTHMinPasscodeDigits;
    _digitTextFieldsArray = [NSMutableArray new];
    _coverViewTag = 994499;
    _lockAnimationDuration = 0.25;
    _slideAnimationDuration = 0.15;
    _maxNumberOfAllowedFailedAttempts = 0;
    _usesKeychain = YES;
    _isSimple = YES;
    _displayedAsModal = YES;
    _hidesBackButton = YES;
    _hidesCancelButton = YES;
    _passcodeAlreadyExists = YES;
    _newPasscodeEqualsOldPasscode = NO;
    _passcodeCharacter = @"\u2014"; // A longer "-";
    _displayAdditionalInfoDuringSettingPasscode = NO;
}


- (void)_loadStringDefaults {
    self.enterOldPasscodeString = @"Enter your old passcode";
    self.enterPasscodeString = @"Enter your passcode";
    self.enablePasscodeString = @"Enable Passcode";
    self.changePasscodeString = @"Change Passcode";
    self.disablePasscodeString = @"Turn Off Passcode";
    self.reenterPasscodeString = @"Re-enter your passcode";
    self.reenterNewPasscodeString = @"Re-enter your new passcode";
    self.enterNewPasscodeString = @"Enter your new passcode";
    self.biometricsDetailsString = @"Unlock using Touch ID";
    self.errorFailedAttemptsString = @"Failed attempts: %@";
    self.errorCannotReuseString = @"Cannot reuse the same passcode";
    self.errorMismatchString = @"Passcodes did not match. Try again.";
}


- (void)_loadGapDefaults {
    _fontSizeModifier = 1;
    _horizontalGap = 40 * _fontSizeModifier;
    _verticalGap = 25.0f;
    _modifierForBottomVerticalGap = 3.0f;
    _failedAttemptLabelGap = _verticalGap * _modifierForBottomVerticalGap - 2.0f;
    _passcodeOverlayHeight = 40.0f;
}


- (void)_loadFontDefaults {
    _labelFont = [UIFont fontWithName: @"AvenirNext-Regular"
                                 size: 15.0 * _fontSizeModifier];
    _passcodeFont = [UIFont fontWithName: @"AvenirNext-Regular"
                                    size: 33.0 * _fontSizeModifier];
}


- (void)_loadColorDefaults {
    // Backgrounds
    _backgroundColor = [UIColor colorWithRed:0.97f green:0.97f blue:1.0f alpha:1.00f];
    _passcodeBackgroundColor = [UIColor clearColor];
    _coverViewBackgroundColor = [UIColor colorWithRed:0.97f green:0.97f blue:1.0f alpha:1.00f];
    _failedAttemptLabelBackgroundColor =  [UIColor colorWithRed:0.8f green:0.1f blue:0.2f alpha:1.000f];
    _enterPasscodeLabelBackgroundColor = [UIColor clearColor];
    
    // Text
    _labelTextColor = [UIColor colorWithWhite:0.31f alpha:1.0f];
    _passcodeTextColor = [UIColor colorWithWhite:0.31f alpha:1.0f];
    _failedAttemptLabelTextColor = [UIColor whiteColor];
}

#pragma mark - Handling rotation
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (_displayedAsLockScreen)
        return UIInterfaceOrientationMaskPortrait;
    // I'll be honest and mention I have no idea why this line of code below works.
    // Without it, if you present the passcode view as lockscreen (directly on the window)
    // and then inside of a modal, the orientation will be wrong.
    
    // If you could explain why, I'd be more than grateful :)
    return UIInterfaceOrientationMaskPortrait;
}


// All of the rotation handling is thanks to Håvard Fossli's - https://github.com/hfossli
// answer: http://stackoverflow.com/a/4960988/793916
- (void)statusBarFrameOrOrientationChanged:(NSNotification *)notification {
    /*
     This notification is most likely triggered inside an animation block,
     therefore no animation is needed to perform this nice transition.
     */
    [self rotateAccordingToStatusBarOrientationAndSupportedOrientations];
    _animatingView.frame = self.view.bounds;
}


// And to his AGWindowView: https://github.com/hfossli/AGWindowView
// Without the 'desiredOrientation' method, using showLockscreen in one orientation,
// then presenting it inside a modal in another orientation would display
// the view in the first orientation.
- (UIInterfaceOrientation)desiredOrientation {
    UIInterfaceOrientation statusBarOrientation =
    [[UIApplication sharedApplication] statusBarOrientation];
    UIInterfaceOrientationMask statusBarOrientationAsMask = UIInterfaceOrientationMaskFromOrientation(statusBarOrientation);
    if(self.supportedInterfaceOrientations & statusBarOrientationAsMask) {
        return statusBarOrientation;
    }
    else {
        if(self.supportedInterfaceOrientations & UIInterfaceOrientationMaskPortrait) {
            return UIInterfaceOrientationPortrait;
        }
        else if(self.supportedInterfaceOrientations & UIInterfaceOrientationMaskLandscapeLeft) {
            return UIInterfaceOrientationLandscapeLeft;
        }
        else if(self.supportedInterfaceOrientations & UIInterfaceOrientationMaskLandscapeRight) {
            return UIInterfaceOrientationLandscapeRight;
        }
        else {
            return UIInterfaceOrientationPortraitUpsideDown;
        }
    }
}


- (void)rotateAccordingToStatusBarOrientationAndSupportedOrientations {
    UIInterfaceOrientation orientation = [self desiredOrientation];
    CGFloat angle = UIInterfaceOrientationAngleOfOrientation(orientation);
    CGAffineTransform transform = CGAffineTransformMakeRotation(angle);
    
    [self setIfNotEqualTransform: transform];
}


- (void)setIfNotEqualTransform:(CGAffineTransform)transform {
    CGRect frame = self.view.superview.frame;
    if(!CGAffineTransformEqualToTransform(self.view.transform, transform)) {
        self.view.transform = transform;
    }
    if(!CGRectEqualToRect(self.view.frame, frame)) {
        self.view.frame = frame;
    }
}


+ (CGFloat)getStatusBarHeight {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        return [UIApplication sharedApplication].statusBarFrame.size.width;
    }
    else {
        return [UIApplication sharedApplication].statusBarFrame.size.height;
    }
}


CGFloat UIInterfaceOrientationAngleOfOrientation(UIInterfaceOrientation orientation) {
    CGFloat angle;
    
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            angle = -M_PI_2;
            break;
        case UIInterfaceOrientationLandscapeRight:
            angle = M_PI_2;
            break;
        default:
            angle = 0.0;
            break;
    }
    
    return angle;
}

UIInterfaceOrientationMask UIInterfaceOrientationMaskFromOrientation(UIInterfaceOrientation orientation) {
    return 1 << orientation;
}

- (instancetype)initWithMode:(LTHPasscodeViewControllerMode)mode {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _mode = mode;
        [self _commonInit];
    }
    return self;
}

@end
