import 'package:flutter/material.dart';
import '../utils/comp_off_api.dart';
import '../utils/permission_service.dart';

class CompOffPage extends StatefulWidget {
  const CompOffPage({super.key});

  @override
  State<CompOffPage> createState() => _CompOffPageState();
}

class _CompOffPageState extends State<CompOffPage> {
  String searchQuery = '';
  bool isLoading = false;
  bool showAddForm = false;
  final ScrollController _horizontalScrollController = ScrollController();
  final CompOffApiService _apiService = CompOffApiService();
  final PermissionService _permissionService = PermissionService();

  // Permissions
  bool _canWrite  = false; // Add New
  bool _canUpdate = false; // Cancel button

  // Data lists
  List<Map<String, String>> compOffData = [];
  List<Map<String, String>> filteredCompOffData = [];

  // Employee data
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
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  // Form dropdown/date values
  String selectedApplicationType = 'Comp-off';
  String selectedDayCount = 'Full Day';
  String selectedLocation = 'Home'; // Default location
  DateTime? selectedCompOffDate;
  DateTime? selectedWorkingDate;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fetchCompOffData();
  }

  Future<void> _loadPermissions() async {
    final canWrite  = await _permissionService.canWrite('Comp-Off');
    final canUpdate = await _permissionService.canUpdate('Comp-Off');
    if (mounted) {
      setState(() {
        _canWrite  = canWrite;
        _canUpdate = canUpdate;
      });
    }
    debugPrint('🔐 Comp-Off permissions — Write: $canWrite, Update: $canUpdate');
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _empCodeController.dispose();
    _empNameController.dispose();
    _locationController.dispose();
    _departmentController.dispose();
    _reportingManagerController.dispose();
    _addressController.dispose();
    _mobileNumberController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // ─── Column widths ───────────────────────────────────────────────────────────
  static const Map<int, TableColumnWidth> _colWidths = {
    0:  FixedColumnWidth(80),   // Cancel
    1:  FixedColumnWidth(130),  // Application Type
    2:  FixedColumnWidth(120),  // Comp-off Date
    3:  FixedColumnWidth(120),  // Working Date
    4:  FixedColumnWidth(100),  // Day Part
    5:  FixedColumnWidth(130),  // Application Status
    6:  FixedColumnWidth(160),  // Reason
    7:  FixedColumnWidth(120),  // Applied On
    8:  FixedColumnWidth(120),  // Approved On
    9:  FixedColumnWidth(120),  // Rejected On
    10: FixedColumnWidth(150),  // Updated By
    11: FixedColumnWidth(150),  // Remarks
  };

  static final TableBorder _tableBorder = TableBorder(
    verticalInside: BorderSide(color: Colors.grey.shade400, width: 0.5),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Comp-Off Application Form'),
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
            onPressed: isLoading ? null : _fetchCompOffData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Top controls ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
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
                if (_canWrite || showAddForm)
                  ElevatedButton.icon(
                    onPressed: _toggleAddForm,
                    icon: Icon(showAddForm ? Icons.close : Icons.add, color: Colors.white, size: 16),
                    label: Text(
                      showAddForm ? 'Cancel' : 'Add New',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: showAddForm ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
              ],
            ),
          ),

          // ── Add New Form ──────────────────────────────────────────────────
          if (showAddForm)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SingleChildScrollView(child: _buildAddNewForm()),
              ),
            ),

          // ── Table ─────────────────────────────────────────────────────────
          if (!showAddForm)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _horizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  // sum of all column widths
                                  width: 80+130+120+120+100+130+160+120+120+120+150+150.0,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // ── Header ──────────────────────────
                                      Container(
                                        color: Colors.blue[100],
                                        child: Table(
                                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                          columnWidths: _colWidths,
                                          border: _tableBorder,
                                          children: [
                                            TableRow(children: [
                                              _buildHeaderCell('Cancel'),
                                              _buildHeaderCell('Application Type'),
                                              _buildHeaderCell('Comp-off Date'),
                                              _buildHeaderCell('Working Date'),
                                              _buildHeaderCell('Day Part'),
                                              _buildHeaderCell('Application Status'),
                                              _buildHeaderCell('Reason'),
                                              _buildHeaderCell('Applied On'),
                                              _buildHeaderCell('Approved On'),
                                              _buildHeaderCell('Rejected On'),
                                              _buildHeaderCell('Updated By'),
                                              _buildHeaderCell('Remarks'),
                                            ]),
                                          ],
                                        ),
                                      ),

                                      // ── Body ────────────────────────────
                                      if (isLoading)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 48),
                                          child: Center(
                                            child: Column(
                                              children: [
                                                CircularProgressIndicator(),
                                                SizedBox(height: 16),
                                                Text('Loading comp-off applications...',
                                                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                        )
                                      else if (compOffData.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 48),
                                          child: Center(
                                            child: Column(
                                              children: [
                                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                                                SizedBox(height: 16),
                                                Text('No comp-off applications found',
                                                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                                                SizedBox(height: 8),
                                                Text('Click "Add New" to create your first application',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                        )
                                      else if (filteredCompOffData.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 48),
                                          child: Center(
                                            child: Column(
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
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: filteredCompOffData.length,
                                          itemBuilder: (context, index) {
                                            final data = filteredCompOffData[index];
                                            return Container(
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(color: Colors.grey[200]!),
                                                ),
                                              ),
                                              child: Table(
                                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                                columnWidths: _colWidths,
                                                border: _tableBorder,
                                                children: [
                                                  TableRow(children: [
                                                    _buildCancelCell(data['id'] ?? '', data['applicationStatus'] ?? ''),
                                                    _buildDataCell(data['applicationType'] ?? ''),
                                                    _buildDataCell(data['compOffDate'] ?? ''),
                                                    _buildDataCell(data['workingDate'] ?? ''),
                                                    _buildDataCell(data['dayPart'] ?? ''),
                                                    _buildStatusCell(data['applicationStatus'] ?? ''),
                                                    _buildDataCell(data['reason'] ?? ''),
                                                    _buildDataCell(data['appliedOn'] ?? ''),
                                                    _buildDataCell(data['approvedOn'] ?? ''),
                                                    _buildDataCell(data['rejectedOn'] ?? ''),
                                                    _buildDataCell(data['updatedBy'] ?? ''),
                                                    _buildDataCell(data['remarks'] ?? ''),
                                                  ]),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Pagination overlay ───────────────────────────────
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
                                  ? 'Showing ${compOffData.isEmpty ? 0 : 1}–${compOffData.length} of ${compOffData.length}'
                                  : '${filteredCompOffData.length} of ${compOffData.length}',
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
                              child: const Text('1',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
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

  // ─── Add New Form ────────────────────────────────────────────────────────────
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
            'Add New Comp-Off Application',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),

          // Row 1: Employee Code | Employee Name
          Row(
            children: [
              Expanded(child: _buildFormField('Employee Code *', _empCodeController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Employee Name *', _empNameController, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),

          // Row 2: Location | Department
          Row(
            children: [
              Expanded(child: _buildFormField('Location *', _locationController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Department *', _departmentController, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),

          // Row 3: Reporting Manager | Application Type
          Row(
            children: [
              Expanded(
                child: _buildFormField('Reporting Manager', _reportingManagerController, enabled: false),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Application Type *', TextEditingController(text: selectedApplicationType), enabled: false)),
            ],
          ),
          const SizedBox(height: 16),

          // Row 4: Comp-off Date | Working Date
          Row(
            children: [
              Expanded(
                child: _buildDateField('Comp-off Date *', selectedCompOffDate, (date) {
                  setState(() => selectedCompOffDate = date);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSundayOnlyDateField('Working Date *', selectedWorkingDate, (date) {
                  setState(() => selectedWorkingDate = date);
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 5: Full Day/Half Day | Location (Dropdown)
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  'Full Day/Half Day (Day Count) *',
                  selectedDayCount,
                  const ['Full Day', 'Half Day - Morning', 'Half Day - Evening'],
                  (value) => setState(() => selectedDayCount = value!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  'Location *',
                  selectedLocation,
                  const ['Home', 'Office', 'Client Site', 'Other'],
                  (value) => setState(() => selectedLocation = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 6: Address During Day Period | Mobile Number
          Row(
            children: [
              Expanded(child: _buildFormField('Address During Day Period *', _addressController, hintText: 'Enter your address')),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Mobile Number *', _mobileNumberController, hintText: 'Enter mobile number')),
            ],
          ),
          const SizedBox(height: 16),

          // Row 7: Reason For Leave (full width)
          _buildFormField('Reason For Leave *', _reasonController, hintText: 'Enter reason for comp-off'),
          const SizedBox(height: 20),

          // Save button
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ─── Reusable cell widgets ───────────────────────────────────────────────────
  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildDataCell(String text) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildStatusCell(String status) {
    Color bg;
    switch (status.toLowerCase()) {
      case 'pending':
        bg = Colors.orange;
        break;
      case 'approved':
        bg = Colors.green;
        break;
      case 'rejected':
        bg = Colors.red;
        break;
      default:
        bg = Colors.grey;
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(status,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCancelCell(String? applicationId, String status) {
    final isPending = status.toLowerCase() == 'pending';
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.center,
      child: isPending && _canUpdate && applicationId != null && applicationId.isNotEmpty
          ? ElevatedButton(
              onPressed: () => _showCancelDialog(applicationId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 30),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
            )
          : Text(
              status.isNotEmpty ? status.substring(0, status.length.clamp(0, 3)).toUpperCase() : '-',
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500),
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
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: onPressed == null ? Colors.grey[400] : Colors.black87,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── Form field widgets ──────────────────────────────────────────────────────
  Widget _buildFormField(String label, TextEditingController controller,
      {bool enabled = true, String? hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey[300]!)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey[300]!)),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey[200]!)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: !enabled,
            fillColor: enabled ? Colors.white : Colors.grey[50],
          ),
          style: TextStyle(fontSize: 14, color: enabled ? Colors.black : Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items,
      ValueChanged<String?> onChanged, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue)),
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
              hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 14)) : null,
              items: items
                  .map((item) => DropdownMenuItem<String>(
                      value: item, child: Text(item, style: const TextStyle(fontSize: 14))))
                  .toList(),
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
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) onChanged(picked);
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
                      : 'mm/dd/yyyy',
                  style: TextStyle(
                      fontSize: 14,
                      color: selectedDate != null ? Colors.black : Colors.grey[500]),
                ),
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Date field that only allows Sundays, 2nd Saturdays, and last Saturdays
  Widget _buildSundayOnlyDateField(String label, DateTime? selectedDate, ValueChanged<DateTime?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? _findNextWeeklyOff(DateTime.now()),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              selectableDayPredicate: (DateTime date) {
                // Allow Sundays
                if (date.weekday == DateTime.sunday) return true;
                // Allow 2nd Saturday (day falls between 8–14)
                if (date.weekday == DateTime.saturday && date.day >= 8 && date.day <= 14) return true;
                // Allow last Saturday (day falls in last 7 days of month)
                if (date.weekday == DateTime.saturday) {
                  final lastDayOfMonth = DateTime(date.year, date.month + 1, 0).day;
                  if (date.day > lastDayOfMonth - 7) return true;
                }
                return false;
              },
            );
            if (picked != null) onChanged(picked);
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
                      : 'Select Working Day',
                  style: TextStyle(
                      fontSize: 14,
                      color: selectedDate != null ? Colors.black : Colors.grey[500]),
                ),
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper: find the next Sunday / 2nd Saturday / last Saturday from a given date
  DateTime _findNextWeeklyOff(DateTime date) {
    for (int i = 0; i <= 31; i++) {
      final d = date.add(Duration(days: i));
      if (d.weekday == DateTime.sunday) return d;
      if (d.weekday == DateTime.saturday && d.day >= 8 && d.day <= 14) return d;
      if (d.weekday == DateTime.saturday) {
        final lastDayOfMonth = DateTime(d.year, d.month + 1, 0).day;
        if (d.day > lastDayOfMonth - 7) return d;
      }
    }
    return date;
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────
  void _submitForm() async {
    // Validate required fields
    if (_empCodeController.text.isEmpty ||
        _empNameController.text.isEmpty ||
        selectedCompOffDate == null ||
        selectedWorkingDate == null ||
        _addressController.text.isEmpty ||
        _mobileNumberController.text.isEmpty ||
        _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Submitting application...'),
          ],
        ),
      ),
    );

    try {
      // Format dates for API (YYYY-MM-DD format)
      final formattedCompOffDate = '${selectedCompOffDate!.year}-${selectedCompOffDate!.month.toString().padLeft(2, '0')}-${selectedCompOffDate!.day.toString().padLeft(2, '0')}';
      final formattedWorkingDate = '${selectedWorkingDate!.year}-${selectedWorkingDate!.month.toString().padLeft(2, '0')}-${selectedWorkingDate!.day.toString().padLeft(2, '0')}';

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

      debugPrint('📝 Submitting comp-off application:');
      debugPrint('   Employee Code: ${_empCodeController.text}');
      debugPrint('   Employee Name: ${_empNameController.text}');
      debugPrint('   Location: $selectedLocation');
      debugPrint('   Department: ${_departmentController.text}');
      debugPrint('   Reporting Manager: ${_reportingManagerController.text}');
      debugPrint('   Application Type: $selectedApplicationType');
      debugPrint('   Comp-off Date (leave_from): $formattedCompOffDate');
      debugPrint('   Working Date (working_day): $formattedWorkingDate');
      debugPrint('   Day Part: $dayPart');
      debugPrint('   Address: ${_addressController.text}');
      debugPrint('   Mobile Number (phone): ${_mobileNumberController.text}');
      debugPrint('   Reason: ${_reasonController.text}');

      // Submit the application via API
      final success = await _apiService.submitCompOffApplication(
        compOffDate:  formattedCompOffDate,  // from_date
        workingDate:  formattedWorkingDate,  // till_date
        dayPart:      dayPart,               // day_part
        address:      _addressController.text, // address
        mobileNumber: _mobileNumberController.text, // phone
        reason:       _reasonController.text, // reason
        department:   _departmentController.text, // department
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (success) {
        debugPrint('✅ Comp-off application submitted successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comp-off application submitted successfully!'),
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
        _fetchCompOffData();
      } else {
        debugPrint('⚠️ Comp-off application submission failed');

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
      debugPrint('❌ Error submitting comp-off application: $e');

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
      selectedCompOffDate = null;
      selectedWorkingDate = null;
      selectedDayCount = 'Full Day';
      selectedLocation = 'Home'; // Reset location dropdown
    });
    _empCodeController.clear();
    _empNameController.clear();
    _locationController.clear();
    _departmentController.clear();
    _reportingManagerController.clear();
    _addressController.clear();
    _mobileNumberController.clear();
    _reasonController.clear();
  }

  void _showCancelDialog(String applicationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Application'),
        content: const Text('Are you sure you want to cancel this comp-off application?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelApplication(applicationId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelApplication(String applicationId) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Cancelling application...'),
          ],
        ),
      ),
    );

    try {
      debugPrint('🔄 Cancelling comp-off application: $applicationId');
      final success = await _apiService.cancelCompOffApplication(applicationId);

      if (mounted) Navigator.pop(context); // close loading dialog

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? 'Application cancelled successfully'
              : 'Failed to cancel application'),
          backgroundColor: success ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ));
      }
      if (success) _fetchCompOffData();
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading dialog
      debugPrint('❌ Error cancelling comp-off application: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error cancelling application: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  // ─── Fetch list from API ──────────────────────────────────────────────────
  Future<void> _fetchCompOffData() async {
    setState(() => isLoading = true);
    try {
      debugPrint('🔄 Fetching comp-off applications...');
      final apiData = await _apiService.fetchCompOffApplications();

      debugPrint('📊 API returned ${apiData.length} items');
      
      final converted = apiData.map((item) {
        debugPrint('🔍 Converting item: id=${item['id']}, compOffDate=${item['compOffDate']}, workingDate=${item['workingDate']}');
        
        return {
          'id':                item['id']?.toString()                ?? '',
          'applicationType':   item['applicationType']?.toString()   ?? '',
          'compOffDate':       item['compOffDate']?.toString()       ?? '',
          'workingDate':       item['workingDate']?.toString()       ?? '',
          'dayPart':           item['dayPart']?.toString()           ?? '',
          'dayCount':          item['dayCount']?.toString()          ?? '',
          'applicationStatus': item['applicationStatus']?.toString() ?? '',
          'reason':            item['reason']?.toString()            ?? '',
          'appliedOn':         item['appliedOn']?.toString()         ?? '',
          'approvedOn':        item['approvedOn']?.toString()        ?? '',
          'rejectedOn':        item['rejectedOn']?.toString()        ?? '',
          'updatedBy':         item['updatedBy']?.toString()         ?? '',
          'remarks':           item['remarks']?.toString()           ?? '',
        };
      }).toList();

      debugPrint('✅ Converted ${converted.length} items');
      if (converted.isNotEmpty) {
        debugPrint('📝 First item: ${converted[0]}');
      }

      setState(() {
        compOffData = converted;
        filteredCompOffData = converted;
        isLoading = false;
      });

      debugPrint('✅ Loaded ${converted.length} comp-off applications');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Loaded ${converted.length} comp-off applications'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      debugPrint('❌ Error fetching comp-off data: $e');
      setState(() => isLoading = false);
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
      filteredCompOffData = query.isEmpty
          ? compOffData
          : compOffData
              .where((item) => item.values
                  .any((v) => v.toLowerCase().contains(query.toLowerCase())))
              .toList();
    });
  }

  void _toggleAddForm() async {
    if (!showAddForm) {
      setState(() => showAddForm = true);

      debugPrint('🔄 Initializing session for new comp-off application...');
      final sessionReady = await _apiService.initializeSession();

      if (sessionReady) {
        debugPrint('✅ Session initialized successfully');
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
        setState(() => showAddForm = false);
      }
    } else {
      setState(() => showAddForm = false);
      _clearForm();
    }
  }

  Future<void> _loadEmployeeData() async {
    try {
      debugPrint('🔄 Loading employee data for comp-off form...');

      final employeeData = await _apiService.fetchEmployeeData();
      if (employeeData != null) {
        setState(() {
          empCode       = employeeData['emp_code']                  ?? '';
          empName       = employeeData['emp_name']                  ?? '';
          location      = employeeData['loc_name']                  ?? '';
          department    = employeeData['dep_name']                  ?? '';
          reportingManager = employeeData['reporting_manager_name'] ?? '';

          // Pre-fill read-only controllers
          _empCodeController.text       = empCode;
          _empNameController.text       = empName;
          _locationController.text      = location;
          _departmentController.text    = department;
          // Reporting manager shown as plain text (disabled field)
          _reportingManagerController.text = reportingManager;
        });

        debugPrint('✅ Employee data loaded: $empName ($empCode)');
        debugPrint('🏢 Dept: $department  📍 Location: $location');
        debugPrint('👨‍💼 Reporting Manager: $reportingManager');
      } else {
        debugPrint('⚠️ No employee data received');
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
}
