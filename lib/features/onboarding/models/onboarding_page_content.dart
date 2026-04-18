import 'package:flutter/material.dart';

class OnboardingPageContent {
  const OnboardingPageContent({
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.backdropColors,
    required this.overlayColor,
    required this.imageTint,
    required this.imageAlignment,
  });

  final String title;
  final String description;
  final String imageAsset;
  final List<Color> backdropColors;
  final Color overlayColor;
  final Color imageTint;
  final Alignment imageAlignment;
}

const onboardingPages = <OnboardingPageContent>[
  OnboardingPageContent(
    title: 'Care that fits\nyour day',
    description:
        'Appointments, reminders, and updates in one calm space made for patients.',
    imageAsset: 'assets/images/1.png',
    backdropColors: [Color(0xFF457B9D), Color(0xFF0B5C73)],
    overlayColor: Color(0xFF063D4F),
    imageTint: Color(0x551C667F),
    imageAlignment: Alignment.centerRight,
  ),
  OnboardingPageContent(
    title: 'Track progress\nin one glance',
    description:
        'See medications, vitals, and reports quickly with secure access anytime.',
    imageAsset: 'assets/images/2.jpg',
    backdropColors: [Color(0xFFA9573E), Color(0xFF7A2D2F)],
    overlayColor: Color(0xFF5D1F24),
    imageTint: Color(0x557A321A),
    imageAlignment: Alignment.centerLeft,
  ),
  OnboardingPageContent(
    title: 'Book, chat\nand stay ready',
    description:
        'Schedule visits and connect with your care team from one streamlined app.',
    imageAsset: 'assets/images/3.jpg',
    backdropColors: [Color(0xFF0E3D43), Color(0xFF062527)],
    overlayColor: Color(0xFF05181A),
    imageTint: Color(0x5530746A),
    imageAlignment: Alignment.topRight,
  ),
];
