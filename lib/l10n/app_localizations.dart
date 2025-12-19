import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en', 'US'), Locale('tr', 'TR')];

  static const _localizedValues = <String, Map<String, String>>{
    // General
    'common.cancel': {'en': 'Cancel', 'tr': 'İptal'},
    'common.apply': {'en': 'Apply', 'tr': 'Uygula'},
    'common.ok': {'en': 'OK', 'tr': 'Tamam'},
    'common.save': {'en': 'Save', 'tr': 'Kaydet'},
    'common.add': {'en': 'Add', 'tr': 'Ekle'},
    'common.create': {'en': 'Create', 'tr': 'Oluştur'},
    'common.edit': {'en': 'Edit', 'tr': 'Düzenle'},
    'common.delete': {'en': 'Delete', 'tr': 'Sil'},
    'common.tryAgain': {
      'en': 'An error occurred. Please try again.',
      'tr': 'Bir hata oluştu. Lütfen tekrar deneyin.',
    },
    'common.error': {
      'en': 'Something went wrong',
      'tr': 'Bir şeyler ters gitti',
    },
    'common.loading': {'en': 'Loading...', 'tr': 'Yükleniyor...'},
    'common.backToLogin': {'en': 'Back to Login', 'tr': 'Girişe Dön'},
    'common.useDifferentAccount': {
      'en': 'Use Different Account',
      'tr': 'Farklı Hesap Kullan',
    },
    'common.viewProduct': {'en': 'View Product', 'tr': 'Ürünü Gör'},
    'common.signOut': {'en': 'Sign Out', 'tr': 'Çıkış Yap'},
    'common.language': {'en': 'Language', 'tr': 'Dil'},
    'common.languagePrompt': {'en': 'Choose language', 'tr': 'Dil seç'},
    'common.english': {'en': 'English', 'tr': 'İngilizce'},
    'common.turkish': {'en': 'Turkish', 'tr': 'Türkçe'},
    'common.linkOpenFailed': {
      'en': 'Link could not be opened',
      'tr': 'Link açılamadı',
    },
    'common.couldNotOpenLink': {
      'en': 'Could not open link',
      'tr': 'Link açılamadı',
    },
    'common.emailLabel': {'en': 'Email', 'tr': 'E-posta'},
    'common.signInToLike': {
      'en': 'Please sign in to like wishes.',
      'tr': 'Beğenmek için lütfen giriş yap.',
    },
    'common.likeFailed': {
      'en': 'Failed to update like. Try again.',
      'tr': 'Beğeni güncellenemedi. Lütfen tekrar dene.',
    },
    // Onboarding
    'onboarding.title': {
      'en': 'Create Your Personal Wish List',
      'tr': 'Kişisel Dilek Listeni Oluştur',
    },
    'onboarding.subtitle': {
      'en':
          'Add a photo, enter a price, drop a link, and organize every wish in one place.',
      'tr':
          'Fotoğraf ekle, fiyat gir, link paylaş. İsteklerini tek bir yerde topla.',
    },
    'onboarding.cta': {'en': 'Continue', 'tr': 'Devam Et'},
    'onboarding.error': {
      'en': 'We couldn\'t save your progress. Please try again.',
      'tr': 'İlerlemen kaydedilemedi. Lütfen tekrar dene.',
    },
    'onboarding.followTitle': {
      'en': 'Follow Your Friends',
      'tr': 'Arkadaşlarını Takip Et',
    },
    'onboarding.followSubtitle': {
      'en': 'Add friends, see their activity feed, and send surprise gifts.',
      'tr':
          'Arkadaş ekle, aktivitelerini akışta gör ve onlara sürpriz hediyeler gönder.',
    },
    'onboarding.skip': {'en': 'Skip', 'tr': 'Atla'},
    'onboarding.pinTitlePrefix': {
      'en': 'Like-comment wishes,',
      'tr': 'Wishleri beğen-yorumla,',
    },
    'onboarding.pinTitleHighlight': {'en': 'Gift twins', 'tr': 'piştileri'},
    'onboarding.pinTitleSuffix': {'en': 'no more.', 'tr': 'önle.'},
    'onboarding.pinSubtitle': {
      'en': 'Let friends know you\'re buying this.',
      'tr': 'Diğer arkadaşlarına bu hediyeyi alacağını göster.',
    },
    'onboarding.pinMeta': {
      'en': 'Keep notifications on',
      'tr': 'Bildirimleri açık tut',
    },
    'onboarding.hiddenTitle': {'en': 'No spoilers!', 'tr': 'Sürpriz bozulmaz!'},
    'onboarding.hiddenSubtitle': {
      'en': 'Friends likes and comments; the wish owner never sees them.',
      'tr': 'Arkadaşlar beğeni ve yorumlar yapar, wish sahibi asla görmez.',
    },
    'onboarding.hiddenMeta': {
      'en': 'Only your gift circle sees activity',
      'tr': 'Aktiviteyi sadece hediye ekibi görür',
    },
    // Reporting & Blocking
    'report.reasonLabel': {'en': 'Choose a reason', 'tr': 'Bir sebep seç'},
    'report.noteLabel': {
      'en': 'Additional details (optional)',
      'tr': 'Ek açıklama (opsiyonel)',
    },
    'report.noteHint': {
      'en': 'Tell us what happened',
      'tr': 'Ne olduğunu kısaca anlat',
    },
    'report.reasonSpam': {
      'en': 'Spam or misleading',
      'tr': 'Spam veya yanıltıcı',
    },
    'report.reasonHarassment': {
      'en': 'Harassment or hate',
      'tr': 'Taciz veya nefret',
    },
    'report.reasonInappropriate': {
      'en': 'Sexual or violent content',
      'tr': 'Uygunsuz ya da şiddet içerik',
    },
    'report.reasonMisleading': {
      'en': 'Scam or fraud',
      'tr': 'Dolandırıcılık şüphesi',
    },
    'report.reasonOther': {'en': 'Other', 'tr': 'Diğer'},
    'report.submitAction': {'en': 'Send report', 'tr': 'Şikayeti gönder'},
    'report.userTitle': {
      'en': 'Report {name}',
      'tr': '{name} kullanıcısını şikayet et',
    },
    'report.userDescription': {
      'en': 'Tell us why this profile should be reviewed.',
      'tr': 'Bu profilin neden incelenmesi gerektiğini belirt.',
    },
    'report.wishTitle': {'en': 'Report wish', 'tr': 'Wish\'i şikayet et'},
    'report.wishDescription': {
      'en': 'Flag this wish for our moderation team.',
      'tr': 'Bu wish\'i moderasyon için işaretle.',
    },
    'report.successMessage': {
      'en': 'Report sent. Thanks for helping keep Wishlink safe.',
      'tr':
          'Şikayetin gönderildi. Wishlink\'i güvenli tuttuğun için teşekkürler.',
    },
    'report.failureMessage': {
      'en': 'Could not send report. Please try again.',
      'tr': 'Şikayet gönderilemedi. Lütfen tekrar dene.',
    },
    'report.menuReportUser': {
      'en': 'Report user',
      'tr': 'Kullanıcıyı şikayet et',
    },
    'report.menuReportWish': {'en': 'Report wish', 'tr': 'Wish\'i şikayet et'},
    'block.menuBlockUser': {'en': 'Block user', 'tr': 'Kullanıcıyı engelle'},
    'block.menuUnblockUser': {'en': 'Unblock user', 'tr': 'Engeli kaldır'},
    'block.confirmTitle': {
      'en': 'Block this user?',
      'tr': 'Bu kullanıcı engellensin mi?',
    },
    'block.confirmMessage': {
      'en': 'They will no longer be able to view or interact with you.',
      'tr': 'Artık seninle etkileşime giremez ve seni göremez.',
    },
    'block.unblockConfirmTitle': {
      'en': 'Remove block?',
      'tr': 'Engeli kaldır?',
    },
    'block.unblockConfirmMessage': {
      'en': 'They will be able to interact with you again.',
      'tr': 'Tekrar etkileşime girebilir.',
    },
    'block.successMessage': {
      'en': 'User blocked.',
      'tr': 'Kullanıcı engellendi.',
    },
    'block.failureMessage': {
      'en': 'Could not block user. Please try again.',
      'tr': 'Engelleme başarısız. Lütfen tekrar dene.',
    },
    'block.unblockedMessage': {
      'en': 'Block removed.',
      'tr': 'Engel kaldırıldı.',
    },
    'block.unblockFailureMessage': {
      'en': 'Could not remove block. Please try again.',
      'tr': 'Engel kaldırılamadı. Lütfen tekrar dene.',
    },
    'block.statusBlocked': {
      'en': 'You blocked this user',
      'tr': 'Bu kullanıcıyı engelledin',
    },
    'block.infoBanner': {
      'en':
          'You blocked this user so likes, comments and other interactions are disabled.',
      'tr':
          'Bu kullanıcıyı engellediğin için beğeni, yorum vb. etkileşimler kapalı.',
    },
    'block.actionUnblock': {'en': 'Unblock', 'tr': 'Engeli kaldır'},
    'block.statusBlockedByUser': {
      'en': 'This user blocked you',
      'tr': 'Bu kullanıcı seni engelledi',
    },
    'block.blockedProfileMessage': {
      'en': 'This profile is unavailable because the user blocked you.',
      'tr': 'Bu kullanıcı seni engellediği için profil kullanılamıyor.',
    },
    'block.blockedWishMessage': {
      'en': 'You can\'t view this wish because its owner blocked you.',
      'tr': 'Sahibi seni engellediği için bu wish\'i göremezsin.',
    },
    'block.blockedByOwnerBanner': {
      'en': 'You can\'t interact with this wish because its owner blocked you.',
      'tr': 'Sahibi seni engellediği için bu wish ile etkileşim kuramazsın.',
    },
    // Settings
    'settings.title': {'en': 'Settings', 'tr': 'Ayarlar'},
    'settings.editProfile': {'en': 'Edit Profile', 'tr': 'Profili Düzenle'},
    'settings.changePassword': {
      'en': 'Change Password',
      'tr': 'Şifreyi Değiştir',
    },
    'editProfile.section.profile': {
      'en': 'Profile basics',
      'tr': 'Profil bilgileri',
    },
    'editProfile.section.profileSubtitle': {
      'en': 'Update your username and names.',
      'tr': 'Kullanıcı adını ve isimlerini güncelle.',
    },
    'editProfile.section.personal': {
      'en': 'Personal details',
      'tr': 'Kişisel detaylar',
    },
    'editProfile.section.personalSubtitle': {
      'en': 'Control how your birthday appears.',
      'tr': 'Doğum gününün nasıl görüneceğini seç.',
    },
    'editProfile.heroTitle': {'en': 'Make it yours', 'tr': 'Seni yansıtsın'},
    'editProfile.heroSubtitle': {
      'en': 'Refresh your profile photo and details.',
      'tr': 'Profil fotoğrafını ve bilgilerini yenile.',
    },
    'settings.section.account': {
      'en': 'Account & Profile',
      'tr': 'Hesap ve Profil',
    },
    'settings.section.accountSubtitle': {
      'en': 'Update your personal info and security basics.',
      'tr': 'Kişisel bilgilerini ve güvenliğini güncelle.',
    },
    'settings.section.preferences': {
      'en': 'App Preferences',
      'tr': 'Uygulama Tercihleri',
    },
    'settings.section.preferencesSubtitle': {
      'en': 'Fine-tune language, theme and vibe.',
      'tr': 'Dilini ve temayı ruh haline göre ayarla.',
    },
    'settings.section.support': {
      'en': 'Support & Legal',
      'tr': 'Destek ve Yasal',
    },
    'settings.section.supportSubtitle': {
      'en': 'Need help? These areas are on the way.',
      'tr': 'Yardım mı lazım? Bu bölümler yakında geliyor.',
    },
    'settings.adminPanel': {'en': 'Admin panel', 'tr': 'Admin paneli'},
    'settings.adminPanelSubtitle': {
      'en': 'Review reports, bans and community actions in one place.',
      'tr': 'Raporları, yasaklamaları ve topluluğu buradan yönet.',
    },
    'admin.reportsEmptyTitle': {
      'en': 'No reports yet',
      'tr': 'Henüz rapor yok',
    },
    'admin.reportsEmptySubtitle': {
      'en': 'Incoming reports from the community will appear here.',
      'tr': 'Topluluktan gelen raporlar burada görünecek.',
    },
    'admin.tabReports': {'en': 'Reports', 'tr': 'Raporlar'},
    'admin.tabUsers': {'en': 'Users', 'tr': 'Kullanıcılar'},
    'admin.tabBanned': {'en': 'Banned', 'tr': 'Yasaklılar'},
    'admin.searchReportsHint': {
      'en': 'Search reports by username',
      'tr': 'Raporları kullanıcı adına göre ara',
    },
    'admin.searchUsersHint': {
      'en': 'Search users by username',
      'tr': 'Kullanıcıları kullanıcı adına göre ara',
    },
    'admin.searchBannedHint': {
      'en': 'Search banned users by username',
      'tr': 'Yasaklı kullanıcıları kullanıcı adına göre ara',
    },
    'admin.reportsFilteredEmpty': {
      'en': 'No reports match this search',
      'tr': 'Bu aramayla eşleşen rapor yok',
    },
    'admin.usersSearchStart': {
      'en': 'Type at least 3 characters to search users.',
      'tr': 'Kullanıcı aramak için en az 3 karakter yaz.',
    },
    'admin.usersNoResults': {
      'en': 'No users found for this username',
      'tr': 'Bu kullanıcı adına sahip kullanıcı bulunamadı',
    },
    'admin.usersSearchError': {
      'en': 'Unable to search users right now. Please try again.',
      'tr': 'Kullanıcı araması şu anda yapılamıyor. Lütfen tekrar dene.',
    },
    'admin.reportDeleteOption': {'en': 'Delete report', 'tr': 'Raporu sil'},
    'admin.reportDeleteSuccess': {
      'en': 'Report deleted.',
      'tr': 'Rapor silindi.',
    },
    'admin.reportDeleteFailure': {
      'en': 'Could not delete report: {error}',
      'tr': 'Rapor silinemedi: {error}',
    },
    'admin.reportNoTargetForBan': {
      'en': 'No target user to moderate for this report.',
      'tr': 'Bu raporda yasaklanacak kullanıcı yok.',
    },
    'admin.reportActionsTooltip': {
      'en': 'Report actions',
      'tr': 'Rapor işlemleri',
    },
    'admin.bannedEmptyTitle': {
      'en': 'No banned users',
      'tr': 'Yasaklı kullanıcı yok',
    },
    'admin.bannedEmptySubtitle': {
      'en': 'Banned users will appear here.',
      'tr': 'Yasaklanan kullanıcılar burada görünecek.',
    },
    'admin.bannedFilteredEmpty': {
      'en': 'No banned users match this search',
      'tr': 'Bu aramayla eşleşen yasaklı kullanıcı yok',
    },
    'admin.userBanOption': {'en': 'Ban user', 'tr': 'Kullanıcıyı yasakla'},
    'admin.userUnbanOption': {'en': 'Remove ban', 'tr': 'Yasağı kaldır'},
    'admin.userBanSuccess': {
      'en': 'User status updated to banned.',
      'tr': 'Kullanıcı yasaklandı.',
    },
    'admin.userUnbanSuccess': {
      'en': 'User ban removed.',
      'tr': 'Kullanıcının yasağı kaldırıldı.',
    },
    'admin.userBanFailure': {
      'en': 'Could not update ban status: {error}',
      'tr': 'Yasak durumu güncellenemedi: {error}',
    },
    'admin.userActionsTooltip': {
      'en': 'Moderation actions',
      'tr': 'Moderasyon işlemleri',
    },
    'admin.reporterLabel': {'en': 'Reporter', 'tr': 'Bildirimi yapan'},
    'admin.targetLabel': {'en': 'Target', 'tr': 'Hedef'},
    'admin.detailsLabel': {'en': 'Details', 'tr': 'Detaylar'},
    'admin.reportIdLabel': {'en': 'Report ID', 'tr': 'Rapor ID'},
    'admin.userIdLabel': {'en': 'User ID', 'tr': 'Kullanıcı ID'},
    'admin.reportedAtLabel': {'en': 'Reported', 'tr': 'Rapor tarihi'},
    'admin.unknownValue': {'en': 'Unknown', 'tr': 'Bilinmiyor'},
    'admin.targetType.user': {'en': 'User', 'tr': 'Kullanıcı'},
    'admin.targetType.wish': {'en': 'Wish', 'tr': 'Wish'},
    'admin.reportDetailTitle': {
      'en': 'Report details',
      'tr': 'Rapor detayları',
    },
    'admin.targetSectionTitle': {
      'en': 'Target information',
      'tr': 'Hedef bilgileri',
    },
    'admin.preview.targetIdLabel': {'en': 'Target ID', 'tr': 'Hedef ID'},
    'admin.action.ignore': {'en': 'Ignore report', 'tr': 'Raporu yok say'},
    'admin.action.remove': {'en': 'Remove content', 'tr': 'İçeriği kaldır'},
    'admin.action.banUser': {'en': 'Ban user', 'tr': 'Kullanıcıyı yasakla'},
    'admin.action.confirmIgnore': {
      'en': 'Mark this report as ignored?',
      'tr': 'Bu rapor yok sayılsın mı?',
    },
    'admin.action.confirmRemove': {
      'en': 'Remove the reported content?',
      'tr': 'Şikayet edilen içerik kaldırılsın mı?',
    },
    'admin.action.confirmBanUser': {
      'en': 'Ban this user?',
      'tr': 'Bu kullanıcı yasaklansın mı?',
    },
    'admin.action.confirm': {'en': 'Confirm', 'tr': 'Onayla'},
    'admin.action.success': {
      'en': 'Action completed',
      'tr': 'İşlem tamamlandı',
    },
    'admin.action.failure': {
      'en': 'Could not complete action: {error}',
      'tr': 'İşlem tamamlanamadı: {error}',
    },
    'admin.targetPreviewUnavailableTitle': {
      'en': 'Preview unavailable',
      'tr': 'Önizleme kullanılamıyor',
    },
    'admin.targetPreviewUnavailableSubtitle': {
      'en': 'This content may have been removed.',
      'tr': 'Bu içerik kaldırılmış olabilir.',
    },
    'admin.targetPreviewLoadError': {
      'en': 'Unable to load target preview.',
      'tr': 'Önizleme yüklenemedi.',
    },
    'admin.targetPreviewUnknown': {
      'en': 'Unknown target',
      'tr': 'Bilinmeyen hedef',
    },
    'admin.targetPreviewUserTitle': {
      'en': 'Profile preview',
      'tr': 'Profil önizlemesi',
    },
    'admin.targetPreviewWishTitle': {
      'en': 'Wish preview',
      'tr': 'Wish önizlemesi',
    },
    'admin.preview.wishUnknownName': {
      'en': 'Untitled wish',
      'tr': 'Adsız wish',
    },
    'admin.preview.wishPriceLabel': {
      'en': 'Price {price}',
      'tr': 'Fiyat {price}',
    },
    'admin.preview.wishDescriptionLabel': {
      'en': 'Description',
      'tr': 'Açıklama',
    },
    'admin.preview.wishOwnerLabel': {'en': 'Owner ID', 'tr': 'Sahip ID'},
    'admin.preview.wishLinkLabel': {'en': 'Product link', 'tr': 'Ürün linki'},
    'admin.preview.userStatusLabel': {'en': 'Status', 'tr': 'Durum'},
    'admin.preview.userStatusBanned': {'en': 'Banned', 'tr': 'Yasaklı'},
    'admin.preview.userStatusActive': {'en': 'Active', 'tr': 'Aktif'},
    'settings.deleteAccount': {'en': 'Delete account', 'tr': 'Hesabı sil'},
    'settings.deleteAccountSubtitle': {
      'en': 'This removes your profile, wishes and saved data permanently.',
      'tr': 'Profilini, wishlerini ve kayıtlı verilerini kalıcı olarak siler.',
    },
    'settings.deleteAccountConfirmTitle': {
      'en': 'Delete your account?',
      'tr': 'Hesabını silmek istiyor musun?',
    },
    'settings.deleteAccountConfirmMessage': {
      'en':
          'All of your data including wishes, lists, notes and notifications will be removed forever. This action cannot be undone.',
      'tr':
          'Wishlerin, listelerin, notların ve bildirimlerin dahil tüm verilerin kalıcı olarak silinecek. Bu işlem geri alınamaz.',
    },
    'settings.deleteAccountConfirmAction': {
      'en': 'Delete my account',
      'tr': 'Hesabımı sil',
    },
    'settings.deleteAccountReauth': {
      'en':
          'For security reasons, please sign in again before deleting your account.',
      'tr':
          'Güvenlik nedeniyle hesabını silmeden önce lütfen tekrar giriş yap.',
    },
    'settings.reauth.passwordTitle': {
      'en': 'Confirm your password',
      'tr': 'Şifreni doğrula',
    },
    'settings.reauth.passwordMessage': {
      'en': 'Enter your password to continue.',
      'tr': 'Devam etmek için lütfen mevcut şifreni gir.',
    },
    'settings.reauth.passwordPlaceholder': {
      'en': 'Current password',
      'tr': 'Mevcut şifre',
    },
    'settings.reauth.passwordConfirm': {'en': 'Confirm', 'tr': 'Onayla'},
    'settings.reauth.passwordRequired': {
      'en': 'Password is required',
      'tr': 'Şifre gerekli',
    },
    'settings.reauth.invalidPassword': {
      'en': 'Incorrect password. Please try again.',
      'tr': 'Şifre hatalı. Lütfen tekrar dene.',
    },
    'settings.reauth.unsupportedProvider': {
      'en': 'Please sign out and sign back in before deleting your account.',
      'tr': 'Hesabını silmeden önce lütfen oturumu kapatıp tekrar giriş yap.',
    },
    'settings.reauth.genericError': {
      'en': 'Could not verify your session. Please try again.',
      'tr': 'Oturum doğrulanamadı. Lütfen tekrar dene.',
    },
    'settings.deleteAccountError': {
      'en': 'Could not delete account: {error}',
      'tr': 'Hesap silinemedi: {error}',
    },
    'settings.deleteAccountInProgress': {
      'en': 'Deleting your account...',
      'tr': 'Hesabın siliniyor...',
    },
    // Edit Profile
    'editProfile.loadFailed': {
      'en': 'Failed to load profile: {error}',
      'tr': 'Profil yüklenemedi: {error}',
    },
    'editProfile.photoPickFailed': {
      'en': 'Failed to pick image: {error}',
      'tr': 'Fotoğraf seçilemedi: {error}',
    },
    'editProfile.saveFailed': {
      'en': 'Failed to save profile: {error}',
      'tr': 'Profil kaydedilemedi: {error}',
    },
    'editProfile.usernameRequired': {
      'en': 'Please choose a username',
      'tr': 'Lütfen bir kullanıcı adı seç',
    },
    'editProfile.usernameRules': {
      'en': '3-20 characters using letters, numbers, ., _, -',
      'tr': '3-20 karakter, harf, rakam, ., _, - kullan',
    },
    'editProfile.usernameTaken': {
      'en': 'This username is already taken',
      'tr': 'Bu kullanıcı adı zaten alınmış',
    },
    'editProfile.removeSelectedPhoto': {
      'en': 'Remove selected photo',
      'tr': 'Seçilen fotoğrafı kaldır',
    },
    'editProfile.removeCurrentPhoto': {
      'en': 'Remove current photo',
      'tr': 'Mevcut fotoğrafı kaldır',
    },
    'editProfile.usernameLabel': {'en': 'Username', 'tr': 'Kullanıcı adı'},
    'editProfile.firstNameLabel': {'en': 'First name', 'tr': 'Ad'},
    'editProfile.firstNameRequired': {
      'en': 'Please enter your first name',
      'tr': 'Lütfen adını gir',
    },
    'editProfile.lastNameLabel': {'en': 'Last name', 'tr': 'Soyad'},
    'editProfile.birthDateLabel': {'en': 'Birth date', 'tr': 'Doğum tarihi'},
    'editProfile.removeBirthDate': {
      'en': 'Remove birth date',
      'tr': 'Doğum tarihini kaldır',
    },
    'editProfile.birthDateDisplayLabel': {
      'en': 'Birth date display',
      'tr': 'Doğum tarihi gösterimi',
    },
    'editProfile.birthDateOptionFull': {
      'en': 'Show day / month / year (dd.mm.yyyy)',
      'tr': 'Gün / ay / yıl göster (gg.aa.yyyy)',
    },
    'editProfile.birthDateOptionPartial': {
      'en': 'Show only day / month (dd.mm)',
      'tr': 'Sadece gün / ay göster (gg.aa)',
    },
    'editProfile.saveButton': {
      'en': 'Save changes',
      'tr': 'Değişiklikleri kaydet',
    },
    'editProfile.wishesTitle': {'en': 'My Wishes', 'tr': 'Wishlerim'},
    'editProfile.wishesEmpty': {
      'en': 'You have not added any wishes yet.',
      'tr': 'Henüz hiç wish eklemedin.',
    },
    'editProfile.editWishTooltip': {'en': 'Edit wish', 'tr': 'Wishi düzenle'},
    // Change Password
    'changePassword.updateSuccess': {
      'en': 'Password updated successfully',
      'tr': 'Şifre başarıyla güncellendi',
    },
    'changePassword.updateFailed': {
      'en': 'Failed to update password',
      'tr': 'Şifre güncellenemedi',
    },
    'changePassword.title': {'en': 'Update password', 'tr': 'Şifreni güncelle'},
    'changePassword.subtitle': {
      'en': 'Secure your account by refreshing your password.',
      'tr': 'Hesabını şifreni yenileyerek güvende tut.',
    },
    'changePassword.heroTitle': {
      'en': 'Lock things down',
      'tr': 'Her şeyi kilitle',
    },
    'changePassword.heroSubtitle': {
      'en': 'Re-enter your current password and pick a new one.',
      'tr': 'Mevcut şifreni gir ve yeni bir şifre seç.',
    },
    'changePassword.currentLabel': {
      'en': 'Current password',
      'tr': 'Mevcut şifre',
    },
    'changePassword.currentRequired': {
      'en': 'Please enter your current password',
      'tr': 'Lütfen mevcut şifreni gir',
    },
    'changePassword.newLabel': {'en': 'New password', 'tr': 'Yeni şifre'},
    'changePassword.newRequired': {
      'en': 'Please enter a new password',
      'tr': 'Lütfen yeni bir şifre gir',
    },
    'changePassword.newTooShort': {
      'en': 'Password should be at least 6 characters',
      'tr': 'Şifre en az 6 karakter olmalı',
    },
    'changePassword.confirmLabel': {
      'en': 'Confirm new password',
      'tr': 'Yeni şifreyi doğrula',
    },
    'changePassword.confirmRequired': {
      'en': 'Please confirm your new password',
      'tr': 'Lütfen yeni şifreni doğrula',
    },
    'changePassword.mismatch': {
      'en': 'Passwords do not match',
      'tr': 'Şifreler eşleşmiyor',
    },
    'changePassword.saveButton': {
      'en': 'Update password',
      'tr': 'Şifreyi güncelle',
    },
    'settings.appearance': {'en': 'Appearance', 'tr': 'Görünüm'},
    'settings.appearance.matchSystem': {
      'en': 'Match system',
      'tr': 'Sistemi takip et',
    },
    'settings.appearance.matchSystemDesc': {
      'en': 'Automatically follows your device',
      'tr': 'Cihazın temasını otomatik takip eder',
    },
    'settings.appearance.light': {'en': 'Light', 'tr': 'Açık'},
    'settings.appearance.lightDesc': {
      'en': 'Always use the light theme',
      'tr': 'Her zaman açık temayı kullan',
    },
    'settings.appearance.dark': {'en': 'Dark', 'tr': 'Koyu'},
    'settings.appearance.darkDesc': {
      'en': 'Always use the dark theme',
      'tr': 'Her zaman koyu temayı kullan',
    },
    'settings.appearance.chooseTheme': {'en': 'Choose theme', 'tr': 'Tema seç'},
    'settings.notifications': {
      'en': 'Notification Settings',
      'tr': 'Bildirim Ayarları',
    },
    'settings.notificationsComing': {
      'en': 'Notifications - Coming Soon',
      'tr': 'Bildirimler - Yakında',
    },
    'settings.notifications.lede': {
      'en': 'Choose which alerts you want WishLink to send.',
      'tr': 'WishLink\'ten almak istediğin bildirimleri seç.',
    },
    'settings.notifications.loadError': {
      'en': 'Could not load notification settings: {error}',
      'tr': 'Bildirim ayarları yüklenemedi: {error}',
    },
    'settings.notifications.pushTitle': {
      'en': 'Push notifications',
      'tr': 'Anlık bildirimler',
    },
    'settings.notifications.pushSubtitle': {
      'en': 'Allow WishLink to alert you on this device',
      'tr': 'WishLink\'in bu cihazda bildirim göndermesine izin ver',
    },
    'settings.notifications.friendRequests': {
      'en': 'Friend requests',
      'tr': 'Arkadaşlık istekleri',
    },
    'settings.notifications.friendRequestsSubtitle': {
      'en': 'Get notified when someone wants to connect with you',
      'tr': 'Biri seninle bağlantı kurmak istediğinde haber al',
    },
    'settings.notifications.friendActivity': {
      'en': 'Friend activity',
      'tr': 'Arkadaş aktiviteleri',
    },
    'settings.notifications.friendActivitySubtitle': {
      'en': 'Hear when friends share or update wishes',
      'tr': 'Arkadaşların wish paylaştığında ya da güncellediğinde haberdar ol',
    },
    'settings.notifications.tips': {
      'en': 'Inspiration & tips',
      'tr': 'İlham & ipuçları',
    },
    'settings.notifications.tipsSubtitle': {
      'en': 'Occasional ideas to keep your lists fresh',
      'tr': 'Listeni canlı tutan ara sıra öneriler al',
    },
    'settings.notifications.saving': {
      'en': 'Saving your preferences...',
      'tr': 'Tercihlerin kaydediliyor...',
    },
    'settings.notifications.saved': {
      'en': 'All changes saved',
      'tr': 'Tüm değişiklikler kaydedildi',
    },
    'settings.notifications.saveError': {
      'en': 'Could not save notification settings: {error}',
      'tr': 'Bildirim ayarları kaydedilemedi: {error}',
    },
    'settings.notifications.permissionDenied': {
      'en': 'Notifications are blocked in your device settings',
      'tr': 'Bildirim izni cihaz ayarlarında kapalı',
    },
    'settings.notifications.statusEnabled': {
      'en': 'Notifications are active',
      'tr': 'Bildirimler açık',
    },
    'settings.notifications.statusDisabled': {
      'en': 'Notifications are turned off',
      'tr': 'Bildirimler kapalı',
    },
    'settings.privacy': {'en': 'Privacy', 'tr': 'Gizlilik'},
    'settings.privacyComing': {'en': 'Privacy', 'tr': 'Gizlilik'},
    'settings.help': {'en': 'Help & Support', 'tr': 'Yardım ve Destek'},
    'settings.helpComing': {'en': 'Help & Support', 'tr': 'Yardım & Destek'},
    'settings.errorSigningOut': {
      'en': 'Error signing out',
      'tr': 'Çıkış yapılırken hata oluştu',
    },
    'settings.profileUpdated': {
      'en': 'Profile updated',
      'tr': 'Profil güncellendi',
    },
    'settings.heroSubtitle': {
      'en': 'Fine-tune how WishLink looks and feels.',
      'tr': 'WishLink deneyimini kendi stiline göre ayarla.',
    },
    'settings.signedInAs': {
      'en': 'Signed in as {email}',
      'tr': '{email} olarak giriş yaptın',
    },
    // Email verification
    'emailVerification.title': {
      'en': 'Email Verification Required',
      'tr': 'E-posta Doğrulaması Gerekli',
    },
    'emailVerification.subtitle': {
      'en':
          'To verify your account, please send a verification email to:\n{email}',
      'tr':
          'Hesabını doğrulamak için lütfen şu adrese doğrulama e-postası gönder:\n{email}',
    },
    'emailVerification.instructions': {
      'en':
          'Click the button below to send a verification email, then check your inbox and click the verification link.',
      'tr':
          'Aşağıdaki butona basarak doğrulama e-postası gönder, ardından gelen kutunu kontrol edip bağlantıya tıkla.',
    },
    'emailVerification.sendButton': {
      'en': 'Send Verification Email',
      'tr': 'Doğrulama E-postası Gönder',
    },
    'emailVerification.postSendInfo': {
      'en':
          'After sending and verifying your email, you\'ll be automatically redirected.',
      'tr':
          'E-postayı gönderip doğruladıktan sonra otomatik olarak yönlendirileceksin.',
    },
    'emailVerification.resendSuccess': {
      'en': 'Verification email resent successfully!',
      'tr': 'Doğrulama e-postası yeniden gönderildi!',
    },
    'emailVerification.resendError': {
      'en': 'Error resending email: {error}',
      'tr': 'E-posta tekrar gönderilirken hata: {error}',
    },
    // Login
    'login.validation.passwordRequired': {
      'en': 'Please enter a password',
      'tr': 'Lütfen bir şifre gir',
    },
    'login.validation.passwordTooShort': {
      'en': 'Password must be at least 6 characters',
      'tr': 'Şifre en az 6 karakter olmalı',
    },
    'login.validation.confirmPasswordRequired': {
      'en': 'Please confirm your password',
      'tr': 'Lütfen şifreni doğrula',
    },
    'login.validation.passwordsMismatch': {
      'en': 'Passwords do not match',
      'tr': 'Şifreler eşleşmiyor',
    },
    'login.validation.usernameRequired': {
      'en': 'Please choose a username',
      'tr': 'Lütfen bir kullanıcı adı seç',
    },
    'login.validation.usernameRules': {
      'en':
          'Username must be 3-20 characters and can include letters, numbers, ., _, -',
      'tr':
          'Kullanıcı adı 3-20 karakter olmalı ve harf, rakam, ., _, - içerebilir',
    },
    'login.validation.usernameTaken': {
      'en': 'This username is already taken',
      'tr': 'Bu kullanıcı adı zaten kullanımda',
    },
    'login.validation.firstNameRequired': {
      'en': 'Please enter your first name',
      'tr': 'Lütfen adını gir',
    },
    'login.validation.lastNameRequired': {
      'en': 'Please enter your last name',
      'tr': 'Lütfen soyadını gir',
    },
    'login.validation.birthDateRequired': {
      'en': 'Please select your birth date',
      'tr': 'Lütfen doğum tarihini seç',
    },
    'login.validation.emailRequired': {
      'en': 'Please enter your email',
      'tr': 'Lütfen e-posta adresini gir',
    },
    'login.validation.emailInvalid': {
      'en': 'Please enter a valid email',
      'tr': 'Lütfen geçerli bir e-posta gir',
    },
    // Account setup
    'accountSetup.title': {
      'en': 'Complete your account',
      'tr': 'Hesabını tamamla',
    },
    'accountSetup.intro': {
      'en':
          'Hi! Because you signed in with a connected account, we need to save a few details.\nFill these in to keep your WishLink journey going.',
      'tr':
          'Merhaba! Bağlı bir hesapla giriş yaptığın için bazı bilgilerini kaydetmemiz gerekiyor.\nBu alanları doldurup onayladıktan sonra WishLink macerana devam edebilirsin.',
    },
    'accountSetup.saveButton': {
      'en': 'Save and continue',
      'tr': 'Kaydet ve devam et',
    },
    'accountSetup.cancelAndReturn': {
      'en': 'Cancel and return to login',
      'tr': 'İptal et ve girişe dön',
    },
    'accountSetup.saveFailed': {
      'en': 'Could not complete setup. Please try again.',
      'tr': 'Kurulum tamamlanamadı. Lütfen tekrar dene.',
    },
    'login.chooseUsernameTitle': {
      'en': 'Choose a username',
      'tr': 'Kullanıcı adı seç',
    },
    'login.chooseUsernameDescription': {
      'en': 'Pick a unique username so your friends can find you easily.',
      'tr':
          'Arkadaşların seni kolay bulabilsin diye benzersiz bir kullanıcı adı seç.',
    },
    'login.usernameRequired': {
      'en': 'A username is required to continue.',
      'tr': 'Devam etmek için kullanıcı adı gerekli.',
    },
    'login.usernameUpdateFailed': {
      'en': 'We could not update your username. Please try again.',
      'tr': 'Kullanıcı adını güncelleyemedik. Lütfen tekrar dene.',
    },
    'login.googleNoUser': {
      'en': 'No user returned from Google sign-in.',
      'tr': 'Google girişi kullanıcı döndürmedi.',
    },
    'login.googleSetupCancelled': {
      'en': 'Google account setup was cancelled.',
      'tr': 'Google hesap kurulumu iptal edildi.',
    },
    'login.googleFailed': {
      'en': 'Google sign-in failed. Please try again.',
      'tr': 'Google girişi başarısız oldu. Lütfen tekrar dene.',
    },
    'login.appleNoUser': {
      'en': 'No user returned from Apple sign-in.',
      'tr': 'Apple girişi kullanıcı döndürmedi.',
    },
    'login.appleSetupCancelled': {
      'en': 'Apple account setup was cancelled.',
      'tr': 'Apple hesap kurulumu iptal edildi.',
    },
    'login.appleFailed': {
      'en': 'Apple sign-in failed. Please try again.',
      'tr': 'Apple girişi başarısız oldu. Lütfen tekrar dene.',
    },
    'login.appleAccountExists': {
      'en':
          'This email is already registered with another sign-in method. Please log in with that method and connect Apple from settings.',
      'tr':
          'Bu e-posta zaten baska bir giris yontemiyle kayitli. Lutfen once o yontemle giris yapip ayarlardan Apple\'i bagla.',
    },
    'login.error.invalidEmail': {
      'en': 'The email address is invalid.',
      'tr': 'E-posta adresi geçersiz.',
    },
    'login.error.userDisabled': {
      'en': 'This account has been disabled.',
      'tr': 'Bu hesap devre dışı bırakıldı.',
    },
    'login.error.userNotFound': {
      'en': 'No user found with these credentials.',
      'tr': 'Bu bilgilerle kullanıcı bulunamadı.',
    },
    'login.error.wrongPassword': {
      'en': 'Incorrect mail or password. Please try again.',
      'tr': 'Mail adresi veya şifre yanlış. Lütfen tekrar dene.',
    },
    'login.error.emailInUse': {
      'en': 'This email is already registered.',
      'tr': 'Bu e-posta zaten kayıtlı.',
    },
    'login.error.weakPassword': {
      'en': 'Your password must be at least 6 characters.',
      'tr': 'Şifren en az 6 karakter olmalı.',
    },
    'login.signupVerificationSent': {
      'en':
          'Verification email sent. Please check your inbox and verify your email before logging in.',
      'tr':
          'Doğrulama e-postası gönderildi. Lütfen gelen kutunu kontrol edip giriş yapmadan önce doğrula.',
    },
    'login.resetEmailSent': {
      'en': 'Password reset email sent. Please check your inbox.',
      'tr':
          'Şifre sıfırlama e-postası gönderildi. Lütfen gelen kutunu kontrol et.',
    },
    'login.resetEmailFailed': {
      'en': 'Could not send password reset email. Please try again.',
      'tr': 'Şifre sıfırlama e-postası gönderilemedi. Lütfen tekrar dene.',
    },
    'login.resetEmailInputRequired': {
      'en': 'Please enter your email address first.',
      'tr': 'Önce e-posta adresini gir.',
    },
    'login.forgotPassword': {
      'en': 'Forgot Password?',
      'tr': 'Şifreni mi unuttun?',
    },
    'login.orDivider': {'en': 'OR', 'tr': 'VEYA'},
    'login.alreadyHaveAccount': {
      'en': 'Already have an account? ',
      'tr': 'Zaten hesabın var mı? ',
    },
    'login.dontHaveAccount': {
      'en': "Don't have an account? ",
      'tr': 'Hesabın yok mu? ',
    },
    'login.login': {'en': 'Login', 'tr': 'Giriş Yap'},
    'login.signUp': {'en': 'Sign Up', 'tr': 'Kayıt Ol'},
    'login.creatingAccount': {
      'en': 'Creating Account...',
      'tr': 'Hesap oluşturuluyor...',
    },
    'login.loggingIn': {'en': 'Logging in...', 'tr': 'Giriş yapılıyor...'},
    'login.continueWithGoogle': {
      'en': 'Continue with Google',
      'tr': 'Google ile devam et',
    },
    'login.continueWithApple': {
      'en': 'Continue with Apple',
      'tr': 'Apple ile devam et',
    },
    'login.label.firstName': {'en': 'First Name', 'tr': 'Ad'},
    'login.label.lastName': {'en': 'Last Name', 'tr': 'Soyad'},
    'login.label.birthDate': {'en': 'Birth Date', 'tr': 'Doğum Tarihi'},
    'login.label.username': {'en': 'Username', 'tr': 'Kullanıcı Adı'},
    'login.label.email': {'en': 'Email', 'tr': 'E-posta'},
    'login.label.password': {'en': 'Password', 'tr': 'Şifre'},
    'login.label.confirmPassword': {
      'en': 'Confirm Password',
      'tr': 'Şifreyi Doğrula',
    },
    'login.hint.email': {'en': 'you@example.com', 'tr': 'ornek@eposta.com'},
    // Relative time
    'time.justNow': {'en': 'Just now', 'tr': 'Az önce'},
    'time.minute': {'en': '{count} minute ago', 'tr': '{count} dakika önce'},
    'time.minutes': {'en': '{count} minutes ago', 'tr': '{count} dakika önce'},
    'time.hour': {'en': '{count} hour ago', 'tr': '{count} saat önce'},
    'time.hours': {'en': '{count} hours ago', 'tr': '{count} saat önce'},
    'time.day': {'en': '{count} day ago', 'tr': '{count} gün önce'},
    'time.days': {'en': '{count} days ago', 'tr': '{count} gün önce'},
    // Home
    'home.meBadge': {'en': 'ME', 'tr': 'BEN'},
    'home.friendActivityTitle': {
      'en': 'Friend Activity',
      'tr': 'Arkadaş Etkinliği',
    },
    'home.activitiesError': {
      'en': 'An error occurred: {error}',
      'tr': 'Bir hata oluştu: {error}',
    },
    'home.noActivities': {
      'en': 'No activities yet',
      'tr': 'Henüz etkinlik yok',
    },
    'home.connectPrompt': {
      'en': 'Add your first wish or connect with friends',
      'tr': 'İlk wishini ekle veya arkadaşlarınla bağlantı kur',
    },
    // Wish detail
    'wishDetail.ownerLoading': {'en': 'Loading...', 'tr': 'Yükleniyor...'},
    'wishDetail.ownerMissing': {
      'en': 'Owner information not available.',
      'tr': 'Sahip bilgisi bulunamadı.',
    },
    'wishDetail.unknownUser': {
      'en': 'Unknown User',
      'tr': 'Bilinmeyen Kullanıcı',
    },
    'wishDetail.ownWish': {
      'en': 'This wish belongs to you',
      'tr': 'Bu wish sana ait',
    },
    'wishDetail.ownerWish': {'en': "{owner}'s wish", 'tr': '{owner} wishi'},
    'wishDetail.addedLabel': {'en': 'Added {time}', 'tr': '{time} eklendi'},
    'wishDetail.priceLabel': {'en': 'Price {amount}', 'tr': 'Fiyat {amount}'},
    'wishDetail.createdLabel': {
      'en': 'Created {date}',
      'tr': 'Oluşturuldu {date}',
    },
    'wishDetail.viewProduct': {'en': 'View Product', 'tr': 'Ürünü Gör'},
    'wishDetail.like': {'en': 'Like', 'tr': 'Beğen'},
    'wishDetail.liked': {'en': 'Liked', 'tr': 'Beğenildi'},
    'wishDetail.comments': {'en': 'Comments', 'tr': 'Yorumlar'},
    'wishDetail.share': {'en': 'Share', 'tr': 'Paylaş'},
    'wishDetail.shareSuccess': {
      'en': '{wish} shared!',
      'tr': '{wish} paylaşıldı!',
    },
    'share.defaultMessage': {
      'en': 'Check out "{wish}" on WishLink!',
      'tr': '"{wish}" wishine WishLink\'te goz at!',
    },
    'share.friendMessage': {
      'en': '{user} wants "{wish}" on WishLink. Take a look!',
      'tr': '{user}, WishLink\'te "{wish}" wishini istiyor. Bir goz at!',
    },
    'share.wishSubject': {
      'en': 'Wish "{wish}" on WishLink',
      'tr': 'WishLink wishi "{wish}"',
    },
    'share.friendSubject': {
      'en': "{user}'s wish \"{wish}\"",
      'tr': '{user} wishi "{wish}"',
    },
    'share.descriptionLine': {
      'en': 'Details: {description}',
      'tr': 'Detaylar: {description}',
    },
    'share.productLine': {
      'en': 'Product link: {url}',
      'tr': 'Urun linki: {url}',
    },
    'share.someone': {'en': 'a friend', 'tr': 'bir arkadas'},
    'wishDetail.title': {'en': 'Wish Details', 'tr': 'Wish Detayları'},
    'wishDetail.backTooltip': {'en': 'Back', 'tr': 'Geri'},
    'wishDetail.editTooltip': {'en': 'Edit wish', 'tr': 'Wishi düzenle'},
    'wishDetail.menuTooltip': {'en': 'Wish options', 'tr': 'Wish seçenekleri'},
    'wishDetail.deleteConfirmTitle': {
      'en': 'Delete wish?',
      'tr': 'Wish silinsin mi?',
    },
    'wishDetail.deleteConfirmMessage': {
      'en':
          'Are you sure you want to delete {wish}? This action cannot be undone.',
      'tr':
          '{wish} wishini silmek istediğine emin misin? Bu işlem geri alınamaz.',
    },
    'wishDetail.deleteSuccess': {'en': 'Wish deleted.', 'tr': 'Wish silindi.'},
    'wishDetail.deleteFailed': {
      'en': 'Could not delete wish: {error}',
      'tr': 'Wish silinemedi: {error}',
    },
    // Edit wish
    'editWish.sessionMissing': {
      'en': 'Session not found.',
      'tr': 'Oturum bulunamadı.',
    },
    'editWish.loadFailed': {
      'en': 'Unable to load wish: {error}',
      'tr': 'Wish yüklenemedi: {error}',
    },
    'editWish.invalidProductLink': {
      'en': 'Enter a valid link that starts with http or https.',
      'tr': 'Lütfen http veya https ile başlayan geçerli bir link gir.',
    },
    'editWish.autoProductUnavailable': {
      'en': 'Could not fetch product info. Please enter it manually.',
      'tr': 'Ürün bilgisi alınamadı. Lütfen manuel gir.',
    },
    'editWish.autoImageMissing': {
      'en': 'No product image found for this link.',
      'tr': 'Bu link için ürün fotoğrafı bulunamadı.',
    },
    'editWish.autoPriceMissing': {
      'en': 'No price found for this link. Please enter it manually.',
      'tr': 'Bu link için fiyat bulunamadı. Lütfen manuel gir.',
    },
    'editWish.autoFetchFailed': {
      'en': 'Unable to fetch product info right now. Try again later.',
      'tr': 'Şu anda ürün bilgileri alınamadı. Lütfen tekrar dene.',
    },
    'editWish.photoPickFailed': {
      'en': 'Could not select photo: {error}',
      'tr': 'Fotoğraf seçilemedi: {error}',
    },
    'editWish.updated': {'en': 'Wish updated', 'tr': 'Wish güncellendi'},
    'editWish.updateFailed': {
      'en': 'Wish could not be updated: {error}',
      'tr': 'Wish güncellenemedi: {error}',
    },
    'editWish.newListTitle': {
      'en': 'Create New List',
      'tr': 'Yeni Liste Oluştur',
    },
    'editWish.listNameHint': {'en': 'List name', 'tr': 'Liste adı'},
    'editWish.listCreateFailed': {
      'en': 'Could not create list',
      'tr': 'Liste oluşturulamadı',
    },
    'editWish.noLists': {'en': 'No lists', 'tr': 'Liste yok'},
    'editWish.createNewList': {
      'en': '+ Create new list',
      'tr': '+ Yeni liste oluştur',
    },
    'editWish.previousList': {
      'en': 'Previous list (deleted)',
      'tr': 'Önceki liste (silinmiş)',
    },
    'editWish.title': {'en': 'Edit Wish', 'tr': 'Wishi Düzenle'},
    'editWish.listLabel': {'en': 'Select List', 'tr': 'Liste Seç'},
    'editWish.nameLabel': {'en': 'Wish Name *', 'tr': 'Wish Adı *'},
    'editWish.nameValidation': {
      'en': 'Please enter the wish name',
      'tr': 'Lütfen wish adını gir',
    },
    'editWish.descriptionLabel': {'en': 'Description', 'tr': 'Açıklama'},
    'editWish.urlLabel': {'en': 'Product URL *', 'tr': 'Ürün URL *'},
    'editWish.urlRequired': {
      'en': 'Please enter a URL',
      'tr': 'Lütfen URL gir',
    },
    'editWish.urlInvalid': {
      'en': 'Please enter a valid URL',
      'tr': 'Geçerli bir URL gir',
    },
    'editWish.fetchingProduct': {
      'en': 'Fetching product info...',
      'tr': 'Ürün bilgileri getiriliyor...',
    },
    'editWish.priceLabel': {'en': 'Price *', 'tr': 'Fiyat *'},
    'editWish.priceRequired': {
      'en': 'Please enter a price',
      'tr': 'Lütfen fiyat gir',
    },
    'editWish.priceInvalid': {
      'en': 'Enter a valid price greater than 0',
      'tr': '0’dan büyük geçerli bir fiyat gir',
    },
    'editWish.currencyLabel': {'en': 'Currency', 'tr': 'Para Birimi'},
    'editWish.pickPhoto': {'en': 'Choose photo', 'tr': 'Fotoğraf seç'},
    'editWish.removePhoto': {'en': 'Remove photo', 'tr': 'Fotoğrafı kaldır'},
    'editWish.save': {'en': 'Save', 'tr': 'Kaydet'},
    // User profile
    'profile.title': {'en': 'Profile', 'tr': 'Profil'},
    'profile.wishLists': {'en': 'Wish Lists', 'tr': 'Wish listeleri'},
    'profile.createList': {'en': 'Create List', 'tr': 'Liste oluştur'},
    'profile.allWishes': {'en': 'All Wishes', 'tr': 'Tüm wishler'},
    'profile.myWishes': {'en': 'My Wishes', 'tr': 'Wishlerim'},
    'profile.noWishListsTitle': {
      'en': 'No wish lists yet',
      'tr': 'Henüz wish listesi yok',
    },
    'profile.noWishListsSubtitle': {
      'en': '{name} has not created any wish lists yet.',
      'tr': '{name} henüz wish listesi oluşturmadı.',
    },
    'profile.emptyWishes': {
      'en': 'You have not added any wishes yet.',
      'tr': 'Henüz bir wish eklemedin.',
    },
    'profile.editWishTooltip': {'en': 'Edit wish', 'tr': 'Wishi düzenle'},
    'profile.photoPickFromGallery': {
      'en': 'Choose from gallery',
      'tr': 'Galeriden seç',
    },
    'profile.photoRemove': {'en': 'Remove photo', 'tr': 'Fotoğrafı sil'},
    'profile.photoUpdateSuccess': {
      'en': 'Profile photo updated successfully!',
      'tr': 'Profil fotoğrafı başarıyla güncellendi!',
    },
    'profile.photoUpdateError': {
      'en': 'Error updating profile photo: {error}',
      'tr': 'Profil fotoğrafı güncellenirken hata: {error}',
    },
    'profile.photoDeleteSuccess': {
      'en': 'Profile photo removed',
      'tr': 'Profil fotoğrafı silindi',
    },
    'profile.photoDeleteError': {
      'en': 'Error removing profile photo: {error}',
      'tr': 'Profil fotoğrafı silinirken hata: {error}',
    },
    'profile.errorLoadingLists': {
      'en': 'Error loading lists',
      'tr': 'Listeler yüklenemedi',
    },
    'profile.newListTitle': {
      'en': 'Create New List',
      'tr': 'Yeni liste oluştur',
    },
    'profile.editListTitle': {'en': 'Edit List', 'tr': 'Listeyi düzenle'},
    'profile.listNameLabel': {'en': 'List name', 'tr': 'Liste adı'},
    'profile.listNameRequired': {
      'en': 'Please enter a list name',
      'tr': 'Lütfen liste adı gir',
    },
    'profile.coverPhotoLabel': {
      'en': 'Cover photo (optional)',
      'tr': 'Kapak fotoğrafı (opsiyonel)',
    },
    'profile.selectCoverPhoto': {
      'en': 'Choose cover photo',
      'tr': 'Kapak fotoğrafı seç',
    },
    'profile.removeCoverPhoto': {
      'en': 'Remove cover photo',
      'tr': 'Kapak fotoğrafını kaldır',
    },
    'profile.newListHint': {'en': 'List name', 'tr': 'Liste adı'},
    'profile.listCreateFailed': {
      'en': 'Could not create list',
      'tr': 'Liste oluşturulamadı',
    },
    'profile.listUpdateFailed': {
      'en': 'Could not update list',
      'tr': 'Liste güncellenemedi',
    },
    'profile.noteAddTitle': {'en': 'Add Note', 'tr': 'Not Ekle'},
    'profile.noteEditTitle': {'en': 'Edit Note', 'tr': 'Notu Düzenle'},
    'profile.noteLabel': {'en': 'Note', 'tr': 'Not'},
    'profile.pickDateOptional': {
      'en': 'Pick a date (optional)',
      'tr': 'Tarih seç (opsiyonel)',
    },
    'profile.clearDate': {'en': 'Clear date', 'tr': 'Tarihi temizle'},
    'profile.noteSaved': {'en': 'Note saved', 'tr': 'Not kaydedildi'},
    'profile.noteUpdated': {'en': 'Note updated', 'tr': 'Not güncellendi'},
    'profile.noteSaveFailed': {
      'en': 'Could not save note',
      'tr': 'Not kaydedilemedi',
    },
    'profile.noteDeleteTitle': {'en': 'Delete Note', 'tr': 'Notu Sil'},
    'profile.noteDeleteMessage': {
      'en': 'Are you sure you want to delete this note? This cannot be undone.',
      'tr': 'Bu notu silmek istediğine emin misin? Bu işlem geri alınamaz.',
    },
    'profile.noteDeleted': {'en': 'Note deleted', 'tr': 'Not silindi'},
    'profile.noteDeleteFailed': {
      'en': 'Could not delete note',
      'tr': 'Not silinemedi',
    },
    'profile.myNotes': {'en': 'My Private Notes', 'tr': 'Kişisel Notlarım'},
    'profile.addNoteTooltip': {'en': 'Add note', 'tr': 'Not ekle'},
    'profile.noNotes': {
      'en': 'You have not added any notes yet',
      'tr': 'Henüz not eklemedin',
    },
    'profile.notesDescription': {
      'en': 'Create reminders about this user that only you can see.',
      'tr': 'Bu kullanıcı hakkında sadece senin görebileceğin notlar oluştur.',
    },
    'profile.addNoteButton': {'en': 'Add note', 'tr': 'Not ekle'},
    'profile.noteUpdatedAt': {
      'en': 'Last updated: {date}',
      'tr': 'Son güncelleme: {date}',
    },
    'profile.noteEdit': {'en': 'Edit', 'tr': 'Düzenle'},
    'profile.noteDelete': {'en': 'Delete', 'tr': 'Sil'},
    'profile.errorLoadingUser': {
      'en': 'Error loading user data',
      'tr': 'Kullanıcı verileri yüklenemedi',
    },
    'profile.errorLoadingWishes': {
      'en': 'Error loading wishes',
      'tr': 'Wishler yüklenemedi',
    },
    'profile.errorLoadingNotes': {
      'en': 'Error loading notes',
      'tr': 'Notlar yüklenirken hata oluştu',
    },
    'profile.defaultUserName': {'en': 'User', 'tr': 'Kullanıcı'},
    'profile.wishesTitle': {
      'en': "{handle}'s Wishes",
      'tr': '{handle} wishleri',
    },
    'profile.userUnknown': {'en': 'This user', 'tr': 'Bu kullanıcı'},
    'profile.bannedNoticeTitle': {
      'en': 'Account unavailable',
      'tr': 'Hesap kullanılamıyor',
    },
    'profile.bannedNoticeSubtitle': {
      'en': 'This profile is hidden because the user was banned.',
      'tr': 'Bu kullanıcı yasaklandığı için profili görüntülenemiyor.',
    },
    'banned.modalTitle': {
      'en': 'Your account has been banned',
      'tr': 'Hesabın yasaklandı',
    },
    'banned.modalDescription': {
      'en':
          'You no longer have access to Wishlink. You can sign out, contact support or delete your account.',
      'tr':
          'Wishlink erişimin kapatıldı. Çıkış yapabilir, destekle iletişime geçebilir ya da hesabını silebilirsin.',
    },
    'banned.signOut': {'en': 'Sign out', 'tr': 'Çıkış yap'},
    'banned.support': {'en': 'Support', 'tr': 'Destek'},
    'banned.deleteAccount': {'en': 'Delete account', 'tr': 'Hesabı sil'},
    'banned.supportError': {
      'en': 'Could not open support page.',
      'tr': 'Destek sayfası açılamadı.',
    },
    'banned.deleteReauthRequired': {
      'en': 'Please sign out and sign in again before deleting your account.',
      'tr': 'Hesabını silmeden önce çıkış yapıp tekrar giriş yapmalısın.',
    },
    'profile.noWishesTitle': {'en': 'No wishes yet', 'tr': 'Henüz wish yok'},
    'profile.noWishesSubtitle': {
      'en': "{name} hasn't added any wishes yet",
      'tr': '{name} henüz wish eklemedi',
    },
    // Comments
    'comments.addFailed': {
      'en': 'Could not add comment. Please try again.',
      'tr': 'Yorum eklenemedi. Lütfen tekrar dene.',
    },
    'comments.title': {'en': 'Comments', 'tr': 'Yorumlar'},
    'comments.unableToLoad': {
      'en': 'Unable to load comments right now.',
      'tr': 'Yorumlar şu anda yüklenemiyor.',
    },
    'comments.empty': {
      'en': 'No comments yet. Be the first to comment!',
      'tr': 'Henüz yorum yok. İlk yorum yapan sen ol!',
    },
    'comments.hint': {'en': 'Add a comment...', 'tr': 'Yorum ekle...'},
    // Activity actions
    'activity.buyGift': {'en': 'Buy gift', 'tr': 'Hediyeyi satın al'},
    'activity.comment': {'en': 'Comment', 'tr': 'Yorum'},
    'activity.share': {'en': 'Share', 'tr': 'Paylaş'},
    'activity.like': {'en': 'Like', 'tr': 'Beğen'},
    // Friends
    'friends.title': {'en': 'Friends', 'tr': 'Arkadaşlar'},
    'friends.tabMyFriends': {'en': 'My Friends', 'tr': 'Arkadaşlarım'},
    'friends.tabIncoming': {'en': 'Incoming', 'tr': 'Gelenler'},
    'friends.tabOutgoing': {'en': 'Outgoing', 'tr': 'Gidenler'},
    'friends.searchHint': {'en': 'Search users...', 'tr': 'Kullanıcı ara...'},
    'friends.searchError': {
      'en': 'Error searching users',
      'tr': 'Kullanıcı ararken hata oluştu',
    },
    'friends.noUsersFound': {
      'en': 'No users found',
      'tr': 'Kullanıcı bulunamadı',
    },
    'friends.statusFriends': {'en': 'Friends', 'tr': 'Arkadaşsınız'},
    'friends.statusRequestSent': {
      'en': 'Request sent',
      'tr': 'İstek gönderildi',
    },
    'friends.statusPending': {'en': 'Pending', 'tr': 'Beklemede'},
    'friends.buttonRespond': {'en': 'Respond', 'tr': 'Yanıtla'},
    'friends.buttonAdd': {'en': 'Add Friend', 'tr': 'Arkadaş ekle'},
    'friends.buttonSendRequest': {
      'en': 'Send friend request',
      'tr': 'Arkadaşlık isteği gönder',
    },
    'friends.buttonRemove': {'en': 'Remove', 'tr': 'Kaldır'},
    'friends.buttonAccept': {'en': 'Accept', 'tr': 'Kabul et'},
    'friends.buttonReject': {'en': 'Reject', 'tr': 'Reddet'},
    'friends.snackbarRequestSent': {
      'en': 'Friend request sent successfully',
      'tr': 'Arkadaş isteği gönderildi',
    },
    'friends.snackbarRequestFailed': {
      'en': 'Error sending friend request',
      'tr': 'Arkadaş isteği gönderilirken hata oluştu',
    },
    'friends.snackbarFriendRemoved': {
      'en': 'Friend removed successfully',
      'tr': 'Arkadaş silindi',
    },
    'friends.snackbarFriendRemoveFailed': {
      'en': 'Error removing friend',
      'tr': 'Arkadaş silinirken hata oluştu',
    },
    'friends.snackbarAccepted': {
      'en': 'Friend request accepted',
      'tr': 'Arkadaş isteği kabul edildi',
    },
    'friends.snackbarAcceptFailed': {
      'en': 'Error accepting friend request',
      'tr': 'Arkadaş isteği kabul edilirken hata oluştu',
    },
    'friends.snackbarRejected': {
      'en': 'Friend request rejected',
      'tr': 'Arkadaş isteği reddedildi',
    },
    'friends.snackbarRejectFailed': {
      'en': 'Error rejecting friend request',
      'tr': 'Arkadaş isteği reddedilirken hata oluştu',
    },
    'friends.emptyFriendsTitle': {
      'en': 'No friends yet',
      'tr': 'Henüz arkadaşın yok',
    },
    'friends.emptyFriendsSubtitle': {
      'en': 'Connect with friends to see their wishes',
      'tr': 'Arkadaşlarınla bağlantı kurup wishlerini gör',
    },
    'friends.emptyIncomingTitle': {
      'en': 'No incoming friend requests',
      'tr': 'Gelen arkadaş isteği yok',
    },
    'friends.emptyIncomingSubtitle': {
      'en': 'When someone sends you a request, it will appear here',
      'tr': 'Biri sana istek gönderdiğinde burada görünecek',
    },
    'friends.emptyOutgoingTitle': {
      'en': 'No outgoing friend requests',
      'tr': 'Gönderilmiş arkadaş isteği yok',
    },
    'friends.emptyOutgoingSubtitle': {
      'en': 'Search for users and send friend requests to connect',
      'tr': 'Kullanıcı arayıp arkadaş isteği gönder',
    },
    'friends.error': {'en': 'Error: {error}', 'tr': 'Hata: {error}'},
    'friends.unknownUser': {'en': 'User', 'tr': 'Kullanıcı'},
    // Notifications
    'notifications.title': {'en': 'Notifications', 'tr': 'Bildirimler'},
    'notifications.errorLoading': {
      'en': 'Error loading notifications',
      'tr': 'Bildirimler yüklenirken hata',
    },
    'notifications.errorLoadingWithReason': {
      'en': 'Error loading notifications: {error}',
      'tr': 'Bildirimler yüklenirken hata: {error}',
    },
    'notifications.retry': {'en': 'Retry', 'tr': 'Tekrar dene'},
    'notifications.markAllAsRead': {
      'en': 'Mark all as read',
      'tr': 'Tumunu okundu yap',
    },
    'notifications.emptyTitle': {
      'en': 'No notifications yet',
      'tr': 'Henüz bildirimin yok',
    },
    'notifications.emptySubtitle': {
      'en': 'You\'ll see friend requests and new wishes here',
      'tr': 'Burada arkadaş isteklerini ve yeni wishleri göreceksin',
    },
    'notifications.userNotAuthenticated': {
      'en': 'User not authenticated',
      'tr': 'Kullanıcı doğrulanmadı',
    },
    'notifications.friendRequestTitle': {
      'en': 'New Friend Request',
      'tr': 'Yeni arkadaş isteği',
    },
    'notifications.friendRequestMessage': {
      'en': '{user} sent you a friend request',
      'tr': '{user} sana arkadaşlık isteği gönderdi',
    },
    'notifications.friendshipAcceptedTitle': {
      'en': 'New Friend!',
      'tr': 'Yeni arkadaş!',
    },
    'notifications.friendshipAcceptedMessage': {
      'en': 'You and {user} are now friends',
      'tr': '{user} ile artık arkadaşsınız',
    },
    'notifications.newWishTitle': {'en': 'New Wish!', 'tr': 'Yeni wish!'},
    'notifications.newWishMessage': {
      'en': '{user} added "{wish}" to their wishlist',
      'tr': '{user} wish listesine "{wish}" ekledi',
    },
    'notifications.unknownWishFallback': {'en': 'a wish', 'tr': 'bir wish'},
    // Add Wish
    'addWish.title': {'en': 'Add Wish', 'tr': 'Wish Ekle'},
    'addWish.closeKeyboard': {'en': 'Close Keyboard', 'tr': 'Klavye kapat'},
    'addWish.assignList': {'en': 'Assign to List', 'tr': 'Liste seç'},
    'addWish.noList': {'en': 'No list', 'tr': 'Liste yok'},
    'addWish.createListOption': {
      'en': 'Create new list',
      'tr': 'Yeni liste oluştur',
    },
    'addWish.newListTitle': {
      'en': 'Create New List',
      'tr': 'Yeni Liste Oluştur',
    },
    'addWish.newListHint': {'en': 'List name', 'tr': 'Liste adı'},
    'addWish.listCreateFailed': {
      'en': 'Could not create list',
      'tr': 'Liste oluşturulamadı',
    },
    'addWish.invalidLink': {
      'en': 'Please enter a valid product link that starts with http or https.',
      'tr': 'Lütfen http ya da https ile başlayan geçerli bir ürün linki gir.',
    },
    'addWish.metadataUnavailable': {
      'en':
          'We could not fetch product details for this link. You can enter them manually.',
      'tr':
          'Bu link için ürün bilgileri alınamadı. Bilgileri manuel girebilirsin.',
    },
    'addWish.noPhotoFromLink': {
      'en':
          'We could not find a product photo for this link. You can select one from your gallery.',
      'tr':
          'Bu link için ürün fotoğrafı bulunamadı. Galerinden bir fotoğraf seçebilirsin.',
    },
    'addWish.noPriceFromLink': {
      'en':
          'We could not detect the price for this link. Please enter it manually.',
      'tr': 'Bu link için fiyat bulunamadı. Lütfen manuel gir.',
    },
    'addWish.metadataFetchFailed': {
      'en':
          'We could not fetch product details for this link right now. Please try again later.',
      'tr': 'Şu anda ürün bilgileri alınamadı. Lütfen daha sonra tekrar dene.',
    },
    'addWish.photoPickFailed': {
      'en': 'Failed to select photo: {error}',
      'tr': 'Fotoğraf seçilemedi: {error}',
    },
    'addWish.noPhotoSelected': {
      'en': 'No product photo selected yet.',
      'tr': 'Henüz ürün fotoğrafı seçilmedi.',
    },
    'addWish.galleryPhoto': {'en': 'Gallery photo', 'tr': 'Galeriden fotoğraf'},
    'addWish.linkPhoto': {'en': 'From product link', 'tr': 'Ürün linkinden'},
    'addWish.removePhotoTooltip': {
      'en': 'Remove photo',
      'tr': 'Fotoğrafı kaldır',
    },
    'addWish.wishNameLabel': {'en': 'Wish Name *', 'tr': 'Wish Adı *'},
    'addWish.wishNameValidation': {
      'en': 'Please enter a wish name',
      'tr': 'Lütfen wish adını gir',
    },
    'addWish.descriptionLabel': {'en': 'Description', 'tr': 'Açıklama'},
    'addWish.productUrlLabel': {'en': 'Product URL *', 'tr': 'Ürün URL *'},
    'addWish.productUrlRequired': {
      'en': 'Please enter a product URL',
      'tr': 'Lütfen ürün URL’si gir',
    },
    'addWish.productUrlInvalid': {
      'en': 'Please enter a valid URL',
      'tr': 'Lütfen geçerli bir URL gir',
    },
    'addWish.fetchingMetadata': {
      'en': 'Fetching product details...',
      'tr': 'Ürün bilgileri getiriliyor...',
    },
    'addWish.selectPhotoButton': {
      'en': 'Select photo from gallery',
      'tr': 'Galeriden fotoğraf seç',
    },
    'addWish.priceLabel': {'en': 'Price *', 'tr': 'Fiyat *'},
    'addWish.priceRequired': {
      'en': 'Please enter a price',
      'tr': 'Lütfen fiyat gir',
    },
    'addWish.priceInvalid': {
      'en': 'Please enter a valid price greater than 0',
      'tr': '0’dan büyük geçerli bir fiyat gir',
    },
    'addWish.currencyLabel': {'en': 'Currency', 'tr': 'Para birimi'},
    'addWish.priceFetched': {
      'en': 'Price fetched automatically from the link.',
      'tr': 'Fiyat linkten otomatik olarak alındı.',
    },
    'addWish.currencyDetected': {
      'en': 'Currency detected as {currency}.',
      'tr': 'Para birimi {currency} olarak algılandı.',
    },
    'addWish.heroSubtitle': {
      'en': 'Share your next wish with the people you care about.',
      'tr': 'Yeni dileğini sevdiklerinle paylaş.',
    },
    'addWish.listSectionTitle': {'en': 'Wish lists', 'tr': 'Listeler'},
    'addWish.detailsSectionTitle': {
      'en': 'Wish details',
      'tr': 'Wish detayları',
    },
    'addWish.mediaSectionTitle': {
      'en': 'Image & preview',
      'tr': 'Görsel ve ön izleme',
    },
    'addWish.pricingSectionTitle': {
      'en': 'Price & currency',
      'tr': 'Fiyat ve para birimi',
    },
    'addWish.noListInfo': {
      'en': 'Create a list to keep your wishes organized.',
      'tr': 'Wishlerini düzenlemek için yeni bir liste oluştur.',
    },
    'addWish.activityDescription': {
      'en': 'added a new wish',
      'tr': 'yeni bir wish ekledi',
    },
    'addWish.success': {
      'en': 'Wish added successfully!',
      'tr': 'Wish eklendi!',
    },
    'addWish.error': {
      'en': 'Error adding wish: {error}',
      'tr': 'Wish eklenemedi: {error}',
    },
    'addWish.submit': {'en': 'Add Wish', 'tr': 'Wishi Ekle'},
    'home.activityShared': {'en': '{wish} shared!', 'tr': '{wish} paylaşıldı!'},
    'home.linkMissing': {
      'en': 'No link found for {wish}',
      'tr': '{wish} için link bulunamadı',
    },
  };

  static AppLocalizations of(BuildContext context) {
    final result = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(result != null, 'No AppLocalizations found in context');
    return result!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String _languageCode() {
    return locale.languageCode.toLowerCase() == 'tr' ? 'tr' : 'en';
  }

  String t(String key, {Map<String, String>? params}) {
    final languageCode = _languageCode();
    final translations = _localizedValues[key];
    final template = translations?[languageCode] ?? translations?['en'] ?? key;
    if (params == null || params.isEmpty) {
      return template;
    }
    var result = template;
    params.forEach((placeholder, value) {
      result = result.replaceAll('{$placeholder}', value);
    });
    return result;
  }

  String relativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 1) {
      final count = difference.inDays;
      final key = count == 1 ? 'time.day' : 'time.days';
      return t(key, params: {'count': '$count'});
    }
    if (difference.inHours >= 1) {
      final count = difference.inHours;
      final key = count == 1 ? 'time.hour' : 'time.hours';
      return t(key, params: {'count': '$count'});
    }
    if (difference.inMinutes >= 1) {
      final count = difference.inMinutes;
      final key = count == 1 ? 'time.minute' : 'time.minutes';
      return t(key, params: {'count': '$count'});
    }
    return t('time.justNow');
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) =>
          supported.languageCode.toLowerCase() ==
          locale.languageCode.toLowerCase(),
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
