import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:html' as html;
import '../../data/models/transaction.dart';
import '../../data/models/expense.dart';
import '../../data/models/tenant.dart';

/// Service untuk export laporan ke berbagai format (Web Version)
class ReportExporter {
  /// Export laporan ke Excel
  static Future<String?> exportToExcel({
    required List<Transaction> transactions,
    required List<Expense> expenses,
    required double totalSales,
    required double totalExpenses,
    required double profit,
    required DateTime startDate,
    required DateTime endDate,
    required Tenant tenant,
    String? branchName,
  }) async {
    try {
      final excel = Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // Create Summary Sheet
      _createSummarySheet(
        excel,
        totalSales,
        totalExpenses,
        profit,
        transactions.length,
        startDate,
        endDate,
        tenant,
        branchName,
      );

      // Create Transactions Sheet
      _createTransactionsSheet(excel, transactions);

      // Create Expenses Sheet
      _createExpensesSheet(excel, expenses);

      // Create Products Sheet
      _createProductsSheet(excel, transactions);

      // Save file
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Gagal membuat file Excel');
      }

      // For web, trigger download
      final fileName =
          'Laporan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      return fileName;
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      return null;
    }
  }

  /// Export laporan ke PDF
  static Future<String?> exportToPdf({
    required List<Transaction> transactions,
    required List<Expense> expenses,
    required double totalSales,
    required double totalExpenses,
    required double profit,
    required DateTime startDate,
    required DateTime endDate,
    required Tenant tenant,
    String? branchName,
  }) async {
    try {
      final pdf = pw.Document();

      // Load font for Indonesian characters
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      // Add Summary Page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => _buildPdfSummaryPage(
            totalSales,
            totalExpenses,
            profit,
            transactions.length,
            startDate,
            endDate,
            tenant,
            branchName,
            font,
            fontBold,
          ),
        ),
      );

      // Add Transactions Page
      if (transactions.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (context) => [
              _buildPdfTransactionsTable(transactions, font, fontBold),
            ],
          ),
        );
      }

      // Add Expenses Page
      if (expenses.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (context) => [
              _buildPdfExpensesTable(expenses, font, fontBold),
            ],
          ),
        );
      }

      // Save file
      final bytes = await pdf.save();

      // For web, trigger download
      final fileName =
          'Laporan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName;
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      return null;
    }
  }

  /// Print PDF directly
  static Future<bool> printPdf({
    required List<Transaction> transactions,
    required List<Expense> expenses,
    required double totalSales,
    required double totalExpenses,
    required double profit,
    required DateTime startDate,
    required DateTime endDate,
    required Tenant tenant,
    String? branchName,
  }) async {
    try {
      final pdf = pw.Document();

      // Load font
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      // Add Summary Page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => _buildPdfSummaryPage(
            totalSales,
            totalExpenses,
            profit,
            transactions.length,
            startDate,
            endDate,
            tenant,
            branchName,
            font,
            fontBold,
          ),
        ),
      );

      // Print
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );

      return true;
    } catch (e) {
      debugPrint('Error printing PDF: $e');
      return false;
    }
  }

  // ==================== Excel Helper Methods ====================

  static void _createSummarySheet(
    Excel excel,
    double totalSales,
    double totalExpenses,
    double profit,
    int transactionCount,
    DateTime startDate,
    DateTime endDate,
    Tenant tenant,
    String? branchName,
  ) {
    final sheet = excel['Ringkasan'];

    // Header
    sheet.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('LAPORAN PENJUALAN');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
    );

    // Tenant Info
    sheet.cell(CellIndex.indexByString('A3')).value =
        TextCellValue('Toko: ${tenant.name}');
    if (branchName != null) {
      sheet.cell(CellIndex.indexByString('A4')).value =
          TextCellValue('Cabang: $branchName');
    }

    // Period
    final periodRow = branchName != null ? 5 : 4;
    sheet.cell(CellIndex.indexByString('A$periodRow')).value = TextCellValue(
        'Periode: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}');

    // Summary Data
    final dataStartRow = periodRow + 2;
    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    sheet.cell(CellIndex.indexByString('A$dataStartRow')).value =
        TextCellValue('Total Penjualan');
    sheet.cell(CellIndex.indexByString('B$dataStartRow')).value =
        TextCellValue(currencyFormat.format(totalSales));

    sheet.cell(CellIndex.indexByString('A${dataStartRow + 1}')).value =
        TextCellValue('Jumlah Transaksi');
    sheet.cell(CellIndex.indexByString('B${dataStartRow + 1}')).value =
        IntCellValue(transactionCount);

    sheet.cell(CellIndex.indexByString('A${dataStartRow + 2}')).value =
        TextCellValue('Total Biaya');
    sheet.cell(CellIndex.indexByString('B${dataStartRow + 2}')).value =
        TextCellValue(currencyFormat.format(totalExpenses));

    sheet.cell(CellIndex.indexByString('A${dataStartRow + 3}')).value =
        TextCellValue('Laba/Rugi');
    sheet.cell(CellIndex.indexByString('B${dataStartRow + 3}')).value =
        TextCellValue(currencyFormat.format(profit));
    sheet.cell(CellIndex.indexByString('B${dataStartRow + 3}')).cellStyle =
        CellStyle(
      fontColorHex: profit >= 0 ? ExcelColor.green : ExcelColor.red,
      bold: true,
    );

    // Set column widths
    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 20);
  }

  static void _createTransactionsSheet(
      Excel excel, List<Transaction> transactions) {
    final sheet = excel['Transaksi'];

    // Headers
    final headers = [
      'Tanggal',
      'Waktu',
      'ID Transaksi',
      'Subtotal',
      'Diskon',
      'Pajak',
      'Total',
      'Metode Pembayaran'
    ];

    for (var i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Data
    for (var i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final row = i + 1;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(DateFormat('dd/MM/yyyy').format(t.createdAt));
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(DateFormat('HH:mm').format(t.createdAt));
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(t.id.substring(0, 8).toUpperCase());
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = DoubleCellValue(t.subtotal);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = DoubleCellValue(t.discount);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = DoubleCellValue(t.tax);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = DoubleCellValue(t.total);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          .value = TextCellValue(_formatPaymentMethod(t.paymentMethod));
    }

    // Set column widths
    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 8);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 15);
    sheet.setColumnWidth(7, 18);
  }

  static void _createExpensesSheet(Excel excel, List<Expense> expenses) {
    final sheet = excel['Biaya'];

    // Headers
    final headers = ['Tanggal', 'Kategori', 'Deskripsi', 'Jumlah'];

    for (var i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Data
    for (var i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      final row = i + 1;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(DateFormat('dd/MM/yyyy').format(e.date));
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(e.category);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(e.description ?? '');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = DoubleCellValue(e.amount);
    }

    // Set column widths
    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 35);
    sheet.setColumnWidth(3, 15);
  }

  static void _createProductsSheet(
      Excel excel, List<Transaction> transactions) {
    final sheet = excel['Produk'];

    // Aggregate product sales
    final productSales = <String, Map<String, dynamic>>{};
    for (var t in transactions) {
      for (var item in t.items) {
        if (!productSales.containsKey(item.productName)) {
          productSales[item.productName] = {
            'quantity': 0,
            'total': 0.0,
          };
        }
        productSales[item.productName]!['quantity'] += item.quantity;
        productSales[item.productName]!['total'] += item.total;
      }
    }

    // Headers
    final headers = ['Produk', 'Jumlah Terjual', 'Total Penjualan'];

    for (var i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Data
    var row = 1;
    for (var entry in productSales.entries) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(entry.key);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = IntCellValue(entry.value['quantity']);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = DoubleCellValue(entry.value['total']);
      row++;
    }

    // Set column widths
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 18);
  }

  // ==================== PDF Helper Methods ====================

  static pw.Widget _buildPdfSummaryPage(
    double totalSales,
    double totalExpenses,
    double profit,
    int transactionCount,
    DateTime startDate,
    DateTime endDate,
    Tenant tenant,
    String? branchName,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Center(
          child: pw.Text(
            'LAPORAN PENJUALAN',
            style: pw.TextStyle(font: fontBold, fontSize: 20),
          ),
        ),
        pw.SizedBox(height: 20),

        // Tenant Info
        pw.Text(
          'Toko: ${tenant.name}',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
        if (branchName != null)
          pw.Text(
            'Cabang: $branchName',
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
        pw.SizedBox(height: 10),

        // Period
        pw.Text(
          'Periode: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
        pw.SizedBox(height: 20),

        // Summary Box
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            children: [
              _buildPdfSummaryRow('Total Penjualan',
                  currencyFormat.format(totalSales), font, fontBold),
              pw.SizedBox(height: 10),
              _buildPdfSummaryRow(
                  'Jumlah Transaksi', '$transactionCount', font, fontBold),
              pw.SizedBox(height: 10),
              _buildPdfSummaryRow('Total Biaya',
                  currencyFormat.format(totalExpenses), font, fontBold),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              _buildPdfSummaryRow(
                'Laba/Rugi',
                currencyFormat.format(profit),
                font,
                fontBold,
                valueColor: profit >= 0 ? PdfColors.green : PdfColors.red,
              ),
            ],
          ),
        ),

        pw.Spacer(),

        // Footer
        pw.Center(
          child: pw.Text(
            'Dicetak pada: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(
                font: font, fontSize: 10, color: PdfColors.grey600),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfSummaryRow(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold, {
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 12)),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 12,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfTransactionsTable(
    List<Transaction> transactions,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DAFTAR TRANSAKSI',
          style: pw.TextStyle(font: fontBold, fontSize: 16),
        ),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
          cellStyle: pw.TextStyle(font: font, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 25,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerLeft,
          },
          headers: ['Tanggal', 'Waktu', 'Subtotal', 'Total', 'Pembayaran'],
          data: transactions.map((t) {
            final currencyFormat = NumberFormat.currency(
              locale: 'id',
              symbol: 'Rp ',
              decimalDigits: 0,
            );
            return [
              DateFormat('dd/MM/yy').format(t.createdAt),
              DateFormat('HH:mm').format(t.createdAt),
              currencyFormat.format(t.subtotal),
              currencyFormat.format(t.total),
              _formatPaymentMethod(t.paymentMethod),
            ];
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfExpensesTable(
    List<Expense> expenses,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DAFTAR BIAYA',
          style: pw.TextStyle(font: fontBold, fontSize: 16),
        ),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
          cellStyle: pw.TextStyle(font: font, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 25,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerRight,
          },
          headers: ['Tanggal', 'Kategori', 'Deskripsi', 'Jumlah'],
          data: expenses.map((e) {
            final currencyFormat = NumberFormat.currency(
              locale: 'id',
              symbol: 'Rp ',
              decimalDigits: 0,
            );
            return [
              DateFormat('dd/MM/yy').format(e.date),
              e.category,
              (e.description?.length ?? 0) > 30
                  ? '${e.description!.substring(0, 30)}...'
                  : (e.description ?? ''),
              currencyFormat.format(e.amount),
            ];
          }).toList(),
        ),
      ],
    );
  }

  // ==================== Helper Methods ====================

  static String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'debit':
        return 'Kartu Debit';
      case 'transfer':
        return 'Transfer';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return method;
    }
  }
}
