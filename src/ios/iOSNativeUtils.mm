#import "qutils/ios/iOSNativeUtils.h"
#include "qutils/Macros.h"
// UIKit
#import <UIKit/UIKit.h>
#import <Photos/PHPhotoLibrary.h>
#if QUTILS_LOCATION_ENABLED == 1
#import <CoreLocation/CoreLocation.h>
#endif // QUTILS_LOCATION_ENABLED
#import "qutils/ios/QutilsViewDelegate.h"
// Firebase
#if FCM_ENABLED == 1
#import <FirebaseMessaging/FirebaseMessaging.h>
#endif // FCM_ENABLED
#ifdef SAFARI_SERVICES_ENABLED
#import <SafariServices/SafariServices.h>
#endif // SAFARI_SERVICES_ENABLED

namespace zmc
{

    static QutilsViewDelegate *m_QutilsDelegate = [[QutilsViewDelegate alloc] init];
    QList<iOSNativeUtils *> iOSNativeUtils::m_Instances = QList<iOSNativeUtils *>();

    iOSNativeUtils::iOSNativeUtils()
        : m_InstanceIndex(m_Instances.size())
        , m_IsImagePickerOpen(false)
    {
        [[NSNotificationCenter defaultCenter] addObserverForName: UIKeyboardWillHideNotification object: nil queue: nil usingBlock: ^ (NSNotification * _Nonnull note) {
            Q_UNUSED(note);
            iOSNativeUtils::emitKeyboardHeightChangedSignals(0);
        }];

        [[NSNotificationCenter defaultCenter] addObserverForName: UIKeyboardWillShowNotification object: nil queue: nil usingBlock: ^ (NSNotification * _Nonnull note) {
            const float height = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
            iOSNativeUtils::emitKeyboardHeightChangedSignals(static_cast<int>(height));
        }];

        m_Instances.append(this);
    }

    iOSNativeUtils::~iOSNativeUtils()
    {
        m_Instances[m_InstanceIndex] = nullptr;
        onAlertDialogClicked = nullptr;
        onActionSheetClicked = nullptr;

        onImagePickerControllerCancelled = nullptr;
        onImagePickerControllerFinishedPicking = nullptr;
        onKeyboardHeightChanged = nullptr;

        onPhotosAccessGranted = nullptr;
        onPhotosAccessDenied = nullptr;
    }

    void iOSNativeUtils::showAlertView(const QString &title, const QString &message, const QStringList &buttons)
    {
        UIAlertController *alert = [UIAlertController
                                    alertControllerWithTitle: [NSString stringWithUTF8String: title.toStdString().c_str()]
                                    message: [NSString stringWithUTF8String: message.toStdString().c_str()]
                                    preferredStyle: UIAlertControllerStyleAlert];

        for (auto it = buttons.constBegin(); it != buttons.constEnd(); it++) {
            const QString buttonText = (*it);
            UIAlertAction *button = [UIAlertAction
                                     actionWithTitle: [NSString stringWithUTF8String: buttonText.toStdString().c_str()]
                                     style: UIAlertActionStyleDefault
                                     handler: ^ (UIAlertAction * action) {
                                         if (onAlertDialogClicked) {
                                             NSUInteger index = [[alert actions] indexOfObject: action];
                                             onAlertDialogClicked((unsigned int)index);
                                         }
                                     }
                                     ];

            [alert addAction: button];
        }

        UIApplication *app = [UIApplication sharedApplication];
        [[[app keyWindow] rootViewController] presentViewController: alert animated: YES completion: nil];
    }

    void iOSNativeUtils::shareText(const QString &text)
    {
        NSMutableArray *activityItems = [NSMutableArray new];
        [activityItems addObject: [NSString stringWithUTF8String: text.toStdString().c_str()]];
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems: activityItems applicationActivities: nil];

        UIApplication *app = [UIApplication sharedApplication];
        [[[app keyWindow] rootViewController] presentViewController: activityVC animated: YES completion: nil];
    }

    void iOSNativeUtils::showActionSheet(const QString &title, const QString &message, const QVariantList &buttons)
    {
        UIAlertController *alert = [UIAlertController
                                    alertControllerWithTitle: [NSString stringWithUTF8String: title.toStdString().c_str()]
                                    message: [NSString stringWithUTF8String: message.toStdString().c_str()]
                                    preferredStyle: UIAlertControllerStyleActionSheet];

        for (const QVariant &button : buttons) {
            UIAlertActionStyle alertActionStyle = UIAlertActionStyleDefault;
            const QVariantMap buttonData = button.toMap();
            const QString buttonStyle = buttonData.value("type", "").toString();
            const QString buttonTitle = buttonData.value("title", "").toString();

            if (buttonStyle == "destructive") {
                alertActionStyle = UIAlertActionStyleDestructive;
            }
            else if (buttonStyle == "cancel") {
                alertActionStyle = UIAlertActionStyleCancel;
            }

            UIAlertAction *actionButton = [UIAlertAction
                                           actionWithTitle: [NSString stringWithUTF8String: buttonTitle.toStdString().c_str()]
                                           style: alertActionStyle
                                           handler: ^ (UIAlertAction * action) {
                                               if (onActionSheetClicked) {
                                                   NSUInteger index = [[alert actions] indexOfObject: action];
                                                   onActionSheetClicked((unsigned int)index);
                                               }
                                           }
                                           ];

            [alert addAction: actionButton];
        }

        UIApplication *app = [UIApplication sharedApplication];
        [[[app keyWindow] rootViewController] presentViewController: alert animated: YES completion: nil];
    }

    void iOSNativeUtils::schedulePushNotification(const QString &title, const QString &body, const int &delayInSeconds)
    {
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow: delayInSeconds];
        localNotification.alertTitle = title.toNSString();
        localNotification.alertBody = body.toNSString();
        localNotification.timeZone = [NSTimeZone defaultTimeZone];
        UIApplication *app = [UIApplication sharedApplication];
        [app scheduleLocalNotification: localNotification];
    }

    void iOSNativeUtils::dismissKeyboard()
    {
        [[UIApplication sharedApplication] sendAction: @selector(resignFirstResponder) to: nil from: nil forEvent: nil];
    }

    QString iOSNativeUtils::getFCMToken() const
    {
        QString token = "";
#if FCM_ENABLED == 1
        NSString *fcmToken = [FIRMessaging messaging].FCMToken;
        if (fcmToken) {
            token = QString::fromNSString(fcmToken);
        }
#endif // FCM_ENABLED

        return token;
    }

    void iOSNativeUtils::setApplicationIconBadgeNumber(const int &number)
    {
        [UIApplication sharedApplication].applicationIconBadgeNumber = number;
    }

    bool iOSNativeUtils::isiPad() const
    {
        return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    }

    void iOSNativeUtils::openSafari(const QString &url)
    {
#ifdef SAFARI_SERVICES_ENABLED
        SFSafariViewController *safariVC = [[SFSafariViewController alloc]initWithURL: [NSURL URLWithString: url.toNSString()] entersReaderIfAvailable: NO];

        UIApplication *app = [UIApplication sharedApplication];
        [[[app keyWindow] rootViewController] presentViewController: safariVC animated: YES completion: nil];
#else
        Q_UNUSED(url)
#endif // SAFARI_SERVICES_ENABLED
    }

    void iOSNativeUtils::requestLocationPermission()
    {
#if QUTILS_LOCATION_ENABLED == 1
        CLLocationManager *locationManager = [[CLLocationManager alloc] init];
        [locationManager requestWhenInUseAuthorization];
#endif // QUTILS_LOCATION_ENABLED
    }

    iOSNativeUtils::LocationAuthorizationStatus iOSNativeUtils::getLocationAuthorizationStatus()
    {
        LocationAuthorizationStatus authStatus = LocationAuthorizationStatus::LANone;
#if QUTILS_LOCATION_ENABLED == 1
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        if (status == kCLAuthorizationStatusDenied) {
            authStatus = LocationAuthorizationStatus::LADenied;
        }
        else if (status == kCLAuthorizationStatusRestricted) {
            authStatus = LocationAuthorizationStatus::LARestricted;
        }
        else if (status == kCLAuthorizationStatusNotDetermined) {
            authStatus = LocationAuthorizationStatus::LANotDetermined;
        }
        else if (status == kCLAuthorizationStatusAuthorizedAlways) {
            authStatus = LocationAuthorizationStatus::LAAuthorizedAlways;
        }
        else if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
            authStatus = LocationAuthorizationStatus::LAAuthorizedWhenInUse;
        }
#endif // QUTILS_LOCATION_ENABLED

        return authStatus;
    }

    void iOSNativeUtils::requestPhotosPermisson()
    {
#if QUTILS_PHOTOS_ENABLED == 1
        if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    if (onPhotosAccessGranted) {
                        onPhotosAccessGranted();
                    }
                }
                else {
                    if (onPhotosAccessDenied) {
                        onPhotosAccessDenied();
                    }
                }
            }];
        }
#endif // QUTILS_PHOTOS_ENABLED
    }

    iOSNativeUtils::PhotosAuthorizationStatus iOSNativeUtils::getPhotosAuthorizationStatus()
    {
        PhotosAuthorizationStatus authStatus = PhotosAuthorizationStatus::PANone;
#if QUTILS_LOCATION_ENABLED == 1
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusDenied) {
            authStatus = PhotosAuthorizationStatus::PADenied;
        }
        else if (status == PHAuthorizationStatusRestricted) {
            authStatus = PhotosAuthorizationStatus::PARestricted;
        }
        else if (status == PHAuthorizationStatusNotDetermined) {
            authStatus = PhotosAuthorizationStatus::PANotDetermined;
        }
        else if (status == PHAuthorizationStatusAuthorized) {
            authStatus = PhotosAuthorizationStatus::PAAuthorized;
        }
#endif // QUTILS_LOCATION_ENABLED

        return authStatus;
    }

    void iOSNativeUtils::openGallery()
    {
        m_IsImagePickerOpen = true;

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.allowsEditing = NO;
        picker.delegate = (id<UINavigationControllerDelegate, UIImagePickerControllerDelegate>)m_QutilsDelegate;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

        UIApplication *app = [UIApplication sharedApplication];
        [[[app keyWindow] rootViewController] presentViewController: picker animated: YES completion: nil];
    }

    void iOSNativeUtils::emitImagePickerFinished(QVariantMap data)
    {
        for (iOSNativeUtils *instance : m_Instances) {
            if (instance != nullptr && instance->isImagePickerOpen()) {
                instance->callImagePickerFinishedCallback(data);
                break;
            }
        }
    }

    void iOSNativeUtils::emitImagePickerCancelled()
    {
        for (iOSNativeUtils *instance : m_Instances) {
            if (instance != nullptr && instance->isImagePickerOpen()) {
                instance->callImagePickerCancelledCallback();
                break;
            }
        }
    }

    bool iOSNativeUtils::isImagePickerOpen() const
    {
        return m_IsImagePickerOpen;
    }

    void iOSNativeUtils::emitKeyboardHeightChangedSignals(int height)
    {
        for (iOSNativeUtils *instance : m_Instances) {
            if (instance) {
                instance->emitKeyboardHeightChanged(height);
            }
        }
    }

    void iOSNativeUtils::callImagePickerFinishedCallback(QVariantMap &data)
    {
        if (onImagePickerControllerFinishedPicking) {
            onImagePickerControllerFinishedPicking(data);
        }

        m_IsImagePickerOpen = false;
    }

    void iOSNativeUtils::callImagePickerCancelledCallback()
    {
        if (onImagePickerControllerCancelled) {
            onImagePickerControllerCancelled();
        }

        m_IsImagePickerOpen = false;
    }

    void iOSNativeUtils::emitKeyboardHeightChanged(int height)
    {
        if (onKeyboardHeightChanged) {
            onKeyboardHeightChanged(height);
        }
    }
}
