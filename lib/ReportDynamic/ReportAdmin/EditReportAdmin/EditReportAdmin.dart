import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qualityapproach/ReportUtils/subtleloader.dart';
import '../../../ReportUtils/Appbar.dart';
import '../../ReportAPIService.dart';
import 'EditDetailAdmin.dart';

class EditReportAdmin extends StatefulWidget {
  const EditReportAdmin({super.key});

  @override
  _EditReportAdminState createState() => _EditReportAdminState();
}

class _EditReportAdminState extends State<EditReportAdmin> {
  final ReportAPIService _apiService = ReportAPIService();
  List<Map<String, dynamic>> _apiData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchApis();
  }

  Future<void> _fetchApis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final apiNames = await _apiService.getAvailableApis();
      List<Map<String, dynamic>> data = [];
      for (var apiName in apiNames) {
        final details = await _apiService.getApiDetails(apiName);
        data.add({
          'APIName': apiName,
          'ServerIP': details['serverIP'],
          'id': details['id'],
          'UserName': details['userName'],
          'Password': details['password'],
          'DatabaseName': details['databaseName'],
          'APIServerURl': details['url'],
          'Parameter': details['parameters'],
        });
      }
      setState(() {
        _apiData = data;
        _filteredData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load APIs: $e';
      });
    }
  }

  void _filterApis(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredData = _apiData;
      } else {
        _filteredData = _apiData.where((item) {
          final apiName = item['APIName'].toString().toLowerCase();
          final serverIP = item['ServerIP'].toString().toLowerCase();
          return apiName.contains(query.toLowerCase()) || serverIP.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _deleteApi(String id) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _apiService.deleteDatabaseServer(id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'API deleted successfully',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      await _fetchApis(); // Refresh the table
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete API: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 2,
        shadowColor: color.withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: 'Edit Database Configuration',
        onBackPress: () => Navigator.pop(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Improved Search Bar
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search APIs...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 15),
                    prefixIcon: Icon(Icons.search, color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blueAccent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                  onChanged: _filterApis,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Responsive Table View
            Expanded(
              child: _isLoading
                  ? const SubtleLoader()
                  : _errorMessage != null
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.redAccent,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      text: 'Retry',
                      color: Colors.blueAccent,
                      onPressed: _fetchApis,
                      icon: Icons.refresh,
                    ),
                  ],
                ),
              )
                  : _filteredData.isEmpty
                  ? Center(
                child: Text(
                  'No APIs found',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                ),
              )
                  : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowColor: MaterialStateProperty.all(
                          Colors.blueAccent.withOpacity(0.1)),
                      dataRowColor:
                      MaterialStateProperty.all(Colors.white),
                      columns: [
                        DataColumn(
                          label: Text(
                            'Sno',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'API Name',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Server IP',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Actions',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                      rows: _filteredData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final api = entry.value;
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                '${index + 1}',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                            DataCell(
                              Text(
                                api['APIName'],
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                            DataCell(
                              Text(
                                api['ServerIP'],
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildButton(
                                    text: 'Edit',
                                    color: Colors.blueAccent,
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EditDetailAdmin(apiData: api),
                                        ),
                                      );
                                      if (result == true) {
                                        await _fetchApis();
                                      }
                                    },
                                    icon: Icons.edit,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildButton(
                                    text: 'Delete',
                                    color: Colors.redAccent,
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          title: Text(
                                            'Confirm Delete',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          content: Text(
                                            'Are you sure you want to delete "${api['APIName']}"?',
                                            style: GoogleFonts.poppins(fontSize: 14),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                'Cancel',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.grey[700],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _deleteApi(api['id']);
                                              },
                                              child: Text(
                                                'Delete',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: Icons.delete,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}