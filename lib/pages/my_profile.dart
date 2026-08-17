import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/dummy_data_service.dart';
import '../utils/profile_api.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  bool isLoading = true;

  // Employee Basic Info
  String empCode = '';
  String empName = '';
  String payCode = '';
  String gender = '';
  String department = '';
  String designation = '';
  String dateOfJoining = '';
  String dateOfBirth = '';
  String reportingManager = '';

  // Personal Details
  String fatherName = '';
  String motherName = '';
  String spouseName = '';
  String personalEmail = '';
  String maritalStatus = '';
  String marriageDate = '';
  String bloodGroup = '';

  // Government ID
  String panNo = '';
  String aadharNo = '';
  String uanNo = '';
  String esiNo = '';
  
  // Emergency Contact
  String emergencyName = '';
  String emergencyRelationship = '';
  String emergencyMobile = '';
  String emergencyHomePhone = '';
  String emergencyWorkPhone = '';

  // Present Address
  String presentAddress = '';
  String presentTehsil = '';
  String presentDistrict = '';
  String presentCity = '';
  String presentState = '';
  String presentPincode = '';
  String presentCountry = '';
  
  // Permanent Address
  String permanentAddress = '';
  String permanentTehsil = '';
  String permanentDistrict = '';
  String permanentCity = '';
  String permanentState = '';
  String permanentPincode = '';
  String permanentCountry = '';
  bool sameAsPresent = false;
  
  // Contact Details
  String workPhoneNo = '';
  String extensionNo = '';
  String officialEmail = '';
  String personalEmailId = '';

  // ── TextEditingControllers for editable fields ──────────────────────────
  // Official Information (only official email editable)
  late final TextEditingController _officialEmailCtrl;

  // Personal Detail
  late final TextEditingController _fatherNameCtrl;
  late final TextEditingController _motherNameCtrl;
  late final TextEditingController _spouseNameCtrl;
  late final TextEditingController _personalEmailCtrl;
  late final TextEditingController _maritalStatusCtrl;
  late final TextEditingController _marriageDateCtrl;
  late final TextEditingController _bloodGroupCtrl;

  // Government ID
  late final TextEditingController _panNoCtrl;
  late final TextEditingController _aadharNoCtrl;
  late final TextEditingController _uanNoCtrl;
  late final TextEditingController _esiNoCtrl;

  // Original values to detect changes
  String _originalPanNo = '';
  String _originalAadharNo = '';

  // Document upload state
  String? _panCardFileName;
  String? _aadharCardFileName;
  String? _otherFileName;
  PlatformFile? _panCardFile;
  PlatformFile? _aadharCardFile;
  PlatformFile? _otherFile;
  bool _panChanged = false;
  bool _aadharChanged = false;

  bool _isSubmitting = false;

  // Emergency Contact
  late final TextEditingController _emergencyNameCtrl;
  late final TextEditingController _emergencyRelCtrl;
  late final TextEditingController _emergencyMobileCtrl;
  late final TextEditingController _emergencyHomePhoneCtrl;
  late final TextEditingController _emergencyWorkPhoneCtrl;

  // Address
  late final TextEditingController _presAddressCtrl;
  late final TextEditingController _presCityCtrl;
  late final TextEditingController _presStateCtrl;
  late final TextEditingController _presPincodeCtrl;
  late final TextEditingController _presCountryCtrl;
  late final TextEditingController _permAddressCtrl;
  late final TextEditingController _permCityCtrl;
  late final TextEditingController _permStateCtrl;
  late final TextEditingController _permPincodeCtrl;
  late final TextEditingController _permCountryCtrl;

  // Hobbies
  late final TextEditingController _hobbiesCtrl;
  late final TextEditingController _crossFunctionCtrl;

  // Qualifications
  List<Map<String, String>> academicQualifications = [
    {'degree': '', 'year': '', 'specialization': ''}
  ];
  List<Map<String, String>> professionalSkills = [
    {'skill': '', 'level': '', 'exp_years': '', 'comment': ''}
  ];

  // Work Experience
  List<Map<String, String>> workExperiences = [
    {'employer': '', 'designation': '', 'from': '', 'to': '', 'ctc': '', 'location': ''}
  ];

  // Hobbies
  String hobbies = '';
  String crossFunction = '';

  @override
  void initState() {
    super.initState();
    // Initialise all controllers with empty strings; populated after data loads
    _officialEmailCtrl    = TextEditingController();
    _fatherNameCtrl       = TextEditingController();
    _motherNameCtrl       = TextEditingController();
    _spouseNameCtrl       = TextEditingController();
    _personalEmailCtrl    = TextEditingController();
    _maritalStatusCtrl    = TextEditingController();
    _marriageDateCtrl     = TextEditingController();
    _bloodGroupCtrl       = TextEditingController();
    _panNoCtrl            = TextEditingController();
    _aadharNoCtrl         = TextEditingController();
    _uanNoCtrl            = TextEditingController();
    _esiNoCtrl            = TextEditingController();

    // Listen for changes to detect if doc upload becomes required
    _panNoCtrl.addListener(() {
      final changed = _panNoCtrl.text.trim() != _originalPanNo.trim();
      if (changed != _panChanged) setState(() => _panChanged = changed);
    });
    _aadharNoCtrl.addListener(() {
      final changed = _aadharNoCtrl.text.trim() != _originalAadharNo.trim();
      if (changed != _aadharChanged) setState(() => _aadharChanged = changed);
    });
    _emergencyNameCtrl    = TextEditingController();
    _emergencyRelCtrl     = TextEditingController();
    _emergencyMobileCtrl  = TextEditingController();
    _emergencyHomePhoneCtrl = TextEditingController();
    _emergencyWorkPhoneCtrl = TextEditingController();
    _presAddressCtrl      = TextEditingController();
    _presCityCtrl         = TextEditingController();
    _presStateCtrl        = TextEditingController();
    _presPincodeCtrl      = TextEditingController();
    _presCountryCtrl      = TextEditingController();
    _permAddressCtrl      = TextEditingController();
    _permCityCtrl         = TextEditingController();
    _permStateCtrl        = TextEditingController();
    _permPincodeCtrl      = TextEditingController();
    _permCountryCtrl      = TextEditingController();
    _hobbiesCtrl          = TextEditingController();
    _crossFunctionCtrl    = TextEditingController();
    _loadProfileData();
  }

  @override
  void dispose() {
    _officialEmailCtrl.dispose();
    _fatherNameCtrl.dispose();
    _motherNameCtrl.dispose();
    _spouseNameCtrl.dispose();
    _personalEmailCtrl.dispose();
    _maritalStatusCtrl.dispose();
    _marriageDateCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _panNoCtrl.dispose();
    _aadharNoCtrl.dispose();
    _uanNoCtrl.dispose();
    _esiNoCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyRelCtrl.dispose();
    _emergencyMobileCtrl.dispose();
    _emergencyHomePhoneCtrl.dispose();
    _emergencyWorkPhoneCtrl.dispose();
    _presAddressCtrl.dispose();
    _presCityCtrl.dispose();
    _presStateCtrl.dispose();
    _presPincodeCtrl.dispose();
    _presCountryCtrl.dispose();
    _permAddressCtrl.dispose();
    _permCityCtrl.dispose();
    _permStateCtrl.dispose();
    _permPincodeCtrl.dispose();
    _permCountryCtrl.dispose();
    _hobbiesCtrl.dispose();
    _crossFunctionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    debugPrint('🔄 MyProfilePage: _loadProfileData started');
    setState(() => isLoading = true);

    try {
      // ── Test user: use dummy data ────────────────────────────────────────
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 MyProfilePage: test user detected — loading dummy data');
        final d = DummyDataService.getDummyProfileData();
        setState(() {
          empCode          = d['employee_id'] ?? '';
          empName          = d['name'] ?? '';
          payCode          = d['employee_id'] ?? '';
          gender           = 'Male';
          department       = d['department'] ?? '';
          designation      = d['designation'] ?? '';
          dateOfJoining    = ProfileApi.formatDate(d['date_of_joining'] ?? '');
          dateOfBirth      = ProfileApi.formatDate('15-08-1990');
          reportingManager = 'Rameshwar Jaiswal';
          fatherName       = 'Suresh Kumar Singh';
          motherName       = 'Sunita Singh';
          spouseName       = 'Priya Singh';
          personalEmail    = d['email'] ?? '';
          maritalStatus    = 'Married';
          marriageDate     = '12-02-2018';
          panNo            = d['pan_number'] ?? '';
          aadharNo         = d['aadhar_number'] ?? '';
          bloodGroup       = d['blood_group'] ?? '';
          uanNo            = '';
          esiNo            = '';
          emergencyName         = 'Priya Singh';
          emergencyRelationship = 'Spouse';
          emergencyMobile       = d['emergency_contact'] ?? '';
          emergencyHomePhone    = '+91-9876543212';
          emergencyWorkPhone    = '+91-120-4567890';
          presentAddress  = d['address'] ?? '';
          presentCity     = 'Noida';
          presentState    = 'Uttar Pradesh';
          presentPincode  = '201301';
          presentCountry  = 'India';
          permanentAddress = d['address'] ?? '';
          permanentCity    = 'Noida';
          permanentState   = 'Uttar Pradesh';
          permanentPincode = '201301';
          permanentCountry = 'India';
          officialEmail    = d['email'] ?? '';
          isLoading        = false;
        });
        _syncControllers();
        debugPrint('✅ MyProfilePage: dummy data loaded and controllers synced');
        return;
      }

      // ── Real user: call the profile API ─────────────────────────────────
      debugPrint('🌐 MyProfilePage: fetching profile from API');
      final data = await ProfileApi().fetchProfile();

      if (data == null) {
        debugPrint('❌ MyProfilePage: ProfileApi returned null');
        throw Exception('Failed to load profile data');
      }

      debugPrint('✅ MyProfilePage: profile data received, mapping to state');

      const s = ProfileApi.str;

      setState(() {
        // Official Information
        empCode          = s(data, 'emp_code');
        empName          = s(data, 'emp_name');
        payCode          = s(data, 'pay_code');
        gender           = s(data, 'gender');
        department       = s(data, 'department');
        designation      = s(data, 'designation');
        dateOfJoining    = ProfileApi.formatDate(s(data, 'doj'));
        dateOfBirth      = ProfileApi.formatDate(s(data, 'dob'));
        reportingManager = s(data, 'reporting_manager');
        officialEmail    = s(data, 'official_email');

        // Personal Detail
        fatherName    = s(data, 'father_name');
        motherName    = s(data, 'mother_name');
        spouseName    = s(data, 'spouse_name');
        personalEmail = s(data, 'personal_email');
        maritalStatus = s(data, 'marital_status');
        marriageDate  = s(data, 'marriage_date');
        bloodGroup    = s(data, 'blood_group');

        // Government ID
        panNo   = s(data, 'pan_no');
        aadharNo = s(data, 'aadhar_no');
        uanNo   = s(data, 'uan_no');
        esiNo   = s(data, 'esi_no');

        // Emergency Contact
        emergencyName         = s(data, 'emergency_name');
        emergencyRelationship = s(data, 'emergency_relation');
        emergencyMobile       = s(data, 'emergency_mobile');
        emergencyHomePhone    = s(data, 'emergency_phone');
        emergencyWorkPhone    = '';

        // Address
        presentAddress  = s(data, 'pres_address');
        presentCity     = s(data, 'pres_city');
        presentTehsil   = s(data, 'pres_tehsil');
        presentDistrict = s(data, 'pres_district');
        presentState    = s(data, 'pres_state');
        presentPincode  = s(data, 'pres_pin');
        presentCountry  = s(data, 'pres_country');

        permanentAddress  = s(data, 'perm_address');
        permanentCity     = s(data, 'perm_city');
        permanentTehsil   = s(data, 'perm_tehsil');
        permanentDistrict = s(data, 'perm_district');
        permanentState    = s(data, 'perm_state');
        permanentPincode  = s(data, 'perm_pin');
        permanentCountry  = s(data, 'perm_country');

        // Qualifications, Skills, Experiences
        academicQualifications = ProfileApi.parseQualifications(data['qualifications']);
        professionalSkills     = ProfileApi.parseSkills(data['skills']);
        workExperiences        = ProfileApi.parseExperiences(data['experiences']);

        // Hobbies
        hobbies       = ProfileApi.parseHobbies(data['hobbies'], 'Hobby');
        crossFunction = ProfileApi.parseHobbies(data['hobbies'], 'Cross Function');
      });
      _syncControllers();
      debugPrint('✅ MyProfilePage: all fields mapped and controllers synced');
      debugPrint('👤 MyProfilePage: empName=$empName, empCode=$empCode, department=$department');
      debugPrint('📅 MyProfilePage: doj=$dateOfJoining, dob=$dateOfBirth');
      debugPrint('📧 MyProfilePage: officialEmail=$officialEmail');
      debugPrint('🆔 MyProfilePage: panNo=$panNo, aadharNo=$aadharNo');
      debugPrint('🏠 MyProfilePage: presentCity=$presentCity, presentState=$presentState');
      debugPrint('✅ Profile data loaded from API');
    } catch (e, stack) {
      debugPrint('❌ MyProfilePage: error loading profile data: $e');
      debugPrint('❌ MyProfilePage: stacktrace: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      debugPrint('🏁 MyProfilePage: _loadProfileData finished, isLoading=false');
      setState(() => isLoading = false);
    }
  }

  /// Sync all TextEditingControllers from state variables after data load.
  void _syncControllers() {
    _officialEmailCtrl.text    = officialEmail;
    _fatherNameCtrl.text       = fatherName;
    _motherNameCtrl.text       = motherName;
    _spouseNameCtrl.text       = spouseName;
    _personalEmailCtrl.text    = personalEmail;
    _maritalStatusCtrl.text    = maritalStatus;
    _marriageDateCtrl.text     = marriageDate;
    _bloodGroupCtrl.text       = bloodGroup;
    _panNoCtrl.text            = panNo;
    _aadharNoCtrl.text         = aadharNo;
    _uanNoCtrl.text            = uanNo;
    _esiNoCtrl.text            = esiNo;

    // Store originals for change detection
    _originalPanNo    = panNo;
    _originalAadharNo = aadharNo;
    // Reset change flags on fresh load
    _panChanged    = false;
    _aadharChanged = false;
    _emergencyNameCtrl.text    = emergencyName;
    _emergencyRelCtrl.text     = emergencyRelationship;
    _emergencyMobileCtrl.text  = emergencyMobile;
    _emergencyHomePhoneCtrl.text = emergencyHomePhone;
    _emergencyWorkPhoneCtrl.text = emergencyWorkPhone;
    _presAddressCtrl.text      = presentAddress;
    _presCityCtrl.text         = presentCity;
    _presStateCtrl.text        = presentState;
    _presPincodeCtrl.text      = presentPincode;
    _presCountryCtrl.text      = presentCountry;
    _permAddressCtrl.text      = permanentAddress;
    _permCityCtrl.text         = permanentCity;
    _permStateCtrl.text        = permanentState;
    _permPincodeCtrl.text      = permanentPincode;
    _permCountryCtrl.text      = permanentCountry;
    _hobbiesCtrl.text          = hobbies;
    _crossFunctionCtrl.text    = crossFunction;
  }

  /// Opens the device file manager and lets the user pick a document.
  /// Allowed types: PDF, JPG, JPEG, PNG.
  Future<void> _pickFile({
    required void Function(PlatformFile file) onPicked,
  }) async {
    try {
      debugPrint('📂 MyProfilePage: opening file picker');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        debugPrint('📄 MyProfilePage: file picked — name=${file.name}, size=${file.size}, path=${file.path}');
        onPicked(file);
      } else {
        debugPrint('📂 MyProfilePage: file picker cancelled');
      }
    } catch (e) {
      debugPrint('❌ MyProfilePage: file picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitProfile() async {
    // Validate required documents
    debugPrint('📤 MyProfilePage._submitProfile: panFile=${_panCardFile?.name}, aadharFile=${_aadharCardFile?.name}, otherFile=${_otherFile?.name}');
    if (_panChanged && _panCardFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PAN Card upload is required when you change PAN No.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_aadharChanged && _aadharCardFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aadhar Card upload is required when you change Aadhar No.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final formData = <String, String>{
        'emp_code': empCode,
        'pay_code': payCode,
        'emp_name': empName,
        'gender': gender,
        'department': department,
        'designation': designation,
        'doj': dateOfJoining,
        'dob': dateOfBirth,
        'reporting_manager': reportingManager,
        'official_email': _officialEmailCtrl.text.trim(),
        'father_name': _fatherNameCtrl.text.trim(),
        'mother_name': _motherNameCtrl.text.trim(),
        'spouse_name': _spouseNameCtrl.text.trim(),
        'personal_email': _personalEmailCtrl.text.trim(),
        'marital_status': _maritalStatusCtrl.text.trim(),
        'marriage_date': _marriageDateCtrl.text.trim(),
        'blood_group': _bloodGroupCtrl.text.trim(),
        'pan_no': _panNoCtrl.text.trim(),
        'aadhar_no': _aadharNoCtrl.text.trim().replaceAll(' ', ''),
        'uan_no': _uanNoCtrl.text.trim(),
        'esi_no': _esiNoCtrl.text.trim(),
        'emergency_name': _emergencyNameCtrl.text.trim(),
        'emergency_relation': _emergencyRelCtrl.text.trim(),
        'emergency_mobile': _emergencyMobileCtrl.text.trim(),
        'emergency_phone': _emergencyHomePhoneCtrl.text.trim(),
        'pres_address': _presAddressCtrl.text.trim(),
        'pres_city': _presCityCtrl.text.trim(),
        'pres_state': _presStateCtrl.text.trim(),
        'pres_pin': _presPincodeCtrl.text.trim(),
        'pres_country': _presCountryCtrl.text.trim(),
        'perm_address': _permAddressCtrl.text.trim(),
        'perm_city': _permCityCtrl.text.trim(),
        'perm_state': _permStateCtrl.text.trim(),
        'perm_pin': _permPincodeCtrl.text.trim(),
        'perm_country': _permCountryCtrl.text.trim(),
      };

      final result = await ProfileApi().submitProfile(formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green[700] : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        if (result.success) {
          await _loadProfileData();
        }
      }
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadProfileData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Photo and Signature Card
                    _buildPhotoSignatureCard(),
                    const SizedBox(height: 16),
                    
                    // Basic Info Section
                    _buildBasicInfoSection(),
                    const SizedBox(height: 16),
                    
                    // Personal Details Section
                    _buildPersonalDetailsSection(),
                    const SizedBox(height: 16),

                    // Government ID Section
                    _buildGovernmentIdSection(),
                    const SizedBox(height: 16),
                    
                    // Emergency Contact Section
                    _buildEmergencyContactSection(),
                    const SizedBox(height: 16),
                    
                    // Contact Details Section
                    _buildContactDetailsSection(),
                    const SizedBox(height: 16),

                    // Qualifications & Skills Section
                    _buildQualificationsSection(),
                    const SizedBox(height: 16),

                    // Work Experience Section
                    _buildWorkExperienceSection(),
                    const SizedBox(height: 16),

                    // Hobbies & Extra Curricular Section
                    _buildHobbiesSection(),
                    const SizedBox(height: 16),

                    // Document Attachments Section
                    _buildDocumentAttachmentsSection(),
                    const SizedBox(height: 24),

                    // Submit / Cancel buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitProfile,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send, color: Colors.white),
                            label: Text(
                              _isSubmitting ? 'Submitting...' : 'Submit',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPhotoSignatureCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 60, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text(
                          'Photo',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 120,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Center(
                      child: Text(
                        'Signature',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dark navy header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Official Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow('Emp Code', empCode, 'Pay Code', payCode),
                _buildInfoRow('Name', empName, 'Gender', gender),
                _buildInfoRow('Department', department, 'Designation', designation),
                _buildInfoRow('DOJ', dateOfJoining, 'DOB', dateOfBirth),
                _buildInfoRow('Reporting Manager', reportingManager, '', ''),
                _buildEditableInfoRow('Official Email', _officialEmailCtrl, '', null),
              ],
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildPersonalDetailsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Personal Detail',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildEditableInfoRow('Father Name', _fatherNameCtrl, 'Mother Name', _motherNameCtrl),
                _buildEditableInfoRow('Spouse Name', _spouseNameCtrl, 'Personal Email', _personalEmailCtrl),
                _buildMaritalStatusRow(),
                _buildEditableInfoRow('Blood Group', _bloodGroupCtrl, '', null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernmentIdSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Government ID',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildEditableInfoRow('PAN No', _panNoCtrl, 'Aadhar No', _aadharNoCtrl),
                _buildEditableInfoRow('UAN No', _uanNoCtrl, 'ESI No', _esiNoCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Emergency Contact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildEditableInfoRow('Name', _emergencyNameCtrl, 'Relationship', _emergencyRelCtrl),
                _buildEditableInfoRow('Mobile No', _emergencyMobileCtrl, 'Home Phone', _emergencyHomePhoneCtrl),
                _buildEditableInfoRow('Work Phone', _emergencyWorkPhoneCtrl, '', null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetailsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Present + Permanent address side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Present Address',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _presAddressCtrl,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Permanent Address',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _permAddressCtrl,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildEditableInfoRow('Present City', _presCityCtrl, 'Present State', _presStateCtrl),
                _buildEditableInfoRow('Present PIN', _presPincodeCtrl, 'Present Country', _presCountryCtrl),
                _buildEditableInfoRow('Permanent City', _permCityCtrl, 'Permanent State', _permStateCtrl),
                _buildEditableInfoRow('Permanent PIN', _permPincodeCtrl, 'Permanent Country', _permCountryCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualificationsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Qualifications & Skills',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Academic Qualification',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildAcademicTable(),
                const SizedBox(height: 20),
                const Text('Professional Skills',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildSkillsTable(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicTable() {
    return Column(
      children: [
        ...academicQualifications.asMap().entries.map((entry) {
          final i = entry.key;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Column(
              children: [
                _buildInfoRow('Degree', academicQualifications[i]['degree'] ?? '', 'Year', academicQualifications[i]['year'] ?? ''),
                _buildInfoRow('Specialization', academicQualifications[i]['specialization'] ?? '', '', ''),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50), size: 28),
                    onPressed: () {
                      setState(() {
                        academicQualifications.insert(i + 1, {'degree': '', 'year': '', 'specialization': ''});
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSkillsTable() {
    return Column(
      children: [
        ...professionalSkills.asMap().entries.map((entry) {
          final i = entry.key;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Column(
              children: [
                _buildInfoRow('Skill', professionalSkills[i]['skill'] ?? '', 'Level', professionalSkills[i]['level'] ?? ''),
                _buildInfoRow('Exp (Years)', professionalSkills[i]['exp_years'] ?? '', 'Comment', professionalSkills[i]['comment'] ?? ''),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50), size: 28),
                    onPressed: () {
                      setState(() {
                        professionalSkills.insert(i + 1, {'skill': '', 'level': '', 'exp_years': '', 'comment': ''});
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWorkExperienceSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Work Experience',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...workExperiences.asMap().entries.map((entry) {
                  final i = entry.key;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Employer', workExperiences[i]['employer'] ?? '', 'Designation', workExperiences[i]['designation'] ?? ''),
                        _buildInfoRow('From', workExperiences[i]['from'] ?? '', 'To', workExperiences[i]['to'] ?? ''),
                        _buildInfoRow('CTC', workExperiences[i]['ctc'] ?? '', 'Location', workExperiences[i]['location'] ?? ''),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50), size: 28),
                            onPressed: () {
                              setState(() {
                                workExperiences.insert(i + 1, {
                                  'employer': '', 'designation': '', 'from': '',
                                  'to': '', 'ctc': '', 'location': ''
                                });
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHobbiesSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Hobbies & Extra Curricular',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hobbies',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _hobbiesCtrl,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cross Function',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _crossFunctionCtrl,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentAttachmentsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Document Attachments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          _buildDocRow(
            label: 'PAN Card',
            isRequired: _panChanged,
            fileName: _panCardFileName,
            onBrowse: () => _pickFile(onPicked: (file) {
              setState(() {
                _panCardFile = file;
                _panCardFileName = file.name;
              });
            }),
          ),
          _buildDocRow(
            label: 'Aadhar Card',
            isRequired: _aadharChanged,
            fileName: _aadharCardFileName,
            onBrowse: () => _pickFile(onPicked: (file) {
              setState(() {
                _aadharCardFile = file;
                _aadharCardFileName = file.name;
              });
            }),
          ),
          _buildDocRow(
            label: 'Other',
            isRequired: false,
            fileName: _otherFileName,
            onBrowse: () => _pickFile(onPicked: (file) {
              setState(() {
                _otherFile = file;
                _otherFileName = file.name;
              });
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow({
    required String label,
    required bool isRequired,
    required String? fileName,
    required VoidCallback onBrowse,
  }) {
    final missing = isRequired && fileName == null;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        color: missing ? Colors.red[50] : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    if (isRequired)
                      const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onBrowse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: missing ? Colors.red[700] : const Color(0xFF424242),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('Browse...', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName ?? 'No file selected.',
                  style: TextStyle(
                    fontSize: 12,
                    color: fileName != null ? Colors.green[700] : Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (missing)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 120),
              child: Text(
                '$label upload is required when you change this field.',
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  /// Two-column row where both fields are editable TextFields.
  /// Pass null for ctrl2 / label2 to show only the left field.
  Widget _buildEditableInfoRow(
    String label1,
    TextEditingController ctrl1,
    String label2,
    TextEditingController? ctrl2,
  ) {
    final inputDecoration = InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF1A237E))),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label1,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 4),
                TextField(
                  controller: ctrl1,
                  style: const TextStyle(fontSize: 13),
                  decoration: inputDecoration,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ctrl2 == null
                ? const SizedBox()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label2,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      TextField(
                        controller: ctrl2,
                        style: const TextStyle(fontSize: 13),
                        decoration: inputDecoration,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Marital Status (text) + Marriage Date (calendar picker) row.
  Widget _buildMaritalStatusRow() {
    final inputDecoration = InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF1A237E))),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Marital Status — normal text field
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Marital Status',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 4),
                TextField(
                  controller: _maritalStatusCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: inputDecoration,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Marriage Date — calendar picker
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Marriage Date',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    // Parse existing date if available (DD-MM-YYYY format)
                    DateTime initialDate = DateTime.now();
                    if (_marriageDateCtrl.text.isNotEmpty) {
                      try {
                        final parts = _marriageDateCtrl.text.split('-');
                        if (parts.length == 3) {
                          initialDate = DateTime(
                            int.parse(parts[2]),
                            int.parse(parts[1]),
                            int.parse(parts[0]),
                          );
                        }
                      } catch (_) {}
                    }

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF1A237E),
                              onPrimary: Colors.white,
                              onSurface: Colors.black87,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (picked != null) {
                      final formatted =
                          '${picked.day.toString().padLeft(2, '0')}-'
                          '${picked.month.toString().padLeft(2, '0')}-'
                          '${picked.year}';
                      setState(() {
                        _marriageDateCtrl.text = formatted;
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _marriageDateCtrl,
                      readOnly: true,
                      style: const TextStyle(fontSize: 13),
                      decoration: inputDecoration.copyWith(
                        hintText: 'DD-MM-YYYY',
                        hintStyle: TextStyle(
                            fontSize: 13, color: Colors.grey[400]),
                        suffixIcon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label1, String value1, String label2, String value2) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    value1.isEmpty ? '-' : value1,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: label2.isEmpty
                ? const SizedBox()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          value2.isEmpty ? '-' : value2,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }



}
