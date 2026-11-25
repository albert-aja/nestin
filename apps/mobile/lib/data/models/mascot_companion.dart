import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
/// Canonical identifiers for Nestin's 6 everyday bird companions.
enum NestinMascotId {
  roo,
  scout,
  seren,
  pippin,
  twill,
  echo,
}

/// Complete profile describing one bird companion's identity, visual assets,
/// accent palette, and everyday domain roles in EN and ID.
class MascotCompanionProfile {
  final NestinMascotId id;
  final String name;
  final String speciesEn;
  final String speciesId;
  final String archetypeEn;
  final String archetypeId;
  final String domainTitleEn;
  final String domainTitleId;
  final String dayWindowEn;
  final String dayWindowId;
  final Color accentColor;
  final Color lightInkColor;
  final String primarySpriteAsset;
  final String altSpriteAsset;
  final IconData fallbackIcon;
  final String primarySpeechEn;
  final String primarySpeechId;
  final String altSpeechEn;
  final String altSpeechId;
  final List<MascotRolePoint> roles;
  final int destinationTabIndex;
  final int? destinationSubTabIndex;

  const MascotCompanionProfile({
    required this.id,
    required this.name,
    required this.speciesEn,
    required this.speciesId,
    required this.archetypeEn,
    required this.archetypeId,
    required this.domainTitleEn,
    required this.domainTitleId,
    required this.dayWindowEn,
    required this.dayWindowId,
    required this.accentColor,
    required this.lightInkColor,
    required this.primarySpriteAsset,
    required this.altSpriteAsset,
    required this.fallbackIcon,
    required this.primarySpeechEn,
    required this.primarySpeechId,
    required this.altSpeechEn,
    required this.altSpeechId,
    required this.roles,
    required this.destinationTabIndex,
    this.destinationSubTabIndex,
  });

  String species(bool isId) => isId ? speciesId : speciesEn;
  String archetype(bool isId) => isId ? archetypeId : archetypeEn;
  String domainTitle(bool isId) => isId ? domainTitleId : domainTitleEn;
  String dayWindow(bool isId) => isId ? dayWindowId : dayWindowEn;
  String speech(bool isId, {bool alternate = false}) {
    if (alternate) return isId ? altSpeechId : altSpeechEn;
    return isId ? primarySpeechId : primarySpeechEn;
  }

  String get shortInitial => name.substring(0, 1);
}

class MascotRolePoint {
  final IconData icon;
  final String labelEn;
  final String labelId;

  const MascotRolePoint({
    required this.icon,
    required this.labelEn,
    required this.labelId,
  });

  String label(bool isId) => isId ? labelId : labelEn;
}

/// Single source of truth for Nestin's 6 bird companions in onboarding and UI guides.
class NestinFlock {
  static const List<MascotCompanionProfile> companions = [
    MascotCompanionProfile(
      id: NestinMascotId.roo,
      name: 'Roo',
      speciesEn: 'Rooster',
      speciesId: 'Ayam Jantan',
      archetypeEn: 'The Energetic Starter',
      archetypeId: 'Penggerak Pagi',
      domainTitleEn: 'Time, Planning & Habits',
      domainTitleId: 'Waktu, Rencana & Kebiasaan',
      dayWindowEn: 'Dawn & Morning • 06:00–12:00',
      dayWindowId: 'Fajar & Pagi • 06:00–12:00',
      accentColor: AppColors.roo,
      lightInkColor: AppColors.rooDark,
      primarySpriteAsset: 'assets/mascots/sprites/roo/welcome.png',
      altSpriteAsset: 'assets/mascots/sprites/roo/high_five.png',
      fallbackIcon: Icons.alarm_on_rounded,
      primarySpeechEn:
          "Cock-a-doodle-doo! I'll wake you reliably and turn morning inertia into momentum.",
      primarySpeechId:
          'Kukuruyuk! Aku membangunkanmu tepat waktu dan mengubah pagi jadi penuh semangat.',
      altSpeechEn:
          'Tap my Pomodoro sprint, Focus Lock, or App Fast anytime—we are crushing today together!',
      altSpeechId:
          'Aktifkan sprint Pomodoro, Kunci Fokus, atau App Fast kapan saja—kita taklukkan hari ini!',
      roles: [
        MascotRolePoint(
          icon: Icons.alarm_rounded,
          labelEn: 'Reliable alarms with Math, Memory & Typing wake-up gates',
          labelId: 'Alarm andal dengan tantangan Matematika, Memori & Ketik',
        ),
        MascotRolePoint(
          icon: Icons.timer_rounded,
          labelEn: 'Focus Pomodoro sprints, countdown timers & habit streaks',
          labelId: 'Sesi fokus Pomodoro, penghitung waktu & rekor rutinitas',
        ),
        MascotRolePoint(
          icon: Icons.phonelink_lock_rounded,
          labelEn: 'App Fast, Focus Lock & Digital Discipline app allowances',
          labelId: 'App Fast, Kunci Fokus & batas disiplin digital aplikasi',
        ),
        MascotRolePoint(
          icon: Icons.event_note_rounded,
          labelEn: 'Daily agenda calendar & quick-prioritized to-do tasks',
          labelId: 'Agenda kalender harian & daftar tugas prioritas cepat',
        ),
      ],
      destinationTabIndex: 1,
      destinationSubTabIndex: 0,
    ),
    MascotCompanionProfile(
      id: NestinMascotId.scout,
      name: 'Scout',
      speciesEn: 'Carrier Pigeon',
      speciesId: 'Merpati Pos',
      archetypeEn: 'The Reliable Guide',
      archetypeId: 'Pemandu Andal',
      domainTitleEn: 'Everyday Assistance',
      domainTitleId: 'Asisten Harian',
      dayWindowEn: 'All-Day Dispatch • 06:00–17:00',
      dayWindowId: 'Siaga Sepanjang Hari • 06:00–17:00',
      accentColor: AppColors.scout,
      lightInkColor: AppColors.scoutDark,
      primarySpriteAsset: 'assets/mascots/sprites/scout/briefing.png',
      altSpriteAsset: 'assets/mascots/sprites/scout/before_you_go.png',
      fallbackIcon: Icons.explore_rounded,
      primarySpeechEn:
          'Morning briefing ready! No more forgetting keys, wallet, or umbrella at the door.',
      primarySpeechId:
          'Ringkasan siap! Tak ada lagi kunci, dompet, atau payung yang tertinggal di rumah.',
      altSpeechEn:
          'I also watch battery-saver rules, place reminders, Phone Modes, and Universal Search!',
      altSpeechId:
          'Aku juga menjaga pengingat lokasi, Mode Ponsel, dan Pencarian Universal!',
      roles: [
        MascotRolePoint(
          icon: Icons.checklist_rtl_rounded,
          labelEn: 'BeforeYouGo departure checklists with shade quick-actions',
          labelId: 'Daftar siap berangkat BeforeYouGo & aksi cepat notifikasi',
        ),
        MascotRolePoint(
          icon: Icons.location_on_rounded,
          labelEn: 'Offline place reminders, Phone Modes & device automation rules',
          labelId: 'Pengingat lokasi offline, Mode Ponsel & aturan otomatisasi',
        ),
        MascotRolePoint(
          icon: Icons.search_rounded,
          labelEn: 'Global Universal Search & local JSON full-backup safety',
          labelId: 'Pencarian Universal lintas modul & cadangan JSON lokal',
        ),
      ],
      destinationTabIndex: 4,
    ),
    MascotCompanionProfile(
      id: NestinMascotId.seren,
      name: 'Seren',
      speciesEn: 'Dove',
      speciesId: 'Merpati Putih',
      archetypeEn: 'The Gentle Companion',
      archetypeId: 'Sahabat Penenang',
      domainTitleEn: 'Personal Wellness',
      domainTitleId: 'Kebugaran Pribadi',
      dayWindowEn: 'Hydration & Wind-Down • 08:30–06:00',
      dayWindowId: 'Hidrasi & Istirahat • 08:30–06:00',
      accentColor: AppColors.seren,
      lightInkColor: AppColors.serenDark,
      primarySpriteAsset: 'assets/mascots/sprites/seren/hello.png',
      altSpriteAsset: 'assets/mascots/sprites/seren/hydrate.png',
      fallbackIcon: Icons.spa_rounded,
      primarySpeechEn:
          'Breathe gently. Small sips of water, steady meds, and calm nights add up fast.',
      primarySpeechId:
          'Tarik napas pelan. Minum air teratur, obat tepat waktu, dan malam tenang terasa ringan.',
      altSpeechEn:
          'Need help drifting off? My 30-minute rain soundscape and 4-7-8 breathing are ready!',
      altSpeechId:
          'Butuh teman tidur? Suara hujan 30 menit dan napas 4-7-8 siap menenangkanmu!',
      roles: [
        MascotRolePoint(
          icon: Icons.water_drop_rounded,
          labelEn: 'Hydration sparklines, caffeine cutoff timer & move nudges',
          labelId: 'Grafik hidrasi harian, batas kafein & pengingat gerak',
        ),
        MascotRolePoint(
          icon: Icons.medication_rounded,
          labelEn: 'Medication doses with quick snooze & personal vital/step logs',
          labelId: 'Jadwal obat dengan tunda cepat & catatan vital/langkah',
        ),
        MascotRolePoint(
          icon: Icons.bedtime_rounded,
          labelEn: '90-minute REM sleep calculator & procedural ambient rain audio',
          labelId: 'Kalkulator siklus tidur REM & suara hujan prosedural offline',
        ),
      ],
      destinationTabIndex: 4,
    ),
    MascotCompanionProfile(
      id: NestinMascotId.pippin,
      name: 'Pippin',
      speciesEn: 'Explorer Dodo',
      speciesId: 'Dodo Penjelajah',
      archetypeEn: 'The Curious Explorer',
      archetypeId: 'Penjelajah Penuh Rasa Ingin Tahu',
      domainTitleEn: 'Personal Interests',
      domainTitleId: 'Minat & Eksplorasi',
      dayWindowEn: 'Evening Discovery • 17:00–20:00',
      dayWindowId: 'Eksplorasi Sore • 17:00–20:00',
      accentColor: AppColors.pippin,
      lightInkColor: AppColors.pippinDark,
      primarySpriteAsset: 'assets/mascots/sprites/pippin/inspired.png',
      altSpriteAsset: 'assets/mascots/sprites/pippin/exploring.png',
      fallbackIcon: Icons.explore_outlined,
      primarySpeechEn:
          'Every chapter and practice session leaves a footprint! What sparks your curiosity?',
      primarySpeechId:
          'Setiap halaman dan latihan meninggalkan jejak seru! Apa yang membuatmu penasaran?',
      altSpeechEn:
          'Hit your daily page goal or hobby milestone and I will stamp your explorer passport!',
      altSpeechId:
          'Capai target halaman baca atau tonggak hobi, lalu aku cap paspor penjelajahmu!',
      roles: [
        MascotRolePoint(
          icon: Icons.menu_book_rounded,
          labelEn: 'Reading tracker with daily page goals, streak & sparkline chart',
          labelId: 'Pelacak baca dengan target halaman, rekor & grafik harian',
        ),
        MascotRolePoint(
          icon: Icons.palette_rounded,
          labelEn: 'Creative hobby practice sessions & progression milestones',
          labelId: 'Sesi latihan hobi kreatif & pencapaian tingkat keahlian',
        ),
        MascotRolePoint(
          icon: Icons.format_quote_rounded,
          labelEn: 'Inspiring quotes & local Quote Card Studio PNG exporter',
          labelId: 'Kutipan inspiratif & studio ekspor kartu kutipan PNG lokal',
        ),
      ],
      destinationTabIndex: 4,
    ),
    MascotCompanionProfile(
      id: NestinMascotId.twill,
      name: 'Twill',
      speciesEn: 'Weaver Bird',
      speciesId: 'Burung Tempua',
      archetypeEn: 'The Little Architect',
      archetypeId: 'Arsitek Kecil Rapi',
      domainTitleEn: 'Notes, Lists & Money',
      domainTitleId: 'Catatan, Daftar & Keuangan',
      dayWindowEn: 'Midday Structure • 12:00–20:00',
      dayWindowId: 'Struktur Siang • 12:00–20:00',
      accentColor: AppColors.twill,
      lightInkColor: AppColors.twillDark,
      primarySpriteAsset: 'assets/mascots/sprites/twill/organized.png',
      altSpriteAsset: 'assets/mascots/sprites/twill/checklist.png',
      fallbackIcon: Icons.edit_note_rounded,
      primarySpeechEn:
          'A tidy nest makes a calm mind—notes, packing checklists, and offline wallets all sorted!',
      primarySpeechId:
          'Sarang rapi bikin pikiran tenang—catatan, daftar kemas, dan dompet manual tersusun!',
      altSpeechEn:
          'Purely private personal money management: track wallets & budgets offline—no bank links.',
      altSpeechId:
          'Murni pengelola uang pribadi offline: catat dompet & anggaran tanpa tautan bank.',
      roles: [
        MascotRolePoint(
          icon: Icons.description_rounded,
          labelEn: 'Rich Markdown notes with instant 1-tap checkbox toggles',
          labelId: 'Catatan Markdown dengan centang daftar periksa langsung 1-ketuk',
        ),
        MascotRolePoint(
          icon: Icons.luggage_rounded,
          labelEn: 'Reusable trip packing templates, custom lists & wishlists',
          labelId: 'Template daftar kemas perjalanan berulang, koleksi & wishlist',
        ),
        MascotRolePoint(
          icon: Icons.account_balance_wallet_rounded,
          labelEn: 'Offline personal money tracking: wallets, budgets & monthly reports',
          labelId: 'Pencatat keuangan pribadi offline: dompet, anggaran & laporan',
        ),
      ],
      destinationTabIndex: 2,
      destinationSubTabIndex: 0,
    ),
    MascotCompanionProfile(
      id: NestinMascotId.echo,
      name: 'Echo',
      speciesEn: 'Wise Owl',
      speciesId: 'Burung Hantu Bijak',
      archetypeEn: 'The Thoughtful Observer',
      archetypeId: 'Pengamat Bijak',
      domainTitleEn: 'Journal & Memories',
      domainTitleId: 'Jurnal & Kenangan',
      dayWindowEn: 'Dusk Reflections • 20:00–22:30',
      dayWindowId: 'Refleksi Senja • 20:00–22:30',
      accentColor: AppColors.echo,
      lightInkColor: AppColors.echoDark,
      primarySpriteAsset: 'assets/mascots/sprites/echo/reflect.png',
      altSpriteAsset: 'assets/mascots/sprites/echo/grateful.png',
      fallbackIcon: Icons.auto_stories_rounded,
      primarySpeechEn:
          'The day is slowing down. Tell me one small highlight or gratitude worth keeping.',
      primarySpeechId:
          'Hari mulai tenang. Ceritakan satu momen berharga atau hal yang kamu syukuri.',
      altSpeechEn:
          'Every private diary entry stays on your device—with custom clues, PINs, or biometrics.',
      altSpeechId:
          'Setiap diari pribadimu tetap aman di perangkat—dengan petunjuk, PIN, atau biometrik.',
      roles: [
        MascotRolePoint(
          icon: Icons.mood_rounded,
          labelEn: 'Daily mood check-ins, writing prompt carousels & Gratitude Jar',
          labelId: 'Check-in suasana hati, pemantik tulisan & Stoples Syukur',
        ),
        MascotRolePoint(
          icon: Icons.photo_album_rounded,
          labelEn: 'Life timeline milestones & "On This Day" nostalgic throwbacks',
          labelId: 'Linimasa tonggak hidup & kenangan "Pada Hari Ini"',
        ),
        MascotRolePoint(
          icon: Icons.lock_rounded,
          labelEn: 'Configurable auto-lock diary vault with 4–8 digit PIN & password clues',
          labelId: 'Kunci diari otomatis dengan PIN 4–8 digit & petunjuk sandi',
        ),
      ],
      destinationTabIndex: 3,
      destinationSubTabIndex: 0,
    ),
  ];

  static MascotCompanionProfile byId(NestinMascotId id) {
    return companions.firstWhere((m) => m.id == id);
  }
}
