import 'package:flutter/material.dart';
import 'package:qualityapproach/Warranty/Warrantyapi.dart';
import 'package:qualityapproach/Warranty/widget/Custumtextfield.dart';

class WarrantyTableRow {
  final String sNo;
  final String sNo1;
  final String tentativeDate;

  WarrantyTableRow({
    required this.sNo,
    required this.sNo1,
    required this.tentativeDate,
  });
}

class ItemTableRow {
  final String itemName;
  final String mcNo;
  final String sacHsn;
  final String qty;
  final String fromDate;
  final String toDate;
  final String billNo;
  final String billDate;
  final String withSpareParts;
  final String remarks;
  final String InstallationAddress;

  ItemTableRow({
    required this.itemName,
    required this.mcNo,
    required this.sacHsn,
    required this.qty,
    required this.fromDate,
    required this.toDate,
    required this.billNo,
    required this.billDate,
    required this.withSpareParts,
    required this.remarks,
    required this.InstallationAddress,
  });
}

class AddWarrantyScreen extends StatefulWidget {
  const AddWarrantyScreen({Key? key}) : super(key: key);

  @override
  _AddWarrantyScreenState createState() => _AddWarrantyScreenState();
}

class _AddWarrantyScreenState extends State<AddWarrantyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _TentativedateController =
      TextEditingController();
  final TextEditingController _sNoController = TextEditingController();
  int itemnum = 1;
  int datenum = 1;
  DateTime? _selectedDate;

  Map<String, String>? selectedHQ;
  Map<String, String>? selectedBillNo;
  Map<String, String>? selectedCustomer;

  // Lists for dropdowns with map support
  List<Map<String, String>> hqList = [];
  List<Map<String, String>> billNoList = [];
  List<Map<String, String>> customerList = [];
  List<Map<String, dynamic>> warrantyDatesList = [];
  int ItemCounter = 1;
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _mcNoController = TextEditingController();
  final TextEditingController _itemRemarksController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _sacHsnController = TextEditingController();
  final TextEditingController _warrantyFromController = TextEditingController();
  final TextEditingController _warrantyToController = TextEditingController();
  final TextEditingController _itemBillNoController = TextEditingController();
  final TextEditingController _itemBillDateController = TextEditingController();
  final TextEditingController _installationAddressController =
      TextEditingController();
// Add these variables
  List<ItemTableRow> itemTableData = [];
  List<Map<String, dynamic>> itemDetailsList = [];
  String? selectedSpareparts;
  List<String> sparePartsList = ['Yes', 'No'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _selectedDate = DateTime.now();
    _dateController.text = _formatDate(_selectedDate!);
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final customers = await WarrantyService.getCustomers();
      print("customer:::$customers");
      if (mounted) {
        setState(() {
          customerList = customers;
        });
      }
      // Fetch slip number
      final slipNo = await WarrantyService.getSlipNo();
      if (mounted) {
        setState(() => _sNoController.text = slipNo);
      }

      // Fetch headquarters list
      final headquarters = await WarrantyService.getHeadquarters();
      if (mounted) {
        setState(() {
          hqList = headquarters;
        });
      }

      // Fetch customer list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCustomerChanged(int? value) async {
    if (value == null) return;

    setState(() {
      selectedCustomer = customerList[value];
      selectedBillNo = null; // Reset bill number
      billNoList = []; // Clear previous bill numbers
      _isLoading = true;
    });

    try {
      final billNumbers =
          await WarrantyService.getBillNumbers(selectedCustomer!['id']!);
      if (mounted) {
        setState(() {
          billNoList = billNumbers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading bill numbers: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onBillNoChanged(int? value) async {
    if (value == null) return;

    setState(() {
      selectedBillNo = billNoList[value];
      _isLoading = true;
    });

    try {
      final itemDetails =
          await WarrantyService.getItemDetails(selectedBillNo!['id']!);
      if (mounted) {
        setState(() {
          // Populate item details controllers
          // Example:
          _mcNoController.text = itemDetails['mcNo'] ?? '';
          _sacHsnController.text = itemDetails['hsnCode'] ?? '';
          // Add more mappings as needed
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading item details: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? selectedItemName;
  List<String> itemNameList = []; // Will be populated from API

// Add this method to fetch item names
  Future<void> fetchItemNames() async {
    // API call will be implemented later
    // setState(() {
    //   itemNameList = response.data;
    // });
  }
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day}-${months[date.month - 1]}-${date.year}';
  }

  List<WarrantyTableRow> tableData = [];
  int rowCounter = 1;

// Add methods to handle item editing and deletion
  void deleteItem(int index) {
    setState(() {
      itemTableData.removeAt(index);
      itemDetailsList.removeAt(index);
    });
  }

  void editItem(int index) {
    // Populate the form with the selected item's data
    setState(() {
      final item = itemTableData[index];
      _itemNameController.text = item.itemName;
      _mcNoController.text = item.mcNo;
      _sacHsnController.text = item.sacHsn;
      _qtyController.text = item.qty;
      _warrantyFromController.text = item.fromDate;
      _warrantyToController.text = item.toDate;
      _itemBillNoController.text = item.billNo;
      _itemBillDateController.text = item.billDate;
      selectedSpareparts = item.withSpareParts;
      _itemRemarksController.text = item.remarks;

      // Remove the item from the lists
      itemTableData.removeAt(index);
      itemDetailsList.removeAt(index);
    });
  }

// Add this method to clear all item-related fields
  void clearItemFields() {
    setState(() {
      _itemNameController.clear();
      _mcNoController.clear();
      _itemRemarksController.clear();
      _qtyController.clear();
      _sacHsnController.clear();
      _warrantyFromController.clear();
      _warrantyToController.clear();
      _itemBillNoController.clear();
      _itemBillDateController.clear();
      selectedSpareparts = null;
    });
  }

// Add this widget after the existing date table
  Widget buildItemTable() {
    return Container(
      width: 800,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.blue),
        columnWidths: const {
          0: FlexColumnWidth(0.5),
          1: FlexColumnWidth(0.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1),
          4: FlexColumnWidth(1),
          5: FlexColumnWidth(0.5),
        },
        children: [
          // Table Header
          const TableRow(
            decoration: BoxDecoration(
              color: Colors.lightBlue,
            ),
            children: [
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: Text('Edit')),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: Text('Delete')),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: Text('Item Name')),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: Text('M/C No')),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: Text('SAC/HSN')),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: Text('Qty')),
                ),
              ),
            ],
          ),
          // Table Data
          ...itemTableData.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return TableRow(
              children: [
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => editItem(index),
                      ),
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => deleteItem(index),
                      ),
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: Text(row.itemName)),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: Text(row.mcNo)),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: Text(row.sacHsn)),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: Text(row.qty)),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  // Add this method to your state class
  void addNewRow() {
    if (_TentativedateController.text.isNotEmpty) {
      setState(() {
        tableData.add(
          WarrantyTableRow(
            sNo: _sNoController.text,
            sNo1: rowCounter.toString(),
            tentativeDate: _TentativedateController.text,
          ),
        );
        warrantyDatesList.add({
          'sNo': _sNoController.text,
          'sNo1': rowCounter.toString(),
          'tentativeDate': _TentativedateController.text,
        });
        print(warrantyDatesList);
        rowCounter++;
        _TentativedateController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter S.No. and Tentative Date'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void deleteRow(int index) {
    setState(() {
      tableData.removeAt(index);
    });
  }

  void editRow(int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        WarrantyTableRow oldRow = tableData[index];
        tableData[index] = WarrantyTableRow(
          sNo: oldRow.sNo,
          sNo1: oldRow.sNo1,
          tentativeDate: _formatDate(picked),
        );
      });
    }
  }

  // Function to open the date picker
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        controller.text = _formatDate(_selectedDate!);
      });
    }
  }

  Future<void> fetchHQData() async {
    // API call to fetch HQ data
  }

  Future<void> fetchBillData() async {
    // API call to fetch Bill data
  }

  Future<void> fetchCustomerData() async {
    // API call to fetch Customer data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Warranty'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Selected Date',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () =>
                                  _selectDate(context, _dateController),
                              child: Container(
                                width: 150,
                                height: 50,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                alignment: Alignment.center,
                                child: Text(
                                  _dateController.text,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 800),
                        SizedBox(
                          width: 200,
                          child: CustomTextFieldRow(
                            length: 50,
                            label: 'S No.',
                            controller: _sNoController,
                            hintText: 'Enter S No.',
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Please enter S No.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 0),
                    CustomTextFieldRow(
                      length: 180,
                      label: 'Head Quarter',
                      isDropdown: true,
                      dropdownItems: hqList.map((hq) => hq['name']!).toList(),
                      selectedValue: selectedHQ != null
                          ? hqList.indexOf(selectedHQ!)
                          : null,
                      onChanged: (value) {
                        setState(() {
                          selectedHQ = hqList[value!];
                        });
                      },
                    ),
                    const SizedBox(height: 0),
                    CustomTextFieldRow(
                      length: 180,
                      label: 'Bill No.',
                      isDropdown: true,
                      dropdownItems:
                          billNoList.map((bill) => bill['name']!).toList(),
                      selectedValue: selectedBillNo != null
                          ? billNoList.indexOf(selectedBillNo!)
                          : null,
                      onChanged: _onBillNoChanged,
                    ),

                    CustomTextFieldRow(
                      length: 180,
                      label: 'Customer Name',
                      isDropdown: true,
                      dropdownItems: customerList
                          .map((customer) => customer['name']!)
                          .toList(),
                      selectedValue: selectedCustomer != null
                          ? customerList.indexOf(selectedCustomer!)
                          : null,
                      onChanged: _onCustomerChanged,
                    ),
                    // const SizedBox(height: 20),
                    // ElevatedButton(
                    //   onPressed: _submitForm,
                    //   child: const Text('Submit'),
                    // ),
                    const SizedBox(height: 0),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Item Details',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 0,
                    ),
                    SizedBox(
                      width: 800,
                      child: CustomTextFieldRow(
                        length: 110,
                        label: 'Item name',
                        isDropdown: true,
                        dropdownItems: itemNameList,
                        selectedValue: selectedItemName != null
                            ? itemNameList.indexOf(selectedItemName!)
                            : null,
                        onChanged: (value) {
                          setState(() {
                            selectedItemName = itemNameList[value!];
                            _itemNameController.text = selectedItemName!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 0),
                    SizedBox(
                      width: 800,
                      child: CustomTextFieldRow(
                        length: 110,
                        label: 'MC No.',
                        isDropdown: false,
                        controller: _mcNoController,
                      ),
                    ),
                    const SizedBox(height: 0),
                    SizedBox(
                      width: 800,
                      child: CustomTextFieldRow(
                        length: 110,
                        label: 'Item Remarks',
                        isDropdown: false,
                        controller: _itemRemarksController,
                      ),
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 210,
                          child: CustomTextFieldRow(
                            length: 110,
                            label: 'Qty',
                            isDropdown: false,
                            controller: _qtyController,
                            onChanged: (value) {},
                          ),
                        ),
                        const SizedBox(width: 200),
                        SizedBox(
                          width: 210,
                          child: CustomTextFieldRow(
                            length: 110,
                            label: 'Sac HSN',
                            isDropdown: false,
                            controller: _sacHsnController,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Warranty/AMC\nFrom',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 0),
                            GestureDetector(
                              onTap: () =>
                                  _selectDate(context, _warrantyFromController),
                              child: Container(
                                width: 100,
                                height: 50,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                alignment: Alignment.center,
                                child: Text(
                                  _warrantyFromController.text,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 200),
                        Row(
                          children: [
                            const Text(
                              'To',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 95),
                            GestureDetector(
                              onTap: () =>
                                  _selectDate(context, _warrantyToController),
                              child: Container(
                                width: 100,
                                height: 50,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                alignment: Alignment.center,
                                child: Text(
                                  _warrantyToController.text,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 210,
                          child: CustomTextFieldRow(
                            length: 110,
                            label: 'Bill No.',
                            isDropdown: false,
                            controller: _itemBillNoController,
                          ),
                        ),
                        const SizedBox(width: 200),
                        Row(
                          children: [
                            const Text(
                              'Bill Date',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 50),
                            GestureDetector(
                              onTap: () =>
                                  _selectDate(context, _itemBillDateController),
                              child: Container(
                                width: 100,
                                height: 50,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                alignment: Alignment.center,
                                child: Text(
                                  _itemBillDateController.text,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 300,
                      child: CustomTextFieldRow(
                        length: 110,
                        label: 'With Spare Parts',
                        isDropdown: true,
                        dropdownItems: sparePartsList,
                        selectedValue: selectedSpareparts != null
                            ? sparePartsList.indexOf(selectedSpareparts!)
                            : null,
                        onChanged: (value) {
                          setState(() {
                            selectedSpareparts = sparePartsList[value!];
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 800,
                      child: CustomTextFieldRow(
                        length: 110,
                        label: 'Installation Address',
                        isDropdown: false,
                        controller: _installationAddressController,
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Tentative Service Date',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 50),
                        GestureDetector(
                          onTap: () =>
                              _selectDate(context, _TentativedateController),
                          child: Container(
                            width: 120,
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.center,
                            child: Text(
                              _TentativedateController.text,
                              style: const TextStyle(fontSize: 17),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 25,
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: addNewRow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 5, vertical: 5),
                            child: Text(
                              'Add Date',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () {
                            _TentativedateController.clear();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 5, vertical: 5),
                            child: Text(
                              'Clear',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          width: 400,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red),
                          ),
                          child: Table(
                            border: TableBorder.all(color: Colors.red),
                            columnWidths: const {
                              0: FlexColumnWidth(1),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(2),
                            },
                            children: [
                              // Table Header
                              const TableRow(
                                decoration: BoxDecoration(
                                  color:
                                      const Color.fromARGB(255, 255, 255, 255),
                                ),
                                children: [
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Center(child: Text('Edit')),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Center(child: Text('Delete')),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child:
                                          Center(child: Text('Tentative Date')),
                                    ),
                                  ),
                                ],
                              ),
                              // Table Data
                              ...tableData.asMap().entries.map((entry) {
                                final index = entry.key;
                                final row = entry.value;
                                return TableRow(
                                  children: [
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                          child: IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => editRow(index),
                                          ),
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                          child: IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () => deleteRow(index),
                                          ),
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                          child: Text(row.tentativeDate),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            if (_mcNoController.text.isEmpty ||
                                _qtyController.text.isEmpty ||
                                _sacHsnController.text.isEmpty ||
                                _warrantyFromController.text.isEmpty ||
                                _warrantyToController.text.isEmpty ||
                                _itemBillNoController.text.isEmpty ||
                                _itemBillDateController.text.isEmpty ||
                                selectedSpareparts == null) {
                              // Show error if required fields are empty
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Please fill all required fields'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              // Add item to table data
                              itemTableData.add(
                                ItemTableRow(
                                  itemName: _itemNameController.text,
                                  mcNo: _mcNoController.text,
                                  sacHsn: _sacHsnController.text,
                                  qty: _qtyController.text,
                                  fromDate: _warrantyFromController.text,
                                  toDate: _warrantyToController.text,
                                  billNo: _itemBillNoController.text,
                                  billDate: _itemBillDateController.text,
                                  withSpareParts: selectedSpareparts ?? 'No',
                                  remarks: _itemRemarksController.text,
                                  InstallationAddress:
                                      _installationAddressController.text,
                                ),
                              );

                              // Add item to details list for API
                              itemDetailsList.add({
                                'itemName': _itemNameController.text,
                                'mcNo': _mcNoController.text,
                                'sacHsn': _sacHsnController.text,
                                'qty': _qtyController.text,
                                'fromDate': _warrantyFromController.text,
                                'toDate': _warrantyToController.text,
                                'billNo': _itemBillNoController.text,
                                'billDate': _itemBillDateController.text,
                                'withSpareParts': selectedSpareparts,
                                'remarks': _itemRemarksController.text,
                                'InstallationAddress':
                                    _installationAddressController.text,
                              });

                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Item added successfully'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              // Clear all fields after successful addition
                              _itemNameController.clear();
                              _mcNoController.clear();
                              _itemRemarksController.clear();
                              _qtyController.clear();
                              _sacHsnController.clear();
                              _warrantyFromController.clear();
                              _warrantyToController.clear();
                              _itemBillNoController.clear();
                              _itemBillDateController.clear();
                              selectedSpareparts = null;
                              _installationAddressController.clear();
                            });
                            ItemCounter++;
                            tableData.clear();
                            warrantyDatesList.clear();
                            rowCounter =
                                1; // Reset row counter for tentative dates
                            _TentativedateController.clear();
                            // Print the updated lists for debugging
                            print('Item Table Data: $itemTableData');
                            print('Item Details List: $itemDetailsList');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 15),
                            child: Text(
                              'Add Item Details',
                              style:
                                  TextStyle(fontSize: 19, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              // Clear all fields
                              _itemNameController.clear();
                              _mcNoController.clear();
                              _itemRemarksController.clear();
                              _qtyController.clear();
                              _sacHsnController.clear();
                              _warrantyFromController.clear();
                              _warrantyToController.clear();
                              _itemBillNoController.clear();
                              _itemBillDateController.clear();
                              selectedSpareparts = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 15),
                            child: Text(
                              'Clear',
                              style:
                                  TextStyle(fontSize: 19, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    buildItemTable(),
// Also add this widget right after the buttons to display the items table
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _sNoController.dispose();
    super.dispose();
  }
}
