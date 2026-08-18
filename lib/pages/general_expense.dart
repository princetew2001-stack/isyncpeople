import 'package:flutter/material.dart';
import '../utils/general_expense_api.dart';
import '../utils/permission_service.dart';

class GeneralExpensePage extends StatefulWidget {
  const GeneralExpensePage({super.key});

  @override
  State<GeneralExpensePage> createState() => _GeneralExpensePageState();
}

class _GeneralExpensePageState extends State<GeneralExpensePage> {
  final GeneralExpenseApiService _apiService = GeneralExpenseApiService();
  final PermissionService _permissionService = PermissionService();
  final ScrollController _horizontalScrollController = ScrollController();

  bool _canWrite = false;
  bool isLoading = false;
  String searchQuery = '';

  List<Map<String, dynamic>> expenseData = [];
  List<Map<String, dynamic>> filteredData = [];

  // ── Column widths ─────────────────────────────────────────────────────────
  static const Map<int, TableColumnWidth> _colWidths = {
    0: FixedColumnWidth(60),  // SR. NO
    1: FixedColumnWidth(140), // CLAIM NO
    2: FixedColumnWidth(110), // CLAIM DATE
    3: FixedColumnWidth(250), // EMPLOYEE NAME(PAYCODE)
    4: FixedColumnWidth(160), // EMPLOYEE DEP(DES)
    5: FixedColumnWidth(120), // PURPOSE
    6: FixedColumnWidth(130), // TOTAL AMOUNT
    7: FixedColumnWidth(100), // STATUS
    8: FixedColumnWidth(120), // APPROVED DATE
    9: FixedColumnWidth(140), // APPROVED BY
  };

  static final TableBorder _tableBorder = TableBorder(
    verticalInside: BorderSide(color: Colors.grey.shade300, width: 0.5),
    horizontalInside: BorderSide(color: Colors.grey.shade200, width: 0.5),
  );

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fetchData();
  }

  Future<void> _loadPermissions() async {
    final canWrite = await _permissionService.canWrite('General Expense');
    if (mounted) {
      setState(() => _canWrite = canWrite);
    }
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final data = await _apiService.fetchGeneralExpenses();
      if (mounted) {
        setState(() {
          expenseData = data;
          filteredData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load general expenses: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterData(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredData = expenseData;
      } else {
        filteredData = expenseData.where((item) {
          return item.values.any((v) =>
              v.toString().toLowerCase().contains(query.toLowerCase()));
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('General Expense History'),
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
            onPressed: isLoading ? null : _fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Loading general expenses...',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _horizontalScrollController,
                        child: SizedBox(
                          width: 60 + 140 + 110 + 250 + 160 + 120 + 130 + 100 + 120 + 140.0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Container(
                                color: Colors.blue[100],
                                child: Table(
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  columnWidths: _colWidths,
                                  border: TableBorder(
                                    verticalInside: BorderSide(
                                        color: Colors.grey.shade400,
                                        width: 0.5),
                                  ),
                                  children: [
                                    TableRow(children: [
                                      _buildHeaderCell('SR. NO'),
                                      _buildHeaderCell('CLAIM NO'),
                                      _buildHeaderCell('CLAIM DATE'),
                                      _buildHeaderCell('EMPLOYEE NAME(PAYCODE)'),
                                      _buildHeaderCell('EMPLOYEE DEP(DES)'),
                                      _buildHeaderCell('PURPOSE'),
                                      _buildHeaderCell('TOTAL AMOUNT (₹)'),
                                      _buildHeaderCell('STATUS'),
                                      _buildHeaderCell('APPROVED DATE'),
                                      _buildHeaderCell('APPROVED BY'),
                                    ]),
                                  ],
                                ),
                              ),
                              // Body
                              if (expenseData.isEmpty && !isLoading)
                                const Padding(
                                  padding: EdgeInsets.only(top: 48),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.inbox_outlined,
                                            size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text(
                                          'No general expenses found',
                                          style: TextStyle(
                                              fontSize: 16, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredData.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredData[index];
                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey[200]!),
                                        ),
                                      ),
                                      child: Table(
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        columnWidths: _colWidths,
                                        border: _tableBorder,
                                        children: [
                                          TableRow(children: [
                                            _buildDataCell('${index + 1}',
                                                align: TextAlign.center),
                                            _buildClaimNoCell(
                                                item['claimNo'] ?? ''),
                                            _buildDataCell(
                                                item['claimDate'] ?? ''),
                                            _buildDataCell(
                                                item['employeeName'] ?? ''),
                                            _buildDataCell(
                                                item['department'] ?? ''),
                                            _buildDataCell(
                                                item['purpose'] ?? ''),
                                            _buildAmountCell(
                                                item['totalAmount'] ?? '0.00'),
                                            _buildStatusCell(
                                                item['status'] ?? ''),
                                            _buildDataCell(
                                                item['approvedDate'] ?? '-'),
                                            _buildDataCell(
                                                item['approvedBy'] ?? '-'),
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

            // Pagination overlay
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      'Showing ${expenseData.isEmpty ? 0 : 1}–${expenseData.length} of ${expenseData.length}',
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
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────
  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildDataCell(String text, {TextAlign align = TextAlign.left}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment:
          align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }

  Widget _buildClaimNoCell(String claimNo) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.centerLeft,
      child: Text(
        claimNo,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF1565C0),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAmountCell(String amount) {
    final display =
        amount.isEmpty || amount == '0' ? '-' : '₹ ${_formatAmount(amount)}';
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.centerLeft,
      child: Text(
        display,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF2E7D32),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatAmount(String amount) {
    try {
      final value = double.parse(amount);
      return value.toStringAsFixed(2);
    } catch (_) {
      return amount;
    }
  }

  Widget _buildStatusCell(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'cancelled':
        color = Colors.grey;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.centerLeft,
      child: Text(
        status.isEmpty ? '-' : status,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
}
