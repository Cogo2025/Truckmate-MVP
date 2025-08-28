import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/owner/owner_main_navigation.dart';
import 'detail_my_post.dart';

class MyPostedJobsPage extends StatefulWidget {
  const MyPostedJobsPage({super.key});

  @override
  State<MyPostedJobsPage> createState() => _MyPostedJobsPageState();
}

class _MyPostedJobsPageState extends State<MyPostedJobsPage>
    with TickerProviderStateMixin {
  bool isLoading = true;
  List jobPosts = [];
  List filteredJobs = [];
  String? errorMessage;
  String searchQuery = '';

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  late AnimationController _refreshController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _fabAnimationController.forward();
    _searchController.addListener(_onSearchChanged);
    fetchJobs();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _fabAnimationController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _filterJobs);
  }

  void _filterJobs() {
    setState(() {
      filteredJobs =
          jobPosts.where((job) {
            final source =
                job['sourceLocation']?.toString().toLowerCase() ?? '';
            return source.contains(_searchController.text.toLowerCase());
          }).toList();
      searchQuery = _searchController.text;
    });
  }

  Future<void> fetchJobs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = "Authentication required.";
      });
      return;
    }

    try {
      _refreshController.repeat();
      final response = await http.get(
        Uri.parse(ApiConfig.jobs),
        headers: {"Authorization": "Bearer $token"},
      );
      _refreshController.stop();

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          jobPosts = data;
          filteredJobs = data;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to load jobs: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load jobs: $e";
        isLoading = false;
      });
      _refreshController.stop();
    }
  }

  void _navigateToCreateJob() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const OwnerMainNavigation(initialTabIndex: 2),
      ),
    ).then((_) => fetchJobs());
  }

  void _navigateToEditJob(Map job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailPage(isEditMode: true, job: job),
      ),
    ).then((_) => fetchJobs());
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatSalary(Map? salaryRange) {
    if (salaryRange == null) return "N/A";
    final min = salaryRange['min']?.toString() ?? "";
    final max = salaryRange['max']?.toString() ?? "";
    if (min.isEmpty && max.isEmpty) return "N/A";
    if (min.isEmpty) return "₹$max";
    if (max.isEmpty) return "₹$min";
    return "₹$min - ₹$max";
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "N/A";
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date).inDays;
      if (diff == 0) return "Today";
      if (diff == 1) return "Yesterday";
      if (diff < 7) return "$diff days ago";
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return dateStr.substring(0, 10);
    }
  }

  Widget _buildJobCard(Map job) {
    final destination = job['destinationLocation'];
    final showDestination =
        destination != null &&
        destination.isNotEmpty &&
        destination != 'Destination not specified';
    final status = job['status'];
    final showStatus =
        status != null &&
        status.isNotEmpty &&
        status.toLowerCase() != 'pending';

    String? imageUrl;
    if (job['lorryPhotos'] != null && job['lorryPhotos'].isNotEmpty) {
      imageUrl = job['lorryPhotos'][0];
      // Ensure URL has proper protocol if coming from Cloudinary
      if (imageUrl != null && !imageUrl.startsWith('http')) {
        imageUrl = 'https://${imageUrl.replaceAll('//', '/')}';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToEditJob(job),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job['sourceLocation'] ?? 'Location not available',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (showDestination)
                              Text(
                                "→ $destination",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (showStatus)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getStatusColor(status).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            status.toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 80,
                          height: 80,
                          child:
                              imageUrl != null
                                  ? FadeInImage.assetNetwork(
                                    placeholder:
                                        'assets/images/placeholder_truck.png',
                                    image: imageUrl,
                                    fit: BoxFit.cover,
                                    imageErrorBuilder:
                                        (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => Image.asset(
                                          'assets/images/placeholder_truck.png',
                                          fit: BoxFit.cover,
                                        ),
                                  )
                                  : Image.asset(
                                    'assets/images/placeholder_truck.png',
                                    fit: BoxFit.cover,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow(
                              Icons.local_shipping,
                              "Truck Type",
                              job['truckType'] ?? "N/A",
                            ),
                            const SizedBox(height: 8),
                            _infoRow(
                              Icons.currency_rupee,
                              "Salary",
                              _formatSalary(job['salaryRange']),
                            ),
                            const SizedBox(height: 8),
                            _infoRow(
                              Icons.calendar_today,
                              "Posted",
                              _formatDate(job['createdAt']),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: Colors.blue,
                        onPressed: () => _navigateToEditJob(job),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red,
                        onPressed: () => _deleteJobConfirmation(job),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          "$label:",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _deleteJobConfirmation(Map job) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: const [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text("Delete Job"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Are you sure you want to delete this job at ${job['sourceLocation'] ?? 'N/A'}?",
                ),
                const SizedBox(height: 12),
                const Text(
                  "This action cannot be undone.",
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Delete"),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _deleteJob(job['_id']);
    }
  }

  Future<void> _deleteJob(String jobId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    Navigator.pop(context); // remove loader if token missing

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Missing auth token")));
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse("${ApiConfig.jobs}/$jobId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Job deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
        fetchJobs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting job: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting job: $e")));
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.work_off_outlined,
              size: 64,
              color: Colors.blue.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              "No Jobs Found",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isEmpty
                  ? "Start by posting your first job."
                  : "No jobs match your search.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed:
                  searchQuery.isEmpty
                      ? _navigateToCreateJob
                      : () {
                        _searchController.clear();
                        _filterJobs();
                      },
              icon: Icon(searchQuery.isEmpty ? Icons.add : Icons.clear),
              label: Text(
                searchQuery.isEmpty ? "Post Your First Job" : "Clear Search",
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Column(
          children: [
            const Text(
              "My Posted Jobs",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!isLoading && filteredJobs.isNotEmpty)
              Text(
                "${filteredJobs.length} job${filteredJobs.length != 1 ? 's' : ''}",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_refreshController),
              child: const Icon(Icons.refresh),
            ),
            onPressed: isLoading ? null : fetchJobs,
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton.extended(
          onPressed: _navigateToCreateJob,
          icon: const Icon(Icons.add),
          label: const Text("Post New Job"),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 8,
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search jobs by location",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child:
                        filteredJobs.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                              onRefresh: fetchJobs,
                              child: ListView.builder(
                                itemCount: filteredJobs.length,
                                itemBuilder:
                                    (context, index) =>
                                        _buildJobCard(filteredJobs[index]),
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}
