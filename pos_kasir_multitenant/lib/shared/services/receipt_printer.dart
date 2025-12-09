import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../data/models/transaction.dart';
import '../../data/models/tenant.dart';
import '../../data/models/user.dart';

class ReceiptPrinter {
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static bool _fontsLoaded = false;

  /// Load fonts for PDF generation
  static Future<void> _loadFonts() async {
    if (_fontsLoaded) return;

    try {
      // Use Google Fonts from printing package
      _regularFont = await PdfGoogleFonts.notoSansRegular();
      _boldFont = await PdfGoogleFonts.notoSansBold();
      _fontsLoaded = true;
    } catch (e) {
      debugPrint('Failed to load Google Fonts: $e');
      _fontsLoaded = true; // Mark as loaded to avoid retry
    }
  }

  /// Print receipt - shows print preview dialog
  /// Uses thermal printer format (80mm width)
  static Future<void> printReceipt({
    required BuildContext context,
    required Transaction transaction,
    required Tenant tenant,
    required User user,
    double cashReceived = 0,
  }) async {
    final pdf = await _generateReceiptPdf(
      transaction: transaction,
      tenant: tenant,
      user: user,
      cashReceived: cashReceived,
    );

    // Thermal printer format: 80mm width
    const double receiptWidth = 226.77;
    final int itemCount = transaction.items.length;
    const double baseHeight = 350;
    final double itemHeight = itemCount * 35.0;
    final double totalHeight = baseHeight + itemHeight;

    final thermalFormat = PdfPageFormat(
      receiptWidth,
      totalHeight,
      marginAll: 0,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf,
      name: 'Struk_${transaction.id.substring(0, 8)}',
      format: thermalFormat,
    );
  }

  /// Show receipt preview in a dialog
  static Future<void> showReceiptPreview({
    required BuildContext context,
    required Transaction transaction,
    required Tenant tenant,
    required User user,
    double cashReceived = 0,
  }) async {
    final pdf = await _generateReceiptPdf(
      transaction: transaction,
      tenant: tenant,
      user: user,
      cashReceived: cashReceived,
    );

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Preview Struk',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: PdfPreview(
                  build: (format) async => pdf,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  allowPrinting: true,
                  allowSharing: true,
                  // Use thermal format for preview
                  initialPageFormat:
                      const PdfPageFormat(226.77, 500, marginAll: 0),
                  pdfFileName: 'Struk_${transaction.id.substring(0, 8)}.pdf',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Generate PDF document for receipt
  static Future<Uint8List> _generateReceiptPdf({
    required Transaction transaction,
    required Tenant tenant,
    required User user,
    double cashReceived = 0,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    final change = cashReceived - transaction.total;
    final dateStr = DateFormat('dd/MM/yyyy').format(transaction.createdAt);
    final timeStr = DateFormat('HH:mm:ss').format(transaction.createdAt);
    final txnNo = transaction.id.substring(0, 8).toUpperCase();

    // Build theme only if fonts loaded successfully
    final theme = (_regularFont != null && _boldFont != null)
        ? pw.ThemeData.withFont(base: _regularFont, bold: _boldFont)
        : null;

    // Thermal printer paper format: 80mm width, continuous roll
    // 80mm = 226.77 points (1mm = 2.83465 points)
    const double receiptWidth = 226.77;

    // Calculate receipt height based on content (dynamic)
    // Base height + items height + extra space
    final int itemCount = transaction.items.length;
    const double baseHeight = 350; // Header, footer, totals
    final double itemHeight = itemCount * 35.0; // ~35 points per item
    final double totalHeight = baseHeight + itemHeight;

    // Custom page format for thermal printer - no margins, content at top
    final thermalFormat = PdfPageFormat(
      receiptWidth,
      totalHeight,
      marginAll: 0,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: thermalFormat,
        margin: pw.EdgeInsets.zero, // No margin - content starts at top
        theme: theme,
        build: (pw.Context context) {
          return pw.Container(
            width: receiptWidth,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header - Store name (compact for thermal)
                pw.Text(tenant.name,
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (tenant.address != null)
                  pw.Text(tenant.address!,
                      style: const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center),
                if (tenant.phone != null)
                  pw.Text('Telp: ${tenant.phone}',
                      style: const pw.TextStyle(fontSize: 7)),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 2),

                // Transaction Info
                _infoRow('Tanggal', dateStr),
                _infoRow('Jam', timeStr),
                _infoRow('Kasir', user.name),
                _infoRow('No.', txnNo),
                pw.SizedBox(height: 2),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 4),

                // Items
                ...transaction.items.map((item) => pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.productName,
                            style: const pw.TextStyle(fontSize: 8)),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                                '  ${item.quantity} x ${_formatCurrency(item.price)}',
                                style: const pw.TextStyle(fontSize: 7)),
                            pw.Text(_formatCurrency(item.total),
                                style: const pw.TextStyle(fontSize: 7)),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                      ],
                    )),

                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 2),

                // Totals
                _totalRow('Subtotal', transaction.subtotal),
                if (transaction.tax > 0)
                  _totalRow(
                      'Pajak (${(tenant.taxRate * 100).toStringAsFixed(0)}%)',
                      transaction.tax),
                if (transaction.discount > 0)
                  _totalRow('Diskon', -transaction.discount),
                pw.SizedBox(height: 2),
                pw.Divider(thickness: 0.5),
                _totalRow('TOTAL', transaction.total, isBold: true),
                pw.SizedBox(height: 2),

                // Payment
                if (transaction.paymentMethod == 'cash') ...[
                  _totalRow('Tunai', cashReceived),
                  _totalRow('Kembalian', change > 0 ? change : 0, isBold: true),
                ] else
                  _totalRow(_getPaymentLabel(transaction.paymentMethod),
                      transaction.total),

                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 4),

                // Footer
                pw.Text('Terima Kasih!',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Selamat Menikmati',
                    style: const pw.TextStyle(fontSize: 7)),
                pw.SizedBox(height: 4),
              ],
            ),
          );
        },
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, double amount,
      {bool isBold = false}) {
    final style = pw.TextStyle(
      fontSize: isBold ? 10 : 9,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(_formatCurrency(amount), style: style),
        ],
      ),
    );
  }

  static String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  static String _getPaymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'debit':
        return 'Kartu Debit';
      case 'transfer':
        return 'Transfer Bank';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return method;
    }
  }
}
