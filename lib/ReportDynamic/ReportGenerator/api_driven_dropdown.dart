import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ReportAPIService.dart';

// A model for the dropdown items, using FieldID and FieldName as you specified.
class DropdownOption {
  final String id;
  final String name;

  DropdownOption({required this.id, required this.name});
}

class ApiDrivenDropdown extends StatefulWidget {
  final Map<String, dynamic> columnConfig;
  final Map<String, dynamic> rowData;
  final String initialValue; // This will be the DISPLAY NAME, e.g., "Dispatch"
  final ReportAPIService apiService;
  final Function(String?) onSelectionChanged;

  const ApiDrivenDropdown({
    Key? key,
    required this.columnConfig,
    required this.rowData,
    required this.initialValue,
    required this.apiService,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  _ApiDrivenDropdownState createState() => _ApiDrivenDropdownState();
}

class _ApiDrivenDropdownState extends State<ApiDrivenDropdown> {
  bool _isLoading = false;
  List<DropdownOption> _options = [];
  String? _selectedValue; // This will now store the ID, e.g., "E"
  String _displayText = ''; // This will store the display name
  String? _error;

  @override
  void initState() {
    super.initState();
    // Initially, set the display text to what the grid provides.
    _displayText = widget.initialValue;
    // We don't know the ID yet, so _selectedValue is null.
  }

  Future<void> _fetchOptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final String baseUrl = widget.columnConfig['api_url'] ?? '';
      if (baseUrl.isEmpty) {
        throw Exception('API URL is missing in column configuration.');
      }

      final List<dynamic> fieldParams = widget.columnConfig['field_params'] as List<dynamic>? ?? [];
      final Map<String, String> dynamicParams = {};

      for (var param in fieldParams) {
        final String paramName = param['parameterName'] ?? '';
        final String paramSource = param['parameterValue'] ?? '';

        if (paramName.isNotEmpty) {
          if (widget.rowData.containsKey(paramSource)) {
            dynamicParams[paramName] = widget.rowData[paramSource]?.toString() ?? '';
          } else {
            dynamicParams[paramName] = paramSource;
          }
        }
      }

      final uri = Uri.parse(baseUrl);
      final finalUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...dynamicParams
      });

      debugPrint('Fetching dropdown options from: ${finalUri.toString()}');

      final List<dynamic> responseData = await widget.apiService.fetchRawJsonFromUrl(finalUri.toString());

      final List<DropdownOption> fetchedOptions = responseData.map((item) {
        return DropdownOption(
          id: item['FieldID']?.toString() ?? '',
          name: item['FieldName']?.toString() ?? 'Unnamed',
        );
      }).toList();

      // ******************* CHANGE IS HERE *******************
      // After fetching options, find the ID that corresponds to the initial display text.
      String? initialId;
      try {
        final matchingOption = fetchedOptions.firstWhere((opt) => opt.name == _displayText);
        initialId = matchingOption.id;
      } catch (e) {
        // It's okay if no match is found, initialId will remain null.
        debugPrint('Initial value "$_displayText" not found in fetched options.');
      }

      setState(() {
        _options = fetchedOptions;
        _selectedValue = initialId; // Set the selected ID
        _isLoading = false;
      });
      // ******************* END OF CHANGE *******************

    } catch (e) {
      setState(() {
        _error = 'Failed to load options: $e';
        _isLoading = false;
      });
      debugPrint(_error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (_error != null) {
      return Tooltip(
          message: _error,
          child: Center(child: Icon(Icons.error_outline, color: Colors.red, size: 18))
      );
    }

    // If we have options, show the dropdown.
    if (_options.isNotEmpty) {
      return DropdownButton<String>(
        // *** The value is now correctly bound to the ID ***
        value: _selectedValue,
        isExpanded: true,
        underline: Container(),
        hint: const Text('Select...'),
        items: _options.map((DropdownOption option) {
          return DropdownMenuItem<String>(
            // *** The value of each item is also an ID ***
            value: option.id,
            child: Text(option.name, style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue == null) return;

          final selectedOption = _options.firstWhere((opt) => opt.id == newValue);
          setState(() {
            _selectedValue = newValue;
            // Update the display text as well for consistency.
            _displayText = selectedOption.name;
          });
          widget.onSelectionChanged(newValue);
        },
      );
    }

    // Default state: A button to trigger the fetch.
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        alignment: Alignment.centerLeft,
      ),
      onPressed: _fetchOptions,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _displayText.isEmpty ? 'Load Options' : _displayText,
              style: GoogleFonts.poppins(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }
}