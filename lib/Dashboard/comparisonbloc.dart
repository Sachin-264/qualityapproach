import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Events
abstract class ComparisonEvent extends Equatable {
  const ComparisonEvent();

  @override
  List<Object> get props => [];
}

class FetchComparisonData extends ComparisonEvent {
  final String bidRecNo;
  final String indentRecNo;

  const FetchComparisonData(this.bidRecNo, this.indentRecNo);

  @override
  List<Object> get props => [bidRecNo, indentRecNo];
}

// States
abstract class ComparisonState extends Equatable {
  const ComparisonState();

  @override
  List<Object> get props => [];
}

class ComparisonInitial extends ComparisonState {}

class ComparisonLoading extends ComparisonState {}

class ComparisonLoaded extends ComparisonState {
  final List<ItemDetail> itemDetails;
  final List<Vendor> vendors;
  final List<VendorQuote> vendorQuotes;

  const ComparisonLoaded(this.itemDetails, this.vendors, this.vendorQuotes);

  @override
  List<Object> get props => [itemDetails, vendors, vendorQuotes];
}

class ComparisonError extends ComparisonState {
  final String message;

  const ComparisonError(this.message);

  @override
  List<Object> get props => [message];
}

// Data Models
class ItemDetail {
  final String sno;
  final String indentNo;
  final String bidNo;
  final String itemNo;
  final String itemName;
  final String qty;
  final String unit;
  final String previousPurchase;
  final String? subTotal;
  final String? splDiscountAmount;
  final String? packingAmount;
  final String? insuranceAmount;
  final String? freightAmount;
  final String? otherChargesAmount;
  final String? gstAmount;
  final String? freightType;
  final String? paymentTerms;

  ItemDetail({
    required this.sno,
    required this.indentNo,
    required this.bidNo,
    required this.itemNo,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.previousPurchase,
    this.subTotal,
    this.splDiscountAmount,
    this.packingAmount,
    this.insuranceAmount,
    this.freightAmount,
    this.otherChargesAmount,
    this.gstAmount,
    this.freightType,
    this.paymentTerms,
  });

  factory ItemDetail.fromJson(Map<String, dynamic> json) {
    return ItemDetail(
      sno: json['SNO'] ?? '',
      indentNo: json['indentNo'] ?? '',
      bidNo: json['BidNo'] ?? '',
      itemNo: json['ItemNo'] ?? '',
      itemName: json['ItemName'] ?? '',
      qty: json['Qty'] ?? '',
      unit: json['QOUnitName'] ?? '',
      previousPurchase: json['PreviousPurchase'] ?? '',
      subTotal: json['SubTotal']?.toString(),
      splDiscountAmount: json['SplDisAmt']?.toString(),
      packingAmount: json['PackingAmt']?.toString(),
      insuranceAmount: json['InsuranceAmt']?.toString(),
      freightAmount: json['FreightAmt']?.toString(),
      otherChargesAmount: json['OtherChargesAmt']?.toString(),
      gstAmount: json['TotalGSTAmt']?.toString(),
      freightType: json['FreightType'],
      paymentTerms: json['PaymentName'],
    );
  }
}

class Vendor {
  final String accountCode;
  final String accountName;

  Vendor({required this.accountCode, required this.accountName});

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      accountCode: json['AccountCode'] ?? '',
      accountName: json['AccountName'] ?? '',
    );
  }
}

class VendorQuote {
  final String accountCode;
  final String itemNo;
  final String itemRate;
  final String netRate;
  final String discountPercent;
  final String discountAmount;
  final String netValue;
  final String gstPercent;
  final String gstAmount;
  final String subTotal;
  final String totalBeforeTax;
  final String grandTotal;
  final String deliveryPeriod;
  final String paymentTerms;
  final String freightRemarks;
  final String gstRemarks;
  final String? actionL1;
  final String? actionL1Remark;
  final String? actionL2;
  final String? actionL2Remark;

  VendorQuote({
    required this.accountCode,
    required this.itemNo,
    required this.itemRate,
    required this.netRate,
    required this.discountPercent,
    required this.discountAmount,
    required this.netValue,
    required this.gstPercent,
    required this.gstAmount,
    required this.subTotal,
    required this.totalBeforeTax,
    required this.grandTotal,
    required this.deliveryPeriod,
    required this.paymentTerms,
    required this.freightRemarks,
    required this.gstRemarks,
    this.actionL1,
    this.actionL1Remark,
    this.actionL2,
    this.actionL2Remark,
  });

  factory VendorQuote.fromJson(Map<String, dynamic> json) {
    return VendorQuote(
      accountCode: json['AccountCode'] ?? '',
      itemNo: json['ItemNo'] ?? '',
      itemRate: json['ItemRate']?.toString() ?? '',
      netRate: json['NetRate']?.toString() ?? '',
      discountPercent: json['DisPer']?.toString() ?? '',
      discountAmount: json['DisAmt']?.toString() ?? '',
      netValue: json['NetValue']?.toString() ?? '',
      gstPercent: json['GSTPer']?.toString() ?? '',
      gstAmount: json['GSTAmt']?.toString() ?? '',
      subTotal: json['SubTotal']?.toString() ?? '',
      totalBeforeTax: json['TotalBeforeTax']?.toString() ?? '',
      grandTotal: json['GrandTotal']?.toString() ?? '',
      deliveryPeriod: json['DeliveryPeriod']?.toString() ?? '',
      paymentTerms: json['PaymentName']?.toString() ?? '',
      freightRemarks: json['FreightRemarks']?.toString() ?? '',
      gstRemarks: json['GSTRemarks']?.toString() ?? '',
      actionL1: json['Action_L1']?.toString(),
      actionL1Remark: json['Action_L1_Remark']?.toString(),
      actionL2: json['Action_L2']?.toString(),
      actionL2Remark: json['Action_L2_Remark']?.toString(),
    );
  }
}

// BLoC
class ComparisonBloc extends Bloc<ComparisonEvent, ComparisonState> {
  ComparisonBloc() : super(ComparisonInitial()) {
    on<FetchComparisonData>(_onFetchComparisonData);
  }

  Future<void> _onFetchComparisonData(
      FetchComparisonData event,
      Emitter<ComparisonState> emit,
      ) async {
    emit(ComparisonLoading());
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost/Dash/Compare.php?BranchCode=E&FromDate=2025-04-01&ToDate=2025-04-16&BidRecNo=${event.bidRecNo}&IndentRecNo=${event.indentRecNo}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final itemDetails = (data['data'][0] as List)
              .map((item) => ItemDetail.fromJson(item))
              .toList();
          final vendors = (data['data'][1] as List)
              .map((vendor) => Vendor.fromJson(vendor))
              .toList();
          final vendorQuotes = (data['data'][2] as List)
              .map((quote) => VendorQuote.fromJson(quote))
              .toList();

          emit(ComparisonLoaded(itemDetails, vendors, vendorQuotes));
        } else {
          emit(const ComparisonError('Failed to load data'));
        }
      } else {
        emit(const ComparisonError('Server error'));
      }
    } catch (e) {
      emit(ComparisonError('Error: $e'));
    }
  }
}