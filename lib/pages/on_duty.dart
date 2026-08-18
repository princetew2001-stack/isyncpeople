import 'package:flutter/material.dart';
import '../utils/on_duty_api.dart';

class OnDutyPage extends StatefulWidget {
  const OnDutyPage({super.key});

  @override
  State<OnDutyPage> createState() => _OnDutyPageState();
}

class _OnDutyPageState extends State<OnDutyPage> {
  String searchQuery = '';
  bool isLoading = false;
  bool showAddForm = false; // For showing/hiding the add form
  final ScrollController _horizontalScrollController = ScrollController();
  final OnDutyApiService _apiService = OnDutyApiService();

  // Sample data for the table - will be replaced with API data
  List<Map<String, String>> onDutyData = [];
  List<Map<String, String>> filteredOnDutyData = []; // For search results

  // Employee data from API response
  String empCode = '';
  String empPaycode = '';
  String empName = '';
  String locCode = '';
  String location = '';
  String depCode = '';
  String department = '';
  String joiningDate = '';
  String reportingManagerPaycode = '';
  String reportingManager = '';

  // Form controllers
  final TextEditingController _empCodeController = TextEditingController();
  final TextEditingController _empPaycodeController = TextEditingController();
  final TextEditingController _empNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _reportingManagerController = TextEditingController();
  final TextEditingController _visitLocationController = TextEditingController();
  final TextEditingController _purposeOfVisitController = TextEditingController();
  
  // Form dropdown values
  String selectedApplicationType = 'On Duty';
  String selectedVisitLocationType = 'Outside Unit';
  String selectedDayCount = 'Full Day';
  DateTime? selectedFromDate;
  DateTime? selectedTillDate;

  @override
  void initState() {
    super.initState();
    _fetchOnDutyData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _empCodeController.dispose();
    _empPaycodeController.dispose();
    _empNameController.dispose();
    _locationController.dispose();
    _departmentController.dispose();
    _reportingManagerController.dispose();
    _visitLocationController.dispose();
    _purposeOfVisitController.dispose();
    super.dispose();
  }

  Future<void> _fetchOnDutyData() async {
    setState(() {
      isLoading = true;
    });

    try {
      debugPrint('🔄 Fetching on duty applications...');
      final List<Map<String, dynamic>> apiData = await _apiService.fetchOnDutyApplications();
      
      // Convert dynamic data to String data for the table
      final List<Map<String, String>> convertedData = apiData.map((item) {
        return {
          'id': item['id']?.toString() ?? '',
          'applicationType': item['applicationType']?.toString() ?? '',
          'fromDate': item['fromDate']?.toString() ?? '',
          'tillDate': item['tillDate']?.toString() ?? '',
          'dayPart': item['dayPart']?.toString() ?? '',
          'dayCount': item['dayCount']?.toString() ?? '',
          'applicationStatus': item['applicationStatus']?.toString() ?? '',
          'visitLocationType': item['visitLocationType']?.toString() ?? '',
          'visitLocation': item['visitLocation']?.toString() ?? '',
          'purposeOfVisit': item['purposeOfVisit']?.toString() ?? '',
          'appliedOn': item['appliedOn']?.toString() ?? '',
          'approvedRejectedOn': item['approvedRejectedOn']?.toString() ?? '',
          'cancelledOn': item['cancelledOn']?.toString() ?? '',
          'approvedRejectedBy': item['approvedRejectedBy']?.toString() ?? '',
          'remarks': item['remarks']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        onDutyData = convertedData;
        filteredOnDutyData = convertedData; // Initialize filtered data
        isLoading = false;
      });

      debugPrint('✅ Successfully loaded ${convertedData.length} on duty applications');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${convertedData.length} on duty applications'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching on duty data: $e');
      
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
        title: const Text('On Duty Application Form'),
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
            onPressed: isLoading ? null : _fetchOnDutyData,
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
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 1767,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                        // Table header (sticky at top, outside vertical scroll)
                        Container(
                          color: Colors.blue[100],
                          child: Table(
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            columnWidths: const {
                              0: FixedColumnWidth(80),
                              1: FixedColumnWidth(0.5), // Divider
                              2: FixedColumnWidth(120),
                              3: FixedColumnWidth(0.5), // Divider
                              4: FixedColumnWidth(100),
                              5: FixedColumnWidth(0.5), // Divider
                              6: FixedColumnWidth(100),
                              7: FixedColumnWidth(0.5), // Divider
                              8: FixedColumnWidth(100),  // Day Part
                              9: FixedColumnWidth(0.5), // Divider
                              10: FixedColumnWidth(100),
                              11: FixedColumnWidth(0.5), // Divider
                              12: FixedColumnWidth(120),
                              13: FixedColumnWidth(0.5), // Divider
                              14: FixedColumnWidth(140),
                              15: FixedColumnWidth(0.5), // Divider
                              16: FixedColumnWidth(120),
                              17: FixedColumnWidth(0.5), // Divider
                              18: FixedColumnWidth(140),
                              19: FixedColumnWidth(0.5), // Divider
                              20: FixedColumnWidth(100),
                              21: FixedColumnWidth(0.5), // Divider
                              22: FixedColumnWidth(140),
                              23: FixedColumnWidth(0.5), // Divider
                              24: FixedColumnWidth(100),
                              25: FixedColumnWidth(0.5), // Divider
                              26: FixedColumnWidth(180), // Approved/Rejected By
                              27: FixedColumnWidth(0.5), // Divider
                              28: FixedColumnWidth(120), // Remarks
                            },
                            children: [
                              TableRow(
                                children: [
                                  _buildHeaderCell('Cancel'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Application Type'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('From'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Till'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Day Part'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Day Count'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Application Status'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Visit Location Type'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Visit Location'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Purpose of Visit'),
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
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading on duty applications...',
                                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                                ],
                              ),
                            ),
                          )
                        else if (onDutyData.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No on duty applications found',
                                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                                  SizedBox(height: 8),
                                  Text('Click "Add New" to create your first application',
                                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          )
                        else if (filteredOnDutyData.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No results found',
                                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                                  SizedBox(height: 8),
                                  Text('Try adjusting your search terms',
                                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          )
                        else
                          for (final data in filteredOnDutyData)
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                              child: Table(
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                columnWidths: const {
                                  0: FixedColumnWidth(80),
                                  1: FixedColumnWidth(0.5),
                                  2: FixedColumnWidth(120),
                                  3: FixedColumnWidth(0.5),
                                  4: FixedColumnWidth(100),
                                  5: FixedColumnWidth(0.5),
                                  6: FixedColumnWidth(100),
                                  7: FixedColumnWidth(0.5),
                                  8: FixedColumnWidth(100),
                                  9: FixedColumnWidth(0.5),
                                  10: FixedColumnWidth(100),
                                  11: FixedColumnWidth(0.5),
                                  12: FixedColumnWidth(120),
                                  13: FixedColumnWidth(0.5),
                                  14: FixedColumnWidth(140),
                                  15: FixedColumnWidth(0.5),
                                  16: FixedColumnWidth(120),
                                  17: FixedColumnWidth(0.5),
                                  18: FixedColumnWidth(140),
                                  19: FixedColumnWidth(0.5),
                                  20: FixedColumnWidth(100),
                                  21: FixedColumnWidth(0.5),
                                  22: FixedColumnWidth(140),
                                  23: FixedColumnWidth(0.5),
                                  24: FixedColumnWidth(100),
                                  25: FixedColumnWidth(0.5),
                                  26: FixedColumnWidth(180),
                                  27: FixedColumnWidth(0.5),
                                  28: FixedColumnWidth(120),
                                },
                                children: [
                                  TableRow(
                                    children: [
                                      _buildCancelCell(data['id'] ?? '', data['applicationStatus'] ?? ''),
                                      _buildDividerCell(),
                                      _buildDataCell(data['applicationType'] ?? ''),
                                      _buildDividerCell(),
                                      _buildDataCell(data['fromDate'] ?? ''),
                                      _buildDividerCell(),
                                      _buildDataCell(data['tillDate'] ?? ''),
                                      _buildDividerCell(),
                                      _buildDataCell(data['dayPart'] ?? ''),
                                      _buildDividerCell(),
                                      _buildDataCell(data['dayCount'] ?? ''),
                                      _buildDividerCell(),
                                      _buildStatusCell(data['applicationStatus'] ?? ''),
                                      _buildDividerCell(),
                                      _buildDataCell(data['visitLocationType'] ?? ''),
                                      _buildDividerCell(),
                                      _buildDataCell(data['visitLocation'] ?? ''),
                                      _buildDividerCell(),
                                      _buildDataCell(data['purposeOfVisit'] ?? ''),
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
                            ),
                                  // end table body
                                ],
                              ), // inner Column
                            ), // SizedBox(width:1767)
                          ), // SingleChildScrollView (horizontal)
                          ), // SingleChildScrollView (vertical)
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
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
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
                                ? 'Showing ${onDutyData.isEmpty ? 0 : 1}–${onDutyData.length} of ${onDutyData.length}'
                                : '${filteredOnDutyData.length} of ${onDutyData.length}',
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

  Widget _buildHeaderCell(String text) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
      height: 50,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
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
            'Add New On Duty Application',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // First Row: Employee Code, Employee Paycode
          Row(
            children: [
              Expanded(child: _buildFormField('Employee Code *', _empCodeController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Employee Paycode *', _empPaycodeController, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Second Row: Employee Name, Location
          Row(
            children: [
              Expanded(child: _buildFormField('Employee Name *', _empNameController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Location *', _locationController, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Third Row: Department, Reporting Manager
          Row(
            children: [
              Expanded(child: _buildFormField('Department *', _departmentController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Reporting Manager *', _reportingManagerController, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Fourth Row: Application Type (full width)
          _buildDropdownField('Application Type *', selectedApplicationType, ['On Duty'], (value) {
            setState(() {
              selectedApplicationType = value!;
            });
          }),
          const SizedBox(height: 16),
          
          // Fifth Row: OD From, OD Till
          Row(
            children: [
              Expanded(child: _buildDateField('OD From *', selectedFromDate, (date) {
                setState(() {
                  selectedFromDate = date;
                });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildDateField('OD Till *', selectedTillDate, (date) {
                setState(() {
                  selectedTillDate = date;
                });
              })),
            ],
          ),
          const SizedBox(height: 16),

          // Fifth-B Row: Full Day / Half Day selection
          _buildDropdownField('Full Day / Half Day *', selectedDayCount, [
            'Full Day',
            'Half Day - Morning',
            'Half Day - Evening',
          ], (value) {
            setState(() {
              selectedDayCount = value!;
            });
          }),
          const SizedBox(height: 16),
          
          // Sixth Row: Visit Location Type, Visit Location
          Row(
            children: [
              Expanded(child: _buildDropdownField('Visit Location Type (Internal Visit Not Required) *', selectedVisitLocationType, [
                'Outside Unit',
                'Client Office',
                'Branch Office',
                'Customer Site',
                'Training Center',
                'Other'
              ], (value) {
                setState(() {
                  selectedVisitLocationType = value!;
                });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Visit Location (To be specified) *', _visitLocationController, hintText: 'Enter visit location')),
            ],
          ),
          const SizedBox(height: 16),
          
          // Seventh Row: Purpose of Visit (full width)
          _buildFormField('Purpose of Visit (To be specified) *', _purposeOfVisitController, hintText: 'Enter purpose of visit'),
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

  Widget _buildDateField(String label, DateTime? selectedDate, ValueChanged<DateTime?> onChanged) {
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
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              onChanged(picked);
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
                      ? '${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}'
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
        _empPaycodeController.text.isEmpty ||
        _empNameController.text.isEmpty ||
        _locationController.text.isEmpty ||
        _departmentController.text.isEmpty ||
        _reportingManagerController.text.isEmpty ||
        selectedFromDate == null ||
        selectedTillDate == null ||
        _visitLocationController.text.isEmpty ||
        _purposeOfVisitController.text.isEmpty) {
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
      // Format dates for API (YYYY-MM-DDTHH:MM format as expected by Django backend)
      final formattedFromDate = '${selectedFromDate!.year}-${selectedFromDate!.month.toString().padLeft(2, '0')}-${selectedFromDate!.day.toString().padLeft(2, '0')}T09:00';
      final formattedTillDate = '${selectedTillDate!.year}-${selectedTillDate!.month.toString().padLeft(2, '0')}-${selectedTillDate!.day.toString().padLeft(2, '0')}T18:00';
      
      // Calculate day count
      final dayCount = selectedTillDate!.difference(selectedFromDate!).inDays + 1;

      // Determine day part from selection
      String dayPart;
      switch (selectedDayCount) {
        case 'Half Day - Morning':
          dayPart = 'HDM';
          break;
        case 'Half Day - Evening':
          dayPart = 'HDE';
          break;
        default:
          dayPart = 'FD';
      }
      
      debugPrint('📝 Submitting on duty application:');
      debugPrint('   Employee Code: ${_empCodeController.text}');
      debugPrint('   Employee Paycode: ${_empPaycodeController.text}');
      debugPrint('   Employee Name: ${_empNameController.text}');
      debugPrint('   Location: ${_locationController.text}');
      debugPrint('   Department: ${_departmentController.text}');
      debugPrint('   Reporting Manager: ${_reportingManagerController.text}');
      debugPrint('   Application Type: $selectedApplicationType');
      debugPrint('   From Date: $formattedFromDate');
      debugPrint('   Till Date: $formattedTillDate');
      debugPrint('   Day Count: $dayCount');
      debugPrint('   Day Part: $dayPart');
      debugPrint('   Visit Location Type: $selectedVisitLocationType');
      debugPrint('   Visit Location: ${_visitLocationController.text}');
      debugPrint('   Purpose of Visit: ${_purposeOfVisitController.text}');

      // Submit the application via API
      final success = await _apiService.submitOnDutyApplication(
        fromDate: formattedFromDate,
        tillDate: formattedTillDate,
        dayCount: dayCount.toString(),
        dayPart: dayPart,
        visitLocationType: selectedVisitLocationType,
        visitLocation: _visitLocationController.text,
        purposeOfVisit: _purposeOfVisitController.text,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (success) {
        debugPrint('✅ On duty application submitted successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('On duty application submitted successfully!'),
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
        _fetchOnDutyData();
      } else {
        debugPrint('⚠️ On duty application submission failed');
        
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
      debugPrint('❌ Error submitting on duty application: $e');
      
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

  void _clearForm() {
    setState(() {
      selectedFromDate = null;
      selectedTillDate = null;
      selectedApplicationType = 'On Duty';
      selectedVisitLocationType = 'Outside Unit';
      selectedDayCount = 'Full Day';
      _visitLocationController.clear();
      _purposeOfVisitController.clear();
    });
  }

  void _showCancelDialog(String applicationId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Application'),
          content: const Text('Are you sure you want to cancel this on duty application?'),
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
      
      final success = await _apiService.cancelOnDutyApplication(applicationId);
      
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
        _fetchOnDutyData();
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
        filteredOnDutyData = onDutyData;
      } else {
        filteredOnDutyData = onDutyData.where((item) {
          // Search in all fields
          return item.values.any((value) => 
            value.toLowerCase().contains(query.toLowerCase())
          );
        }).toList();
      }
    });
    
    debugPrint('🔍 Search query: "$query"');
    debugPrint('📊 Filtered results: ${filteredOnDutyData.length} out of ${onDutyData.length}');
  }

  Future<void> _loadEmployeeData() async {
    try {
      debugPrint('🔄 Loading employee data for form...');
      
      // Fetch employee data from API
      final employeeData = await _apiService.fetchEmployeeData();
      
      if (employeeData != null) {
        setState(() {
          empCode = employeeData['emp_code'] ?? '';
          empPaycode = employeeData['emp_paycode'] ?? '';
          empName = employeeData['emp_name'] ?? '';
          locCode = employeeData['loc_code'] ?? '';
          location = employeeData['loc_name'] ?? '';
          depCode = employeeData['dep_code'] ?? '';
          department = employeeData['dep_name'] ?? '';
          joiningDate = employeeData['joining_date'] ?? '';
          reportingManagerPaycode = employeeData['reporting_manager_paycode'] ?? '';
          reportingManager = employeeData['reporting_manager_name'] ?? '';
          
          // Pre-fill the form controllers
          _empCodeController.text = empCode;
          _empPaycodeController.text = empPaycode;
          _empNameController.text = empName;
          _locationController.text = location;
          _departmentController.text = department;
          _reportingManagerController.text = reportingManager;
        });
        
        debugPrint('✅ Employee data loaded successfully');
        debugPrint('👤 Employee: $empName ($empCode)');
        debugPrint('💼 Employee Paycode: $empPaycode');
        debugPrint('🏢 Department: $department (Code: $depCode)');
        debugPrint('📍 Location: $location (Code: $locCode)');
        debugPrint('📅 Joining Date: $joiningDate');
        debugPrint('👨‍💼 Reporting Manager: $reportingManager (Paycode: $reportingManagerPaycode)');
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
      
      // Initialize session for new on duty application (get fresh CSRF token)
      debugPrint('🔄 Initializing session for new on duty application...');
      final sessionReady = await _apiService.initializeSession();
      
      if (sessionReady) {
        debugPrint('✅ Session initialized successfully');
        // Load employee data when opening the form
        await _loadEmployeeData();
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