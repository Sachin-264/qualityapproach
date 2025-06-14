
import 'package:pdf/pdf.dart'; // For PdfColor constants

import '../../ReportMakeEdit/EditDetailMaker.dart';
import 'printservice.dart'; // Import PrintTemplate

extension PrintTemplateForMakerToPrintTemplate on PrintTemplateForMaker {
  PrintTemplate toPrintTemplate() {
    switch (this) {
      case PrintTemplateForMaker.premium:
        return PrintTemplate.premium;
      case PrintTemplateForMaker.minimalist:
        return PrintTemplate.minimalist;
      case PrintTemplateForMaker.corporate:
        return PrintTemplate.corporate;
      case PrintTemplateForMaker.modern:
        return PrintTemplate.modern;
    }
  }
}