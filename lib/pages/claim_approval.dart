import 'package:flutter/material.dart';
import '../utils/claim_approval_api.dart';

class ClaimApprovalPage extends StatefulWidget {
  const ClaimApprovalPage({super.key});

  @override
  State<ClaimApprovalPage> createState() => _ClaimApprovalPageState();
}

class _ClaimApprovalPageState extends State<ClaimApprovalPage> {
  final ClaimApprovalApiService _apiService = ClaimApprovalApiService();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Role flags from API
  bool isReporting = false;
  bool isManagement = false;
  bool isAccounts = false;

  bool isLoading = false;

  // Filter bar hide/show on scroll
  bool _filterVisible = true;
  double _lastScrollOffset = 0;

  List<Map<String, dynamic>> allClaims = [];
  List<Map<String, dynamic>> filteredClaims = [];

  // Filter state
  String selectedClaimType = 'All Claims';
  String selectedStatus = 'All Status';
  final TextEditingController _claimNoController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();

  static const List<String> _claimTypes = [
    'All Claims',
    'Travel',
    'General',
    'Conveyance',
    'Reimbursement',
  ];

  static const List<String> _statusOptions = [
    'All Status',
    'Pending',
    'Approve',
    'Accepted',
    'Rejected',
  ];

  // ── Column widths ─────────────────────────────────────────────────────────
  static const Map<int, TableColumnWidth> _colWidths = {
    0:  FixedColumnWidth(55),
    1:  FixedColumnWidth(140),
    2:  FixedColumnWidth(110),
    3:  FixedColumnWidth(140),
    4:  FixedColumnWidth(180),
    5:  FixedColumnWidth(110),
    6:  FixedColumnWidth(100),
    7:  FixedColumnWidth(130),
    8:  FixedColumnWidth(140),
    9:  FixedColumnWidth(130),
    10: FixedColumnWidth(150),
    11: FixedColumnWidth(140),
    12: FixedColumnWidth(160),
  };

  static final TableBorder _tableBorder = TableBorder(
    verticalInside: BorderSide(color: Colors.grey.shade300, width: 0.5),
    horizontalInside: BorderSide(color: Colors.grey.shade200, width: 0.5),
  );

  double get _tableWidth =>
      55 + 140 + 110 + 140 + 180 + 110 + 100 + 130 + 140 + 130 + 150 + 140 + 160.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _verticalScrollController.addListener(_onVerticalScroll);
  }

  void _onVerticalScroll() {
    final offset = _verticalScrollController.offset;
    if (offset > _lastScrollOffset + 10 && _filterVisible) {
      setState(() => _filterVisible = false);
    } else if (offset < _lastScrollOffset - 10 && !_filterVisible) {
      setState(() => _filterVisible = true);
    }
    _lastScrollOffset = offset;
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final result = await _apiService.fetchClaimApprovals();
      if (mounted) {
        setState(() {
          allClaims = List<Map<String, dynamic>>.from(result['claims'] as List);
          isReporting = result['isReporting'] as bool;
          isManagement = result['isManagement'] as bool;
          isAccounts = result['isAccounts'] as bool;
          isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load claim approvals: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      filteredClaims = allClaims.where((item) {
        if (selectedClaimType != 'All Claims') {
          final type = (item['claimType'] as String).toLowerCase();
          if (type != selectedClaimType.toLowerCase()) return false;
        }
        if (_claimNoController.text.isNotEmpty) {
          final claimNo = (item['claimNo'] as String).toLowerCase();
          if (!claimNo.contains(_claimNoController.text.toLowerCase())) return false;
        }
        if (_purposeController.text.isNotEmpty) {
          final purpose = (item['purpose'] as String).toLowerCase();
          if (!purpose.contains(_purposeController.text.toLowerCase())) return false;
        }
        if (selectedStatus != 'All Status') {
          final rs  = (item['reportingStatus']  as String).toLowerCase();
          final ms  = (item['managementStatus'] as String).toLowerCase();
          final as_ = (item['accountsStatus']   as String).toLowerCase();
          final filter = selectedStatus.toLowerCase();
          if (rs != filter && ms != filter && as_ != filter) return false;
        }
        return true;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      selectedClaimType = 'All Claims';
      selectedStatus = 'All Status';
      _claimNoController.clear();
      _purposeController.clear();
    });
    _applyFilters();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _claimNoController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'CLAIM APPROVAL SCREEN',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              letterSpacing: 0.5,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: isLoading ? null : _fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Bar (animated hide on scroll down) ───────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _filterVisible ? _buildFilterBar() : const SizedBox.shrink(),
          ),

          // ── Table ────────────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    Expanded(
                      child: isLoading
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading claim approvals...',
                                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              controller: _verticalScrollController,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                controller: _horizontalScrollController,
                                child: SizedBox(
                                  width: _tableWidth,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildTableHeader(),
                                      const Divider(
                                          height: 1, thickness: 1, color: Color(0xFFDDDDDD)),
                                      filteredClaims.isEmpty
                                          ? SizedBox(
                                              height: 200,
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.task_alt_outlined,
                                                        size: 56, color: Colors.grey[400]),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      'No claim approvals found',
                                                      style: TextStyle(
                                                          fontSize: 15, color: Colors.grey[600]),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: filteredClaims.length,
                                              itemBuilder: (context, index) {
                                                final item = filteredClaims[index];
                                                final isEven = index % 2 == 0;
                                                return Container(
                                                  color: isEven
                                                      ? Colors.white
                                                      : const Color(0xFFF8F9FA),
                                                  child: Table(
                                                    defaultVerticalAlignment:
                                                        TableCellVerticalAlignment.middle,
                                                    columnWidths: _colWidths,
                                                    border: _tableBorder,
                                                    children: [
                                                      TableRow(children: [
                                                        _buildDataCell('${index + 1}',
                                                            align: TextAlign.center),
                                                        _buildClaimNoCell(item['claimNo'] ?? ''),
                                                        _buildDataCell(item['claimType'] ?? ''),
                                                        _buildDataCell(item['purpose'] ?? ''),
                                                        _buildDataCell(item['employeeName'] ?? '-'),
                                                        _buildDataCell(item['date'] ?? '-'),
                                                        _buildAmountCell(item['amount'] ?? '0.00'),
                                                        _buildApprovalCell(
                                                          status: item['reportingStatus'] ?? 'Pending',
                                                          canSee: item['canSeeReporting'] ?? true,
                                                          isUser: item['isReportingUser'] ?? false,
                                                        ),
                                                        _buildReasonCell(item['reportingStatus'] ?? ''),
                                                        _buildApprovalCell(
                                                          status: item['managementStatus'] ?? 'Pending',
                                                          canSee: item['canSeeManagement'] ?? true,
                                                          isUser: item['isManagementUser'] ?? false,
                                                        ),
                                                        _buildReasonCell(item['managementStatus'] ?? ''),
                                                        _buildApprovalCell(
                                                          status: item['accountsStatus'] ?? 'Pending',
                                                          canSee: item['canSeeAccounts'] ?? true,
                                                          isUser: item['isAccountsUser'] ?? false,
                                                        ),
                                                        _buildReasonCell(item['accountsStatus'] ?? ''),
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
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Showing ${filteredClaims.length} of ${allClaims.length} records',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
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

  // ── Filter Bar — 2 rows, 2 fields each ────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Claim Type + Claim No ─────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel('CLAIM TYPE'),
                    const SizedBox(height: 5),
                    _buildDropdown(
                      value: selectedClaimType,
                      items: _claimTypes,
                      onChanged: (v) => setState(() => selectedClaimType = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel('CLAIM NO'),
                    const SizedBox(height: 5),
                    _buildTextField(
                      controller: _claimNoController,
                      hint: 'e.g. TA/22012026/1',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Row 2: Purpose + Status + buttons ───────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel('PURPOSE'),
                    const SizedBox(height: 5),
                    _buildTextField(
                      controller: _purposeController,
                      hint: 'Search purpose...',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel('STATUS'),
                    const SizedBox(height: 5),
                    _buildDropdown(
                      value: selectedStatus,
                      items: _statusOptions,
                      onChanged: (v) => setState(() => selectedStatus = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Buttons aligned to bottom of row 2
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      child: const Text('Search',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _resetFilters,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Reset', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
      ),
    );
  }

  // ── Table Header ──────────────────────────────────────────────────────────
  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: _colWidths,
        border: TableBorder(
          verticalInside: BorderSide(color: Colors.grey.shade300, width: 0.5),
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        children: [
          TableRow(children: [
            _buildHeaderCell('Sr. No ↕'),
            _buildHeaderCell('Claim No ↕'),
            _buildHeaderCell('Claim Type'),
            _buildHeaderCell('Purpose'),
            _buildHeaderCell('Employee Name(Dep)'),
            _buildHeaderCell('Date'),
            _buildHeaderCell('Amount'),
            _buildHeaderCell('Reporting Person'),
            _buildHeaderCell('Reporting Reason'),
            _buildHeaderCell('By Management'),
            _buildHeaderCell('Management Reason'),
            _buildHeaderCell('Admin / Accounts'),
            _buildHeaderCell('Admin / Accounts Reason'),
          ]),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Color(0xFF2C3E50),
        ),
      ),
    );
  }

  // ── Data Cells ────────────────────────────────────────────────────────────
  Widget _buildDataCell(String text, {TextAlign align = TextAlign.left}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment:
          align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildClaimNoCell(String claimNo) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        claimNo,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1565C0),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAmountCell(String amount) {
    String display;
    try {
      final val = double.parse(amount);
      display = '₹${val.toStringAsFixed(2)}';
    } catch (_) {
      display = amount;
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        display,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF2E7D32),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildApprovalCell({
    required String status,
    required bool canSee,
    required bool isUser,
  }) {
    if (!canSee) return _buildNACell();

    Color color;
    switch (status.toLowerCase()) {
      case 'approve':
      case 'approved':
      case 'accepted':
        color = const Color(0xFF2E7D32);
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'reject':
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    final displayStatus = status == 'Approve' ? 'Approved' : status;

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: Alignment.centerLeft,
      child: status.toLowerCase() == 'pending' && isUser
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Approve',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]),
                ],
              ),
            )
          : Text(
              displayStatus.isEmpty ? '-' : displayStatus,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildReasonCell(String status) {
    final isApproved = status.toLowerCase() == 'approve' ||
        status.toLowerCase() == 'approved' ||
        status.toLowerCase() == 'accepted';
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        isApproved ? 'NA' : '--Select--',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildNACell() {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text('NA', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
    );
  }
}
