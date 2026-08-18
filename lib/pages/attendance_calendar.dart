import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class AttendanceCalendarPage extends StatefulWidget {
  final Map<String, String> attendanceData; // date -> status mapping
  final String? filterStatus; // Optional filter: 'P' for Present, 'A' for Absent, null for all
  final String title; // Title for the page

  const AttendanceCalendarPage({
    super.key,
    required this.attendanceData,
    this.filterStatus,
    this.title = 'Attendance Calendar',
  });

  @override
  State<AttendanceCalendarPage> createState() => _AttendanceCalendarPageState();
}

class _AttendanceCalendarPageState extends State<AttendanceCalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    
    // Debug: Print received attendance data
    debugPrint('📅 Calendar received ${widget.attendanceData.length} days of data');
    debugPrint('📅 Filter status: ${widget.filterStatus}');
    debugPrint('📅 Sample data: ${widget.attendanceData.entries.take(5).map((e) => '${e.key}: ${e.value}').join(', ')}');
  }
  
  // Check if a date should be shown based on filter
  bool _shouldShowDate(String? status) {
    if (widget.filterStatus == null) return true; // Show all if no filter
    if (status == null) return false; // Don't show dates with no data
    
    final statusUpper = status.toUpperCase();
    final filterUpper = widget.filterStatus!.toUpperCase();
    
    // Handle Absent filter - include MS (Miss Punch) as well
    if (filterUpper == 'A') {
      return statusUpper == 'A' || statusUpper == 'MS';
    }
    
    // Handle Present filter - include P, H1 (first half absent), H2 (second half absent)
    if (filterUpper == 'P') {
      return statusUpper == 'P' || statusUpper == 'H1' || statusUpper == 'H2';
    }
    
    // Handle Week Off variations (WO, WO*)
    if (filterUpper == 'WO') {
      return statusUpper == 'WO' || statusUpper == 'WO*';
    }
    
    // Handle Holiday - H or HD (from API)
    if (filterUpper == 'H') {
      return statusUpper == 'H' || statusUpper == 'HD';
    }
    
    return statusUpper == filterUpper;
  }

  // Get status for a specific date
  String? _getStatusForDate(DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final status = widget.attendanceData[dateKey];
    
    // Debug logging for today's date
    if (date.day == DateTime.now().day && date.month == DateTime.now().month) {
      debugPrint('🔍 Looking up status for today ($dateKey): $status');
      debugPrint('🔍 Available dates: ${widget.attendanceData.keys.take(5).join(', ')}');
    }
    
    return status;
  }

  // Get color for status
  Color _getStatusColor(String? status, {bool isFiltered = false, DateTime? date}) {
    if (status == null) return Colors.grey.shade200;
    
    // If filtered and doesn't match, return transparent/grey
    if (isFiltered && !_shouldShowDate(status)) {
      return Colors.grey.shade100;
    }

    // Future dates should never be coloured — always grey regardless of status
    if (date != null) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final checkDate = DateTime(date.year, date.month, date.day);
      if (checkDate.isAfter(today)) {
        return Colors.grey.shade200;
      }
    }
    
    switch (status.toUpperCase()) {
      case 'P':
        return const Color.fromARGB(255, 186, 252, 189); // Full day present - green
      case 'H1': // First half absent
      case 'H2': // Second half absent
        return const Color.fromARGB(255, 151, 194, 213); // Half day - blue
      case 'A':
        return Colors.red.shade100;
      case 'WO':
      case 'WO*':
        return Colors.orange.shade100;
      case 'H': // Full day holiday
      case 'HD': // Holiday (from API)
        return const Color(0xFFD4AF37); // Gold color for holidays
      case 'L':
      case 'CL':
      case 'EL':
      case 'SL':
        return Colors.blue.shade100;
      case 'MS':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  // Get status display text
  String _getStatusText(String? status) {
    if (status == null) return 'No Data';
    
    switch (status.toUpperCase()) {
      case 'P':
        return 'Present';
      case 'H1':
        return 'Half Day (1st Half Absent)';
      case 'H2':
        return 'Half Day (2nd Half Absent)';
      case 'A':
        return 'Absent';
      case 'WO':
      case 'WO*':
        return 'Week Off';
      case 'H':
      case 'HD':
        return 'Holiday';
      case 'L':
        return 'Leave';
      case 'CL':
        return 'Casual Leave';
      case 'EL':
        return 'Earned Leave';
      case 'SL':
        return 'Sick Leave';
      case 'MS':
        return 'Miss Punch';
      default:
        return status;
    }
  }

  // Get filter icon based on status
  IconData _getFilterIcon(String? filterStatus) {
    if (filterStatus == null) return Icons.filter_alt;
    
    switch (filterStatus.toUpperCase()) {
      case 'P':
        return Icons.check_circle;
      case 'A':
        return Icons.cancel;
      case 'WO':
        return Icons.weekend;
      case 'H':
        return Icons.celebration;
      default:
        return Icons.filter_alt;
    }
  }

  // Get filter color based on status
  Color _getFilterColor(String? filterStatus) {
    if (filterStatus == null) return Colors.blue;
    
    switch (filterStatus.toUpperCase()) {
      case 'P':
        return Colors.green;
      case 'A':
        return Colors.red;
      case 'WO':
        return Colors.orange;
      case 'H':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  // Get filter label based on status
  String _getFilterLabel(String? filterStatus) {
    if (filterStatus == null) return 'All';
    
    switch (filterStatus.toUpperCase()) {
      case 'P':
        return 'Present';
      case 'A':
        return 'Absent';
      case 'WO':
        return 'Week Off';
      case 'H':
        return 'Holiday';
      default:
        return filterStatus;
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
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Legend - only show if not filtered
          if (widget.filterStatus == null)
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.cardColor,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildLegendItem('Present (Full Day)', const Color.fromARGB(255, 186, 252, 189)),
                  _buildLegendItem('Present (Half Day)', const Color.fromARGB(255, 151, 194, 213)),
                  _buildLegendItem('Absent', Colors.red.shade100),
                  _buildLegendItem('Week Off', Colors.orange.shade100),
                  _buildLegendItem('Holiday', const Color(0xFFD4AF37)), // Gold color
                  _buildLegendItem('Leave', Colors.blue.shade100),
                  _buildLegendItem('Miss Punch', Colors.red.shade100),
                ],
              ),
            )
          else if (widget.filterStatus == 'P')
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getFilterIcon(widget.filterStatus),
                        color: _getFilterColor(widget.filterStatus),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Showing only ${_getFilterLabel(widget.filterStatus)} days',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getFilterColor(widget.filterStatus),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildLegendItem('Full Day', const Color.fromARGB(255, 186, 252, 189)),
                      _buildLegendItem('Half Day (H1/H2)', const Color.fromARGB(255, 151, 194, 213)),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.cardColor,
              child: Row(
                children: [
                  Icon(
                    _getFilterIcon(widget.filterStatus),
                    color: _getFilterColor(widget.filterStatus),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Showing only ${_getFilterLabel(widget.filterStatus)} days',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getFilterColor(widget.filterStatus),
                    ),
                  ),
                ],
              ),
            ),
          
          // Calendar
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.shade300,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final status = _getStatusForDate(day);
                        final shouldShow = _shouldShowDate(status);
                        final color = _getStatusColor(status, isFiltered: widget.filterStatus != null, date: day);
                        final isHalfDay = status?.toUpperCase() == 'H1' || status?.toUpperCase() == 'H2';
                        
                        // If filtered and doesn't match, show as grey/faded
                        if (widget.filterStatus != null && !shouldShow) {
                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }
                        
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: status != null && shouldShow ? color.withValues(alpha: 0.5) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: status != null && shouldShow ? Colors.black87 : Colors.black54,
                                    fontWeight: status != null && shouldShow ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            // Add marker for half days (H1/H2)
                            if (isHalfDay)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                      todayBuilder: (context, day, focusedDay) {
                        final status = _getStatusForDate(day);
                        final shouldShow = _shouldShowDate(status);
                        final color = _getStatusColor(status, isFiltered: widget.filterStatus != null, date: day);
                        
                        // If filtered and doesn't match, show as grey/faded
                        if (widget.filterStatus != null && !shouldShow) {
                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.blue.shade300,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }
                        
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blue.shade700,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        final status = _getStatusForDate(day);
                        final shouldShow = _shouldShowDate(status);
                        final color = _getStatusColor(status, isFiltered: widget.filterStatus != null, date: day);
                        
                        // If filtered and doesn't match, show as grey/faded
                        if (widget.filterStatus != null && !shouldShow) {
                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.shade400,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }
                        
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4CAF50),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Selected day details
                  if (_selectedDay != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDay!),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_getStatusForDate(_selectedDay!), date: _selectedDay),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Status',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getStatusText(_getStatusForDate(_selectedDay!)),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
