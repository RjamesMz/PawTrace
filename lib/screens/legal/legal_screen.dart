import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';

enum LegalTab { privacy, terms }

class LegalScreen extends StatefulWidget {
  final LegalTab initialTab;

  const LegalScreen({
    super.key,
    this.initialTab = LegalTab.privacy,
  });

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == LegalTab.privacy ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Legal & Policies',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Privacy Policy'),
                Tab(text: 'Terms & Conditions'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPrivacyPolicyTab(),
                _buildTermsOfServiceTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVACY POLICY TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPrivacyPolicyTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildHeroBanner(
          title: 'Privacy Policy',
          subtitle:
              'How ${AppConstants.appName} collects, protects, and handles your personal and pet data.',
          badge: 'Effective: October 2026',
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          number: '1',
          title: 'Introduction & Scope',
          content:
              '${AppConstants.appName} is dedicated to safeguarding pet welfare and facilitating community-based pet recovery while strictly upholding user privacy in compliance with Republic Act No. 10173 (Philippine Data Privacy Act of 2012) and international privacy standards.\n\nThis policy explains what information we collect when you register, pair GPS devices, report lost pets, or browse our services.',
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '2',
          title: 'Information We Collect',
          content: 'We collect information necessary to provide pet registration and recovery services:',
          bulletPoints: const [
            'Account Information: Name, email address, phone number, and barangay residence.',
            'Pet Profiles: Pet name, species, breed, color markings, weight, date of birth, and photos.',
            'Optional GPS Telemetry & Location: Real-time satellite coordinates and battery status only if a physical GPS collar is paired to your pet.',
            'Incident & Lost Reports: Last seen location, community sighting images, and incident descriptions.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '3',
          title: 'Location & GPS Data Retention',
          content:
              'For pets equipped with an optional GPS tracker, location data is collected solely for pet security, live tracking by verified owners, and lost pet recovery assistance.',
          bulletPoints: const [
            'Live GPS coordinates are accessible exclusively by the registered pet owner.',
            'When a lost pet report is published, only the designated vicinity or barangay is displayed to community members to protect home privacy.',
            'Unpairing a GPS tracker permanently removes the collar assignment and cleanses historical telemetry breadcrumbs.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '4',
          title: 'AI Photo Matching & Computer Vision',
          content:
              'Photos uploaded during registration and lost reporting are processed by our automated image recognition engine to identify distinctive visual patterns (fur color, facial markings, species). We do not perform human facial recognition or store biometric data of owners.',
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '5',
          title: 'Data Sharing & Disclosure',
          content:
              'We never sell, rent, or monetize your personal information. Data is only shared under the following conditions:',
          bulletPoints: const [
            'Community Alerts: When you voluntarily file a Lost Pet Report, pet details and designated emergency contact options are visible on the public feed.',
            'Barangay Administration: Authorized local administrators can access anonymized demographic data and incident summaries for community pet management.',
            'Legal Compliance: Disclosures required by lawful court order or government animal welfare regulations.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '6',
          title: 'Your Privacy Rights',
          content:
              'Under Philippine Data Privacy regulations, you retain full rights over your personal data:',
          bulletPoints: const [
            'Right to Access: View all registered pet profiles and account history.',
            'Right to Rectification: Update or correct inaccurate information at any time.',
            'Right to Erasure: Request permanent deletion of your profile, pet records, and stored photos.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '7',
          title: 'Contact Information',
          content:
              'For questions regarding this Privacy Policy, data access requests, or privacy concerns, please contact the PetTrace Data Protection team at support@petttrace.com.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TERMS OF SERVICE TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTermsOfServiceTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildHeroBanner(
          title: 'Terms & Conditions',
          subtitle:
              'Rules, rights, and responsibilities governing your use of the ${AppConstants.appName} platform.',
          badge: 'Version 2.0 · October 2026',
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          number: '1',
          title: 'Agreement to Terms',
          content:
              'By creating an account, pairing a tracker, or using ${AppConstants.appName} (mobile application and web portal), you agree to comply with and be bound by these Terms of Service. If you do not agree with any part of these terms, you must discontinue use immediately.',
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '2',
          title: 'User Accounts & Registration',
          content: 'To use ${AppConstants.appName} features, you must maintain an active and verified account:',
          bulletPoints: const [
            'You must provide accurate, current, and complete registration information.',
            'You are responsible for maintaining the confidentiality of your account credentials.',
            'Only legitimate pet owners, authorized caretakers, and verified municipal personnel may create accounts.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '3',
          title: 'Optional GPS Tracker & Hardware Rules',
          content:
              'GPS tracking is an optional feature on ${AppConstants.appName}. Pets can be registered with or without a physical tracker. When a GPS collar is paired, the following rules apply:',
          bulletPoints: const [
            'One Collar = One Pet Rule: A single GPS tracker serial number can only be linked to one active pet profile at a time.',
            'You agree to only pair hardware trackers that you legally own or are authorized to manage.',
            'PetTrace is not liable for device connectivity loss resulting from cellular carrier outages, weak satellite signals, or uncharged tracker batteries.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '4',
          title: 'Lost Pet & Sighting Reports',
          content:
              'The community reporting system is designed for genuine animal welfare and recovery:',
          bulletPoints: const [
            'Users must not submit false, fraudulent, or malicious lost/found pet reports.',
            'When submitting sighting photos, you warrant that you have the right to share the image and that it accurately depicts the incident.',
            'Spamming or abusing the alert notification system will result in immediate account suspension.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '5',
          title: 'AI Image Matching Disclaimer',
          content:
              'PetTrace provides automated AI visual matching to assist owners in identifying candidate pets based on uploaded photos. AI confidence scores are probabilistic estimates and should be verified through direct physical confirmation (such as distinctive fur patterns, facial markings, unique physical traits, or in-person inspection).',
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '6',
          title: 'Prohibited Conduct',
          content: 'You agree not to engage in any of the following activities:',
          bulletPoints: const [
            'Using the platform to stalk, harass, or track individuals without consent.',
            'Reverse engineering, decompiling, or disrupting the GPS telemetry ingestion API.',
            'Posting offensive, misleading, or abusive content in public lost pet listings.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          number: '7',
          title: 'Limitation of Liability & Governing Law',
          content:
              '${AppConstants.appName} provides tracking and recovery coordination tools on an "as-is" basis. While we strive for maximum accuracy, we cannot guarantee pet recovery under all circumstances.\n\nThese terms are governed by and construed in accordance with the laws of the Republic of the Philippines.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroBanner({
    required String title,
    required String subtitle,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String number,
    required String title,
    required String content,
    List<String>? bulletPoints,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  number,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (bulletPoints != null && bulletPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...bulletPoints.map((point) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurface,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
