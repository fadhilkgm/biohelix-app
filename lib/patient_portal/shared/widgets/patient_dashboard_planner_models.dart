part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _DoctorDetailChip extends StatelessWidget {
  const _DoctorDetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

const List<String> _plannerGoals = <String>[
  'General',
  'Diabetes',
  'Cardiac',
  'Thyroid',
  'Weight',
];

class _PeriodicTestSuggestion {
  const _PeriodicTestSuggestion({
    required this.name,
    required this.category,
    required this.reason,
    required this.priority,
  });

  final String name;
  final String category;
  final String reason;
  final String priority;
}

class _PeriodicScheduleItem {
  const _PeriodicScheduleItem({
    required this.quarter,
    required this.title,
    required this.description,
    required this.tests,
  });

  final String quarter;
  final String title;
  final String description;
  final List<String> tests;
}

class _PeriodicPlan {
  const _PeriodicPlan({
    required this.riskScore,
    required this.tier,
    required this.headline,
    required this.summary,
    required this.tests,
    required this.healthTips,
    required this.redFlags,
    required this.doctorConsultReason,
    required this.yearlySchedule,
  });

  final int riskScore;
  final String tier;
  final String headline;
  final String summary;
  final List<_PeriodicTestSuggestion> tests;
  final List<String> healthTips;
  final List<String> redFlags;
  final String doctorConsultReason;
  final List<_PeriodicScheduleItem> yearlySchedule;
}

double? _calculateBmi(double? heightCm, double? weightKg) {
  if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) {
    return null;
  }
  final meters = heightCm / 100;
  return weightKg / (meters * meters);
}

String _bmiLabel(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Normal';
  if (bmi < 30) return 'Overweight';
  return 'Obese';
}

_PeriodicPlan _buildPeriodicPlan({
  required int age,
  required double? bmi,
  required String goal,
  required bool hasSymptoms,
  required String conditions,
  required String concerns,
  required bool wantsYearlyPlan,
  required int documentCount,
  required int labOrderCount,
}) {
  final normalizedConditions = conditions.toLowerCase();
  final normalizedConcerns = concerns.toLowerCase();
  var riskScore = 10;
  final redFlags = <String>[];
  final tests = <_PeriodicTestSuggestion>[
    const _PeriodicTestSuggestion(
      name: 'CBC',
      category: 'Baseline',
      reason: 'General screening for anemia, infection, and inflammation.',
      priority: 'Essential',
    ),
    const _PeriodicTestSuggestion(
      name: 'Fasting Blood Sugar',
      category: 'Metabolic',
      reason: 'Baseline sugar screening for preventive follow-up.',
      priority: 'Essential',
    ),
    const _PeriodicTestSuggestion(
      name: 'Urine Routine',
      category: 'Baseline',
      reason: 'General screening for renal and urinary issues.',
      priority: 'Essential',
    ),
  ];
  final healthTips = <String>[];

  void addTest(_PeriodicTestSuggestion suggestion) {
    if (tests.any((item) => item.name == suggestion.name)) return;
    tests.add(suggestion);
  }

  if (age >= 40) {
    riskScore += 15;
    addTest(
      const _PeriodicTestSuggestion(
        name: 'Lipid Profile',
        category: 'Cardiac risk',
        reason: 'Recommended for age-linked cardiovascular risk screening.',
        priority: 'Recommended',
      ),
    );
  }
  if (age >= 55) {
    riskScore += 10;
    addTest(
      const _PeriodicTestSuggestion(
        name: 'Kidney Function Test',
        category: 'Renal',
        reason:
            'Older adults benefit from renal monitoring, especially with chronic disease risk.',
        priority: 'Recommended',
      ),
    );
  }
  if (hasSymptoms) {
    riskScore += 15;
    healthTips.add(
      'Do not delay medical review if symptoms are worsening or recurrent.',
    );
  }
  if (normalizedConditions.contains('diabetes')) {
    riskScore += 20;
    addTest(
      const _PeriodicTestSuggestion(
        name: 'HbA1c',
        category: 'Diabetes',
        reason: 'Tracks average sugar control across the prior 2-3 months.',
        priority: 'Essential',
      ),
    );
    addTest(
      const _PeriodicTestSuggestion(
        name: 'Urine Microalbumin',
        category: 'Diabetes',
        reason: 'Screens for early kidney impact from diabetes.',
        priority: 'Recommended',
      ),
    );
  }
  if (normalizedConditions.contains('hypertension') ||
      normalizedConcerns.contains('bp')) {
    riskScore += 15;
    addTest(
      const _PeriodicTestSuggestion(
        name: 'Renal Function and Electrolytes',
        category: 'Blood pressure',
        reason: 'Helps monitor kidney impact and treatment safety.',
        priority: 'Recommended',
      ),
    );
  }
  if (normalizedConditions.contains('thyroid') || goal == 'Thyroid') {
    riskScore += 12;
    addTest(
      const _PeriodicTestSuggestion(
        name: 'Thyroid Profile (T3/T4/TSH)',
        category: 'Hormonal',
        reason:
            'Useful for thyroid symptoms, medication follow-up, or unexplained weight changes.',
        priority: 'Essential',
      ),
    );
  }
  if (goal == 'Cardiac') {
    riskScore += 12;
    addTest(
      const _PeriodicTestSuggestion(
        name: 'ECG',
        category: 'Cardiac risk',
        reason:
            'Supports evaluation of rhythm complaints or routine cardiac screening.',
        priority: 'Recommended',
      ),
    );
    addTest(
      const _PeriodicTestSuggestion(
        name: 'hs-CRP',
        category: 'Cardiac risk',
        reason: 'Inflammatory marker that may help frame cardiovascular risk.',
        priority: 'Optional',
      ),
    );
  }
  if (goal == 'Weight') {
    addTest(
      const _PeriodicTestSuggestion(
        name: 'Liver Function Test',
        category: 'Metabolic',
        reason:
            'Useful when weight concerns may overlap with fatty liver risk.',
        priority: 'Recommended',
      ),
    );
  }
  if (goal == 'Diabetes') {
    addTest(
      const _PeriodicTestSuggestion(
        name: 'Post Prandial Blood Sugar',
        category: 'Diabetes',
        reason:
            'Adds post-meal sugar context when planning diabetic follow-up.',
        priority: 'Recommended',
      ),
    );
  }
  if (bmi != null && (bmi >= 30 || bmi < 18.5)) {
    riskScore += 15;
    healthTips.add(
      bmi >= 30
          ? 'Focus on gradual weight reduction with structured activity and meal timing.'
          : 'Review diet quality and any unintentional weight loss with your clinician.',
    );
  }
  if (documentCount > 0) {
    healthTips.add(
      'Use report-specific chat on uploaded documents to review abnormalities before your next visit.',
    );
  }
  if (labOrderCount == 0) {
    healthTips.add(
      'You do not have any recent lab orders in the app yet, so schedule preventive screening instead of waiting for symptoms alone.',
    );
  }

  if (normalizedConcerns.contains('chest pain') ||
      normalizedConcerns.contains('breath') ||
      normalizedConcerns.contains('faint') ||
      normalizedConcerns.contains('severe')) {
    redFlags.add(
      'Your concerns include symptoms that may need prompt clinician review rather than routine screening alone.',
    );
    riskScore += 20;
  }
  if (normalizedConcerns.contains('weight loss') ||
      normalizedConcerns.contains('blood') ||
      normalizedConcerns.contains('persistent')) {
    redFlags.add(
      'Persistent or unexplained symptoms should be evaluated clinically, even if the package suggests routine tests.',
    );
    riskScore += 10;
  }

  if (healthTips.isEmpty) {
    healthTips.addAll(const <String>[
      'Maintain regular sleep, hydration, and moderate exercise between checkups.',
      'Track weight, blood pressure, and symptom changes inside the app so follow-ups stay useful.',
      'Bring old reports or upload them before consultations to make trend review faster.',
    ]);
  }

  final tier = riskScore >= 60
      ? 'Full'
      : riskScore >= 35
      ? 'Moderate'
      : 'Mini';
  final headline = switch (tier) {
    'Full' => 'Structured screening with strong follow-up emphasis',
    'Moderate' => 'Balanced package with targeted follow-up tests',
    _ => 'Lean preventive package for routine monitoring',
  };
  final summary =
      'Based on age, goal, current symptoms, BMI, and known conditions, this plan prioritizes ${tests.length} tests with a $tier-risk screening scope. Use it as a preventive package outline and confirm clinical decisions with a doctor.';
  final doctorConsultReason = redFlags.isNotEmpty || hasSymptoms
      ? 'Doctor consultation is recommended because your input suggests active concerns or follow-up needs beyond a one-time screening package.'
      : 'Doctor consultation is optional but still useful for finalizing the package and reviewing trends across uploaded reports.';

  final yearlySchedule = wantsYearlyPlan
      ? <_PeriodicScheduleItem>[
          _PeriodicScheduleItem(
            quarter: 'Q1',
            title: 'Baseline package',
            description:
                'Run the full screening package and document symptoms, weight, and blood pressure.',
            tests: tests.take(4).map((item) => item.name).toList(),
          ),
          _PeriodicScheduleItem(
            quarter: 'Q2',
            title: 'Trend follow-up',
            description:
                'Repeat the most condition-sensitive tests and review lifestyle adherence.',
            tests: tests
                .where(
                  (item) =>
                      item.category == 'Diabetes' ||
                      item.category == 'Cardiac risk' ||
                      item.priority == 'Essential',
                )
                .take(3)
                .map((item) => item.name)
                .toList(),
          ),
          _PeriodicScheduleItem(
            quarter: 'Q3',
            title: 'Doctor review checkpoint',
            description:
                'Reassess unresolved symptoms and any abnormal trends from the first half of the year.',
            tests: tests.take(2).map((item) => item.name).toList(),
          ),
          _PeriodicScheduleItem(
            quarter: 'Q4',
            title: 'Annual comparison panel',
            description:
                'Repeat baseline markers to compare year-over-year change and refresh the next plan.',
            tests: tests
                .where((item) => item.priority != 'Optional')
                .take(4)
                .map((item) => item.name)
                .toList(),
          ),
        ]
      : const <_PeriodicScheduleItem>[];

  return _PeriodicPlan(
    riskScore: riskScore > 100 ? 100 : riskScore,
    tier: tier,
    headline: headline,
    summary: summary,
    tests: tests,
    healthTips: healthTips,
    redFlags: redFlags,
    doctorConsultReason: doctorConsultReason,
    yearlySchedule: yearlySchedule,
  );
}

