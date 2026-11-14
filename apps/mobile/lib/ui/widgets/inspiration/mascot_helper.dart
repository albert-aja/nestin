import 'package:flutter/material.dart';

class InspirationMascotMeta {
  final String domain;
  final String displayName;
  final String assetPath;
  final Color accentColor;

  const InspirationMascotMeta({
    required this.domain,
    required this.displayName,
    required this.assetPath,
    required this.accentColor,
  });
}

InspirationMascotMeta? inspirationMascotFor(String? domain) {
  switch (domain) {
    case 'roo':
      return const InspirationMascotMeta(
        domain: 'roo',
        displayName: 'Roo',
        assetPath: 'assets/mascots/sprites/roo/morning.png',
        accentColor: Color(0xFFE04A3A),
      );
    case 'seren':
      return const InspirationMascotMeta(
        domain: 'seren',
        displayName: 'Seren',
        assetPath: 'assets/mascots/sprites/seren/peace.png',
        accentColor: Color(0xFF8B5CF6),
      );
    case 'echo':
      return const InspirationMascotMeta(
        domain: 'echo',
        displayName: 'Echo',
        assetPath: 'assets/mascots/sprites/echo/grateful.png',
        accentColor: Color(0xFFEC4899),
      );
    case 'pippin':
      return const InspirationMascotMeta(
        domain: 'pippin',
        displayName: 'Pippin',
        assetPath: 'assets/mascots/sprites/pippin/inspired.png',
        accentColor: Color(0xFF10B981),
      );
    case 'twill':
      return const InspirationMascotMeta(
        domain: 'twill',
        displayName: 'Twill',
        assetPath: 'assets/mascots/sprites/twill/noted.png',
        accentColor: Color(0xFF3A86FF),
      );
    case 'scout':
      return const InspirationMascotMeta(
        domain: 'scout',
        displayName: 'Scout',
        assetPath: 'assets/mascots/sprites/scout/dawn_brief.png',
        accentColor: Color(0xFFF59E0B),
      );
    default:
      return null;
  }
}

const List<String> allInspirationMascotDomains = [
  'roo',
  'pippin',
  'seren',
  'echo',
  'twill',
  'scout',
];
