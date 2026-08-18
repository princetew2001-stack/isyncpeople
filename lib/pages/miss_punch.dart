import 'package:flutter/material.dart';
import '../utils/miss_punch_api.dart';

class MissPunchPage extends StatefulWidget {
  const MissPunchPage({super.key});

  @override
  State<MissPunchPage> createState() => _MissPunchPageState();
}

class _MissPunchPageState extends State<MissPunchPage> {
  String searchQuery = '';
  bool isLoading = false;
  bool showAddForm = false; // For showing/hiding the add form
  final MissPunchApiService _apiService = MissPunchApiService();
  final ScrollController _horizontalScrollController = ScrollController();

  // Sample data for the table - will be replaced with API data
  List<Map<String, String>> missPunchData = [];
  List<Map<String, String>> filteredMissPunchData = []; // For search results
  
  // Available dates for miss punch applications
  List<DateTime> availableMissPunchDates = [];

  // Employee data from API response
  String empCode = '';
  String empName = '';
  String location = '';
  String department = '';
  String reportingManager = '';

  // Form controllers
  final TextEditingController _empCodeController = TextEditingController();
  final TextEditingController _empNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _reportingManagerController = TextEditingController();
  final TextEditingController _missPunchTimeController = TextEditingController();
  
  // Form dropdown values
  String selectedApplicationType = 'Miss Punch';
  String selectedReason = 'Forgot to punch';
  String selectedDayPart = 'IN';
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchMissPunchData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _empCodeController.dispose();
    _empNameController.dispose();
    _locationController.dispose();
    _departmentController.dispose();
    _reportingManagerController.dispose();
    _missPunchTimeController.dispose();
    super.dispose();
  }

  Future<void> _fetchMissPunchData() async {
    setState(() {
      isLoading = true;
    });

    try {
      debugPrint('🔄 Fetching miss punch applications...');
      final List<Map<String, dynamic>> apiData = await _apiService.fetchMissPunchApplications();
      
      // Extract employee data from API response if available
      // Note: This assumes the API returns employee data in the response
      // You may need to make a separate API call to get employee details
      
      // Convert dynamic data to String data for the table
      final List<Map<String, String>> convertedData = apiData.map((item) {
        return {
          'id': item['id']?.toString() ?? '', // Store ID for cancellation
          'applicationType': item['applicationType']?.toString() ?? '',
          'missPunchDate': item['missPunchDate']?.toString() ?? '',
          'missPunchTime': item['missPunchTime']?.toString() ?? '',
          'dayPart': item['dayPart']?.toString() ?? '',
          'reason': item['reason']?.toString() ?? '',
          'applicationStatus': item['applicationStatus']?.toString() ?? '',
          'appliedOn': item['appliedOn']?.toString() ?? '',
          'approvedRejectedOn': item['approvedRejectedOn']?.toString() ?? '',
          'cancelledOn': item['cancelledOn']?.toString() ?? '',
          'approvedRejectedBy': item['approvedRejectedBy']?.toString() ?? '',
          'remarks': item['remarks']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        missPunchData = convertedData;
        filteredMissPunchData = convertedData; // Initialize filtered data
        isLoading = false;
      });

      debugPrint('✅ Successfully loaded ${convertedData.length} miss punch applications');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${convertedData.length} miss punch applications'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching miss punch data: $e');
      
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
        title: const Text('Miss Punch Application Form'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : _fetchMissPunchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top controls row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'search in table...',
                      hintStyle: const TextStyle(fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      _filterData(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Add New button
                ElevatedButton.icon(
                  onPressed: _toggleAddForm,
                  icon: Icon(showAddForm ? Icons.close : Icons.add, color: Colors.white, size: 16),
                  label: Text(showAddForm ? 'Cancel' : 'Add New', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: showAddForm ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expandable Add New Form
          if (showAddForm)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SingleChildScrollView(
                  child: _buildAddNewForm(),
                ),
              ),
            ),

          // Table — takes all remaining space
          if (!showAddForm)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Stack(
                children: [
                  // Full-size table container
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          // Horizontal scroll wraps header + body together
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 1366,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                        // Table header
                        Container(
                          color: Colors.blue[100],
                          child: Table(
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            columnWidths: const {
                              0: FixedColumnWidth(80),
                              1: FixedColumnWidth(0.5), // Divider
                              2: FixedColumnWidth(120),
                              3: FixedColumnWidth(0.5), // Divider
                              4: FixedColumnWidth(120),
                              5: FixedColumnWidth(0.5), // Divider
                              6: FixedColumnWidth(120),
                              7: FixedColumnWidth(0.5), // Divider
                              8: FixedColumnWidth(80),
                              9: FixedColumnWidth(0.5), // Divider
                              10: FixedColumnWidth(150),
                              11: FixedColumnWidth(0.5), // Divider
                              12: FixedColumnWidth(120),
                              13: FixedColumnWidth(0.5), // Divider
                              14: FixedColumnWidth(100),
                              15: FixedColumnWidth(0.5), // Divider
                              16: FixedColumnWidth(140),
                              17: FixedColumnWidth(0.5), // Divider
                              18: FixedColumnWidth(100),
                              19: FixedColumnWidth(0.5), // Divider
                              20: FixedColumnWidth(140),
                              21: FixedColumnWidth(0.5), // Divider
                              22: FixedColumnWidth(150),
                            },
                            children: [
                              TableRow(
                                children: [
                                  _buildHeaderCell('Cancel'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Application Type'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Miss Punch Date'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Miss Punch Time'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Day Part'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Reason'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Application Status'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Applied On'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Approved/Rejected On'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Cancelled On'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Approved/Rejected By'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Remarks'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Table body
                        isLoading
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text(
                                        'Loading miss punch applications...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : missPunchData.isEmpty
                                  ? const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No miss punch applications found',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Click "Add New" to create your first application',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : filteredMissPunchData.isEmpty
                                  ? const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.search_off,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No results found',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Try adjusting your search terms',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: filteredMissPunchData.length,
                                      itemBuilder: (context, index) {
                                        final data = filteredMissPunchData[index];
                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: Colors.grey[200]!),
                                            ),
                                          ),
                                          child: Table(
                                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                            columnWidths: const {
                                              0: FixedColumnWidth(80),
                                              1: FixedColumnWidth(0.5), // Divider
                                              2: FixedColumnWidth(120),
                                              3: FixedColumnWidth(0.5), // Divider
                                              4: FixedColumnWidth(120),
                                              5: FixedColumnWidth(0.5), // Divider
                                              6: FixedColumnWidth(120),
                                              7: FixedColumnWidth(0.5), // Divider
                                              8: FixedColumnWidth(80),
                                              9: FixedColumnWidth(0.5), // Divider
                                              10: FixedColumnWidth(150),
                                              11: FixedColumnWidth(0.5), // Divider
                                              12: FixedColumnWidth(120),
                                              13: FixedColumnWidth(0.5), // Divider
                                              14: FixedColumnWidth(100),
                                              15: FixedColumnWidth(0.5), // Divider
                                              16: FixedColumnWidth(140),
                                              17: FixedColumnWidth(0.5), // Divider
                                              18: FixedColumnWidth(100),
                                              19: FixedColumnWidth(0.5), // Divider
                                              20: FixedColumnWidth(140),
                                              21: FixedColumnWidth(0.5), // Divider
                                              22: FixedColumnWidth(150),
                                            },
                                            children: [
                                              TableRow(
                                                children: [
                                                  _buildCancelCell(data['id'] ?? '', data['applicationStatus'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['applicationType'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['missPunchDate'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['missPunchTime'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['dayPart'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['reason'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildStatusCell(data['applicationStatus'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['appliedOn'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['approvedRejectedOn'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['cancelledOn'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['approvedRejectedBy'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['remarks'] ?? ''),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  // end table body
                                ],
                              ), // inner Column (SizedBox child)
                            ), // SizedBox(width:1366)
                          ), // SingleChildScrollView
                        ), // Expanded
                        ],
                      ), // outer Column
                    ), // Container (Positioned.fill child)
                  ), // Positioned.fill

                  // Pagination overlay — bottom-right corner
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            searchQuery.isEmpty
                                ? 'Showing ${missPunchData.isEmpty ? 0 : 1}–${missPunchData.length} of ${missPunchData.length}'
                                : '${filteredMissPunchData.length} of ${missPunchData.length}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 10),
                          ),
                          const SizedBox(width: 6),
                          _buildPageBtn('‹', null),
                          const SizedBox(width: 2),
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 2),
                          _buildPageBtn('›', null),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14, // Increased from 12 to 14
        ),
        textAlign: TextAlign.left, // Changed from center to left
      ),
    );
  }

  Widget _buildDataCell(String text) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildStatusCell(String status) {
    Color backgroundColor;
    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange;
        break;
      case 'approved':
        backgroundColor = Colors.green;
        break;
      case 'rejected':
        backgroundColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey;
    }

    return Container(
      height: 50, // Fixed height to match other cells
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft, // Changed from center to centerLeft
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          status,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14, // Increased from 12 to 14
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center, // Keep center for status badges
        ),
      ),
    );
  }

  Widget _buildCancelCell(String? applicationId, String status) {
    // Only show cancel button if status is "Pending"
    final isPending = status.toLowerCase() == 'pending';
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.center,
      child: isPending && applicationId != null && applicationId.isNotEmpty
          ? ElevatedButton(
              onPressed: () => _showCancelDialog(applicationId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 30),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : Container(
              width: 60,
              height: 30,
              alignment: Alignment.center,
              child: Text(
                isPending ? '-' : status.substring(0, 3).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  Widget _buildDividerCell() {
    return Container(
      width: 0.5,
      height: 50,
      color: Colors.grey[400],
    );
  }

  Widget _buildPageBtn(String label, VoidCallback? onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onPressed == null ? Colors.grey[200] : Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: onPressed == null ? Colors.grey[400] : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAddNewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add New Miss Punch Application',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // First Row: Employee Code, Employee Name
          Row(
            children: [
              Expanded(child: _buildFormField('Employee Code *', _empCodeController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Employee Name *', _empNameController, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Second Row: Location, Department
          Row(
            children: [
              Expanded(child: _buildFormField('Location', _locationController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Department *', _departmentController, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Third Row: Reporting Manager, Application Type
          Row(
            children: [
              Expanded(child: _buildFormField('Reporting Manager', _reportingManagerController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdownField('Application Type *', selectedApplicationType, ['Miss Punch'], (value) {
                setState(() {
                  selectedApplicationType = value!;
                });
              })),
            ],
          ),
          const SizedBox(height: 16),
          
          // Fourth Row: Miss Punch Date, Day Part
          Row(
            children: [
              Expanded(child: _buildDateField('Miss Punch Date *')),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdownField('Select Day Part (Miss Punch Count) *', selectedDayPart, ['IN', 'OUT'], (value) {
                setState(() {
                  selectedDayPart = value!;
                });
              })),
            ],
          ),
          const SizedBox(height: 16),
          
          // Fifth Row: Miss Punch Time, Reason for miss punch
          Row(
            children: [
              Expanded(child: _buildTimeField('Miss Punch Time *')),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdownField('Reason for miss punch *', selectedReason, ['Forgot to punch'], (value) {
                setState(() {
                  selectedReason = value!;
                });
              })),
            ],
          ),
          const SizedBox(height: 20),
          
          // Save Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, {bool enabled = true, String? hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: !enabled,
            fillColor: enabled ? Colors.white : Colors.grey[50],
          ),
          style: TextStyle(
            fontSize: 14,
            color: enabled ? Colors.black : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            if (availableMissPunchDates.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Loading available dates...'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            
            // Show custom date picker with only available dates
            final DateTime? picked = await _showAvailableDatePicker();
            if (picked != null) {
              setState(() {
                selectedDate = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null 
                      ? '${selectedDate!.day.toString().padLeft(2, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.year}'
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: selectedDate != null ? Colors.black : Colors.grey[500],
                  ),
                ),
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _submitForm() async {
    // Validate required fields
    if (_empCodeController.text.isEmpty ||
        _empNameController.text.isEmpty ||
        _departmentController.text.isEmpty ||
        selectedDate == null ||
        _missPunchTimeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Submitting application...'),
            ],
          ),
        );
      },
    );

    try {
      // Format date for API (YYYY-MM-DD) — read UTC fields directly since dates are stored as DateTime.utc()
      final formattedDate = '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
      
      debugPrint('📝 Submitting miss punch application:');
      debugPrint('   Employee Code: ${_empCodeController.text}');
      debugPrint('   Employee Name: ${_empNameController.text}');
      debugPrint('   Department: ${_departmentController.text}');
      debugPrint('   Date: $formattedDate');
      debugPrint('   Time: ${_missPunchTimeController.text}');
      debugPrint('   Day Part: $selectedDayPart');
      debugPrint('   Reason: $selectedReason');

      // Submit the application via API
      final success = await _apiService.submitMissPunchApplication(
        missPunchDate: formattedDate,
        missPunchTime: _missPunchTimeController.text,
        dayPart: selectedDayPart,
        reason: selectedReason,
        department: _departmentController.text,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (success) {
        debugPrint('✅ Miss punch application submitted successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Miss punch application submitted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Clear form and close
        _clearForm();
        setState(() {
          showAddForm = false;
        });
        
        // Refresh data to show new application
        _fetchMissPunchData();
      } else {
        debugPrint('⚠️ Miss punch application submission failed');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit application. Please try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error submitting miss punch application: $e');
      
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting application: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildTimeField(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
              setState(() {
                _missPunchTimeController.text = formattedTime;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _missPunchTimeController.text.isNotEmpty 
                      ? _missPunchTimeController.text
                      : '--:--:--',
                  style: TextStyle(
                    fontSize: 14,
                    color: _missPunchTimeController.text.isNotEmpty ? Colors.black : Colors.grey[500],
                  ),
                ),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<DateTime?> _showAvailableDatePicker() async {
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Miss Punch Date'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: availableMissPunchDates.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading available dates...'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: availableMissPunchDates.length,
                    itemBuilder: (context, index) {
                      final date = availableMissPunchDates[index];
                      final isSelected = selectedDate != null &&
                          selectedDate!.year == date.year &&
                          selectedDate!.month == date.month &&
                          selectedDate!.day == date.day;
                      
                      return ListTile(
                        title: Text(
                          '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.blue : Colors.black,
                          ),
                        ),
                        subtitle: Text(_getDayName(date.weekday)),
                        leading: Icon(
                          Icons.calendar_today,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        selected: isSelected,
                        onTap: () {
                          Navigator.of(context).pop(date);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  void _clearForm() {
    setState(() {
      selectedDate = null;
      selectedDayPart = 'IN';
      selectedReason = 'Forgot to punch';
      _missPunchTimeController.clear();
    });
  }

  void _showCancelDialog(String applicationId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Application'),
          content: const Text('Are you sure you want to cancel this miss punch application?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelApplication(applicationId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelApplication(String applicationId) async {
    try {
      debugPrint('🔄 Cancelling application with ID: $applicationId');
      
      final success = await _apiService.cancelMissPunchApplication(applicationId);
      
      if (success) {
        debugPrint('✅ Application cancelled successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application cancelled successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        // Refresh the data to show updated status
        _fetchMissPunchData();
      } else {
        debugPrint('⚠️ Application cancellation failed');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel application'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error cancelling application: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling application: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _filterData(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredMissPunchData = missPunchData;
      } else {
        filteredMissPunchData = missPunchData.where((item) {
          // Search in all fields
          return item.values.any((value) => 
            value.toLowerCase().contains(query.toLowerCase())
          );
        }).toList();
      }
    });
    
    debugPrint('🔍 Search query: "$query"');
    debugPrint('📊 Filtered results: ${filteredMissPunchData.length} out of ${missPunchData.length}');
  }

  Future<void> _loadAvailableDates() async {
    try {
      debugPrint('🔄 Loading available miss punch dates...');
      
      // Fetch available dates from API
      final dates = await _apiService.fetchAvailableMissPunchDates();
      
      setState(() {
        availableMissPunchDates = dates;
      });
      
      debugPrint('✅ Available dates loaded successfully');
      debugPrint('📅 ${availableMissPunchDates.length} dates available for miss punch');
    } catch (e) {
      debugPrint('❌ Error loading available dates: $e');
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading available dates: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadEmployeeData() async {
    try {
      debugPrint('🔄 Loading employee data for form...');
      
      // Fetch employee data from API
      final employeeData = await _apiService.fetchEmployeeData();
      
      if (employeeData != null) {
        setState(() {
          empCode = employeeData['emp_code'] ?? '';
          empName = employeeData['emp_name'] ?? '';
          location = employeeData['loc_name'] ?? '';
          department = employeeData['dep_name'] ?? '';
          reportingManager = employeeData['reporting_manager_name'] ?? '';
          
          // Pre-fill the form controllers
          _empCodeController.text = empCode;
          _empNameController.text = empName;
          _locationController.text = location;
          _departmentController.text = department;
          _reportingManagerController.text = reportingManager;
        });
        
        debugPrint('✅ Employee data loaded successfully');
        debugPrint('👤 Employee: $empName ($empCode)');
        debugPrint('🏢 Department: $department');
        debugPrint('📍 Location: $location');
        debugPrint('👨‍💼 Reporting Manager: $reportingManager');
      } else {
        debugPrint('⚠️ No employee data received from API');
        
        // Show error message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to load employee data. Please try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading employee data: $e');
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading employee data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _toggleAddForm() async {
    if (!showAddForm) {
      // Show loading state while fetching employee data
      setState(() {
        showAddForm = true;
      });
      
      // Initialize session for new miss punch application (get fresh CSRF token)
      debugPrint('🔄 Initializing session for new miss punch application...');
      final sessionReady = await _apiService.initializeSession();
      
      if (sessionReady) {
        debugPrint('✅ Session initialized successfully');
        // Load employee data and available dates when opening the form
        await Future.wait([
          _loadEmployeeData(),
          _loadAvailableDates(),
        ]);
      } else {
        debugPrint('❌ Failed to initialize session');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initialize session. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Close the form if session initialization failed
        setState(() {
          showAddForm = false;
        });
      }
    } else {
      // Just close the form
      setState(() {
        showAddForm = false;
      });
      
      // Clear form when closing
      _clearForm();
    }
  }
}