# WishLink - The Future of Gift-Giving

<div align="center">
  <img src="assets/images/LogoBlackPNG.png" alt="WishLink Logo" width="200"/>
  
  **Social and Interactive Wish List Platform**
</div>

## About

WishLink is an innovative mobile application designed to make the gift-giving process more enjoyable, meaningful, and efficient. Adapted to the needs of the modern age, it reduces stress related to gift selection while preventing waste and strengthening social bonds, making it possible to express the love and appreciation at the core of gift-giving in a more meaningful way.

## Features

### Personalized Wish Lists
- Create wish lists through personal profiles
- Add desired products, experiences, or anything you wish to receive contributions for
- Direct guidance for gift-givers

### Social Connections
- Add friends and view their wish lists
- Friend activities that enhance social interaction
- Making the gift-giving process more organized and enjoyable

### Smart Gift Coordination (Pinning Mechanism)
- "Pin" an item from a friend's wish list
- Prevent the same gift from being purchased by multiple people
- Prevent duplicate gift purchases and reduce waste

### Surprise Protection
- Pinning action is not visible to the recipient
- Prevent spoiling the gift surprise
- Preserve the magic of the gift-giving moment

### User-Friendly Interface
- Intuitive and easy-to-use design
- Structure that everyone can easily use
- Modern and clean user experience

## Target Audience

WishLink targets everyone who gives and receives gifts:

- **Individual Users**: Those who want to receive gifts for birthdays, anniversaries, special occasions
- **Friend Groups**: Those who want to collectively buy gifts for their common friends
- **Families**: Those who want to coordinate gifts among family members
- **Special Events**: Those who want to create wish lists for special events like weddings, graduations, and baby showers

## Technical Details

### Technologies
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore
- **Platform**: iOS, Android, Web

### Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.0.0
  cloud_firestore: ^6.0.0
  firebase_auth: ^6.0.0
  font_awesome_flutter: ^10.8.0
  url_launcher: ^6.2.5
  rxdart: ^0.27.7
```

## Installation

1. **Clone the project**
   ```bash
   git clone https://github.com/yourusername/wishlink.git
   cd wishlink
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase configuration**
   - Create a new project from Firebase Console
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files
   - Enable Firestore database

4. **Run the application**
   ```bash
   flutter run
   ```

## Screenshots

The application includes the following main screens:
- **Login Screen**: User authentication
- **Home Screen**: Friend activities and wish lists
- **Profile**: Personal wish list management
- **Friends**: Friend adding and management
- **Notifications**: Activity notifications
- **Add Wish**: New wish adding form

## Future Plans

- [ ] **Mobile Application Development**: Native applications for iOS and Android
- [ ] **E-commerce Integrations**: Integration with popular e-commerce sites
- [ ] **Group Gifting Features**: Features that allow more than one person to contribute to a single large gift
- [ ] **Event-Based Lists**: Special templates and organization options for specific events
- [ ] **AI-Powered Recommendations**: Gift and list recommendations based on users' past interactions
- [ ] **WishLink Community**: Community space for sharing gift ideas and finding inspiration

## Contributing

1. Fork this repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a Pull Request

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Developer

**SAMET YILMAZ**

- Project: WishLink
- Goal: Shaping the future of gift-giving
- Technology: Flutter & Firebase

## Contact

For questions about the project:
- Email: [your-email@example.com]
- GitHub: [@yourusername]

---

<div align="center">
  <p><strong>Giving and receiving gifts with WishLink will always be an enjoyable experience!</strong></p>
</div>
