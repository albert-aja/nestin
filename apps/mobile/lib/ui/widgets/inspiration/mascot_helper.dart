import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

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
        accentColor: AppColors.roo,
      );
    case 'seren':
      return const InspirationMascotMeta(
        domain: 'seren',
        displayName: 'Seren',
        assetPath: 'assets/mascots/sprites/seren/peace.png',
        accentColor: AppColors.seren,
      );
    case 'echo':
      return const InspirationMascotMeta(
        domain: 'echo',
        displayName: 'Echo',
        assetPath: 'assets/mascots/sprites/echo/grateful.png',
        accentColor: AppColors.echo,
      );
    case 'pippin':
      return const InspirationMascotMeta(
        domain: 'pippin',
        displayName: 'Pippin',
        assetPath: 'assets/mascots/sprites/pippin/inspired.png',
        accentColor: AppColors.pippin,
      );
    case 'twill':
      return const InspirationMascotMeta(
        domain: 'twill',
        displayName: 'Twill',
        assetPath: 'assets/mascots/sprites/twill/noted.png',
        accentColor: AppColors.twill,
      );
    case 'scout':
      return const InspirationMascotMeta(
        domain: 'scout',
        displayName: 'Scout',
        assetPath: 'assets/mascots/sprites/scout/dawn_brief.png',
        accentColor: AppColors.scout,
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
