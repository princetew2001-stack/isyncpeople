import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../utils/leave_application_api.dart';
import '../utils/auth_service.dart';

class LeaveApplicationPage extends StatefulWidget {
  final bool autoOpenAddForm;
  
  const LeaveApplicationPage({
    super.key,
    this.autoOpenAddForm = false,
  });

  @override
  State<LeaveApplicationPage> createState() => _LeaveApplicationPageState();
}

class _LeaveApplicationPageState extends State<LeaveApplicationPage> {
  String searchQuery = '';
  bool isLoading = false;
  bool showAddForm = false; // For showing/hiding the add form
  final ScrollController _horizontalScrollController = ScrollController();
  final LeaveApplicationApiService _apiService = LeaveApplicationApiService();

  // Sample data for the table - will be replaced with API data
  List<Map<String, String>> leaveApplicationData = [];
  List<Map<String, String>> filteredLeaveApplicationData = []; // For search results

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
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  // Form dropdown values
  String selectedApplicationType = 'Leave';
  String selectedLeaveType = 'Casual Leave';
  String selectedDayCount = 'Full Day';
  String selectedLocation = 'HO';
  String selectedReportingManager = '';
  List<String> availableReportingManagers = []; // Dynamic list
  List<String> availableLocations = ['HO', 'Unit-1', 'Branch Office', 'Remote']; // Dynamic list
  DateTime? selectedFromDate;
  DateTime? selectedToDate;
  
  // File attachment variables
  PlatformFile? selectedFile;
  String? selectedFileName;

  @override
  void initState() {
    super.initState();
    _fetchLeaveApplicationData();
    
    // Auto-open add form if requested
    if (widget.autoOpenAddForm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          showAddForm = true;
        });
        _loadEmployeeData();
      });
    }
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
    _mobileNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaveApplicationData() async {
    setState(() {
      isLoading = true;
    });

    try {
      debugPrint('🔄 Fetching leave applications...');
      final List<Map<String, dynamic>> apiData = await _apiService.fetchLeaveApplications();
      
      // Convert dynamic data to String data for the table
      final List<Map<String, String>> convertedData = apiData.map((item) {
        return {
          'id': item['id']?.toString() ?? '', // Store ID for cancellation
          'applicationType': item['applicationType']?.toString() ?? '',
          'leaveType': item['leaveType']?.toString() ?? '',
          'fromDate': item['fromDate']?.toString() ?? '',
          'toDate': item['toDate']?.toString() ?? '',
          'dayPart': item['dayPart']?.toString() ?? '',
          'dayCount': item['dayCount']?.toString() ?? '',
          'applicationStatus': item['applicationStatus']?.toString() ?? '',
          'reason': item['reason']?.toString() ?? '',
          'appliedOn': item['appliedOn']?.toString() ?? '',
          'approvedRejectedOn': item['approvedRejectedOn']?.toString() ?? '',
          'cancelledOn': item['cancelledOn']?.toString() ?? '',
          'approvedRejectedBy': item['approvedRejectedBy']?.toString() ?? '',
          'remarks': item['remarks']?.toString() ?? '',
          'attachment': item['attachment']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        leaveApplicationData = convertedData;
        filteredLeaveApplicationData = convertedData; // Initialize filtered data
        isLoading = false;
      });

      debugPrint('✅ Successfully loaded ${convertedData.length} leave applications');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${convertedData.length} leave applications'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint(' Error fetching leave application data: $e');
      
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
        title: const Text('Leave Application Form'),
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
            onPressed: isLoading ? null : _fetchLeaveApplicationData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top controls row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
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
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: SingleChildScrollView(
                  child: _buildAddNewForm(),
                ),
              ),
            ),

          // Table — takes all remaining space
          if (!showAddForm)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
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
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                width: 1720,
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
                            6: FixedColumnWidth(100),
                            7: FixedColumnWidth(0.5), // Divider
                            8: FixedColumnWidth(100),
                            9: FixedColumnWidth(0.5), // Divider
                            10: FixedColumnWidth(80),
                            11: FixedColumnWidth(0.5), // Divider
                            12: FixedColumnWidth(100),
                            13: FixedColumnWidth(0.5), // Divider
                            14: FixedColumnWidth(120),
                            15: FixedColumnWidth(0.5), // Divider
                            16: FixedColumnWidth(150),
                            17: FixedColumnWidth(0.5), // Divider
                            18: FixedColumnWidth(100),
                            19: FixedColumnWidth(0.5), // Divider
                            20: FixedColumnWidth(140),
                            21: FixedColumnWidth(0.5), // Divider
                            22: FixedColumnWidth(100),
                            23: FixedColumnWidth(0.5), // Divider
                            24: FixedColumnWidth(140),
                            25: FixedColumnWidth(0.5), // Divider
                            26: FixedColumnWidth(150),
                            27: FixedColumnWidth(0.5), // Divider
                            28: FixedColumnWidth(140),
                          },
                            children: [
                              TableRow(
                                children: [
                                  _buildHeaderCell('Cancel'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Application Type'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Leave Type'),
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
                                  _buildHeaderCell('Approved/Rejected On'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Cancelled On'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Approved/Rejected By'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Remarks'),
                                  _buildDividerCell(),
                                  _buildHeaderCell('Attachment'),
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
                                        'Loading leave applications...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : leaveApplicationData.isEmpty
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
                                            'No leave applications found',
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
                                  : filteredLeaveApplicationData.isEmpty
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
                                      itemCount: filteredLeaveApplicationData.length,
                                      itemBuilder: (context, index) {
                                        final data = filteredLeaveApplicationData[index];
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
                                              6: FixedColumnWidth(100),
                                              7: FixedColumnWidth(0.5), // Divider
                                              8: FixedColumnWidth(100),
                                              9: FixedColumnWidth(0.5), // Divider
                                              10: FixedColumnWidth(80),
                                              11: FixedColumnWidth(0.5), // Divider
                                              12: FixedColumnWidth(100),
                                              13: FixedColumnWidth(0.5), // Divider
                                              14: FixedColumnWidth(120),
                                              15: FixedColumnWidth(0.5), // Divider
                                              16: FixedColumnWidth(150),
                                              17: FixedColumnWidth(0.5), // Divider
                                              18: FixedColumnWidth(100),
                                              19: FixedColumnWidth(0.5), // Divider
                                              20: FixedColumnWidth(140),
                                              21: FixedColumnWidth(0.5), // Divider
                                              22: FixedColumnWidth(100),
                                              23: FixedColumnWidth(0.5), // Divider
                                              24: FixedColumnWidth(140),
                                              25: FixedColumnWidth(0.5), // Divider
                                              26: FixedColumnWidth(150),
                                              27: FixedColumnWidth(0.5), // Divider
                                              28: FixedColumnWidth(140),
                                            },
                                            children: [
                                              TableRow(
                                                children: [
                                                  _buildCancelCell(data['id'] ?? '', data['applicationStatus'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['applicationType'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['leaveType'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['fromDate'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['toDate'] ?? ''),
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
                                                  _buildDataCell(data['approvedRejectedOn'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['cancelledOn'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['approvedRejectedBy'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildDataCell(data['remarks'] ?? ''),
                                                  _buildDividerCell(),
                                                  _buildAttachmentViewCell(data['attachment'] ?? ''),
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
                            ), // SizedBox(width:1720)
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
                                ? 'Showing ${leaveApplicationData.isEmpty ? 0 : 1}–${leaveApplicationData.length} of ${leaveApplicationData.length}'
                                : '${filteredLeaveApplicationData.length} of ${leaveApplicationData.length}',
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataCell(String text) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          status,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
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

  Widget _buildAttachmentViewCell(String attachment) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.center,
      child: attachment.isNotEmpty 
          ? ElevatedButton(
              onPressed: () => _downloadAndOpenAttachment(attachment),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 32),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : const Text(
              'No file',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
    );
  }

  /// Download and open attachment file
  Future<void> _downloadAndOpenAttachment(String attachmentPath) async {
    try {
      debugPrint('🔄 Downloading attachment: $attachmentPath');
      
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

      // Get auth service for authenticated download
      final authService = AuthService();
      
      // Construct full URL for the attachment
      final attachmentUrl = '${authService.baseUrl}/media/$attachmentPath';
      debugPrint('🔗 Attachment URL: $attachmentUrl');
      
      // Get authentication headers
      final headers = await authService.getAuthHeaders();
      
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
                content: Text('File opened successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          debugPrint('⚠️ Could not open file: ${result.message}');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File downloaded but could not open: ${result.message}'),
                backgroundColor: Colors.orange,
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
              content: Text('Failed to download file (${response.statusCode})'),
              backgroundColor: Colors.red,
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
            content: Text('Error downloading file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
            'Add New Leave Application',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // First Row: Employee Pay Code, Employee Name
          Row(
            children: [
              Expanded(child: _buildFormField('Employee Pay Code *', _empCodeController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Employee Name *', _empNameController, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Second Row: Location, Department
          Row(
            children: [
              Expanded(child: _buildDropdownField('Location', selectedLocation, availableLocations, (value) {
                setState(() {
                  selectedLocation = value!;
                });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Department *', _departmentController, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Third Row: Reporting Manager, Application Type
          Row(
            children: [
              Expanded(child: _buildDropdownField('Reporting Manager', selectedReportingManager, availableReportingManagers, (value) {
                setState(() {
                  selectedReportingManager = value!;
                });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdownField('Application Type *', selectedApplicationType, ['Leave'], (value) {
                setState(() {
                  selectedApplicationType = value!;
                });
              })),
            ],
          ),
          const SizedBox(height: 16),
          
          // Fourth Row: Leave From, Leave Till
          Row(
            children: [
              Expanded(child: _buildDateField('Leave From *', selectedFromDate, (date) {
                setState(() {
                  selectedFromDate = date;
                });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildDateField('Leave Till *', selectedToDate, (date) {
                setState(() {
                  selectedToDate = date;
                });
              })),
            ],
          ),
          const SizedBox(height: 16),
          
          // Fifth Row: Day Count, Mobile Number
          Row(
            children: [
              Expanded(child: _buildDropdownField('Full Day/Half Day (Day Count) *', selectedDayCount, [
                'Full Day',
                'Half Day - Morning',
                'Half Day - Evening'
              ], (value) {
                setState(() {
                  selectedDayCount = value!;
                });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildFormField('Mobile Number *', _mobileNumberController, hintText: 'Enter mobile number')),
            ],
          ),
          const SizedBox(height: 16),
          
          // Sixth Row: Address During Day Period, Leave Type
          Row(
            children: [
              Expanded(child: _buildFormField('Address During Day Period *', _addressController, hintText: 'Enter address')),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdownField('Leave Type *', selectedLeaveType, [
                'Casual Leave',
                'Sick Leave', 
                'Earned Leave',
                'Maternity Leave',
                'Paternity Leave'
              ], (value) {
                setState(() {
                  selectedLeaveType = value!;
                });
              })),
            ],
          ),
          const SizedBox(height: 16),
          
          // Seventh Row: Reason For Leave, Attachment
          Row(
            children: [
              Expanded(child: _buildFormField('Reason For Leave *', _reasonController, hintText: 'Enter reason for leave')),
              const SizedBox(width: 12),
              Expanded(child: _buildAttachmentField()),
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

  Widget _buildAttachmentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachment',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedFileName ?? 'No file selected.',
                  style: TextStyle(
                    fontSize: 14,
                    color: selectedFileName != null ? Colors.black : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _pickFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Choose File',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (selectedFile != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearFile,
                  icon: const Icon(Icons.close, size: 16),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red,
                    minimumSize: const Size(32, 32),
                  ),
                  tooltip: 'Remove file',
                ),
              ],
            ],
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
              firstDate: DateTime(2020),
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
        _empNameController.text.isEmpty ||
        _departmentController.text.isEmpty ||
        selectedFromDate == null ||
        selectedToDate == null ||
        _reasonController.text.isEmpty ||
        _mobileNumberController.text.isEmpty ||
        _addressController.text.isEmpty) {
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
      
      
      final formattedFromDate = '${selectedFromDate!.year}-${selectedFromDate!.month.toString().padLeft(2, '0')}-${selectedFromDate!.day.toString().padLeft(2, '0')}';
      final formattedToDate = '${selectedToDate!.year}-${selectedToDate!.month.toString().padLeft(2, '0')}-${selectedToDate!.day.toString().padLeft(2, '0')}';
      
      // day count
      final dayCount = selectedToDate!.difference(selectedFromDate!).inDays + 1;
      
      debugPrint('📝 Submitting leave application:');
      debugPrint('   Employee Code: ${_empCodeController.text}');
      debugPrint('   Employee Name: ${_empNameController.text}');
      debugPrint('   Department: ${_departmentController.text}');
      debugPrint('   Leave Type: $selectedLeaveType');
      debugPrint('   From Date: $formattedFromDate');
      debugPrint('   To Date: $formattedToDate');
      debugPrint('   Day Count: $dayCount');
      debugPrint('   Mobile Number: ${_mobileNumberController.text}');
      debugPrint('   Address: ${_addressController.text}');
      debugPrint('   Reason: ${_reasonController.text}');
      debugPrint('   Attachment: ${selectedFile?.name ?? 'None'}');

      // Map day count selection to proper day part value
      String dayPart;
      switch (selectedDayCount) {
        case 'Full Day':
          dayPart = 'FD';
          break;
        case 'Half Day - Morning':
          dayPart = 'HDM';
          break;
        case 'Half Day - Evening':
          dayPart = 'HDE';
          break;
        default:
          dayPart = 'FD'; // Default to full day
      }

      // Submitting the data
      final success = await _apiService.submitLeaveApplication(
        leaveType: selectedLeaveType,
        fromDate: formattedFromDate,
        tillDate: formattedToDate,
        dayPart: dayPart,
        reason: _reasonController.text,
        phone: _mobileNumberController.text,
        address: _addressController.text,
        department: _departmentController.text,
        attachment: selectedFile?.path, // Pass the file path if available
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (success) {
        debugPrint('✅ Leave application submitted successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave application submitted successfully!'),
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
        _fetchLeaveApplicationData();
      } else {
        debugPrint('⚠️ Leave application submission failed');
        
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
      debugPrint('❌ Error submitting leave application: $e');
      
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
      selectedToDate = null;
      selectedLeaveType = 'Casual Leave';
      selectedDayCount = 'Full Day';
      _reasonController.clear();
      _mobileNumberController.clear();
      _addressController.clear();
      
      // Clear file selection
      selectedFile = null;
      selectedFileName = null;
      
      // Don't clear employee data fields as they should remain pre-filled
      // _empCodeController.clear();
      // _empNameController.clear();
      // _departmentController.clear();
      // selectedLocation = 'HO';
      // selectedReportingManager = '';
    });
  }

  /// Pick a file from device storage
  Future<void> _pickFile() async {
    try {
      debugPrint('🔄 Opening file picker...');
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Check file size (limit to 5MB)
        if (file.size > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File size must be less than 5MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        setState(() {
          selectedFile = file;
          selectedFileName = file.name;
        });
        
        debugPrint('✅ File selected: ${file.name} (${(file.size / 1024).toStringAsFixed(1)} KB)');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File selected: ${file.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('⚠️ No file selected');
      }
    } catch (e) {
      debugPrint('❌ Error picking file: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Clear the selected file
  void _clearFile() {
    setState(() {
      selectedFile = null;
      selectedFileName = null;
    });
    
    debugPrint('🗑️ File selection cleared');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File removed'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showCancelDialog(String applicationId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Application'),
          content: const Text('Are you sure you want to cancel this leave application?'),
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
      
      final success = await _apiService.cancelLeaveApplication(applicationId);
      
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
        _fetchLeaveApplicationData();
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
        filteredLeaveApplicationData = leaveApplicationData;
      } else {
        filteredLeaveApplicationData = leaveApplicationData.where((item) {
          // Search in all fields
          return item.values.any((value) => 
            value.toLowerCase().contains(query.toLowerCase())
          );
        }).toList();
      }
    });
    
    debugPrint('🔍 Search query: "$query"');
    debugPrint('📊 Filtered results: ${filteredLeaveApplicationData.length} out of ${leaveApplicationData.length}');
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
          location = employeeData['loc_name'] ?? 'HO';
          department = employeeData['dep_name'] ?? '';
          reportingManager = employeeData['reporting_manager_name'] ?? '';
          
          // Pre-fill the form controllers
          _empCodeController.text = empCode;
          _empNameController.text = empName;
          _locationController.text = location;
          _departmentController.text = department;
          _reportingManagerController.text = reportingManager;
          
          // Set dropdown values and update available options
          selectedLocation = location.isNotEmpty ? location : 'HO';
          selectedReportingManager = reportingManager.isNotEmpty ? reportingManager : '';
          
          // Update available reporting managers list to include the actual manager
          if (reportingManager.isNotEmpty && !availableReportingManagers.contains(reportingManager)) {
            availableReportingManagers = [reportingManager];
          } else if (reportingManager.isNotEmpty) {
            availableReportingManagers = [reportingManager];
          }
          
          // Update available locations list to include the actual location
          if (location.isNotEmpty && !availableLocations.contains(location)) {
            availableLocations = [location, 'HO', 'Unit-1', 'Branch Office', 'Remote'];
          }
        });
        
        debugPrint('✅ Employee data loaded and form pre-filled successfully');
        debugPrint('👤 Employee: $empName ($empCode)');
        debugPrint('🏢 Department: $department');
        debugPrint('📍 Location: $location');
        debugPrint('👨‍💼 Reporting Manager: $reportingManager');
        
        // Show success message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee data loaded successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
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
      
      // Initialize session for new leave application (get fresh CSRF token)
      debugPrint('🔄 Initializing session for new leave application...');
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