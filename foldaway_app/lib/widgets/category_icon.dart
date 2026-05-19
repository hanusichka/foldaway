import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  final String icon;
  final double size;

  const CategoryIcon({
    super.key,
    required this.icon,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    switch (icon) {
      case '🌿':
        return Icon(Icons.eco_outlined, size: size);
      case '🍽️':
        return Icon(Icons.restaurant_outlined, size: size);
      case '☕':
        return Icon(Icons.local_cafe_outlined, size: size);
      case '🥐':
        return Icon(Icons.bakery_dining_outlined, size: size);
      case '🏛️':
        return Icon(Icons.account_balance_outlined, size: size);
      case '🖼️':
        return Icon(Icons.image_outlined, size: size);
      case '🛍️':
        return Icon(Icons.shopping_bag_outlined, size: size);
      case '🧳':
        return Icon(Icons.luggage_outlined, size: size);
      case '🏨':
        return Icon(Icons.hotel_outlined, size: size);
      case '🚆':
        return Icon(Icons.train_outlined, size: size);
      case '✈️':
        return Icon(Icons.flight_outlined, size: size);
      case '⭐':
        return Icon(Icons.star_border_outlined, size: size);
      case '📍':
        return Icon(Icons.place_outlined, size: size);
      default:
        return Text(
          icon,
          style: TextStyle(
            fontSize: size,
            fontFamily: 'Apple Color Emoji',
          ),
        );
    }
  }
}