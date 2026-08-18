import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/auth_service.dart';
import '../utils/payslip_pdf_service.dart';
import 'package:open_file/open_file.dart';

class PaySlipPage extends StatefulWidget {
  const PaySlipPage({super.key});

  @override
  State<PaySlipPage> createState() => _PaySlipPageState();
}

class _PaySlipPageState extends State<PaySlipPage> {
  String selectedYear = DateTime.now().year.toString();
  String selectedMonth = '12'; // Default to December (previous month logic will be handled in initState)
  bool isLoading = false;
  Map<String, dynamic>? payslipData;
  String? empPaycode;
  bool _visibilityFlag = true; // controls download button visibility
  
  final AuthService _authService = AuthService();

  // Generate year list - exclude current year if we're in January
  List<String> get yearList {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;
    
    // If current month is January, don't include current year
    if (currentMonth == 1) {
      return List.generate(5, (index) => (currentYear - 1 - index).toString());
    } else {
      // Include current year if we're past January
      return List.generate(5, (index) => (currentYear - index).toString());
    }
  }

  // Generate month list based on selected year
  List<String> get monthList {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;
    final selectedYearInt = int.tryParse(selectedYear) ?? currentYear;
    
    if (selectedYearInt == currentYear) {
      // For current year, only show months up to previous month
      return List.generate(currentMonth - 1, (index) => (index + 1).toString());
    } else {
      // For previous years, show all 12 months
      return List.generate(12, (index) => (index + 1).toString());
    }
  }

  // Check if a month is selectable (not in future)
  bool isMonthSelectable(String monthNumber) {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;
    final selectedYearInt = int.tryParse(selectedYear) ?? currentYear;
    final monthInt = int.tryParse(monthNumber) ?? 1;
    
    if (selectedYearInt == currentYear) {
      return monthInt < currentMonth; // Only past months in current year
    } else if (selectedYearInt < currentYear) {
      return true; // All months in previous years
    } else {
      return false; // No months in future years
    }
  }

  // Get month name for display
  String getMonthName(String monthNumber) {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    try {
      final index = int.parse(monthNumber) - 1;
      if (index >= 0 && index < monthNames.length) {
        return monthNames[index];
      }
    } catch (e) {
      debugPrint('Error parsing month number: $monthNumber');
    }

    return 'January'; // Default fallback
  }

  @override
  void initState() {
    super.initState();
    _setDefaultValues();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      empPaycode = await _authService.getEmployeePaycode();
      
      if (empPaycode != null) {
        debugPrint('📱 Loaded employee paycode: $empPaycode');
      } else {
        debugPrint('❌ No employee paycode found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee data not found. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }

  void _setDefaultValues() {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;
    
    // Set default year
    if (currentMonth == 1) {
      // If January, default to previous year
      selectedYear = (currentYear - 1).toString();
      selectedMonth = '12'; // December of previous year
    } else {
      // If not January, default to current year
      selectedYear = currentYear.toString();
      selectedMonth = (currentMonth - 1).toString(); // Previous month
    }
  }

  Future<void> _generatePaySlip() async {
    if (empPaycode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee data not available. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
      payslipData = null;
      _visibilityFlag = true; // reset until new response arrives
    });

    try {
      debugPrint('🔄 Generating pay slip for $selectedMonth/$selectedYear');

      // Use GET method with query parameters - server only allows GET
      final endpoint = '/ess/payslip-generate/?year=$selectedYear&month=$selectedMonth&json=true';
      
      debugPrint('🔗 Fetching payslip data from: $endpoint');
      
      // Make a direct HTTP request to bypass potential issues
      final url = '${_authService.baseUrl}$endpoint';
      final cookies = await _authService.getSessionCookies();
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cookie': cookies,
          'User-Agent': 'AttendanceApp/1.0',
          'X-Requested-With': 'XMLHttpRequest',  // Indicates AJAX request - may trigger JSON response
        },
      );

      debugPrint('📡 API Response Status: ${response.statusCode}');
      debugPrint('📡 API Response Headers: ${response.headers}');
      debugPrint('📡 API Response Body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      if (response.statusCode == 200) {
        // Check if response is HTML or JSON
        final contentType = response.headers['content-type'] ?? '';
        final body = response.body.trim();
        
        if (contentType.contains('text/html') || body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
          // If we get HTML, it might be the rendered payslip page
          // Try to extract JSON data from the HTML or show a message
          debugPrint('⚠️ Received HTML response - the endpoint may return a rendered page');
          throw Exception('The payslip endpoint returned an HTML page. This may indicate the payslip is not available in JSON format for the selected period.');
        }
        
        // Try to parse as JSON
        try {
          final data = jsonDecode(response.body);
          
          // Validate response structure
          if (data['data'] == null || (data['data'] as List).isEmpty) {
            throw Exception('No payslip data available for the selected period');
          }
          
          setState(() {
            payslipData = data;
            // visibility_flag controls whether the download button is shown.
            // Defaults to true if the field is absent (backward-compatible).
            _visibilityFlag = data['visibility_flag'] != false;
          });

          debugPrint('✅ Pay slip data loaded successfully');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pay slip loaded for ${getMonthName(selectedMonth)} $selectedYear'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          debugPrint('❌ Failed to parse JSON: $e');
          throw Exception('Failed to parse payslip data. The server may have returned an unexpected format.');
        }
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Handle redirect - might need to follow it
        final location = response.headers['location'];
        debugPrint('🔄 Redirect to: $location');
        throw Exception('Server redirected the request. Please try again or contact support.');
      } else {
        throw Exception('Failed to load payslip data. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error generating pay slip: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
          'Pay Slip',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pay slip Generator Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First Line: Payslip Generator Label
                  const Text(
                    'Payslip Generator',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Second Line: Year and Month Dropdowns
                  Row(
                    children: [
                      // Year Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedYear,
                              hint: const Text('Year'),
                              isExpanded: true,
                              items: yearList.map((String year) {
                                return DropdownMenuItem<String>(
                                  value: year,
                                  child: Text(year),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedYear = newValue;
                                    // Reset month to last available month when year changes
                                    final availableMonths = monthList;
                                    if (availableMonths.isNotEmpty) {
                                      selectedMonth = availableMonths.last;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Month Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: monthList.contains(selectedMonth) ? selectedMonth : (monthList.isNotEmpty ? monthList.last : '1'),
                              hint: const Text('Month'),
                              isExpanded: true,
                              items: List.generate(12, (index) {
                                final month = (index + 1).toString();
                                final isSelectable = isMonthSelectable(month);
                                final currentYear = DateTime.now().year;
                                final selectedYearInt = int.tryParse(selectedYear) ?? currentYear;
                                
                                // Show all months for previous years, limited months for current year
                                if (selectedYearInt == currentYear && index >= DateTime.now().month - 1) {
                                  return null; // Don't show future months for current year
                                }
                                
                                return DropdownMenuItem<String>(
                                  value: month,
                                  enabled: isSelectable,
                                  child: Text(
                                    getMonthName(month),
                                    style: TextStyle(
                                      color: isSelectable ? Colors.black : Colors.grey[400],
                                      fontWeight: isSelectable ? FontWeight.normal : FontWeight.w300,
                                    ),
                                  ),
                                );
                              }).where((item) => item != null).cast<DropdownMenuItem<String>>().toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null && isMonthSelectable(newValue)) {
                                  setState(() {
                                    selectedMonth = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Third Line: Search Button (Right Aligned)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: isLoading ? null : _generatePaySlip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Search',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Content Area (for pay slip display)
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: payslipData == null || (payslipData!['data'] as List).isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No pay slip data available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Select a different month or contact HR if you believe this is an error',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Payslip Header
                            Text(
                              'Pay Slip - ${getMonthName(selectedMonth)} $selectedYear',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Employee Details Card
                            _buildEmployeeDetailsCard(),
                            const SizedBox(height: 12),
                            
                            // Salary Details Card
                            _buildSalaryDetailsCard(),
                            const SizedBox(height: 16),
                            
                            // Action Buttons — only shown when visibility_flag is true
                            if (_visibilityFlag)
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: _downloadPdf,
                                  icon: const Icon(Icons.download, color: Colors.white),
                                  label: const Text(
                                    'Download PDF',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 96),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeDetailsCard() {
    // Safety check: ensure data array is not empty
    if (payslipData == null || 
        payslipData!['data'] == null || 
        (payslipData!['data'] as List).isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text(
            'No employee data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    // When visibility_flag is false, mask all values
    final employeeData = payslipData!['data'][0];
    String val(String key) => _visibilityFlag ? (employeeData[key]?.toString() ?? '--') : '--';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employee Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Name', val('name')),
          _buildDetailRow('Employee Code', val('pay_code')),
          _buildDetailRow('Department', val('dep_name')),
          _buildDetailRow('Designation', val('des_name')),
          _buildDetailRow('Bank Name', val('bank_name')),
          _buildDetailRow('Account No.', val('bank_no')),
        ],
      ),
    );
  }

  Widget _buildSalaryDetailsCard() {
    // Safety check: ensure data array is not empty
    if (payslipData == null || 
        payslipData!['data'] == null || 
        (payslipData!['data'] as List).isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text(
            'No salary data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    final employeeData = payslipData!['data'][0];
    // bel/bcl/bsl/bml in data[0] are the correct leave balance values

    // When visibility_flag is false, mask all numeric/text values
    final hide = !_visibilityFlag;
    String masked(dynamic value) => hide ? '--' : (value?.toString() ?? '--');
    String maskedAmt(dynamic value) => hide ? '--' : '₹${_formatAmount(_parseDouble(value))}';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Salary Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Leave Balance Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Leave Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLeaveItem('EL', hide ? '--' : (employeeData['bel'] ?? 0.0)),
                    _buildLeaveItem('CL', hide ? '--' : (employeeData['bcl'] ?? 0.0)),
                    _buildLeaveItem('SL', hide ? '--' : (employeeData['bsl'] ?? 0.0)),
                    _buildLeaveItem('ML', hide ? '--' : (employeeData['bml'] ?? 0.0)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Earnings ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Earnings',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    ...(hide ? [_buildDetailRow('--', '--')] : _buildEarningRows(employeeData)),
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Total Earnings',
                      hide ? '--' : '₹${_formatAmount(_parseDouble(employeeData['tot_sal']))}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // ── Deductions ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deductions',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    ...(hide ? [_buildDetailRow('--', '--')] : _buildDeductionRows(employeeData)),
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Total Deductions',
                      hide ? '--' : '₹${_formatAmount(_parseDouble(employeeData['tot_ded']))}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Working Days Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Working Days',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDayInfo('Working\nDays', masked(employeeData['wday'])),
                    _buildDayInfo('Weekly\nOff',   masked(employeeData['wf'])),
                    _buildDayInfo('Payable\nDays', masked(employeeData['pday'])),
                    _buildDayInfo('Absent\nDays',  masked(employeeData['absent_days'] ?? 0)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Net Salary — hidden entirely when visibility_flag is false
          if (!hide)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Net Salary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    maskedAmt(employeeData['net_sal']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildLeaveItem(String label, dynamic value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '${value ?? 0}',
            style: const TextStyle(fontSize: 12, color: Colors.blue),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDayInfo(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.black54),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Returns only earning rows where value > 0
  List<Widget> _buildEarningRows(Map<String, dynamic> e) {
    // label → API key
    final entries = <MapEntry<String, String>>[
      MapEntry('Basic',      'earn1'),
      MapEntry('HRA',        'earn2'),
      MapEntry('Adv. Bonus', 'earn3'),
      MapEntry('LTA',        'earn4'),
      MapEntry('Spl Allow',  'earn5'),
      MapEntry('CEA',        'earn6'),
      MapEntry('HEA',        'earn7'),
    ];

    final rows = <Widget>[];
    for (final entry in entries) {
      final raw = e[entry.value];
      final val = _parseDouble(raw);
      if (val > 0) {
        rows.add(_buildDetailRow(entry.key, '₹${_formatAmount(val)}'));
      }
    }
    if (rows.isEmpty) {
      rows.add(const Text('No earnings data', style: TextStyle(fontSize: 12, color: Colors.grey)));
    }
    return rows;
  }

  // Returns only deduction rows where value > 0
  List<Widget> _buildDeductionRows(Map<String, dynamic> e) {
    // The `pay` object from the API response contains the correct per-item deduction amounts
    final pay = (payslipData?['pay'] ?? {}) as Map<String, dynamic>;

    // label → resolve value: first try `pay` object, fall back to `ded*` fields
    final deductions = <MapEntry<String, double>>[
      MapEntry('PF',      _parseDouble(pay['PF']      ?? e['ded1'])),
      MapEntry('ESI',     _parseDouble(pay['ESI']     ?? e['ded2'])),
      MapEntry('TDS',     _parseDouble(pay['TDS']     ?? 0)),
      MapEntry('Loan',    _parseDouble(pay['Loan']    ?? e['ded4'])),
      MapEntry('GMI',     _parseDouble(pay['GMI']     ?? 0)),
      MapEntry('Advance', _parseDouble(pay['Advance'] ?? 0)),
      MapEntry('LWF',     _parseDouble(pay['LWF']     ?? 0)),
      MapEntry('Canteen', _parseDouble(pay['Canteen'] ?? 0)),
      MapEntry('P.Tax',   _parseDouble(pay['P.Tax']   ?? 0)),
      MapEntry('Society', _parseDouble(pay['Society'] ?? 0)),
    ];

    final rows = <Widget>[];
    for (final entry in deductions) {
      if (entry.value > 0) {
        rows.add(_buildDetailRow(entry.key, '₹${_formatAmount(entry.value)}'));
      }
    }
    if (rows.isEmpty) {
      rows.add(const Text('No deductions', style: TextStyle(fontSize: 12, color: Colors.grey)));
    }
    return rows;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _formatAmount(double value) {
    // Show without unnecessary decimals
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  Future<void> _downloadPdf() async {
    if (!mounted) return;
    
    try {
      debugPrint('🔄 Generating PDF for download...');
      
      final pdfFile = await PayslipPdfService.generatePayslipPdf(
        payslipData!,
        selectedMonth,
        selectedYear,
      );
      
      debugPrint('✅ PDF generated: ${pdfFile.path}');
      
      // Auto-open the PDF immediately after download
      final result = await OpenFile.open(pdfFile.path);
      
      debugPrint('📂 OpenFile result: ${result.type} - ${result.message}');
      
      if (mounted) {
        if (result.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF downloaded and opened successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved but could not open: ${result.message}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error generating PDF: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}