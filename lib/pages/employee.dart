import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/employee_api.dart';


class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  bool isLoading = false;
  final ScrollController _horizontalScrollController = ScrollController();
  final EmployeeApiService _apiService = EmployeeApiService();
  
  // Filter controllers
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _employeeController = TextEditingController();
  String selectedStatus = 'All';
  String selectedUnit = 'All';
  String selectedType = 'All';
  
  // Employee data - initially empty
  List<Map<String, String>> employeeData = [];
  
  List<Map<String, String>> filteredEmployeeData = [];

  @override
  void initState() {
    super.initState();
    filteredEmployeeData = employeeData;
    _fetchEmployeeData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _employeeController.dispose();
    super.dispose();
  }

  void _searchEmployees() {
    // Use API-based filtering instead of client-side filtering
    _fetchEmployeeData();
  }

  void _clearFilters() {
    setState(() {
      _fromDateController.clear();
      _toDateController.clear();
      _employeeController.clear();
      selectedStatus = 'All';
      selectedUnit = 'All';
      selectedType = 'All';
    });
    // Fetch data without filters
    _fetchEmployeeData();
  }

  Future<void> _fetchEmployeeData() async {
    setState(() {
      isLoading = true;
    });

    try {
      debugPrint('🔄 Fetching employee data with filters...');
      
      // Format dates for API (YYYY-MM-DD format)
      String? formattedFromDate;
      String? formattedToDate;
      
      if (_fromDateController.text.isNotEmpty) {
        try {
          // Assuming input is in MM/DD/YYYY format, convert to YYYY-MM-DD
          final parts = _fromDateController.text.split('/');
          if (parts.length == 3) {
            final month = parts[0].padLeft(2, '0');
            final day = parts[1].padLeft(2, '0');
            final year = parts[2];
            formattedFromDate = '$year-$month-$day';
          }
        } catch (e) {
          debugPrint('Error parsing from date: ${_fromDateController.text}');
        }
      }
      
      if (_toDateController.text.isNotEmpty) {
        try {
          // Assuming input is in MM/DD/YYYY format, convert to YYYY-MM-DD
          final parts = _toDateController.text.split('/');
          if (parts.length == 3) {
            final month = parts[0].padLeft(2, '0');
            final day = parts[1].padLeft(2, '0');
            final year = parts[2];
            formattedToDate = '$year-$month-$day';
          }
        } catch (e) {
          debugPrint('Error parsing to date: ${_toDateController.text}');
        }
      }

      // Call API with filters
      final List<Map<String, dynamic>> apiData = await _apiService.fetchEmployees(
        fromDate: formattedFromDate,
        toDate: formattedToDate,
        name: _employeeController.text.isNotEmpty ? _employeeController.text : null,
        status: selectedStatus != 'All' ? selectedStatus : null,
        unit: selectedUnit != 'All' ? selectedUnit : null,
        type: selectedType != 'All' ? selectedType : null,
      );

      // Convert dynamic data to String data for the UI
      final List<Map<String, String>> convertedData = apiData.map((item) {
        return {
          'id': item['id']?.toString() ?? '',
          'type': item['type']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
          'phone_no': item['phone_no']?.toString() ?? '',
          'unit': item['unit']?.toString() ?? '',
          'company': item['company']?.toString() ?? '',
          'address': item['address']?.toString() ?? '',
          'email': item['email']?.toString() ?? '',
          'person_to_meet': item['person_to_meet']?.toString() ?? '',
          'employee_code': item['employee_code']?.toString() ?? '',
          'department': item['department']?.toString() ?? '',
          'doc_type': item['doc_type']?.toString() ?? '',
          'doc_number': item['doc_number']?.toString() ?? '',
          'purpose': item['purpose']?.toString() ?? '',
          'status': item['status']?.toString() ?? '',
          'created_at': item['created_at']?.toString() ?? '',
          'time_approved': item['time_approved']?.toString() ?? '',
          'reject_reason': item['reject_reason']?.toString() ?? '',
          'is_vip': item['is_vip']?.toString() ?? 'false',
        };
      }).toList();

      setState(() {
        employeeData = convertedData;
        filteredEmployeeData = convertedData; // No need for separate filtering since API handles it
        isLoading = false;
      });

      debugPrint('✅ Successfully loaded ${convertedData.length} employees');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${convertedData.length} employees'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching employee data: $e');

      setState(() {
        isLoading = false;
      });
 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
        title: const Text(
          'Employee Screen',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : _fetchEmployeeData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.black,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // First Row - From and Status
                  Row(
                    children: [
                      // From Date Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('From:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _fromDateController.text = '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100]!,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _fromDateController.text.isEmpty ? 'mm/dd/yyyy' : _fromDateController.text,
                                      style: TextStyle(
                                        color: _fromDateController.text.isEmpty ? Colors.grey : Colors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Status Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100]!,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedStatus,
                                  dropdownColor: const Color(0xFF2C3E50),
                                  style: const TextStyle(color: Colors.black),
                                  isExpanded: true,
                                  items: ['All', 'Wait', 'Allow', 'Reject'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedStatus = newValue!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Second Row - To and Unit
                  Row(
                    children: [
                      // To Date Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('To:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _toDateController.text = '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100]!,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _toDateController.text.isEmpty ? 'mm/dd/yyyy' : _toDateController.text,
                                      style: TextStyle(
                                        color: _toDateController.text.isEmpty ? Colors.grey : Colors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Unit Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unit:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100]!,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedUnit,
                                  dropdownColor: const Color(0xFF2C3E50),
                                  style: const TextStyle(color: Colors.black),
                                  isExpanded: true,
                                  items: ['All', 'HO', 'Unit-1', 'Unit-2'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedUnit = newValue!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Third Row - Type and Employee Name
                  Row(
                    children: [
                      // Type Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Type:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100]!,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedType,
                                  dropdownColor: const Color(0xFF2C3E50),
                                  style: const TextStyle(color: Colors.black),
                                  isExpanded: true,
                                  items: ['All', 'Standard', 'VIP', 'Guest'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedType = newValue!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Employee Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Employee:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _employeeController,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: 'Enter Name',
                                hintStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey[100]!,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Fourth Row - Buttons
                  Row(
                    children: [
                      // Buttons Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Actions:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _searchEmployees,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('Search'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _clearFilters,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('Clear'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Total Employees Count
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text(
                  'Total Employees: ${filteredEmployeeData.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Employee Cards Section
            filteredEmployeeData.isEmpty
                ? const SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No employees found',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Use the filters above to search for employees',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: filteredEmployeeData.map((employee) {
                      return _buildEmployeeCard(employee);
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, String> employee) {
    // Get status color
    Color statusColor;
    switch (employee['status']?.toLowerCase() ?? '') {
      case 'allow':
        statusColor = Colors.green;
        break;
      case 'wait':
        statusColor = Colors.orange;
        break;
      case 'reject':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    // Check if VIP
    bool isVip = employee['is_vip'] == 'true';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: isVip ? Border.all(color: Colors.amber, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            employee['name'] ?? 'Unknown Employee',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVip) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  employee['status'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Employee details with two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column - Main details
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.person, 'Name', employee['name'] ?? ''),
                    _buildDetailRow(Icons.phone, 'Phone No', employee['phone_no'] ?? '--'),
                    _buildDetailRow(Icons.location_city, 'Unit', employee['unit'] ?? ''),
                    _buildDetailRow(Icons.business, 'Company', employee['company'] ?? '--'),
                    _buildDetailRow(Icons.location_on, 'Address', employee['address'] ?? '--'),
                    _buildDetailRow(Icons.work, 'Purpose', employee['purpose'] ?? '--'),
                    if (employee['time_approved']?.isNotEmpty == true)
                      _buildDetailRow(Icons.check_circle, 'Time Approved', employee['time_approved'] ?? ''),
                    if (employee['reject_reason']?.isNotEmpty == true)
                      _buildDetailRow(Icons.cancel, 'Reject Reason', employee['reject_reason'] ?? ''),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right column - Sr. No and Date & Time
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCompactDetailRow(Icons.badge, 'Sr. No', employee['id'] ?? ''),
                    _buildDateTimeRow(Icons.access_time, 'Date & Time', employee['created_at'] ?? ''),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showEmployeeDetailDialog(employee);
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Allow/Reject buttons (only show if status is wait)
          if (employee['status']?.toLowerCase() == 'wait')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _updateEmployeeStatus(employee, 'approve');
                    },
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Allow'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _updateEmployeeStatus(employee, 'reject');
                    },
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '--' : value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value.isEmpty ? '--' : value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '$label:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '--' : value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showEmployeeDetailDialog(Map<String, String> employee) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${employee['name']} - Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogDetailRow('ID:', employee['id'] ?? '--'),
                _buildDialogDetailRow('Name:', employee['name'] ?? '--'),
                _buildDialogDetailRow('Phone No:', employee['phone_no'] ?? '--'),
                _buildDialogDetailRow('Email:', employee['email'] ?? '--'),
                _buildDialogDetailRow('Company:', employee['company'] ?? '--'),
                _buildDialogDetailRow('Address:', employee['address'] ?? '--'),
                _buildDialogDetailRow('Unit:', employee['unit'] ?? '--'),
                _buildDialogDetailRow('Type:', employee['type'] ?? '--'),
                _buildDialogDetailRow('Person to Meet:', employee['person_to_meet'] ?? '--'),
                if (employee['department']?.isNotEmpty == true)
                  _buildDialogDetailRow('Department:', employee['department'] ?? '--'),
                if (employee['doc_type']?.isNotEmpty == true)
                  _buildDialogDetailRow('Doc Type:', employee['doc_type'] ?? '--'),
                if (employee['doc_number']?.isNotEmpty == true)
                  _buildDialogDetailRow('Doc Number:', employee['doc_number'] ?? '--'),
                _buildDialogDetailRow('Purpose:', employee['purpose'] ?? '--'),
                _buildDialogDetailRow('Created At:', employee['created_at'] ?? '--'),
                if (employee['time_approved']?.isNotEmpty == true)
                  _buildDialogDetailRow('Time Approved:', employee['time_approved'] ?? '--'),
                if (employee['reject_reason']?.isNotEmpty == true)
                  _buildDialogDetailRow('Reject Reason:', employee['reject_reason'] ?? '--'),
                _buildDialogDetailRow('VIP:', employee['is_vip'] == 'true' ? 'Yes' : 'No'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: employee['status']?.toLowerCase() == 'allow'
                            ? Colors.green
                            : employee['status']?.toLowerCase() == 'reject'
                                ? Colors.red
                                : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        employee['status'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (employee['status']?.toLowerCase() == 'wait') ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateEmployeeStatus(employee, 'reject');
                },
                child: const Text('Reject', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateEmployeeStatus(employee, 'approve');
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
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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

  Future<void> _updateEmployeeStatus(Map<String, String> employee, String action) async {
    try {
      debugPrint('🔄 Updating employee status: ${employee['name']} with action: $action');
      
      // Call API without waiting for response validation
      _apiService.updateEmployeeStatus(employee['id'] ?? '', action);
      
      // Wait 1 second then refresh data
      await Future.delayed(const Duration(seconds: 1));
      
      debugPrint('🔄 Refreshing employee data after $action...');
      
      // Refresh the data to show updated status
      if (mounted) {
        _fetchEmployeeData();
      }
    } catch (e) {
      debugPrint('❌ Error updating employee status: $e');
    }
  }
}