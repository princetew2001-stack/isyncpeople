import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../utils/auth_service.dart';
import '../utils/dummy_data_service.dart';

class ApplicationApprovalPage extends StatefulWidget {
  const ApplicationApprovalPage({super.key});

  @override
  State<ApplicationApprovalPage> createState() => _ApplicationApprovalPageState();
}

class _ApplicationApprovalPageState extends State<ApplicationApprovalPage> {
  List<ApplicationData> applications = [];
  List<UserData> users = [];
  List<UnitData> units = [];
  bool isLoading = true;
  String? selectedEmployeeId;
  String? selectedUnitId;
  String? selectedStatus;
  
  // Filter controllers
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 ApplicationApprovalPage initialized');
    _loadApplications();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    debugPrint('🔄 Starting to load applications...');
    setState(() {
      isLoading = true;
    });

    try {
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - loading dummy application approval data');
        
        final dummyApprovals = DummyDataService.getDummyApplicationApprovalData();
        
        // Convert dummy data to ApplicationData format
        final convertedApplications = dummyApprovals.map((app) {
          // Parse dates properly
          DateTime? fromDate;
          DateTime? tillDate;
          DateTime appliedOn = DateTime.now();
          
          try {
            if (app['from_date'] != null && app['from_date'].toString().isNotEmpty) {
              fromDate = DateTime.parse(app['from_date']);
            }
          } catch (e) {
            debugPrint('Error parsing from_date: $e');
          }
          
          try {
            if (app['to_date'] != null && app['to_date'].toString().isNotEmpty) {
              tillDate = DateTime.parse(app['to_date']);
            }
          } catch (e) {
            debugPrint('Error parsing to_date: $e');
          }
          
          try {
            if (app['applied_date'] != null && app['applied_date'].toString().isNotEmpty) {
              appliedOn = DateTime.parse(app['applied_date']);
            }
          } catch (e) {
            debugPrint('Error parsing applied_date: $e');
          }
          
          return ApplicationData(
            id: int.tryParse(app['id'] ?? '0') ?? 0,
            userId: int.tryParse(app['employee_id']?.replaceAll('EMP', '') ?? '0') ?? 0,
            dep: app['department'] ?? 'Information Technology',
            applicationType: app['type'] ?? '',
            leaveType: app['application_type'] ?? '',
            fromDate: fromDate,
            tillDate: tillDate,
            time: null,
            dayPart: 'Full Day',
            dayCount: app['days']?.toString() ?? '0',
            reason: app['reason'] ?? '',
            address: null,
            visitLocationType: null,
            mobileNumber: null,
            status: app['status'] ?? 'Pending',
            remarks: '',
            attachment: null,
            appliedOn: appliedOn,
            approvedOn: null,
            cancelledOn: null,
            userLocationId: 1,
            displayName: app['employee_name'] ?? '',
            displayUnit: 'IT Department',
          );
        }).toList();
        
        setState(() {
          applications = convertedApplications;
          users = [
            UserData(id: 1, fullName: 'Test Manager', locationId: 1),
          ];
          units = [
            UnitData(id: 1, name: 'IT Department', address: 'Noida Office'),
          ];
          isLoading = false;
        });
        
        debugPrint('✅ Dummy application approval data loaded: ${convertedApplications.length} applications');
        return;
      }
      // Build endpoint with filter parameters and cache busting
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String endpoint = '/ess/application-approval/?json=1&_t=$timestamp';
      
      // Add employee ID filter
      if (selectedEmployeeId != null && selectedEmployeeId != 'all') {
        endpoint += '&eid=$selectedEmployeeId';
      } else {
        endpoint += '&eid=';
      }
      
      // Add date filters
      if (_fromDateController.text.isNotEmpty) {
        // Convert MM/dd/yyyy to yyyy-MM-dd format
        final fromDate = _convertDateFormat(_fromDateController.text);
        endpoint += '&from_date=$fromDate';
      } else {
        endpoint += '&from_date=';
      }
      
      if (_toDateController.text.isNotEmpty) {
        // Convert MM/dd/yyyy to yyyy-MM-dd format
        final toDate = _convertDateFormat(_toDateController.text);
        endpoint += '&till_date=$toDate';
      } else {
        endpoint += '&till_date=';
      }
      
      // Add status filter
      if (selectedStatus != null && selectedStatus != 'all') {
        endpoint += '&status=$selectedStatus';
      } else {
        endpoint += '&status=';
      }
      
      // Add unit filter
      if (selectedUnitId != null && selectedUnitId != 'all') {
        endpoint += '&unit=$selectedUnitId';
      } else {
        endpoint += '&unit=';
      }
      
      debugPrint('🔗 Fetching application approval data from: $endpoint');
      
      debugPrint('📡 Making authenticated request...');
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      debugPrint('📊 Response received - Status Code: ${response.statusCode}');
      debugPrint('📄 Response Body Length: ${response.body.length} characters');
      debugPrint('📝 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ Successful response, parsing JSON...');
        final responseData = jsonDecode(response.body);
        debugPrint('🔍 Parsed JSON keys: ${responseData.keys.toList()}');
        
        if (responseData['application_list'] != null) {
          final List<dynamic> applicationList = responseData['application_list'];
          final List<dynamic> userList = responseData['user_list'] ?? [];
          final List<dynamic> unitList = responseData['unit_list'] ?? [];
          
          debugPrint('📋 Found ${applicationList.length} applications in response');
          debugPrint('👥 Found ${userList.length} users in response');
          debugPrint('🏢 Found ${unitList.length} units in response');
          
          // Parse users (for backward compatibility with old format)
          final convertedUsers = <UserData>[];
          for (int i = 0; i < userList.length; i++) {
            try {
              final user = UserData.fromJson(userList[i]);
              convertedUsers.add(user);
              debugPrint('✅ Successfully converted user $i: ID=${user.id}, Name="${user.fullName}", LocationID=${user.locationId}');
            } catch (e) {
              debugPrint('❌ Error converting user $i: $e');
              debugPrint('📄 Problematic user JSON: ${userList[i]}');
            }
          }
          
          // Parse units (for backward compatibility with old format)
          final convertedUnits = <UnitData>[];
          for (int i = 0; i < unitList.length; i++) {
            try {
              final unit = UnitData.fromJson(unitList[i]);
              convertedUnits.add(unit);
              debugPrint('✅ Successfully converted unit $i: ID=${unit.id}, Name="${unit.name}", Address="${unit.address}"');
            } catch (e) {
              debugPrint('❌ Error converting unit $i: $e');
              debugPrint('📄 Problematic unit JSON: ${unitList[i]}');
            }
          }
          
          // Extract users and units from embedded application data for new format
          final Set<int> seenUserIds = <int>{};
          final Set<int> seenUnitIds = <int>{};
          
          for (final appJson in applicationList) {
            if (appJson['user'] != null) {
              final userObj = appJson['user'];
              final userId = userObj['id'];
              
              if (userId != null && !seenUserIds.contains(userId)) {
                seenUserIds.add(userId);
                try {
                  final user = UserData(
                    id: userId,
                    fullName: userObj['full_name'] ?? 'Unknown User',
                    locationId: userObj['location_id'],
                  );
                  convertedUsers.add(user);
                  debugPrint('✅ Extracted user from application: ID=${user.id}, Name="${user.fullName}"');
                } catch (e) {
                  debugPrint('❌ Error extracting user from application: $e');
                }
              }
              
              // Extract location/unit data
              if (userObj['location'] != null) {
                final locationObj = userObj['location'];
                final locationId = locationObj['id'];
                
                if (locationId != null && !seenUnitIds.contains(locationId)) {
                  seenUnitIds.add(locationId);
                  try {
                    final unit = UnitData(
                      id: locationId,
                      name: locationObj['name'] ?? 'Unknown Unit',
                      address: locationObj['name'] ?? 'N/A', // Use name as address for display
                    );
                    convertedUnits.add(unit);
                    debugPrint('✅ Extracted unit from application: ID=${unit.id}, Name="${unit.name}"');
                  } catch (e) {
                    debugPrint('❌ Error extracting unit from application: $e');
                  }
                }
              }
            }
          }
          
          debugPrint('🔄 Converting JSON to ApplicationData objects...');
          final convertedApplications = <ApplicationData>[];
          
          for (int i = 0; i < applicationList.length; i++) {
            try {
              final app = ApplicationData.fromJson(applicationList[i], convertedUsers, convertedUnits);
              convertedApplications.add(app);
              debugPrint('✅ Successfully converted application $i: ID=${app.id}, Type=${app.applicationType}, Status=${app.status}');
            } catch (e) {
              debugPrint('❌ Error converting application $i: $e');
              debugPrint('📄 Problematic JSON: ${applicationList[i]}');
            }
          }
          
          setState(() {
            applications = convertedApplications;
            users = convertedUsers;
            units = convertedUnits;
            isLoading = false;
          });
          
          debugPrint('🎉 Successfully loaded ${applications.length} applications');
          debugPrint('👥 Successfully loaded ${users.length} users');
          debugPrint('🏢 Successfully loaded ${units.length} units');
          
          // Debug: Print first few applications with resolved names
          for (int i = 0; i < applications.length && i < 3; i++) {
            final app = applications[i];
            debugPrint('📋 App $i: ID=${app.id}, User=${app.displayName}, Unit=${app.displayUnit}, Type=${app.applicationType}');
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Loaded ${applications.length} applications from ${users.length} users across ${units.length} units'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          debugPrint('⚠️ No application_list found in response');
          setState(() {
            applications = [];
            isLoading = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No applications found'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        debugPrint('❌ HTTP Error - Status: ${response.statusCode}');
        debugPrint('📄 Error Response Body: ${response.body}');
        
        String errorMessage;
        
        // Check for specific server errors
        if (response.statusCode == 500) {
          if (response.body.contains('QuerySet is not JSON serializable')) {
            errorMessage = 'Server Error: The backend API has a configuration issue. Please contact your system administrator to fix the QuerySet serialization in the application approval endpoint.';
          } else if (response.body.contains('TypeError')) {
            errorMessage = 'Server Error: There\'s a data type issue on the server. Please contact your system administrator.';
          } else {
            errorMessage = 'Internal Server Error (500): The server encountered an unexpected error. Please try again later or contact support.';
          }
        } else if (response.statusCode == 404) {
          errorMessage = 'API Endpoint Not Found (404): The application approval service is not available. Please contact your system administrator.';
        } else if (response.statusCode == 403) {
          errorMessage = 'Access Denied (403): You don\'t have permission to view application approvals. Please contact your administrator.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Authentication Error (401): Your session has expired. Please log in again.';
        } else if (response.statusCode >= 500) {
          errorMessage = 'Server Error (${response.statusCode}): The server is experiencing issues. Please try again later.';
        } else if (response.statusCode >= 400) {
          errorMessage = 'Request Error (${response.statusCode}): There was an issue with your request. Please try again.';
        } else {
          errorMessage = 'Unexpected Error (${response.statusCode}): Please try again or contact support.';
        }
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('💥 Exception occurred: $e');
      debugPrint('📍 Exception type: ${e.runtimeType}');
      
      setState(() {
        isLoading = false;
      });
      
      if (mounted) {
        String userMessage;
        
        if (e.toString().contains('Server Error') || e.toString().contains('Server configuration error')) {
          userMessage = e.toString().replaceFirst('Exception: ', '');
        } else if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
          userMessage = 'Network Error: Please check your internet connection and try again.';
        } else if (e.toString().contains('TimeoutException')) {
          userMessage = 'Request Timeout: The server is taking too long to respond. Please try again.';
        } else if (e.toString().contains('FormatException')) {
          userMessage = 'Data Format Error: The server returned invalid data. Please contact support.';
        } else {
          userMessage = 'Error loading applications: ${e.toString().replaceFirst('Exception: ', '')}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _loadApplications();
              },
            ),
          ),
        );
      }
    }
  }

  // Helper method to convert MM/dd/yyyy to yyyy-MM-dd format
  String _convertDateFormat(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final month = parts[0].padLeft(2, '0');
        final day = parts[1].padLeft(2, '0');
        final year = parts[2];
        return '$year-$month-$day';
      }
    } catch (e) {
      debugPrint('Error converting date format: $dateStr');
    }
    return dateStr;
  }

  List<ApplicationData> get filteredApplications {
    // Since we're now doing server-side filtering, just return all applications
    // The server already filtered them based on our parameters
    debugPrint('📊 Returning ${applications.length} server-filtered applications');
    return applications;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 Building ApplicationApprovalPage UI');
    debugPrint('📊 isLoading: $isLoading');
    debugPrint('📋 applications.length: ${applications.length}');
    debugPrint('🔍 filteredApplications.length: ${filteredApplications.length}');
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Application Approval',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: isLoading ? null : _loadApplications,
            tooltip: 'Refresh Applications',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // First row of filters
                Row(
                  children: [
                    Expanded(
                      child: _buildEmployeeDropdown(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildUnitDropdown(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusDropdown(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Second row with date filters, search button, and clear button
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        controller: _fromDateController,
                        hint: 'mm / dd / yyyy',
                        icon: Icons.calendar_today,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateField(
                        controller: _toDateController,
                        hint: 'mm / dd / yyyy',
                        icon: Icons.calendar_today,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Reload applications with current filter parameters
                        debugPrint('🔍 Search button pressed - reloading with filters');
                        debugPrint('📋 Current filters:');
                        debugPrint('   - Employee ID: $selectedEmployeeId');
                        debugPrint('   - Unit ID: $selectedUnitId');
                        debugPrint('   - Status: $selectedStatus');
                        debugPrint('   - From Date: ${_fromDateController.text}');
                        debugPrint('   - To Date: ${_toDateController.text}');
                        _loadApplications();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        // Clear all filters and reload
                        debugPrint('🔄 Clear filters button pressed');
                        setState(() {
                          selectedEmployeeId = null;
                          selectedUnitId = null;
                          selectedStatus = null;
                          _fromDateController.clear();
                          _toDateController.clear();
                        });
                        _loadApplications();
                      },
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      tooltip: 'Clear Filters',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Table Section with Horizontal Scroll
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredApplications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No applications found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters or refresh the page',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadApplications,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 1600, // Adjusted width to fit all columns properly
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      alignment: Alignment.center,
                                      child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 99,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: const Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 99,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: const Text('Reporting Person', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 49,
                                      alignment: Alignment.center,
                                      child: const Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 89,
                                      alignment: Alignment.center,
                                      child: const Text('Application Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 109,
                                      alignment: Alignment.center,
                                      child: const Text('Applied On', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 69,
                                      alignment: Alignment.center,
                                      child: const Text('No. of Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 89,
                                      alignment: Alignment.center,
                                      child: const Text('Half / Full Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 89,
                                      alignment: Alignment.center,
                                      child: const Text('From Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 89,
                                      alignment: Alignment.center,
                                      child: const Text('Till Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 109,
                                      alignment: Alignment.center,
                                      child: const Text('Miss Punch Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 69,
                                      alignment: Alignment.center,
                                      child: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 109,
                                      alignment: Alignment.center,
                                      child: const Text('Approved/Rejected On', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 130,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: const Text('Approved/Rejected By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 89,
                                      alignment: Alignment.center,
                                      child: const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 79,
                                      alignment: Alignment.center,
                                      child: const Text('Attachment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Container(
                                      width: 89,
                                      alignment: Alignment.center,
                                      child: const Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Table Body
                              Expanded(
                                child: ListView.builder(
                                  scrollDirection: Axis.vertical,
                                  itemCount: filteredApplications.length,
                                  itemBuilder: (context, index) {
                                    final app = filteredApplications[index];
                                    return _buildApplicationRow(app, index);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    List<DropdownMenuItem<String>> items = [
      const DropdownMenuItem<String>(
        value: 'all',
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('-- All Employees --', style: TextStyle(fontSize: 14)),
        ),
      ),
    ];
    
    for (final user in users) {
      items.add(
        DropdownMenuItem<String>(
          value: user.id.toString(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              user.fullName,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedEmployeeId,
          hint: Text(
            '-- All Employees --',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          isExpanded: true,
          items: items,
          onChanged: (value) {
            debugPrint('👤 Employee filter changed to: $value');
            setState(() {
              selectedEmployeeId = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    List<DropdownMenuItem<String>> items = [
      const DropdownMenuItem<String>(
        value: 'all',
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('-- All Units --', style: TextStyle(fontSize: 14)),
        ),
      ),
    ];
    
    for (final unit in units) {
      items.add(
        DropdownMenuItem<String>(
          value: unit.id.toString(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              unit.name, // Use unit name instead of address
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedUnitId,
          hint: Text(
            '-- All Units --',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          isExpanded: true,
          items: items,
          onChanged: (value) {
            debugPrint('🏢 Unit filter changed to: $value');
            setState(() {
              selectedUnitId = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    const List<String> statusOptions = ['all', 'Pending', 'Approved', 'Rejected'];
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedStatus,
          hint: Text(
            '-- All Status --',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          isExpanded: true,
          items: statusOptions.map((String status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  status == 'all' ? '-- All Status --' : status,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            debugPrint('📊 Status filter changed to: $value');
            setState(() {
              selectedStatus = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: Icon(icon, color: Colors.grey[600], size: 18),
        ),
        readOnly: true,
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (picked != null) {
            controller.text = DateFormat('MM/dd/yyyy').format(picked);
          }
        },
      ),
    );
  }

  Widget _buildApplicationRow(ApplicationData app, int index) {
    debugPrint('🏗️ Building application row $index for app ID: ${app.id}');
    final isEven = index % 2 == 0;
    return Container(
      width: 1450, // Same width as the table container
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // View Button
          Container(
            width: 50,
            alignment: Alignment.center,
            child: ElevatedButton(
              onPressed: () {
                _showApplicationDetails(app);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: const Size(35, 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'View',
                style: TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Name
          Container(
            width: 99,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              app.displayName,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Reporting Person
          Container(
            width: 99,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              app.reportingManager.isNotEmpty ? app.reportingManager : 'N/A',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Unit
          Container(
            width: 49,
            alignment: Alignment.center,
            child: Text(
              app.displayUnit,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Application Type
          Container(
            width: 89,
            alignment: Alignment.center,
            child: Text(
              app.applicationType,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Applied On
          Container(
            width: 109,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd-MM-yyyy').format(app.appliedOn),
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  DateFormat('HH:mm a').format(app.appliedOn),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // No. of Days
          Container(
            width: 69,
            alignment: Alignment.center,
            child: Text(
              app.noOfDays?.toString() ?? '',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Half / Full Day
          Container(
            width: 89,
            alignment: Alignment.center,
            child: Text(
              app.halfFullDay ?? '',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // From Date
          Container(
            width: 89,
            alignment: Alignment.center,
            child: Text(
              app.fromDate != null ? DateFormat('dd-MM-yyyy').format(app.fromDate!) : '',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Till Date
          Container(
            width: 89,
            alignment: Alignment.center,
            child: Text(
              app.tillDate != null ? DateFormat('dd-MM-yyyy').format(app.tillDate!) : '',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Miss Punch Date (for Miss Punch applications, show from_date)
          Container(
            width: 109,
            alignment: Alignment.center,
            child: Text(
              app.applicationType == 'Miss Punch' && app.fromDate != null 
                  ? DateFormat('dd-MM-yyyy').format(app.fromDate!) 
                  : '',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Status
          Container(
            width: 69,
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(app.status),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                app.status,
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Approved/Rejected On
          Container(
            width: 109,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (app.approvedOn != null)
                  Text(
                    DateFormat('dd-MM-yyyy').format(app.approvedOn!),
                    style: const TextStyle(fontSize: 9, color: Colors.green),
                  )
                else if (app.cancelledOn != null)
                  Text(
                    DateFormat('dd-MM-yyyy').format(app.cancelledOn!),
                    style: const TextStyle(fontSize: 9, color: Colors.red),
                  )
                else
                  const Text(
                    '-',
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                if (app.approvedOn != null)
                  Text(
                    DateFormat('HH:mm a').format(app.approvedOn!),
                    style: const TextStyle(fontSize: 8, color: Colors.green),
                  )
                else if (app.cancelledOn != null)
                  Text(
                    DateFormat('HH:mm a').format(app.cancelledOn!),
                    style: const TextStyle(fontSize: 8, color: Colors.red),
                  ),
              ],
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Approved/Rejected By
          Container(
            width: 130,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              app.updatedByName.isNotEmpty ? app.updatedByName : '-',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Leave Type
          Container(
            width: 89,
            alignment: Alignment.center,
            child: Text(
              app.leaveType ?? '',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Attachment
          Container(
            width: 79,
            alignment: Alignment.center,
            child: app.attachment != null && app.attachment!.isNotEmpty
                ? ElevatedButton(
                    onPressed: () {
                      _downloadAttachment(app.attachment!, app.id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      minimumSize: const Size(60, 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Download',
                      style: TextStyle(color: Colors.white, fontSize: 8),
                    ),
                  )
                : const Text('', style: TextStyle(fontSize: 11)),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          
          // Remarks
          Container(
            width: 89,
            alignment: Alignment.center,
            child: Text(
              app.remarks ?? '',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showApplicationDetails(ApplicationData app) {
    final TextEditingController remarkController = TextEditingController();
    bool remarkError = false;
    double shakeOffset = 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            Future<void> shakeField() async {
              final offsets = [8.0, -8.0, 6.0, -6.0, 4.0, -4.0, 0.0];
              for (final offset in offsets) {
                setDialogState(() => shakeOffset = offset);
                await Future.delayed(const Duration(milliseconds: 50));
              }
            }

            return AlertDialog(
              title: Text('Application Details - ${app.applicationType}'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow('Employee:', app.displayName),
                    _buildDetailRow('Unit:', app.displayUnit),
                    _buildDetailRow('Application Type:', app.applicationType),
                    if (app.leaveType != null) _buildDetailRow('Leave Type:', app.leaveType!),
                    _buildDetailRow('Applied On:', DateFormat('dd-MM-yyyy HH:mm a').format(app.appliedOn)),
                    if (app.noOfDays != null) _buildDetailRow('No. of Days:', app.noOfDays.toString()),
                    if (app.halfFullDay != null) _buildDetailRow('Day Part:', app.halfFullDay!),
                    if (app.fromDate != null) _buildDetailRow('From Date:', DateFormat('dd-MM-yyyy').format(app.fromDate!)),
                    if (app.tillDate != null) _buildDetailRow('Till Date:', DateFormat('dd-MM-yyyy').format(app.tillDate!)),
                    if (app.time != null) _buildDetailRow('Time:', app.time!),
                    if (app.reason != null) _buildDetailRow('Reason:', app.reason!),
                    if (app.address != null) _buildDetailRow('Address:', app.address!),
                    if (app.mobileNumber != null) _buildDetailRow('Mobile:', app.mobileNumber!),
                    if (app.remarks != null) _buildDetailRow('Remarks:', app.remarks!),
                    // Attachment with download button
                    if (app.attachment != null && app.attachment!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text(
                              'Attachment:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _downloadAttachment(app.attachment!, app.id);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download, size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Download',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(app.status),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            app.status,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Remark label
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Remark',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                          ),
                          TextSpan(
                            text: remarkError ? '  * required for rejection' : '  (optional for approval)',
                            style: TextStyle(
                              fontSize: 12,
                              color: remarkError ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Shake wrapper — offset lives outside builder so it persists across rebuilds
                    Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: TextField(
                        controller: remarkController,
                        maxLines: 3,
                        onChanged: (_) {
                          if (remarkError) {
                            setDialogState(() => remarkError = false);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter remark...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue[700]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: remarkError ? Colors.red : Colors.grey[300]!,
                              width: remarkError ? 2 : 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    // Inline error message just below the field
                    if (remarkError) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Please fill this field before rejecting.',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (app.status.toLowerCase() == 'pending') ...[
                  TextButton(
                    onPressed: () {
                      final remark = remarkController.text.trim();
                      if (remark.isEmpty) {
                        setDialogState(() => remarkError = true);
                        shakeField();
                        return;
                      }
                      Navigator.pop(context);
                      _updateApplicationStatus(app, 'Rejected', remark);
                    },
                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final remark = remarkController.text.trim();
                      Navigator.pop(context);
                      _updateApplicationStatus(app, 'Approved', remark.isEmpty ? null : remark);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Approve', style: TextStyle(color: Colors.white)),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAttachment(String attachmentPath, int applicationId) async {
    debugPrint('🔽 Downloading attachment: $attachmentPath for application ID: $applicationId');
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Downloading file...'),
              ],
            ),
          );
        },
      );

      // Construct full URL for the attachment
      final attachmentUrl = '${_authService.baseUrl}/media/$attachmentPath';
      debugPrint('🔗 Attachment URL: $attachmentUrl');
      
      // Get authentication headers
      final headers = await _authService.getAuthHeaders();
      
      // Download the file
      final response = await http.get(
        Uri.parse(attachmentUrl),
        headers: headers,
      );
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
      
      if (response.statusCode == 200) {
        // Get the downloads directory
        final directory = await getApplicationDocumentsDirectory();
        final fileName = attachmentPath.split('/').last;
        final filePath = '${directory.path}/$fileName';
        
        // Write the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        debugPrint('✅ File downloaded to: $filePath');
        
        // Open the file
        final result = await OpenFile.open(filePath);
        
        if (result.type == ResultType.done) {
          debugPrint('✅ File opened successfully');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('File downloaded and opened successfully'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          debugPrint('⚠️ Could not open file: ${result.message}');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('File downloaded but could not open: ${result.message}'),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        debugPrint('❌ Failed to download file: ${response.statusCode}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Failed to download file (${response.statusCode})'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error downloading attachment: $e');
      
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error downloading file: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _updateApplicationStatus(ApplicationData app, String newStatus, [String? remark]) async {
    debugPrint('🔄 Updating application status...');
    debugPrint('🆔 Application ID: ${app.id}');
    debugPrint('📊 Current Status: ${app.status}');
    debugPrint('🔄 New Status: $newStatus');
    debugPrint('💬 Remark: ${remark ?? "No remark provided"}');
    
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Updating application status...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get fresh session info to ensure valid CSRF token
      debugPrint('🔄 Getting fresh session info for CSRF token...');
      final sessionInfo = await _authService.getSessionInfo();
      if (sessionInfo == null) {
        debugPrint('❌ Failed to get fresh session info');
        throw Exception('Failed to get session info. Please login again.');
      }
      
      debugPrint('✅ Fresh session obtained with CSRF token');

      // Prepare API payload - match the HTML form field names exactly
      final payload = <String, String>{
        'id': app.id.toString(),
        'remarks': remark ?? '',
      };
      
      // Add the correct action field based on approve/reject
      if (newStatus == 'Approved') {
        payload['approve_with_remarks'] = 'Approve';
      } else {
        payload['reject_with_remarks'] = 'Reject';
      }
      
      debugPrint('📤 API Payload: $payload');
      
      // Make API call to update application status
      // Try using the same endpoint but with proper form submission
      const endpoint = '/ess/application-approval/';
      
      // Debug: Log current user info to check permissions
      debugPrint('🔍 Checking current user permissions...');
      final userInfo = await _authService.getEmployeeProfile();
      debugPrint('👤 Current user: ${userInfo?['emp_name']} (${userInfo?['emp_code']})');
      
      // Add CSRF token to the payload for form submission
      final csrfToken = await _authService.getStoredCsrfToken();
      if (csrfToken != null) {
        payload['csrfmiddlewaretoken'] = csrfToken;
      }
      
      debugPrint('📤 Final API Payload with CSRF: $payload');
      
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'POST',
        body: payload,
      );
      
      debugPrint('📊 API Response status: ${response.statusCode}');
      
      // Only log response body if it's not HTML to avoid console spam
      if (!response.body.contains('<html') && !response.body.contains('<!DOCTYPE')) {
        debugPrint('📄 API Response body: ${response.body}');
      } else {
        debugPrint('📄 API Response: HTML page returned (likely error page)');
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // API call successful - update the application status locally immediately
        debugPrint('✅ API call successful, updating local state and refreshing from server...');
        
        // Update the application status locally so it shows immediately
        setState(() {
          final idx = applications.indexWhere((a) => a.id == app.id);
          if (idx != -1) {
            applications[idx] = applications[idx].copyWith(status: newStatus);
          }
        });
        
        // Wait for server to process the update
        await Future.delayed(const Duration(milliseconds: 1500));
        
        // Refresh from server — keep current filter so user sees what they expect
        await _loadApplications();

        String message = 'Application ${newStatus.toLowerCase()} successfully';
        if (remark != null && remark.isNotEmpty) {
          message += ' with remark: "$remark"';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message)),
                ],
              ),
              backgroundColor: newStatus == 'Approved' ? Colors.green : Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        
        debugPrint('📱 Status update notification shown');
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Handle redirect as success (common in Django forms)
        debugPrint('✅ Application status updated successfully (redirect response)');
        
        // Update the application status locally so it shows immediately
        setState(() {
          final idx = applications.indexWhere((a) => a.id == app.id);
          if (idx != -1) {
            applications[idx] = applications[idx].copyWith(status: newStatus);
          }
        });
        
        // Wait for server to process the update
        await Future.delayed(const Duration(milliseconds: 1500));
        
        // Refresh from server — keep current filter
        await _loadApplications();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Application ${newStatus.toLowerCase()} successfully')),
                ],
              ),
              backgroundColor: newStatus == 'Approved' ? Colors.green : Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // API call failed
        debugPrint('❌ API call failed with status: ${response.statusCode}');
        
        String errorMessage = 'Failed to update application status (${response.statusCode})';
        
        // Check for specific CSRF errors
        if (response.statusCode == 403 && response.body.contains('CSRF')) {
          errorMessage = 'CSRF verification failed. Please refresh the page and try again.';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  _updateApplicationStatus(app, newStatus, remark);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating application status: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error updating application: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _updateApplicationStatus(app, newStatus, remark);
              },
            ),
          ),
        );
      }
    }
  }
}

class ApplicationData {
  final int id;
  final int userId;
  final String? dep;
  final String applicationType;
  final String? leaveType;
  final DateTime? fromDate;
  final DateTime? tillDate;
  final String? time;
  final String? dayPart;
  final String? dayCount;
  final String? reason;
  final String? address;
  final String? visitLocationType;
  final String? mobileNumber;
  final String status;
  final String? remarks;
  final String? attachment;
  final DateTime appliedOn;
  final DateTime? approvedOn;
  final DateTime? cancelledOn;
  final int? userLocationId;
  
  // Resolved data from user and unit lists
  final String displayName;
  final String displayUnit;
  final String reportingManager;
  final String updatedByName;

  ApplicationData({
    required this.id,
    required this.userId,
    this.dep,
    required this.applicationType,
    this.leaveType,
    this.fromDate,
    this.tillDate,
    this.time,
    this.dayPart,
    this.dayCount,
    this.reason,
    this.address,
    this.visitLocationType,
    this.mobileNumber,
    required this.status,
    this.remarks,
    this.attachment,
    required this.appliedOn,
    this.approvedOn,
    this.cancelledOn,
    this.userLocationId,
    required this.displayName,
    required this.displayUnit,
    this.reportingManager = '',
    this.updatedByName = '',
  });

  ApplicationData copyWith({String? status}) {
    return ApplicationData(
      id: id,
      userId: userId,
      dep: dep,
      applicationType: applicationType,
      leaveType: leaveType,
      fromDate: fromDate,
      tillDate: tillDate,
      time: time,
      dayPart: dayPart,
      dayCount: dayCount,
      reason: reason,
      address: address,
      visitLocationType: visitLocationType,
      mobileNumber: mobileNumber,
      status: status ?? this.status,
      remarks: remarks,
      attachment: attachment,
      appliedOn: appliedOn,
      approvedOn: approvedOn,
      cancelledOn: cancelledOn,
      userLocationId: userLocationId,
      displayName: displayName,
      displayUnit: displayUnit,
      reportingManager: reportingManager,
      updatedByName: updatedByName,
    );
  }

  factory ApplicationData.fromJson(
    Map<String, dynamic> json, 
    List<UserData> users, 
    List<UnitData> units
  ) {
    debugPrint('🔄 Parsing ApplicationData from JSON...');
    debugPrint('📄 JSON keys: ${json.keys.toList()}');
    debugPrint('🆔 ID: ${json['id']}');
    
    try {
      // Handle both old format (user_id) and new format (user object)
      String displayName = 'Unknown User';
      String displayUnit = 'N/A';
      String reportingManager = '';
      int userId = 0;
      int? userLocationId;
      
      if (json['user'] != null) {
        // New format: user data is embedded in the application object
        final userObj = json['user'];
        userId = userObj['id'] ?? 0;
        displayName = userObj['full_name'] ?? 'Unknown User';
        userLocationId = userObj['location_id'];
        
        // Get location name from nested location object
        if (userObj['location'] != null) {
          displayUnit = userObj['location']['name'] ?? 'N/A';
        }
        
        // Get reporting manager name directly from user object
        reportingManager = userObj['reporting_manager']?.toString() ?? '';
        
        debugPrint('✅ New format - User: $displayName, Unit: $displayUnit, Reporting: $reportingManager');
      } else if (json['user_id'] != null) {
        // Old format: separate user_list and unit_list
        userId = json['user_id'] ?? 0;
        debugPrint('🔍 Looking for user with ID: $userId in ${users.length} users');
        
        // Find user data with better error handling
        UserData? foundUser;
        try {
          foundUser = users.firstWhere((u) => u.id == userId);
          debugPrint('✅ Found user: ${foundUser.fullName} (ID: ${foundUser.id})');
        } catch (e) {
          debugPrint('⚠️ User not found for ID: $userId, creating fallback user');
          foundUser = UserData(id: userId, fullName: 'User $userId', locationId: null);
        }
        
        // Find unit data based on user's location with better error handling
        UnitData foundUnit;
        if (foundUser.locationId != null) {
          debugPrint('🔍 Looking for unit with ID: ${foundUser.locationId} in ${units.length} units');
          try {
            foundUnit = units.firstWhere((u) => u.id == foundUser!.locationId);
            debugPrint('✅ Found unit: ${foundUnit.name} - ${foundUnit.address} (ID: ${foundUnit.id})');
          } catch (e) {
            debugPrint('⚠️ Unit not found for ID: ${foundUser.locationId}, creating fallback unit');
            foundUnit = UnitData(id: foundUser.locationId!, name: 'Unknown Unit', address: 'N/A');
          }
        } else {
          debugPrint('⚠️ User has no location ID, using default unit');
          foundUnit = UnitData(id: 0, name: 'No Unit', address: 'N/A');
        }
        
        displayName = foundUser.fullName.isNotEmpty ? foundUser.fullName : 'User $userId';
        displayUnit = foundUnit.address.isNotEmpty ? foundUnit.address : 'N/A';
        userLocationId = foundUser.locationId;
        
        debugPrint('✅ Old format - User: $displayName, Unit: $displayUnit');
      }
      
      debugPrint('📝 Final display values - Name: "$displayName", Unit: "$displayUnit"');
      
      final applicationData = ApplicationData(
        id: json['id'] ?? 0,
        userId: userId,
        dep: json['dep'],
        applicationType: json['application_type'] ?? '',
        leaveType: json['leave_type'],
        fromDate: json['from_date'] != null ? DateTime.parse(json['from_date']) : null,
        tillDate: json['till_date'] != null ? DateTime.parse(json['till_date']) : null,
        time: json['time'],
        dayPart: json['day_part'],
        dayCount: json['day_count'],
        reason: json['reason'],
        address: json['address'],
        visitLocationType: json['visit_location_type'],
        mobileNumber: json['mobile_number'],
        status: json['status'] ?? 'Unknown',
        remarks: json['remarks'],
        attachment: json['attachment'],
        appliedOn: json['applied_on'] != null ? DateTime.parse(json['applied_on']) : DateTime.now(),
        approvedOn: json['approved_on'] != null ? DateTime.parse(json['approved_on']) : null,
        cancelledOn: json['cancelled_on'] != null ? DateTime.parse(json['cancelled_on']) : null,
        userLocationId: userLocationId,
        displayName: displayName,
        displayUnit: displayUnit,
        reportingManager: reportingManager,
        updatedByName: json['updated_by_name']?.toString() ?? '',
      );
      
      debugPrint('✅ Successfully created ApplicationData: ID=${applicationData.id}, Type=${applicationData.applicationType}, User=${applicationData.displayName}');
      return applicationData;
    } catch (e) {
      debugPrint('❌ Error creating ApplicationData: $e');
      debugPrint('📄 Problematic JSON: $json');
      rethrow;
    }
  }

  // Helper getters for display
  int? get noOfDays => dayCount != null ? int.tryParse(dayCount!) : null;
  String? get halfFullDay => dayPart;
}

class UserData {
  final int id;
  final String fullName;
  final int? locationId;

  UserData({
    required this.id,
    required this.fullName,
    this.locationId,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    debugPrint('🔄 Parsing UserData from JSON: ${json.keys.toList()}');
    final id = json['id'] ?? 0;
    final fullName = json['full_name'] ?? 'Unknown User';
    final locationId = json['location_id'];
    
    debugPrint('📝 UserData parsed - ID: $id, Name: "$fullName", LocationID: $locationId');
    
    return UserData(
      id: id,
      fullName: fullName,
      locationId: locationId,
    );
  }
}

class UnitData {
  final int id;
  final String name;
  final String address;

  UnitData({
    required this.id,
    required this.name,
    required this.address,
  });

  factory UnitData.fromJson(Map<String, dynamic> json) {
    debugPrint('🔄 Parsing UnitData from JSON: ${json.keys.toList()}');
    final id = json['id'] ?? 0;
    final name = json['name'] ?? 'Unknown Unit';
    final address = json['address'] ?? 'N/A';
    
    debugPrint('📝 UnitData parsed - ID: $id, Name: "$name", Address: "$address"');
    
    return UnitData(
      id: id,
      name: name,
      address: address,
    );
  }
}