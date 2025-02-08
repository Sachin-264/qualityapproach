import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:qualityapproach/Warranty/AddWaranty.dart';
import 'package:qualityapproach/Warranty/BlocWarranty.dart';

class WarrantyScreen extends StatelessWidget {
  const WarrantyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocListener<WarrantyBloc, WarrantyState>(
      listener: (context, state) {
        if (state is WarrantyError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.lightBlue,
          title:
              const Text('Warranty Amc', style: TextStyle(color: Colors.white)),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddWarrantyScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Column(
          children: [
            // Header row remains the same...
            Padding(
              padding: const EdgeInsets.only(left: 5.0, right: 5, top: 5),
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 211, 210, 210),
                  border: Border.all(color: Colors.grey.shade800, width: 1),
                  borderRadius: BorderRadius.circular(0),
                ),
                child: const Row(
                  children: [
                    HeaderTableColumnCell(text: 'RecNo'),
                    HeaderTableColumnCell(text: 'Entry Date'),
                    HeaderTableColumnCell(text: 'AccountCode'),
                    HeaderTableColumnCell(text: 'Company Code'),
                    HeaderTableColumnCell(text: 'Head Quarter'),
                    HeaderTableColumnCell(text: 'Invoice No'),
                    HeaderTableColumnCell(text: 'Action'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<WarrantyBloc, WarrantyState>(
                builder: (context, state) {
                  if (state is WarrantyInitial) {
                    context.read<WarrantyBloc>().add(LoadWarranty());
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is WarrantyLoaded) {
                    return ListView.builder(
                      itemCount: state.Warranty.length,
                      itemBuilder: (context, index) {
                        final Warranty = state.Warranty[index];
                        return Padding(
                          padding: const EdgeInsets.only(
                              top: 8.0, left: 5.0, right: 5.0),
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 255, 255, 255),
                              border: Border.all(
                                  color: Colors.grey.shade800, width: 1),
                              borderRadius: BorderRadius.circular(0),
                            ),
                            child: Row(
                              children: [
                                BodyTableColumnCell(text: Warranty["RecNo"]!),
                                BodyTableColumnCell(
                                    text: Warranty["EntryDate"]!),
                                BodyTableColumnCell(
                                    text: Warranty["AccountCode"]!),
                                BodyTableColumnCell(
                                    text: Warranty["CompanyCode"]!),
                                BodyTableColumnCell(text: Warranty["HQCode"]!),
                                BodyTableColumnCell(
                                    text: Warranty["InvoiceNo"]!),
                                Expanded(
                                  child: Container(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            // Navigator.push(
                                            //   context,
                                            //   MaterialPageRoute(
                                            //     builder: (context) =>
                                            //         EditUserGroupScreen(
                                            //           initialText: Warranty["UserGroupName"]!,
                                            //           recec: Warranty["RecNo"]!,
                                            //         ),
                                            //   ),
                                            // );
                                          },
                                          child: Text(
                                            Warranty['Action1']!,
                                            style: const TextStyle(
                                                color: Colors.lightBlue),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        TextButton(
                                          onPressed: () {
                                            // Show delete confirmation dialog
                                            showDialog<void>(
                                              context: context,
                                              barrierDismissible: false,
                                              builder:
                                                  (BuildContext dialogContext) {
                                                return AlertDialog(
                                                  title: const Text(
                                                      'Confirm Delete'),
                                                  content: const Text(
                                                      'Are you sure you want to delete this user group?'),
                                                  actions: <Widget>[
                                                    TextButton(
                                                      child:
                                                          const Text('Cancel'),
                                                      onPressed: () {
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop();
                                                      },
                                                    ),
                                                    TextButton(
                                                      child:
                                                          const Text('Delete'),
                                                      onPressed: () {
                                                        // Close the dialog first
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop();
                                                        // Then dispatch the delete event
                                                        context
                                                            .read<
                                                                WarrantyBloc>()
                                                            .add(DeleteWarranty(
                                                                Warranty[
                                                                    "RecNo"]!,
                                                                context));
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          child: Text(
                                            Warranty['Action2']!,
                                            style: const TextStyle(
                                                color: Colors.lightBlue),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    return const Center(child: Text('Something went wrong'));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderTableColumnCell extends StatelessWidget {
  final String text;

  const HeaderTableColumnCell({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
                color: Colors.grey.shade800, width: 1), // Separator line
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: 5.0),
          child: Text(
            text,
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class BodyTableColumnCell extends StatelessWidget {
  final String text;

  const BodyTableColumnCell({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
                color: Colors.grey.shade800, width: 1), // Separator line
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: 5.0),
          child: Text(
            text,
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }
}
