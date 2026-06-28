import 'package:flutter/material.dart';

IconData iconFromParamKey(String key) {
  switch (key) {
    case 'ban':
    case 'block':
      return Icons.block_rounded;
    case 'pause_circle':
    case 'pause':
      return Icons.pause_circle_outline_rounded;
    case 'speed':
      return Icons.speed_rounded;
    case 'book':
      return Icons.menu_book_rounded;
    case 'account_tree':
      return Icons.account_tree_rounded;
    case 'draw':
      return Icons.draw_rounded;
    default:
      return Icons.analytics_rounded;
  }
}
