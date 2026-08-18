import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PayslipPdfService {
  static Future<File> generatePayslipPdf(
      Map<String, dynamic> payslipData, String month, String year) async {
    final pdf = pw.Document();

    debugPrint('PDF Generation - keys: ${payslipData.keys}');

    if (payslipData['data'] == null ||
        (payslipData['data'] as List).isEmpty) {
      throw Exception('No payslip data available to generate PDF');
    }

    final e = payslipData['data'][0] as Map<String, dynamic>;
    final openingLeave =
        (payslipData['opening_leave'] ?? {}) as Map<String, dynamic>;
    final usedLeave =
        (payslipData['used_leave'] ?? {}) as Map<String, dynamic>;
    final pay =
        (payslipData['pay'] ?? {}) as Map<String, dynamic>;
    final monthLabel =
        payslipData['month']?.toString() ?? _getMonthName(month);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(8),
        build: (pw.Context ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── FAR LEFT COLUMN: Leave Details + empty space + Employee Signature ──
                pw.Container(
                  width: 155,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      right: pw.BorderSide(color: PdfColors.black, width: 0.5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // "Leave Details" header
                      pw.Container(
                        height: 30,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
                          ),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text('Leave Details',
                            style: pw.TextStyle(
                                fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ),
                      // Leave table – natural height (compact rows)
                      _leaveTable(e, openingLeave, usedLeave),
                      // Empty space fills remaining height
                      pw.Expanded(child: pw.SizedBox()),
                      // Employee Sign at bottom
                      pw.Container(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: PdfColors.black, width: 0.5),
                          ),
                        ),
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Employee Sign',
                            style: const pw.TextStyle(fontSize: 9)),
                      ),
                    ],
                  ),
                ),

                // ── RIGHT SIDE: Header + Employee/Bank + Salary + Footer ──
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _header(e, monthLabel, year),
                      // Employee + Bank row (4 sections)
                      _employeeBankRow(e),
                      // Salary table – natural height
                      _salarySection(e, pay),
                      // Footer
                      _footer(e),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final name = (e['name'] ?? 'payslip').toString().replaceAll(' ', '_');
    final file = File('${output.path}/payslip_${name}_${month}_$year.pdf');
    await file.writeAsBytes(await pdf.save());
    debugPrint('PDF saved: ${file.path}');
    return file;
  }

  // ─── HEADER (right side top) ─────────────────────────────────────────────
  static pw.Widget _header(Map<String, dynamic> e, String monthLabel, String year) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Column(
        children: [
          pw.Text(
            (e['cmp_name']?.toString() ?? 'DELTON CABLES LIMITED')
                .replaceAll(RegExp(r'\s*\(HO\)\s*', caseSensitive: false), '').trim(),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            e['address']?.toString() ?? '17/4 MATHURA ROAD SEC-16A FARIDABAD HARYANA 121001',
            style: const pw.TextStyle(fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'PAYSLIP FOR THE MONTH OF $monthLabel-$year',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            'FORM - X1 (See Rule 26 (2))',
            style: const pw.TextStyle(fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── LEAVE TABLE ─────────────────────────────────────────────────────────
  static pw.Widget _leaveTable(
    Map<String, dynamic> e,
    Map<String, dynamic> op,
    Map<String, dynamic> used,
  ) {
    // `bel`, `bcl`, `bsl`, `bml` in data[0] are the correct balance values
    final balEl = _d(e['bel']);
    final balCl = _d(e['bcl']);
    final balSl = _d(e['bsl']);
    final balMl = _d(e['bml']);
    final balCo = _d(e['coff']);

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.5),
        top: pw.BorderSide(color: PdfColors.black, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        left: pw.BorderSide(color: PdfColors.black, width: 0.5),
        right: pw.BorderSide(color: PdfColors.black, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header: blank | Balance
        pw.TableRow(children: [
          _tc('', bold: true, fs: 9),
          _tc('Balance', bold: true, fs: 9),
        ]),
        _leaveRow2('CL', balCl),
        _leaveRow2('EL', balEl),
        _leaveRow2('SL', balSl),
        _leaveRow2('ML', balMl),
        _leaveRow2('CO', balCo),
        _leaveRow2('BL', 0, showZero: false),
      ],
    );
  }

  static pw.TableRow _leaveRow2(String type, double balance, {bool showZero = true}) {
    final display = (!showZero && balance == 0) ? '' : _fmt(balance);
    return pw.TableRow(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: pw.Text(type,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: pw.Text(display,
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.right),
      ),
    ]);
  }

  // ─── Employee + Bank row: 4 sections ────────────────────────────────────
  static pw.Widget _employeeBankRow(Map<String, dynamic> e) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section 1+2 combined: each row has label + red box on same line
          pw.Expanded(
            flex: 9,
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _empRow('CODE',               e['pay_code']),
                  _empRow('NAME',               e['name']),
                  _empRow("FATHER'S/HUSB. NAME", e['f_name']),
                  _empRow('DESIGNATION',        e['des_name']),
                  _empRow('DEPT',               e['dep_name']),
                  _empRow('DOJ',                _fmtDate(e['doj1'])),
                  _empRow('UNIT',               e['unit'] ?? e['loc_name']),
                ],
              ),
            ),
          ),

          // Section 3: Bank labels
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.3)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _bankLbl('BANK NAME'),
                  _bankLbl('A/c No'),
                  _bankLbl('PF No'),
                  _bankLbl('UAN'),
                  _bankLbl('PAY MODE'),
                  _bankLbl('ESI No'),
                  _bankLbl('PAN'),
                  _bankLbl('AADHAR NO'),
                ],
              ),
            ),
          ),

          // Section 4: Bank values
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _bankVal(e['bank_name'], bold: true),
                _bankVal(e['bank_no']),
                _bankVal(e['pf_no']),
                _bankVal(e['uan']),
                _bankVal(e['pay_mode']),
                _bankVal(e['esi_no']),
                _bankVal(e['pan']),
                _bankVal(e['adh_no']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One row: bold label on left + value on right
  static pw.Widget _empRow(String label, dynamic value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(value?.toString() ?? '',
                style: const pw.TextStyle(fontSize: 8.5)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _bankLbl(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(label,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _bankVal(dynamic value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        value?.toString() ?? '',
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ─── ROW 3: Salary table ─────────────────────────────────────────────────
  static pw.Widget _salarySection(Map<String, dynamic> e, Map<String, dynamic> pay) {
    // Resolve deduction amounts from `pay` object (correct per-item values)
    // falling back to `ded*` fields for PF/ESI/Loan
    final dedPf      = _d(pay['PF']      ?? e['ded1']);
    final dedEsi     = _d(pay['ESI']     ?? e['ded2']);
    final dedTds     = _d(pay['TDS']     ?? 0);
    final dedLoan    = _d(pay['Loan']    ?? e['ded4']);
    final dedGmi     = _d(pay['GMI']     ?? 0);
    final dedAdvance = _d(pay['Advance'] ?? 0);
    final dedLwf     = _d(pay['LWF']     ?? 0);
    final dedCanteen = _d(pay['Canteen'] ?? 0);
    final dedPtax    = _d(pay['P.Tax']   ?? 0);
    final dedSociety = _d(pay['Society'] ?? 0);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _salaryHeaderRow(),
        _salaryRow('WD',  _fmt(_d(e['wday'])), 'Basic',      e['rat1'], e['earn1'], e['arr1'], e['total1'], 'P F',     dedPf),
        _salaryRow('WO',  _fmt(_d(e['wf'])),   'HRA',        e['rat2'], e['earn2'], e['arr2'], e['total2'], 'ESIC',    dedEsi),
        _salaryRow('HD',  _fmt(_d(e['hd'])),   'Adv. Bonus', e['rat3'], e['earn3'], e['arr3'], e['total3'], 'TDS',     dedTds),
        _salaryRow('CL',  _fmt(_d(e['cl'])),   'LTA',        e['rat4'], e['earn4'], e['arr4'], e['total4'], 'Loan',    dedLoan),
        _salaryRow('EL',  _fmt(_d(e['el'])),   'Spl Allow',  e['rat5'], e['earn5'], e['arr5'], e['total5'], 'GMI',     dedGmi),
        _salaryRow('SL',  _fmt(_d(e['sl'])),   'CEA',        e['rat6'], e['earn6'], e['arr6'], e['total6'], 'Advance', dedAdvance),
        _salaryRow('ML',  _fmt(_d(e['ml'])),   'HEA',        e['rat7'], e['earn7'], e['arr7'], e['total7'], 'LWF',     dedLwf),
        _salaryRow('CO',  _fmt(_d(e['coff'])), '',           null,      null,       null,      null,        'Canteen', dedCanteen),
        _salaryRow('ESI', '0.0',               '',           null,      null,       null,      null,        'P.tax',   dedPtax),
        _salaryRow('BL',  '0.0',               '',           null,      null,       null,      null,        'Society', dedSociety),
        _totalRow(e),
        // Absent Days row – immediately after PAYABLE DAYS
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.3)),
          ),
          child: pw.Row(
            children: [
              // Absent Days label — no border on right
              pw.SizedBox(
                width: 68,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: pw.Text('Absent Days',
                      style: const pw.TextStyle(fontSize: 8)),
                ),
              ),
              // Absent days value
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: pw.Text(_fmt(_d(e['absent_days'])),
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
              ),
              // Divider then net pay in words — spans all middle + deduction columns
              pw.Expanded(
                flex: 23,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: PdfColors.black, width: 0.5),
                      right: pw.BorderSide(color: PdfColors.black, width: 0.3),
                    ),
                  ),
                  child: pw.Text(
                    'RUPEES ${_numberToWords(_d(e["net_sal"]))} ONLY',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ),
              // Net amount — aligns with last deduction amount column (flex:3)
              pw.Expanded(
                flex: 3,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: pw.Text(
                    _fmt(_d(e['net_sal'])),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _salaryHeaderRow() {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
      ),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 68,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.5)),
            ),
            child: pw.Text('WD',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.left),
          ),
        ),
        _sh('SALARY HEAD', flex: 4),
        _sh('SALARY RATE', flex: 4),
        _sh('EARNINGS',    flex: 4),
        _sh('AREAR',       flex: 3),
        _sh('TOTAL',       flex: 4),
        _sh('DEDUCTIONS',  flex: 4),
        _sh('',            flex: 3),
      ]),
    );
  }

  static pw.Widget _salaryRow(
    String wdLabel,
    String wdValue,
    String head,
    dynamic rate,
    dynamic earn,
    dynamic arr,
    dynamic total,
    String dedLabel,
    dynamic dedAmt,
  ) {
    final totalVal = total != null ? _d(total) : 0.0;
    final isBold = totalVal != 0;

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.3)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // WD cell – label on left, value on right (side by side)
          pw.SizedBox(
            width: 68,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.3)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(wdLabel,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(wdValue,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ),
          // Salary head
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.3)),
              ),
              child: pw.Text(head.isNotEmpty ? '|$head' : '',
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          ),
          _sc(rate  != null ? _fmt(_d(rate))  : '', flex: 4, right: true),
          _sc(earn  != null ? _fmt(_d(earn))  : '', flex: 4, right: true),
          _sc(arr   != null ? _fmt(_d(arr))   : '', flex: 3, right: true),
          // Total – bold when non-zero
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.3)),
              ),
              child: pw.Text(
                total != null ? _fmt(totalVal) : '',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
          // Deduction label
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.3)),
              ),
              child: pw.Text(dedLabel.isNotEmpty ? '|$dedLabel' : '',
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          ),
          // Deduction amount
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: pw.Text(
                _d(dedAmt) != 0 ? _fmt(_d(dedAmt)) : '0',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(Map<String, dynamic> e) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 0.5),
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Row(children: [
        // PAYABLE DAYS + value — no border between them
        pw.SizedBox(
          width: 68,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Text('PAYABLE DAYS',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        // Payable days value
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Text(_fmt(_d(e['pday'])),
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        // Divider then "Total"
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.black, width: 0.5),
                right: pw.BorderSide(color: PdfColors.black, width: 0.3),
              ),
            ),
            child: pw.Text('Total',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right),
          ),
        ),
        // SALARY RATE total
        _stc(_fmt(_d(e['total_salary'])),   flex: 4),
        // EARNINGS total
        _stc(_fmt(_d(e['total_earnings'])), flex: 4),
        // AREAR total
        _stc('0.00',                        flex: 3),
        // TOTAL col
        _stc(_fmt(_d(e['tot_sal'])),        flex: 4),
        // DEDUCTIONS label (empty)
        _stc('',                            flex: 4),
        // DEDUCTIONS amount
        _stc(_fmt(_d(e['tot_ded'])),        flex: 3),
      ]),
    );
  }

  // ─── FOOTER ──────────────────────────────────────────────────────────────
  static pw.Widget _footer(Map<String, dynamic> e) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        'This is Computer generated Pay Slip. Hence, Signature does not required.',
        style: const pw.TextStyle(fontSize: 8),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ─── CELL HELPERS ────────────────────────────────────────────────────────
  static pw.Widget _tc(String text, {bool bold = false, double fs = 8}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: fs,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _sh(String text, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.3)),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
      ),
    );
  }

  static pw.Widget _sc(String text, {int flex = 1, bool right = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(3),
        decoration: const pw.BoxDecoration(
          border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.3)),
        ),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left),
      ),
    );
  }

  static pw.Widget _stc(String text, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.3)),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.right),
      ),
    );
  }

  // ─── UTILITY ─────────────────────────────────────────────────────────────
  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

  static String _fmt(double v) => v.toStringAsFixed(1);

  static String _fmtDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return '';
    try {
      final d = DateTime.parse(dateStr.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return dateStr.toString();
    }
  }

  static String _getMonthName(String m) {
    const names = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final i = (int.tryParse(m) ?? 1) - 1;
    return (i >= 0 && i < 12) ? names[i] : 'JAN';
  }

  static String _numberToWords(double number) {
    int amount = number.toInt();
    if (amount == 0) return 'ZERO';
    const ones = ['','ONE','TWO','THREE','FOUR','FIVE','SIX','SEVEN','EIGHT','NINE'];
    const teens = ['TEN','ELEVEN','TWELVE','THIRTEEN','FOURTEEN','FIFTEEN','SIXTEEN','SEVENTEEN','EIGHTEEN','NINETEEN'];
    const tens = ['','','TWENTY','THIRTY','FORTY','FIFTY','SIXTY','SEVENTY','EIGHTY','NINETY'];
    String below1000(int n) {
      if (n == 0) return '';
      String r = '';
      if (n >= 100) { r += '${ones[n ~/ 100]} HUNDRED '; n %= 100; }
      if (n >= 20) { r += '${tens[n ~/ 10]} '; n %= 10; if (n > 0) r += '${ones[n]} '; }
      else if (n >= 10) { r += '${teens[n - 10]} '; }
      else if (n > 0) { r += '${ones[n]} '; }
      return r;
    }
    String result = '';
    if (amount >= 10000000) { result += '${below1000(amount ~/ 10000000)}CRORE '; amount %= 10000000; }
    if (amount >= 100000)   { result += '${below1000(amount ~/ 100000)}LAKH ';    amount %= 100000; }
    if (amount >= 1000)     { result += '${below1000(amount ~/ 1000)}THOUSAND ';  amount %= 1000; }
    if (amount > 0) result += below1000(amount);
    return result.trim();
  }
}
