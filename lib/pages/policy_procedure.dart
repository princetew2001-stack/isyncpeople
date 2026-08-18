import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../utils/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class PolicyItem {
  final int id;
  final String title;
  final String description;
  final String department;
  final int order;
  final String unitName;
  final bool isActive;
  final bool isPdf;
  final String contentType;
  final String attachmentUrl;
  final String attachmentFileUrl;

  const PolicyItem({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.order,
    required this.unitName,
    required this.isActive,
    required this.isPdf,
    required this.contentType,
    required this.attachmentUrl,
    required this.attachmentFileUrl,
  });

  factory PolicyItem.fromJson(Map<String, dynamic> json) {
    return PolicyItem(
      id: json['id'] as int,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      order: json['order'] as int? ?? 0,
      unitName: json['unit_name']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? false,
      isPdf: json['is_pdf'] as bool? ?? false,
      contentType: json['content_type']?.toString() ?? '',
      attachmentUrl: json['attachment_url']?.toString() ?? '',
      attachmentFileUrl: json['attachment_file_url']?.toString() ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Policy & Procedure Page
// ─────────────────────────────────────────────────────────────────────────────

class PolicyProcedurePage extends StatefulWidget {
  const PolicyProcedurePage({super.key});

  @override
  State<PolicyProcedurePage> createState() => _PolicyProcedurePageState();
}

class _PolicyProcedurePageState extends State<PolicyProcedurePage> {
  final AuthService _authService = AuthService();

  List<PolicyItem> _policies = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Cached local file paths: policy id → file path
  final Map<int, String> _cachedPdfPaths = {};
  // Which tiles are currently downloading
  final Map<int, bool> _downloading = {};

  static const _tileColor = Color(0xFF00BCD4);

  @override
  void initState() {
    super.initState();
    _fetchPolicies();
  }

  Future<void> _fetchPolicies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const endpoint = '/policy_procedure/view/?json=1';
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = data['policies'] as List<dynamic>? ?? [];
        final items = rawList
            .map((e) => PolicyItem.fromJson(e as Map<String, dynamic>))
            .where((p) => p.isActive)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        setState(() {
          _policies = items;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load policies (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching policies: $e');
      setState(() {
        _errorMessage = 'Unable to load policies. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  /// Download PDF to temp dir (if not cached), then open with device PDF viewer.
  Future<void> _openPolicy(PolicyItem policy) async {
    // Already cached — open directly
    if (_cachedPdfPaths.containsKey(policy.id)) {
      await OpenFile.open(_cachedPdfPaths[policy.id]!);
      return;
    }

    setState(() => _downloading[policy.id] = true);

    try {
      debugPrint('⬇️ Downloading PDF: ${policy.attachmentFileUrl}');

      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse(policy.attachmentFileUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        // Sanitise title for filename
        final safeName = policy.title
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '_');
        final file = File('${dir.path}/policy_${policy.id}_$safeName.pdf');
        await file.writeAsBytes(response.bodyBytes);

        _cachedPdfPaths[policy.id] = file.path;
        debugPrint('✅ PDF saved: ${file.path}');

        if (mounted) {
          setState(() => _downloading.remove(policy.id));
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open PDF: ${result.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        debugPrint('❌ Download failed: ${response.statusCode}');
        if (mounted) {
          setState(() => _downloading.remove(policy.id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Could not download "${policy.title}" (${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error downloading PDF: $e');
      if (mounted) {
        setState(() => _downloading.remove(policy.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Policy & Procedure',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _tileColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchPolicies,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _tileColor),
            SizedBox(height: 16),
            Text('Loading policies...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchPolicies,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tileColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_policies.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.policy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No policies available',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _policies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _buildPolicyTile(_policies[index]),
    );
  }

  Widget _buildPolicyTile(PolicyItem policy) {
    final isDownloading = _downloading[policy.id] == true;

    return GestureDetector(
      onTap: () => _openPolicy(policy),
      child: Container(
        decoration: BoxDecoration(
          color: _tileColor,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Hamburger icon — matches screenshot
            const Icon(Icons.menu, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                policy.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isDownloading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              const Icon(Icons.expand_more, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
