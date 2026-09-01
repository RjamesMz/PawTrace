import 'package:flutter/material.dart';

class NewsStory {
  final String category;
  final String title;
  final String source;
  final String timeAgo;
  final String summary;
  final String imageUrl;
  final Color accent;

  const NewsStory({
    required this.category,
    required this.title,
    required this.source,
    required this.timeAgo,
    required this.summary,
    required this.imageUrl,
    required this.accent,
  });
}

class LostPetReport {
  final String name;
  final String breed;
  final String location;
  final String timeAgo;
  final String owner;
  final String note;
  final String imageUrl;

  const LostPetReport({
    required this.name,
    required this.breed,
    required this.location,
    required this.timeAgo,
    required this.owner,
    required this.note,
    required this.imageUrl,
  });
}

const List<NewsStory> homeNews = [
  NewsStory(
    category: 'Community Alert',
    title: 'Neighborhood volunteers helped return 4 pets this morning',
    source: 'PawTrace Updates',
    timeAgo: '12 min ago',
    summary: 'A quick sweep around the central park and barangay roads led to multiple reunions before noon.',
    imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=900',
    accent: Color(0xFFFF6600),
  ),
  NewsStory(
    category: 'Lost & Found',
    title: 'New report workflow cuts verification time for sightings',
    source: 'Field Team',
    timeAgo: '1 hour ago',
    summary: 'The updated process lets owners confirm matches faster while keeping report details easy to scan.',
    imageUrl: 'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?w=900',
    accent: Color(0xFF00796B),
  ),
  NewsStory(
    category: 'Safety Tips',
    title: 'Keep collars visible after dark with reflective tags and bright ID plates',
    source: 'Pet Safety Desk',
    timeAgo: '3 hours ago',
    summary: 'Simple visibility upgrades make a big difference when pets move through low-light streets.',
    imageUrl: 'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=900',
    accent: Color(0xFF4E7AC7),
  ),
];

const List<LostPetReport> currentLostPets = [
  LostPetReport(
    name: 'Buddy',
    breed: 'Golden Retriever',
    location: 'Central Park, North Entrance',
    timeAgo: '2 hours ago',
    owner: 'Sarah Mitchell',
    note: 'Blue reflective collar, responds to treats, microchipped.',
    imageUrl: 'https://images.unsplash.com/photo-1558788353-f76d92427f16?w=900',
  ),
  LostPetReport(
    name: 'Luna',
    breed: 'Domestic Shorthair',
    location: 'Oak Ridge Area',
    timeAgo: '5 hours ago',
    owner: 'Jenna Cruz',
    note: 'Small white patch on chest and a pink collar with a bell.',
    imageUrl: 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=900',
  ),
  LostPetReport(
    name: 'Mochi',
    breed: 'Pomeranian',
    location: 'Highland Drive',
    timeAgo: '1 day ago',
    owner: 'Alvin Reyes',
    note: 'Very friendly, fluffy cream coat, may be nervous around traffic.',
    imageUrl: 'https://images.unsplash.com/photo-1591946614720-90a587da4a36?w=900',
  ),
  LostPetReport(
    name: 'Tala',
    breed: 'Aspin Mix',
    location: 'Market District',
    timeAgo: '1 day ago',
    owner: 'Maria Santos',
    note: 'Brown collar, shy around strangers, last seen near the jeepney stop.',
    imageUrl: 'https://images.unsplash.com/photo-1601758003122-58e736c6b3b0?w=900',
  ),
  LostPetReport(
    name: 'Coco',
    breed: 'French Bulldog',
    location: 'Sunrise Subdivision',
    timeAgo: '2 days ago',
    owner: 'Daniel Lee',
    note: 'Small black harness, limps slightly on the rear right leg.',
    imageUrl: 'https://images.unsplash.com/photo-1557568192-4c5a0c0b9d6c?w=900',
  ),
  LostPetReport(
    name: 'Milo',
    breed: 'Tabby Cat',
    location: 'Riverfront Walkway',
    timeAgo: '2 days ago',
    owner: 'Patricia Gomez',
    note: 'Orange tabby with a torn ear tip and a black collar.',
    imageUrl: 'https://images.unsplash.com/photo-1513245543132-31f507417b26?w=900',
  ),
];