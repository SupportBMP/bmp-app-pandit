import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/json.dart';

enum ChartStyle { south, north, east }

const _signAbbr = ['Ar', 'Ta', 'Ge', 'Cn', 'Le', 'Vi', 'Li', 'Sc', 'Sg', 'Cp', 'Aq', 'Pi'];
const _planetAbbr = {
  'Sun': 'Su',
  'Moon': 'Mo',
  'Mars': 'Ma',
  'Mercury': 'Me',
  'Jupiter': 'Ju',
  'Venus': 'Ve',
  'Saturn': 'Sa',
  'Rahu': 'Ra',
  'Ketu': 'Ke',
  'Ascendant': 'Asc',
};
// (row, col) of each sign in the 4×4 grid.
const _south = [(0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (3, 3), (3, 2), (3, 1), (3, 0), (2, 0), (1, 0), (0, 0)];
const _east = [(0, 0), (0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (3, 3), (3, 2), (3, 1), (3, 0), (2, 0), (1, 0)];
// North Indian house polygons in unit coordinates.
const _niHouses = [
  [
    [.5, 0.0],
    [.75, .25],
    [.5, .5],
    [.25, .25],
  ],
  [
    [0.0, 0.0],
    [.5, 0.0],
    [.25, .25],
  ],
  [
    [0.0, 0.0],
    [.25, .25],
    [0.0, .5],
  ],
  [
    [.25, .25],
    [.5, .5],
    [.25, .75],
    [0.0, .5],
  ],
  [
    [0.0, .5],
    [.25, .75],
    [0.0, 1.0],
  ],
  [
    [0.0, 1.0],
    [.25, .75],
    [.5, 1.0],
  ],
  [
    [.25, .75],
    [.5, .5],
    [.75, .75],
    [.5, 1.0],
  ],
  [
    [.5, 1.0],
    [.75, .75],
    [1.0, 1.0],
  ],
  [
    [.75, .75],
    [1.0, .5],
    [1.0, 1.0],
  ],
  [
    [.75, .25],
    [1.0, .5],
    [.75, .75],
    [.5, .5],
  ],
  [
    [1.0, 0.0],
    [1.0, .5],
    [.75, .25],
  ],
  [
    [.5, 0.0],
    [1.0, 0.0],
    [.75, .25],
  ],
];

const _bg = Color(0xFFFFF7F0);
const _line = Color(0xFFD4A574);
const _border = Color(0xFFC4956A);
const _signColor = Color(0xFFA0785C);
const _ink = Color(0xFF30211D);

/// Rasi chart in South, North or East Indian layout (KundliResultsScreen.js).
class RasiChart extends StatelessWidget {
  const RasiChart({super.key, required this.planets, required this.ascendant, required this.style, required this.size});
  final List<Json> planets;
  final int ascendant;
  final ChartStyle style;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _ChartPainter(_bySign(planets), ascendant, style));

  static Map<int, List<String>> _bySign(List<Json> ps) {
    final m = {for (var i = 0; i < 12; i++) i: <String>[]};
    for (final p in ps) {
      final s = intOf(p['sign_num'], -1);
      if (m.containsKey(s)) m[s]!.add(_planetAbbr[str(p['name'])] ?? str(p['name']).padRight(2).substring(0, 2));
    }
    return m;
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.signs, this.asc, this.style);
  final Map<int, List<String>> signs;
  final int asc;
  final ChartStyle style;

  void _text(Canvas c, String s, Offset at, {double size = 11, Color color = _ink, bool bold = false, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.center => at.dx - tp.width / 2,
      TextAlign.right => at.dx - tp.width,
      _ => at.dx,
    };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas c, Size size) {
    final s = size.width;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    c.drawRRect(rr, Paint()..color = _bg);
    if (style == ChartStyle.north) {
      _north(c, s);
    } else {
      _grid(c, s, style == ChartStyle.south ? _south : _east, style == ChartStyle.south);
    }
    c.drawRRect(
      rr,
      Paint()
        ..color = _border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _grid(Canvas c, double s, List<(int, int)> pos, bool diagonal) {
    final cell = s / 4;
    final p = Paint()
      ..color = _line
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final skipInner = i == 2;
      if (skipInner) {
        // Inner lines stop at the 2×2 centre.
        c.drawLine(Offset(i * cell, 0), Offset(i * cell, cell), p);
        c.drawLine(Offset(i * cell, 3 * cell), Offset(i * cell, s), p);
        c.drawLine(Offset(0, i * cell), Offset(cell, i * cell), p);
        c.drawLine(Offset(3 * cell, i * cell), Offset(s, i * cell), p);
      } else {
        c.drawLine(Offset(i * cell, 0), Offset(i * cell, s), p);
        c.drawLine(Offset(0, i * cell), Offset(s, i * cell), p);
      }
    }
    final thin = Paint()
      ..color = _line
      ..strokeWidth = .8;
    if (diagonal) {
      c.drawLine(Offset(cell, cell), Offset(3 * cell, 3 * cell), thin);
      c.drawLine(Offset(3 * cell, cell), Offset(cell, 3 * cell), thin);
    } else {
      c.drawLine(Offset(2 * cell, cell), Offset(2 * cell, 3 * cell), thin);
      c.drawLine(Offset(cell, 2 * cell), Offset(3 * cell, 2 * cell), thin);
    }
    final fs = (cell / 7).clamp(9.0, 13.0);
    for (var i = 0; i < 12; i++) {
      final (r, col) = pos[i];
      final x = col * cell, y = r * cell;
      _text(c, _signAbbr[i], Offset(x + 4, y + 10), size: fs - 2, color: _signColor);
      if (i == asc) _text(c, '★', Offset(x + cell - 4, y + 10), size: fs - 1, color: AppColors.bluntRed, bold: true, align: TextAlign.right);
      final ps = signs[i]!;
      for (var k = 0; k < ps.length; k++) {
        _text(
          c,
          ps[k],
          Offset(x + 8 + (k % 3) * (cell / 3.2), y + 28 + (k ~/ 3) * (fs + 5)),
          size: fs,
          bold: true,
          color: ps[k] == 'Asc' ? AppColors.bluntRed : _ink,
        );
      }
    }
    _text(c, 'Rasi', Offset(s / 2, s / 2 - 8), size: 14, bold: true, color: AppColors.bluntRed, align: TextAlign.center);
    _text(
      c,
      style == ChartStyle.south ? 'South Indian' : 'East Indian',
      Offset(s / 2, s / 2 + 10),
      size: 10,
      color: AppColors.mutedForeground,
      align: TextAlign.center,
    );
  }

  void _north(Canvas c, double s) {
    final hl = Path();
    final h0 = _niHouses[0];
    hl.moveTo(h0[0][0] * s, h0[0][1] * s);
    for (final pt in h0.skip(1)) {
      hl.lineTo(pt[0] * s, pt[1] * s);
    }
    c.drawPath(hl..close(), Paint()..color = const Color(0xFFFFF0E0));

    final strong = Paint()
      ..color = _border
      ..strokeWidth = 1.2;
    c.drawLine(Offset(s * .5, 0), Offset(s, s * .5), strong);
    c.drawLine(Offset(s, s * .5), Offset(s * .5, s), strong);
    c.drawLine(Offset(s * .5, s), Offset(0, s * .5), strong);
    c.drawLine(Offset(0, s * .5), Offset(s * .5, 0), strong);
    final thin = Paint()
      ..color = _line
      ..strokeWidth = .8;
    c.drawLine(Offset.zero, Offset(s, s), thin);
    c.drawLine(Offset(s, 0), Offset(0, s), thin);

    for (var h = 0; h < 12; h++) {
      final poly = _niHouses[h];
      final diamond = poly.length == 4;
      var cx = poly.fold<double>(0, (a, p) => a + p[0]) / poly.length * s;
      var cy = poly.fold<double>(0, (a, p) => a + p[1]) / poly.length * s;
      final pull = diamond ? .08 : .22;
      cx += (s / 2 - cx) * pull;
      cy += (s / 2 - cy) * pull;
      final sign = (asc + h) % 12;
      final ps = signs[sign]!;
      final perRow = diamond ? 3 : 2;
      final gap = diamond ? 24.0 : 18.0;
      final fs = diamond ? 11.0 : 9.5;
      _text(
        c,
        '${_signAbbr[sign]}${h == 0 ? ' ★' : ''}',
        Offset(cx, cy - (ps.isNotEmpty ? (diamond ? 12 : 8) : 0)),
        size: diamond ? 9.5 : 8.5,
        color: h == 0 ? AppColors.bluntRed : _signColor,
        bold: h == 0,
        align: TextAlign.center,
      );
      for (var k = 0; k < ps.length; k++) {
        final row = k ~/ perRow, col = k % perRow;
        final inRow = (ps.length - row * perRow).clamp(1, perRow);
        _text(
          c,
          ps[k],
          Offset(cx + (col - (inRow - 1) / 2) * gap, cy + 5 + row * (fs + 4)),
          size: fs,
          bold: true,
          color: ps[k] == 'Asc' ? AppColors.bluntRed : _ink,
          align: TextAlign.center,
        );
      }
    }
    final badge = Path()
      ..moveTo(s / 2, s / 2 - 20)
      ..lineTo(s / 2 + 20, s / 2)
      ..lineTo(s / 2, s / 2 + 20)
      ..lineTo(s / 2 - 20, s / 2)
      ..close();
    c.drawPath(badge, Paint()..color = _bg);
    c.drawPath(
      badge,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
    _text(c, 'Rasi', Offset(s / 2, s / 2), size: 10, bold: true, color: AppColors.bluntRed, align: TextAlign.center);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.style != style || old.asc != asc || old.signs != signs;
}
