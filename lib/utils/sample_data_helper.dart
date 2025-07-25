import '../models/friend_activity.dart';
import '../models/wish_item.dart';
import '../services/firestore_service.dart';

class SampleDataHelper {
  static final FirestoreService _firestoreService = FirestoreService();

  static Future<void> createSampleData() async {
    // Örnek wishlist ürünleri
    final sampleWishItems = [
      WishItem(
        id: 'item1',
        name: 'Noise-Cancelling Headphones',
        description: 'Premium sound quality with active noise cancellation, ideal for travel and focus.',
        price: 299.99,
        imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500',
        category: 'Electronics',
        productUrl: 'https://example.com/headphones',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      WishItem(
        id: 'item2',
        name: 'Smart Fitness Watch',
        description: 'Track your workouts, monitor your health, and stay connected on the go.',
        price: 249.99,
        imageUrl: 'https://images.unsplash.com/photo-1544117519-31a4b719223d?w=500',
        category: 'Fitness',
        productUrl: 'https://example.com/smartwatch',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      WishItem(
        id: 'item3',
        name: 'Ergonomic Office Chair',
        description: 'Comfortable and supportive chair for long working hours.',
        price: 399.99,
        imageUrl: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=500',
        category: 'Furniture',
        productUrl: 'https://example.com/chair',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      WishItem(
        id: 'item4',
        name: 'Portable Coffee Maker',
        description: 'Brew perfect coffee anywhere with this compact travel-friendly maker.',
        price: 89.99,
        imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=500',
        category: 'Kitchen',
        productUrl: 'https://example.com/coffee-maker',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
    ];

    // Örnek arkadaş etkinlikleri
    final sampleFriends = [
      {
        'userId': 'user1',
        'userName': 'Alice Johnson',
        'userAvatarUrl': 'https://images.unsplash.com/photo-1494790108755-2616b612b5bc?w=150',
      },
      {
        'userId': 'user2',
        'userName': 'Bob Smith',
        'userAvatarUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      },
      {
        'userId': 'user3',
        'userName': 'Carol Williams',
        'userAvatarUrl': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
      },
      {
        'userId': 'user4',
        'userName': 'David Brown',
        'userAvatarUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
      },
    ];

    final activityDescriptions = [
      'Just added this amazing item to my wishlist!',
      'Found this perfect addition for my collection.',
      'This looks exactly what I need!',
      'Can\'t wait to get this!',
    ];

    // Örnek arkadaş etkinliklerini oluştur
    for (int i = 0; i < sampleWishItems.length; i++) {
      final friend = sampleFriends[i % sampleFriends.length];
      final activity = FriendActivity(
        id: 'activity$i',
        userId: friend['userId']!,
        userName: friend['userName']!,
        userAvatarUrl: friend['userAvatarUrl']!,
        wishItem: sampleWishItems[i],
        activityTime: DateTime.now().subtract(Duration(hours: (i + 1) * 2)),
        activityType: 'added',
        activityDescription: activityDescriptions[i % activityDescriptions.length],
        likesCount: (i + 1) * 3,
        commentsCount: i + 1,
      );

      await _firestoreService.addFriendActivity(activity);
    }
  }

  static List<WishItem> getSampleWishItems() {
    return [
      WishItem(
        id: 'sample1',
        name: 'Wireless Earbuds',
        description: 'High-quality wireless earbuds with noise cancellation.',
        price: 159.99,
        imageUrl: 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=500',
        category: 'Electronics',
        productUrl: 'https://example.com/earbuds',
        createdAt: DateTime.now(),
      ),
      WishItem(
        id: 'sample2',
        name: 'Reading Lamp',
        description: 'Adjustable LED reading lamp with touch controls.',
        price: 45.99,
        imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500',
        category: 'Home',
        productUrl: 'https://example.com/lamp',
        createdAt: DateTime.now(),
      ),
    ];
  }
} 