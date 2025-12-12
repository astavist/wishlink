import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import GoogleMobileAds
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var wishNativeAdFactory: WishActivityNativeAdFactory?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    if let controller = window?.rootViewController as? FlutterViewController {
      let badgeChannel = FlutterMethodChannel(
        name: "app.badge", binaryMessenger: controller.binaryMessenger)
      badgeChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "clearBadge":
          DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            result(nil)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    wishNativeAdFactory = WishActivityNativeAdFactory()
    if let factory = wishNativeAdFactory {
      FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        self,
        factoryId: "wishlinkActivity",
        nativeAdFactory: factory
      )
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(
      self,
      factoryId: "wishlinkActivity"
    )
    super.applicationWillTerminate(application)
  }
}

final class WishActivityNativeAdFactory: NSObject, FLTNativeAdFactory {
  private struct Metrics {
    static let cardCornerRadius: CGFloat = 28
    static let iconSize: CGFloat = 48
    static let mediaHeight: CGFloat = 168
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 18
  }

  func createNativeAd(_ nativeAd: GADNativeAd, customOptions: [AnyHashable: Any]? = nil)
    -> GADNativeAdView {
    let adView = GADNativeAdView()
    adView.translatesAutoresizingMaskIntoConstraints = false

    let isDarkMode: Bool
    if let forced = customOptions?["isDark"] as? Bool {
      isDarkMode = forced
    } else if #available(iOS 12.0, *) {
      isDarkMode = adView.traitCollection.userInterfaceStyle == .dark
    } else {
      isDarkMode = false
    }

    let cardColor = isDarkMode
      ? UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
      : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
    let iconBackgroundColor = isDarkMode
      ? UIColor(white: 1.0, alpha: 0.2)
      : UIColor(white: 0.0, alpha: 0.1)
    let mediaBackgroundColor = isDarkMode
      ? UIColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1)
      : UIColor.white
    let primaryTextColor = isDarkMode
      ? UIColor.white
      : UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
    let secondaryTextColor = isDarkMode
      ? UIColor(white: 1.0, alpha: 0.7)
      : UIColor(red: 0.42, green: 0.42, blue: 0.42, alpha: 1)

    let cardView = UIView()
    cardView.translatesAutoresizingMaskIntoConstraints = false
    cardView.backgroundColor = cardColor
    cardView.layer.cornerRadius = Metrics.cardCornerRadius
    cardView.layer.masksToBounds = true

    cardView.layer.borderWidth = 1
    cardView.layer.borderColor = UIColor.black.withAlphaComponent(0.05).cgColor

    adView.addSubview(cardView)
    NSLayoutConstraint.activate([
      cardView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      cardView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      cardView.topAnchor.constraint(equalTo: adView.topAnchor),
      cardView.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
    ])

    let contentStack = UIStackView()
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    contentStack.axis = .vertical
    contentStack.spacing = 12
    cardView.addSubview(contentStack)

    NSLayoutConstraint.activate([
      contentStack.leadingAnchor.constraint(
        equalTo: cardView.leadingAnchor, constant: Metrics.horizontalPadding),
      contentStack.trailingAnchor.constraint(
        equalTo: cardView.trailingAnchor, constant: -Metrics.horizontalPadding),
      contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Metrics.verticalPadding),
      contentStack.bottomAnchor.constraint(
        equalTo: cardView.bottomAnchor, constant: -Metrics.verticalPadding),
    ])

    // Header
    let headerStack = UIStackView()
    headerStack.axis = .horizontal
    headerStack.alignment = .center
    headerStack.spacing = 12

    let iconBackground = UIView()
    iconBackground.translatesAutoresizingMaskIntoConstraints = false
    iconBackground.backgroundColor = iconBackgroundColor
    iconBackground.layer.cornerRadius = Metrics.iconSize / 2
    iconBackground.layer.masksToBounds = true
    NSLayoutConstraint.activate([
      iconBackground.widthAnchor.constraint(equalToConstant: Metrics.iconSize),
      iconBackground.heightAnchor.constraint(equalToConstant: Metrics.iconSize),
    ])

    let iconView = UIImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.contentMode = .scaleAspectFill
    iconBackground.addSubview(iconView)
    NSLayoutConstraint.activate([
      iconView.leadingAnchor.constraint(equalTo: iconBackground.leadingAnchor),
      iconView.trailingAnchor.constraint(equalTo: iconBackground.trailingAnchor),
      iconView.topAnchor.constraint(equalTo: iconBackground.topAnchor),
      iconView.bottomAnchor.constraint(equalTo: iconBackground.bottomAnchor),
    ])
    adView.iconView = iconView

    let advertiserStack = UIStackView()
    advertiserStack.axis = .vertical
    advertiserStack.spacing = 4

    let sponsoredBadge = UILabel()
    sponsoredBadge.text = "Sponsorlu içerik"
    sponsoredBadge.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
    sponsoredBadge.textColor = UIColor.systemOrange

    let advertiserLabel = UILabel()
    advertiserLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    advertiserLabel.textColor = UIColor.label
    advertiserLabel.numberOfLines = 1
    adView.advertiserView = advertiserLabel

    advertiserStack.addArrangedSubview(sponsoredBadge)
    advertiserLabel.textColor = primaryTextColor
    advertiserStack.addArrangedSubview(advertiserLabel)

    headerStack.addArrangedSubview(iconBackground)
    headerStack.addArrangedSubview(advertiserStack)
    headerStack.addArrangedSubview(UIView())

    contentStack.addArrangedSubview(headerStack)

    // Headline
    let headlineLabel = UILabel()
    headlineLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
    headlineLabel.numberOfLines = 3
    headlineLabel.textColor = primaryTextColor
    adView.headlineView = headlineLabel
    contentStack.addArrangedSubview(headlineLabel)

    // Media
    let mediaView = GADMediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaView.contentMode = .scaleAspectFill
    mediaView.layer.cornerRadius = 20
    mediaView.backgroundColor = mediaBackgroundColor
    mediaView.clipsToBounds = true
    NSLayoutConstraint.activate([
      mediaView.heightAnchor.constraint(equalToConstant: Metrics.mediaHeight),
    ])
    adView.mediaView = mediaView
    contentStack.addArrangedSubview(mediaView)

    // Body
    let bodyLabel = UILabel()
    bodyLabel.font = UIFont.systemFont(ofSize: 14)
    bodyLabel.textColor = secondaryTextColor
    bodyLabel.numberOfLines = 3
    adView.bodyView = bodyLabel
    contentStack.addArrangedSubview(bodyLabel)

    // CTA
    let ctaButton = UIButton(type: .system)
    ctaButton.setTitleColor(.white, for: .normal)
    ctaButton.backgroundColor = UIColor(red: 0.96, green: 0.65, blue: 0.2, alpha: 1)
    ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
    ctaButton.layer.cornerRadius = 20
    ctaButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
    ctaButton.isUserInteractionEnabled = false
    adView.callToActionView = ctaButton

    let ctaContainer = UIStackView(arrangedSubviews: [UIView(), ctaButton])
    ctaContainer.axis = .horizontal
    ctaContainer.alignment = .center
    contentStack.addArrangedSubview(ctaContainer)

    // Populate ad assets.
    headlineLabel.text = nativeAd.headline
    bodyLabel.text = nativeAd.body
    bodyLabel.isHidden = nativeAd.body == nil

    advertiserLabel.text = nativeAd.advertiser
    advertiserLabel.isHidden = nativeAd.advertiser == nil

    if let iconImage = nativeAd.icon?.image {
      iconView.image = iconImage
      iconBackground.isHidden = false
    } else {
      iconBackground.isHidden = true
    }

    if let callToAction = nativeAd.callToAction {
      ctaButton.setTitle(callToAction, for: .normal)
      ctaButton.isHidden = false
    } else {
      ctaButton.isHidden = true
    }

    adView.nativeAd = nativeAd
    return adView
  }
}
