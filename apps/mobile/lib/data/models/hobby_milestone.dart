class HobbyMilestone {
  final String id;
  final String title;
  final int requiredHours;
  final String iconEmoji;
  final String description;

  const HobbyMilestone({
    required this.id,
    required this.title,
    required this.requiredHours,
    required this.iconEmoji,
    required this.description,
  });

  bool isUnlocked(double currentHours) => currentHours >= requiredHours;

  static const List<HobbyMilestone> standardMilestones = [
    HobbyMilestone(
      id: 'first_spark',
      title: 'First Spark',
      requiredHours: 1,
      iconEmoji: '🥉',
      description: 'Logged your very first hour of deliberate practice.',
    ),
    HobbyMilestone(
      id: 'curious_seed',
      title: 'Curious Seed',
      requiredHours: 5,
      iconEmoji: '🌱',
      description: '5 hours invested! Practice habit taking root.',
    ),
    HobbyMilestone(
      id: 'dedicated_start',
      title: 'Dedicated Start',
      requiredHours: 10,
      iconEmoji: '⚡',
      description: '10 hours of hands-on practice completed.',
    ),
    HobbyMilestone(
      id: 'quarter_century',
      title: 'Quarter Century',
      requiredHours: 25,
      iconEmoji: '⭐',
      description: '25 hours! Consistency and muscle memory blooming.',
    ),
    HobbyMilestone(
      id: 'half_century',
      title: 'Half Century Club',
      requiredHours: 50,
      iconEmoji: '🏆',
      description: '50 hours milestone reached! True dedication and skill growth.',
    ),
    HobbyMilestone(
      id: 'centurion',
      title: 'Centurion',
      requiredHours: 100,
      iconEmoji: '💎',
      description: '100 hours of craftsmanship! Solid competency unlocked.',
    ),
    HobbyMilestone(
      id: 'artisan',
      title: 'Artisan',
      requiredHours: 250,
      iconEmoji: '👑',
      description: '250 hours! Deep expertise and fluid mastery.',
    ),
    HobbyMilestone(
      id: 'virtuoso',
      title: 'Virtuoso',
      requiredHours: 500,
      iconEmoji: '🌟',
      description: '500+ hours! Elite dedication to your passion.',
    ),
  ];
}

