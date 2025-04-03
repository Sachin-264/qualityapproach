// lib/models/item_model.dart
class Item {
  final String fieldId;
  final String fieldName;
  final String ourItemNo;
  final String hsnCode;

  Item({
    required this.fieldId,
    required this.fieldName,
    required this.ourItemNo,
    required this.hsnCode,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      fieldId: json['FieldID'] ?? '',
      fieldName: json['FieldName'] ?? '',
      ourItemNo: json['OurItemNo'] ?? '',
      hsnCode: json['HSNCode'] ?? '',
    );
  }
}