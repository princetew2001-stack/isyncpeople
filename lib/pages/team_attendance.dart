import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../utils/auth_service.dart';
import '../utils/dummy_data_service.dart';

class TeamAttendancePage extends StatefulWidget {
  const TeamAttendancePage({super.key});

  @override
  State<TeamAttendancePage> createState() => _TeamAttendancePageState();
}

class _TeamAttendancePageState extends State<TeamAttendancePage> {
  late String selectedYear;
  late String selectedMonth;

  final List<String> years = ['2023', '2024', '2025', '2026', '2027', '2028'];
  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // Team data from API
  List<Map<String, dynamic>> teamMembers = [];
  bool isLoading = false;
  
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    
    // Initialize with current month and year
    final now = DateTime.now();
    selectedYear = now.year.toString();
    selectedMonth = months[now.month - 1]; // month is 1-indexed, array is 0-indexed
    
    debugPrint('📅 Initialized with current date: $selectedMonth $selectedYear');
    
    // Automatically load team attendance data when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchTeamAttendance();
    });
  }

  // Get number of days in selected month
  int get daysInMonth {
    final monthIndex = months.indexOf(selectedMonth) + 1;
    final year = int.parse(selectedYear);
    return DateTime(year, monthIndex + 1, 0).day;
  }

  // Get day name for a specific date
  String getDayName(int day) {
    final monthIndex = months.indexOf(selectedMonth) + 1;
    final year = int.parse(selectedYear);
    final date = DateTime(year, monthIndex, day);
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayNames[date.weekday - 1];
  }

  // Method to fetch team attendance data from API
  Future<void> fetchTeamAttendance() async {
    setState(() {
      isLoading = true;
    });

    try {
      debugPrint('🔄 Fetching team attendance data...');
      debugPrint('📅 Selected: $selectedMonth $selectedYear');

      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - loading dummy team attendance data');
        
        final dummyTeamData = DummyDataService.getDummyTeamAttendanceData();
        
        // Transform dummy data to match UI structure
        final transformedData = dummyTeamData.map((member) {
          // Create attendance data array for all days of the month
          final attendanceData = List<String>.filled(daysInMonth, 'P');
          
          // Add some variation in attendance
          for (int i = 0; i < daysInMonth; i++) {
            if (i % 7 == 5 || i % 7 == 6) { // Weekends
              attendanceData[i] = 'WO';
            } else if (i == 14 || i == 25) { // Some holidays
              attendanceData[i] = 'H';
            } else if (member['status'] == 'On Leave' && i == 10) {
              attendanceData[i] = 'L';
            }
          }
          
          return {
            'name': member['name'],
            'username': member['emp_id'],
            'emp_code': member['emp_id'],
            'data': attendanceData,
            'leave_balance': [
              {'type': 'EL', 'balance': 15},
              {'type': 'SL', 'balance': 10},
              {'type': 'CL', 'balance': 11},
            ],
          };
        }).toList();
        
        setState(() {
          teamMembers = transformedData;
          isLoading = false;
        });
        
        debugPrint('✅ Dummy team attendance data loaded: ${transformedData.length} members');
        return;
      }

      // Convert month name to number
      final monthNumber = months.indexOf(selectedMonth) + 1;
      final year = int.parse(selectedYear);

      final endpoint = '/ess/team-attendance/?json=true&month=$monthNumber&year=$year';
      debugPrint('🔗 API Endpoint: $endpoint');
      
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['data'] != null) {
          final List<dynamic> apiData = responseData['data'];
          debugPrint('👥 Found ${apiData.length} team members');

          // Transform API data to match our UI structure
          final transformedData = apiData.map((member) {
            final attendanceList = member['attendance'] as List<dynamic>? ?? [];

            // Create attendance data array for all days of the month
            final attendanceData = List<String>.filled(daysInMonth, 'A');

            // Fill in the actual attendance data
            for (final attendance in attendanceList) {
              final day = attendance['day'] as int? ?? 0;
              if (day > 0 && day <= daysInMonth) {
                final status = (attendance['status'] as String? ?? 'A').trim();
                attendanceData[day - 1] = status; // day-1 because array is 0-indexed
              }
            }

            return {
              'name': member['name'] ?? 'Unknown',
              'username': member['username'] ?? '',
              'emp_code': member['emp_code'] ?? 0,
              'data': attendanceData,
              'leave_balance': member['leave_balance'] ?? [],
            };
          }).toList();

          setState(() {
            teamMembers = transformedData;
          });

          debugPrint('✅ Successfully loaded ${teamMembers.length} team members');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Loaded ${teamMembers.length} team members for $selectedMonth $selectedYear'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          debugPrint('⚠️ No data found in API response');
          setState(() {
            teamMembers = [];
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No team attendance data found'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('Failed to load team attendance: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💥 Error fetching team attendance: $e');
      setState(() {
        teamMembers = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading team attendance: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4CAF50), // Green
                Color(0xFF2196F3), // Blue
              ],
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
          'Team attendance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.table_chart, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Search in table',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.search, color: Colors.white, size: 16),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4CAF50), // Green
                  Color(0xFF2196F3), // Blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Year Dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Year',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 44, // Same as Fetch button
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: selectedYear,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF34495E),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                          items: years.map((String year) {
                            return DropdownMenuItem<String>(
                              value: year,
                              child: Text(year),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedYear = newValue!;
                            });
                            // Auto-refresh data when year changes
                            if (teamMembers.isNotEmpty) {
                              fetchTeamAttendance();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Month Dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Month',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 44, // Same as Fetch button
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: selectedMonth,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF34495E),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          items: months.map((String month) {
                            return DropdownMenuItem<String>(
                              value: month,
                              child: Text(month),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedMonth = newValue!;
                            });
                            // Auto-refresh data when month changes
                            if (teamMembers.isNotEmpty) {
                              fetchTeamAttendance();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Fetch Button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20), // Push button down to align with dropdowns
                    GestureDetector(
                      onTap: fetchTeamAttendance,
                      child: Container(
                        height: 44, // Fixed height
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isLoading ? Colors.grey : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4CAF50),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Fetch',
                                style: TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Legend Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLegendItem('P', 'Present', Colors.green),
                  _buildLegendItem('A', 'Absent', const Color(0xFFE74C3C)),
                  _buildLegendItem('WO', 'Weekly Off', Colors.grey),
                  _buildLegendItem('MS', 'Miss Punch', const Color(0xFFE74C3C)),
                  _buildLegendItem('CL', 'Casual Leave', const Color(0xFFE67E22)),
                  _buildLegendItem('EL', 'Earn Leave', const Color(0xFFE67E22)),
                  _buildLegendItem('SL', 'Sick Leave', const Color(0xFFE67E22)),
                  _buildLegendItem('OD', 'On Duty', const Color(0xFF3498DB)),
                  _buildLegendItem('CO', 'Comp-Off', const Color(0xFFE67E22)),
                  _buildLegendItem('H1', 'Holiday', const Color(0xFF9B59B6)),
                ],
              ),
            ),
          ),
          
          // Table Section
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 200 + (daysInMonth * 40.0), // Employee column + dynamic day columns
                  child: Column(
                    children: [
                      // Header Row
                      Container(
                        height: 60,
                        color: Colors.grey[200],
                        child: Row(
                          children: [
                            // Employee column
                            SizedBox(
                              width: 200,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: const Text(
                                  'Employee | Days',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            // Date columns
                            ...List.generate(daysInMonth, (index) {
                              final day = index + 1;
                              final dayName = getDayName(day);
                              
                              return SizedBox(
                                width: 40,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        day.toString(),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        dayName,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      
                      // Data Rows
                      Expanded(
                        child: teamMembers.isEmpty
                            ? const Center(
                                child: Text(
                                  'No data available. Click Fetch to load team attendance.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                itemCount: teamMembers.length,
                                itemBuilder: (context, index) {
                                  final member = teamMembers[index];
                                  return Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: index % 2 == 0 
                                          ? Colors.grey[100]
                                          : Colors.white,
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Employee name
                                        SizedBox(
                                          width: 200,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                              member['name'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        // Attendance data
                                        ...List.generate(daysInMonth, (dayIndex) {
                                          final attendanceData = member['data'] as List?;
                                          final status = attendanceData != null && dayIndex < attendanceData.length 
                                              ? attendanceData[dayIndex] 
                                              : 'P';
                                          
                                          return SizedBox(
                                            width: 40,
                                            height: 50,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status),
                                                border: Border(
                                                  right: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: _getStatusTextColor(status),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String code, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                code,
                style: TextStyle(
                  color: color == Colors.white ? Colors.black : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final cleanStatus = status.trim();
    switch (cleanStatus) {
      case 'P':
        return Colors.green[50]!;
      case 'A':
        return const Color(0xFFE74C3C); // Red for Absent
      case 'WO':
        return Colors.grey[300]!; // Grey for Weekly Off
      case 'H1':
      case 'H2':
        return const Color(0xFF9B59B6); // Purple for Holiday
      case 'MS':
        return const Color(0xFFE74C3C); // Red for Miss Punch
      case 'CL':
        return const Color(0xFFE67E22); // Orange for Casual Leave
      case 'EL':
        return const Color(0xFFE67E22); // Orange for Earn Leave
      case 'SL':
        return const Color(0xFFE67E22); // Orange for Sick Leave
      case 'OD':
        return const Color(0xFF3498DB); // Blue for On Duty
      case 'CO':
        return const Color(0xFFE67E22); // Orange for Comp-Off
      case 'MP':
        return const Color(0xFFE74C3C); // Red for Miss Punch
      default:
        return Colors.white;
    }
  }

  Color _getStatusTextColor(String status) {
    final cleanStatus = status.trim();
    switch (cleanStatus) {
      case 'P':
        return Colors.green[900]!;
      case 'A':
      case 'MS':
      case 'MP':
        return Colors.white;
      case 'WO':
        return Colors.black;
      case 'H1':
      case 'H2':
        return Colors.white;
      case 'CL':
      case 'EL':
      case 'SL':
      case 'OD':
      case 'CO':
        return Colors.white;
      default:
        return Colors.black;
    }
  }
}