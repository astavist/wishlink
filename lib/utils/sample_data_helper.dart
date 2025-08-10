import 'package:cloud_firestore/cloud_firestore.dart';

class SampleDataHelper {
  static List<Map<String, dynamic>> getSampleWishes() {
    return [
      {
        'name': 'iPhone 15 Pro',
        'description': 'Latest iPhone with advanced camera features',
        'productUrl': 'https://www.apple.com/iphone-15-pro/',
        'imageUrl': 'https://example.com/iphone15pro.jpg',
        'price': 999.99,
        'createdAt': Timestamp.now(),
      },
      {
        'name': 'Nike Air Max 270',
        'description': 'Comfortable running shoes with great cushioning',
        'productUrl': 'https://www.nike.com/t/air-max-270-mens-shoes-KkLcGR',
        'imageUrl': 'https://example.com/nike-airmax.jpg',
        'price': 150.00,
        'createdAt': Timestamp.now(),
      },
      {
        'name': 'MacBook Air M2',
        'description': 'Lightweight laptop with powerful M2 chip',
        'productUrl': 'https://www.apple.com/macbook-air-m2/',
        'imageUrl': 'https://example.com/macbook-air.jpg',
        'price': 1199.99,
        'createdAt': Timestamp.now(),
      },
      {
        'name': 'Samsung 65" QLED TV',
        'description': '4K QLED Smart TV with amazing picture quality',
        'productUrl':
            'https://www.samsung.com/us/televisions-home-theater/tvs/qled-4k-smart-tv-65-class-q60c-qled-4k-uhd-hdr-dual-led-quantum-hdr-smart-tv-with-alexa-built-in-qn65q60cafxza/',
        'imageUrl': 'https://example.com/samsung-tv.jpg',
        'price': 1299.99,
        'createdAt': Timestamp.now(),
      },
      {
        'name': 'Instant Pot Duo',
        'description': '7-in-1 electric pressure cooker',
        'productUrl': 'https://instantpot.com/duo/',
        'imageUrl': 'https://example.com/instant-pot.jpg',
        'price': 89.99,
        'createdAt': Timestamp.now(),
      },
    ];
  }

  static List<Map<String, dynamic>> getSampleFriendActivities() {
    return [
      {
        'userId': 'user1',
        'userName': 'John Doe',
        'userAvatarUrl': 'https://example.com/avatar1.jpg',
        'wishItem': {
          'name': 'iPhone 15 Pro',
          'description': 'Latest iPhone with advanced camera features',
          'productUrl': 'https://www.apple.com/iphone-15-pro/',
          'imageUrl': 'https://example.com/iphone15pro.jpg',
          'price': 999.99,
          'createdAt': Timestamp.now(),
        },
        'activityTime': Timestamp.now(),
        'activityType': 'added',
        'activityDescription': 'Just added this to my wishlist!',
      },
      {
        'userId': 'user2',
        'userName': 'Jane Smith',
        'userAvatarUrl': 'https://example.com/avatar2.jpg',
        'wishItem': {
          'name': 'MacBook Air M2',
          'description': 'Lightweight laptop with powerful M2 chip',
          'productUrl': 'https://www.apple.com/macbook-air-m2/',
          'imageUrl': 'https://example.com/macbook-air.jpg',
          'price': 1199.99,
          'createdAt': Timestamp.now(),
        },
        'activityTime': Timestamp.now(),
        'activityType': 'added',
        'activityDescription': 'Added a new wish to my list!',
      },
    ];
  }
}
