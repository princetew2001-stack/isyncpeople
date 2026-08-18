import 'package:flutter/material.dart';
import '../utils/wfh_api.dart';

class WFHPage extends StatefulWidget {
  const WFHPage({super.key});

  @override
  State<WFHPage> createState() => _WFHPageState();
}

class _WFHPageState extends State<WFHPage> {
  String searchQuery = '';
  bool isLoading = false;
  bool showAddForm = false;
  final WFHApiService _apiService = WFHApiService();
  final ScrollController _horizontalScrollController = ScrollController();

  // Table data
  List<Map<String, String>> wfhData = [];
  List<Map<String, String>> filteredWfhData = [];

  // Employee data (pre-filled)
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
  final TextEditingController _reasonController = TextEditingController();

  // Form values
  String selectedApplicationType = 'WFH';
  String selectedDayPart = 'Full Day';
  DateTime? selectedFromDate;
  DateTime? selectedTillDate;

  @override
  void initState() {
    super.initState();
    _fetchWFHData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _empCodeController.dispose();
    _empNameController.dispose();
    _locationController.dispose();
    _departmentController.dispose();
    _reportingManagerController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchWFHData() async {
    setState(() { isLoading = true; });
    try {
      debugPrint('🔄 Fetching WFH applications...');
      final List<Map<String, dynamic>> apiData = await _apiService.fetchWFHApplications();

      final List<Map<String, String>> convertedData = apiData.map((item) {
        return {
          'id': item['id']?.toString() ?? '',
          'applicationType': item['applicationType']?.toString() ?? '',
          'from': item['from']?.toString() ?? '',
          'till': item['till']?.toString() ?? '',
          'dayPart': item['dayPart']?.toString() ?? '',
          'dayCount': item['dayCount']?.toString() ?? '',
          'applicationStatus': item['applicationStatus']?.toString() ?? '',
          'reason': item['reason']?.toString() ?? '',
          'appliedOn': item['appliedOn']?.toString() ?? '',
          'approvedOn': item['approvedOn']?.toString() ?? '',
          'attachment': item['attachment']?.toString() ?? '',
          'remarks': item['remarks']?.toString() ?? '',
          // API doesn't return reporting_manager — use locally cached value
          'reportingManager': (item['reportingManager'] == '--' || (item['reportingManager'] ?? '').isEmpty)
              ? (reportingManager.isNotEmpty ? reportingManager : '--')
              : item['reportingManager']!.toString(),
        };
      }).toList();

      setState(() {
        wfhData = convertedData;
        filteredWfhData = convertedData;
        isLoading = false;
      });

      debugPrint('✅ Loaded ${convertedData.length} WFH applications');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Loaded ${convertedData.length} WFH applications'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      debugPrint('❌ Error fetching WFH data: $e');
      setState(() { isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  void _filterData(String query) {
    setState(() {
      searchQuery = query;
      filteredWfhData = query.isEmpty
          ? wfhData
          : wfhData.where((item) => item.values
              .any((v) => v.toLowerCase().contains(query.toLowerCase()))).toList();
    });
  }

  void _clearForm() {
    setState(() {
      selectedFromDate = null;
      selectedTillDate = null;
      selectedDayPart = 'Full Day';
      _reasonController.clear();
    });
  }

  Future<void> _loadEmployeeData() async {
    try {
      debugPrint('🔄 Loading employee data for WFH form...');
      final employeeData = await _apiService.fetchEmployeeData();
      if (employeeData != null) {
        setState(() {
          empCode = employeeData['emp_code'] ?? '';
          empName = employeeData['emp_name'] ?? '';
          location = employeeData['loc_name'] ?? '';
          department = employeeData['dep_name'] ?? '';
          reportingManager = employeeData['reporting_manager_name'] ?? '';
          _empCodeController.text = empCode;
          _empNameController.text = empName;
          _locationController.text = location;
          _departmentController.text = department;
          _reportingManagerController.text = reportingManager;
        });
        debugPrint('✅ Employee data loaded: $empName ($empCode)');
      } else {
        // Fallback: fill from SharedPreferences (login data)
        await _loadFromPrefs();
      }
    } catch (e) {
      debugPrint('❌ Error loading employee data from API: $e — falling back to local data');
      await _loadFromPrefs();
    }
  }

  /// Fallback: fill emp code and name from login SharedPreferences
  Future<void> _loadFromPrefs() async {
    try {
      final profile = await _apiService.getLocalEmployeeProfile();
      if (profile != null) {
        setState(() {
          _empCodeController.text = profile['emp_code'] ?? '';
          _empNameController.text = profile['emp_name'] ?? '';
        });
        debugPrint('✅ Loaded employee data from local prefs');
      }
    } catch (e) {
      debugPrint('❌ Error loading from prefs: $e');
    }
  }

  void _toggleAddForm() async {
    if (!showAddForm) {
      setState(() { showAddForm = true; });
      // Load employee data regardless of session status
      // Session failure should not block the form from opening
      await _loadEmployeeData();
    } else {
      setState(() { showAddForm = false; });
      _clearForm();
    }
  }

  void _submitForm() async {
    // Validate required fields — same as leave application
    if (_empCodeController.text.isEmpty ||
        _empNameController.text.isEmpty ||
        _departmentController.text.isEmpty ||
        selectedFromDate == null ||
        selectedTillDate == null ||
        _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all required fields'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Show loading dialog — same as leave application
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Submitting application...'),
        ]),
      ),
    );

    try {
      // Format dates YYYY-MM-DD — Django standard (same as leave application)
      String fmtDate(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final fromDateStr = fmtDate(selectedFromDate!);
      final tillDateStr = fmtDate(selectedTillDate!);

      // Map display value to API value
      String dayPartValue;
      switch (selectedDayPart) {
        case 'Half Day - Morning':
          dayPartValue = 'HDM';
          break;
        case 'Half Day - Evening':
          dayPartValue = 'HDE';
          break;
        case 'Short Leave':
          dayPartValue = 'SL';
          break;
        default:
          dayPartValue = 'FD';
      }

      debugPrint('📝 Submitting WFH application:');
      debugPrint('   application_type : WFH');
      debugPrint('   leave_from       : $fromDateStr');
      debugPrint('   leave_till       : $tillDateStr');
      debugPrint('   day_part         : $dayPartValue');
      debugPrint('   reason           : ${_reasonController.text.trim()}');
      debugPrint('   department       : ${_departmentController.text}');

      final success = await _apiService.submitWFHApplication(
        fromDate: fromDateStr,
        tillDate: tillDateStr,
        dayPart: dayPartValue,
        reason: _reasonController.text.trim(),
        department: _departmentController.text,
        reportingManager: _reportingManagerController.text,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        debugPrint('✅ WFH application submitted successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('WFH application submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ));
        }
        _clearForm();
        setState(() { showAddForm = false; });
        _fetchWFHData();
      } else {
        debugPrint('⚠️ WFH application submission failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to submit application. Please try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ));
        }
      }
    } catch (e) {
      debugPrint('❌ Error submitting WFH application: $e');
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error submitting application: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  void _showCancelDialog(String applicationId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Application'),
          content: const Text('Are you sure you want to cancel this WFH application?'),
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
      debugPrint('🔄 Cancelling WFH application with ID: $applicationId');

      final success = await _apiService.cancelWFHApplication(applicationId);

      if (success) {
        debugPrint('✅ WFH application cancelled successfully');
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
        _fetchWFHData();
      } else {
        debugPrint('⚠️ WFH application cancellation failed');
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
      debugPrint('❌ Error cancelling WFH application: $e');
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

  // ─── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate(bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          selectedFromDate = picked;
          if (selectedTillDate != null && selectedTillDate!.isBefore(picked)) {
            selectedTillDate = picked;
          }
        } else {
          selectedTillDate = picked;
        }
      });
    }
  }

  String _fmtDisplay(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Wfh Application Form'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black)))
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : _fetchWFHData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Top controls ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
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
                  onChanged: _filterData,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _toggleAddForm,
                icon: Icon(showAddForm ? Icons.close : Icons.add,
                    color: Colors.white, size: 16),
                label: Text(showAddForm ? 'Cancel' : 'Add New',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: showAddForm ? Colors.red : Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ]),
          ),

          // ── Add New Form ──────────────────────────────────────────────
          if (showAddForm)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _buildAddNewForm(),
            ),

          // ── Table — takes all remaining space ─────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 1480,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                        // Header
                        Container(
                          color: Colors.blue[100],
                          child: Table(
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            columnWidths: _columnWidths(),
                            children: [
                              TableRow(children: [
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
                                _buildHeaderCell('Reason'),
                                _buildDividerCell(),
                                _buildHeaderCell('Applied On'),
                                _buildDividerCell(),
                                _buildHeaderCell('Approved On'),
                                _buildDividerCell(),
                                _buildHeaderCell('Attachment'),
                                _buildDividerCell(),
                                _buildHeaderCell('Remarks'),
                                _buildDividerCell(),
                                _buildHeaderCell('Reporting Manager'),
                              ]),
                            ],
                          ),
                        ),
                        // Body
                        isLoading
                              ? const Center(child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Loading WFH applications...',
                                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                                  ]))
                              : wfhData.isEmpty
                                  ? const Center(child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text('No WFH applications found',
                                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                                        SizedBox(height: 8),
                                        Text('Click "Add New" to create your first application',
                                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ]))
                                  : filteredWfhData.isEmpty
                                      ? const Center(child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                                            SizedBox(height: 16),
                                            Text('No results found',
                                                style: TextStyle(fontSize: 16, color: Colors.grey)),
                                          ]))
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: filteredWfhData.length,
                                          itemBuilder: (context, index) {
                                            final data = filteredWfhData[index];
                                            return Container(
                                              decoration: BoxDecoration(
                                                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                                              ),
                                              child: Table(
                                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                                columnWidths: _columnWidths(),
                                                children: [
                                                  TableRow(children: [
                                                    _buildDataCell(data['applicationType'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['from'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['till'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['dayPart'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['dayCount'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildStatusCell(data['applicationStatus'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['reason'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['appliedOn'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['approvedOn'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['attachment'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['remarks'] ?? ''),
                                                    _buildDividerCell(),
                                                    _buildDataCell(data['reportingManager'] ?? ''),
                                                  ]),
                                                ],
                                              ),
                                            );
                                          }),
                                  // end table body
                                ],
                              ), // inner Column
                            ), // SizedBox(width:1480)
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
                                ? 'Showing ${wfhData.isEmpty ? 0 : 1}–${wfhData.length} of ${wfhData.length}'
                                : '${filteredWfhData.length} of ${wfhData.length}',
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

  // ─── Column widths ───────────────────────────────────────────────────────────
  Map<int, TableColumnWidth> _columnWidths() {
    return const {
      0:  FixedColumnWidth(120),  // Application Type
      1:  FixedColumnWidth(0.5),
      2:  FixedColumnWidth(110),  // From
      3:  FixedColumnWidth(0.5),
      4:  FixedColumnWidth(110),  // Till
      5:  FixedColumnWidth(0.5),
      6:  FixedColumnWidth(160),  // Day Part
      7:  FixedColumnWidth(0.5),
      8:  FixedColumnWidth(90),   // Day Count
      9:  FixedColumnWidth(0.5),
      10: FixedColumnWidth(140),  // Application Status
      11: FixedColumnWidth(0.5),
      12: FixedColumnWidth(150),  // Reason
      13: FixedColumnWidth(0.5),
      14: FixedColumnWidth(110),  // Applied On
      15: FixedColumnWidth(0.5),
      16: FixedColumnWidth(110),  // Approved On
      17: FixedColumnWidth(0.5),
      18: FixedColumnWidth(100),  // Attachment
      19: FixedColumnWidth(0.5),
      20: FixedColumnWidth(120),  // Remarks
      21: FixedColumnWidth(0.5),
      22: FixedColumnWidth(150),  // Reporting Manager
    };
  }

  // ─── Form ────────────────────────────────────────────────────────────────────
  Widget _buildAddNewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add New WFH Application',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 16),

        // Row 1: Employee Code, Employee Name
        Row(children: [
          Expanded(child: _buildFormField('Employee Code *', _empCodeController, enabled: false)),
          const SizedBox(width: 12),
          Expanded(child: _buildFormField('Employee Name *', _empNameController, enabled: false)),
        ]),
        const SizedBox(height: 16),

        // Row 2: Location, Department
        Row(children: [
          Expanded(child: _buildFormField('Location', _locationController, enabled: false)),
          const SizedBox(width: 12),
          Expanded(child: _buildFormField('Department *', _departmentController, enabled: false)),
        ]),
        const SizedBox(height: 16),

        // Row 3: Reporting Manager, Application Type
        Row(children: [
          Expanded(child: _buildFormField('Reporting Manager *', _reportingManagerController, enabled: false)),
          const SizedBox(width: 12),
          Expanded(child: _buildDropdownField('Application Type *', selectedApplicationType, ['WFH'], (v) {
            setState(() => selectedApplicationType = v!);
          })),
        ]),
        const SizedBox(height: 16),

        // Row 4: WFH From, WFH Till
        Row(children: [
          Expanded(child: _buildDateField('WFH From *', selectedFromDate, () => _pickDate(true))),
          const SizedBox(width: 12),
          Expanded(child: _buildDateField('WFH Till *', selectedTillDate, () => _pickDate(false))),
        ]),
        const SizedBox(height: 16),

        // Row 5: Day Part, Reason
        Row(children: [
          Expanded(child: _buildDropdownField(
            'Full Day/Half Day (Day Count) *',
            selectedDayPart,
            ['Full Day', 'Half Day - Morning', 'Half Day - Evening', 'Short Leave'],
            (v) => setState(() => selectedDayPart = v!),
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildFormField('Reason *', _reasonController, enabled: true)),
        ]),
        const SizedBox(height: 20),

        // Save button
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ]),
      ]),
    );
  }

  // ─── Form helpers ────────────────────────────────────────────────────────────
  Widget _buildFormField(String label, TextEditingController controller, {bool enabled = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey[300]!)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey[200]!)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          filled: !enabled,
          fillColor: enabled ? Colors.white : Colors.grey[50],
        ),
        style: TextStyle(fontSize: 14, color: enabled ? Colors.black : Colors.grey[600]),
      ),
    ]);
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 14)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue)),
      const SizedBox(height: 4),
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              date != null ? _fmtDisplay(date) : 'Select date',
              style: TextStyle(fontSize: 14, color: date != null ? Colors.black : Colors.grey[500]),
            ),
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          ]),
        ),
      ),
    ]);
  }

  // ─── Table helpers ───────────────────────────────────────────────────────────
  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.left),
    );
  }

  Widget _buildDataCell(String text) {
    final isEmpty = text == '--';
    return Container(
      height: 50,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: isEmpty ? Colors.grey[400] : null,
        ),
        textAlign: TextAlign.left,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusCell(String status) {
    Color bg;
    switch (status.toLowerCase()) {
      case 'pending':  bg = Colors.orange; break;
      case 'approved': bg = Colors.green;  break;
      case 'rejected': bg = Colors.red;    break;
      default:         bg = Colors.grey;
    }
    return Container(
      height: 50,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildCancelCell(String applicationId, String status) {
    // Only show cancel button if status is "Pending"
    final isPending = status.toLowerCase() == 'pending';

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.center,
      child: isPending && applicationId.isNotEmpty
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
                isPending ? '-' : (status.length >= 3 ? status.substring(0, 3).toUpperCase() : status.toUpperCase()),
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
    return Container(width: 0.5, height: 50, color: Colors.grey[400]);
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
}
