import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para clipboard
// import 'package:google_mobile_ads/google_mobile_ads.dart'; // Só funciona em mobile
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_cef/webview_cef.dart' as cef;
import 'package:printing/printing.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, Platform;

// Base única de produção (HTTPS). Para trocar sem editar código,
// use: --dart-define=API_BASE_URL=https://seu-dominio.app
const String kProductionApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://lotosmart-api-production.up.railway.app',
);

const kLotofacilPurple = Color(0xFF7B1FA2);
const kLotofacilPurpleGlow = Color(0xFFA855F7);
const kSignalGreen = Color(0xFF16C784);
const kComplianceAcceptedKey = 'compliance_accepted_v1';
const kCaixaBlue = Color(0xFF005CA9);
const kThemeModeStorageKey = 'isDarkMode';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(kThemeModeStorageKey) ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kThemeModeStorageKey, _themeMode == ThemeMode.dark);
  }
}

final ThemeService kThemeService = ThemeService();

ThemeData buildLightTheme() {
  const lightText = Color(0xFF1E293B);
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kLotofacilPurple,
      brightness: Brightness.light,
      primary: kLotofacilPurple,
      surface: const Color(0xFFFFFFFF),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    cardColor: const Color(0xFFFFFFFF),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kLotofacilPurple,
      elevation: 1,
      surfaceTintColor: Colors.white,
      titleTextStyle: GoogleFonts.robotoMono(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: kLotofacilPurple,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: GoogleFonts.robotoMonoTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightText),
        bodySmall: TextStyle(color: Color(0xFF475569)),
        titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(color: lightText, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D9E6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D9E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kLotofacilPurple, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF475569)),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kLotofacilPurple,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kLotofacilPurple,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kLotofacilPurple,
        side: const BorderSide(color: kLotofacilPurple, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconTheme: const IconThemeData(color: kLotofacilPurple),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF6366F1),
      onPrimary: Colors.white,
      secondary: kLotofacilPurpleGlow,
      onSecondary: const Color(0xFF000000),
      surface: const Color(0xFF0F1419),
      onSurface: const Color(0xFFE5E7EB),
      error: const Color(0xFFFF4444),
      onError: Colors.white,
      outline: const Color(0xFF3F4655),
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0A0E12),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F1419),
      foregroundColor: Color(0xFFE5E7EB),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE5E7EB),
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1F2E),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2D3748), width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1F2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2D3748)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2D3748)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFFAEB9C7)),
      hintStyle: TextStyle(color: const Color(0xFFAEB9C7).withOpacity(0.6)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: const Color(0xFF6366F1),
      foregroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6366F1),
        side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: GoogleFonts.robotoMonoTextTheme(
      const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFE5E7EB)),
        bodySmall: TextStyle(color: Color(0xFFAEB9C7)),
        labelLarge: TextStyle(
          color: Color(0xFFE5E7EB),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        titleLarge: TextStyle(
          color: Color(0xFFE5E7EB),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF6366F1)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF6366F1),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6366F1), width: 1),
      ),
      textStyle: const TextStyle(color: kLotofacilPurpleGlow, fontSize: 12),
    ),
  );
}

Widget buildResponsibleFooter(BoxConstraints c, {double bottom = 30}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(
      c.maxWidth * 0.04,
      0,
      c.maxWidth * 0.04,
      bottom,
    ),
    child: Text(
      'A IA não garante prêmios. Jogue com responsabilidade.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: (c.maxWidth * 0.028).clamp(10.0, 12.0),
        color: Colors.grey[500],
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await kThemeService.load();

  runApp(const LotoApp());
}

class ResultadosPage extends StatelessWidget {
  final List<JogoIA> jogos;
  final Diagnostico? diagnostico;
  final String estrategia;
  final DateTime? dataHoraBase;

  const ResultadosPage({
    super.key,
    required this.jogos,
    required this.diagnostico,
    required this.estrategia,
    this.dataHoraBase,
  });

  void _compartilharTodos() {
    final buffer = StringBuffer();
    buffer.writeln('LotoSmart');
    buffer.writeln('Estrategia: ${estrategia.toUpperCase()}');
    buffer.writeln('');
    for (int i = 0; i < jogos.length; i++) {
      final j = jogos[i];
      buffer.writeln('Jogo ${i + 1} | IA Rating: ${j.iaRating}/1000');
      buffer.writeln(j.numeros.join(', '));
      buffer.writeln('');
    }
    Share.share(buffer.toString());
  }

  void _compartilharUm(int i) {
    final jogo = jogos[i];
    Share.share(
      'Jogo ${i + 1} | IA Rating: ${jogo.iaRating}/1000\n${jogo.numeros.join(', ')}',
    );
  }

  String _doisDigitos(int n) => n.toString().padLeft(2, '0');

  String _dataHoraEmissao() {
    final agora = dataHoraBase ?? DateTime.now();
    return '${_doisDigitos(agora.day)}/${_doisDigitos(agora.month)}/${agora.year} '
        '${_doisDigitos(agora.hour)}:${_doisDigitos(agora.minute)}';
  }

  pw.Widget _fundoTimbrado() {
    return pw.Positioned.fill(
      child: pw.Opacity(
        opacity: 0.08,
        child: pw.Center(
          child: pw.Transform.rotateBox(
            angle: -0.40,
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: 160,
                  height: 160,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(
                      color: PdfColor.fromInt(0xFF7B1FA2),
                      width: 3,
                    ),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'LIA',
                    style: pw.TextStyle(
                      fontSize: 58,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF7B1FA2),
                    ),
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'LOTOSMART',
                  style: pw.TextStyle(
                    fontSize: 40,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF7B1FA2),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  pw.Widget _cartelaNumeros(List<int> numeros) {
    final ordenados = List<int>.from(numeros)..sort();
    return pw.Wrap(
      alignment: pw.WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: ordenados
          .map(
            (n) => pw.Container(
              width: 34,
              height: 34,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColor.fromInt(0xFF7B1FA2),
                border: pw.Border.all(
                  color: PdfColor.fromInt(0xFFA855F7),
                  width: 1.2,
                ),
              ),
              child: pw.Text(
                n.toString().padLeft(2, '0'),
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFFFFFFFF),
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Page _buildPaginaJogo({
    required int index,
    required JogoIA jogo,
    required String emissao,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.fromLTRB(16, 16, 16, 16),
      build: (_) => pw.Stack(
        children: [
          _fundoTimbrado(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF5EAFB),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xFF7B1FA2),
                    width: 1,
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'LOTOSMART',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF4A148C),
                      ),
                    ),
                    pw.Text(
                      'Emitido: $emissao',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'JOGO ${index + 1}  |  IA Rating: ${jogo.iaRating}/1000',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Estrategia: ${estrategia.toUpperCase()}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFFFFF),
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xFF4A148C),
                    width: 1.2,
                  ),
                ),
                child: _cartelaNumeros(jogo.numeros),
              ),
              pw.Spacer(),
              pw.Text(
                'Uso pessoal | Nao garante premiacao | Confira sempre no canal oficial',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColor.fromInt(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _gerarPDFUm(BuildContext context, int i) async {
    try {
      final jogo = jogos[i];
      final pdf = pw.Document();
      final emissao = _dataHoraEmissao();

      pdf.addPage(_buildPaginaJogo(index: i, jogo: jogo, emissao: emissao));

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'lotofacil_jogo_${i + 1}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF do jogo: $e')),
        );
      }
    }
  }

  Future<void> _gerarPDFTodos(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final emissao = _dataHoraEmissao();

      for (int i = 0; i < jogos.length; i++) {
        final jogo = jogos[i];
        pdf.addPage(_buildPaginaJogo(index: i, jogo: jogo, emissao: emissao));
      }

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'lotofacil_10_jogos.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF dos jogos: $e')),
        );
      }
    }
  }

  void _abrirSiteCaixa(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          url:
              'https://loterias.caixa.gov.br/wps/portal/loterias/landing/lotofacil',
          title: 'Lotofácil - Caixa',
          jogos: jogos
              .map((j) => {'jogo': j.numeros, 'ia_rating': j.iaRating})
              .toList(),
        ),
      ),
    );
  }

  Widget _rating(int rating) {
    final Color cor = rating >= 800
        ? kSignalGreen
        : rating >= 600
        ? const Color(0xFFFFA500)
        : const Color(0xFFFF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IA Rating: $rating / 1000',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold, color: cor),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: rating / 1000,
          backgroundColor: const Color(0xFF2D3748),
          valueColor: AlwaysStoppedAnimation(cor),
          minHeight: 7,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.0),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: FloatingActionButton.extended(
          onPressed: () => _abrirSiteCaixa(context),
          backgroundColor: kCaixaBlue,
          foregroundColor: Colors.white,
          elevation: 10,
          icon: const Icon(Icons.account_balance_wallet, size: 22),
          label: const Text(
            'Finalizar Apostas no Site Oficial',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final pad = c.maxWidth * 0.04;
          final expanded = (c.maxHeight * 0.35).clamp(180.0, 320.0);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: false,
                expandedHeight: expanded,
                backgroundColor: theme.appBarTheme.backgroundColor,
                surfaceTintColor: theme.appBarTheme.surfaceTintColor,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 12, pad, 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2D3748)
                                : const Color(0xFFD1D9E6),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ESTRATEGIA APLICADA',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              estrategia.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: kLotofacilPurple,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              diagnostico?.regimeDescricao ??
                                  'Analise estatistica aplicada aos jogos gerados.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 6, pad, 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _compartilharTodos,
                        icon: const Icon(Icons.share),
                        label: const Text('Compartilhar Todos'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _gerarPDFTodos(context),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF Todos'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
                  child: Text(
                    'Este app não armazena suas senhas. O login é processado com total segurança pelos servidores da Caixa Econômica Federal.',
                    style: TextStyle(
                      fontSize: (c.maxWidth * 0.027).clamp(10.0, 12.0),
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 96),
                sliver: SliverList.builder(
                  itemCount: jogos.length,
                  itemBuilder: (context, i) {
                    final jogo = jogos[i];
                    final sizeBall = (c.maxWidth * 0.08).clamp(30.0, 36.0);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'JOGO ${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    jogo.tag,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _rating(jogo.iaRating),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: jogo.numeros
                                  .map(
                                    (n) => Container(
                                      width: sizeBall,
                                      height: sizeBall,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? kLotofacilPurple
                                            : theme.colorScheme.primary
                                                  .withOpacity(0.18),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFFCE93D8)
                                              : theme.colorScheme.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          child: Text(
                                            n.toString().padLeft(2, '0'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : kLotofacilPurple,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => _compartilharUm(i),
                                    icon: const Icon(Icons.share, size: 16),
                                    label: const Text('Compartilhar Jogo'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _gerarPDFUm(context, i),
                                    icon: const Icon(
                                      Icons.picture_as_pdf,
                                      size: 16,
                                    ),
                                    label: const Text('PDF Jogo'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(child: buildResponsibleFooter(c)),
            ],
          );
        },
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final List<dynamic>? jogos;

  const WebViewScreen({
    required this.url,
    required this.title,
    this.jogos,
    super.key,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with CodeAutoFill {
  // Mobile (Android/iOS)
  WebViewController? _mobileController;
  WebViewCookieManager? _cookieManager;
  static const String _cookieStorageKey = 'caixa_webview_cookies_v1';
  static const String _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';
  // Desktop/Windows (CEF)
  late final cef.WebViewController _cefController;
  int jogoAtualOverlay = 0;
  bool overlayHovered = false;
  bool overlayMinimizado = false;
  Offset? overlayOffset;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      _cookieManager = WebViewCookieManager();
      final PlatformWebViewControllerCreationParams params =
          const PlatformWebViewControllerCreationParams();
      final controller = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(onPageFinished: _onMobilePageFinished),
        );

      // Em Android, o DOM Storage do WebView já vem habilitado por padrão.
      // Mantemos JavaScript e recursos do browser ativos para integração com
      // o gerenciador de senhas do sistema.
      if (controller.platform is AndroidWebViewController) {
        AndroidWebViewController.enableDebugging(false);
        (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }

      _mobileController = controller;
      _initMobileWebView();
      if (Platform.isAndroid) {
        listenForCode();
      }
    } else {
      // Desktop: usa CEF
      _cefController = cef.WebviewManager().createWebView(
        loading: const Center(child: CircularProgressIndicator()),
      );
      // Aguarda o primeiro frame para que o widget CEF tenha um view ID válido
      // antes de chamar initialize(), evitando PlatformException.
      WidgetsBinding.instance.addPostFrameCallback((_) => _initCef());
    }
  }

  Future<void> _initCef() async {
    try {
      // Passa user agent mobile na primeira inicialização do processo CEF para
      // que o servidor da Caixa entregue o layout responsivo mobile.
      if (!cef.WebviewManager().value) {
        await cef.WebviewManager().initialize(userAgent: _mobileUserAgent);
      }
      await _cefController.initialize(widget.url);
      // Injeta viewport após cada carregamento de página para garantir que as
      // media queries CSS respondam ao tamanho real do widget.
      _cefController.setWebviewListener(
        cef.WebviewEventsListener(
          onLoadEnd: (controller, url) => _onCefPageFinished(controller),
        ),
      );
      if (mounted) setState(() {});
    } catch (_) {
      // PlatformException de inicialização CEF é não-crítica;
      // o webviewWidget já exibirá o indicador de carregamento.
    }
  }

  static const String _responsiveViewportScript = '''
    (function() {
      var m = document.querySelector('meta[name="viewport"]');
      if (!m) {
        m = document.createElement('meta');
        m.name = 'viewport';
        document.head.appendChild(m);
      }
      m.content = 'width=device-width, initial-scale=0.92, maximum-scale=5.0, user-scalable=yes';

      var root = document.documentElement;
      var body = document.body;
      if (root) {
        root.style.overflowX = 'hidden';
      }
      if (body) {
        body.style.overflowX = 'hidden';
        body.style.minWidth = '0';
      }
    })();
  ''';

  void _onCefPageFinished(cef.WebViewController controller) {
    controller.executeJavaScript(_responsiveViewportScript);
  }

  Future<void> _initMobileWebView() async {
    final controller = _mobileController;
    if (controller == null) return;

    await _restoreCookies();
    await controller.setUserAgent(_mobileUserAgent);
    await controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _onMobilePageFinished(String _) async {
    final controller = _mobileController;
    if (controller != null) {
      try {
        await controller.runJavaScript(_responsiveViewportScript);
      } catch (_) {
        // Falha silenciosa para não interromper a navegação.
      }
    }
    await _syncCookiesToStorage();
  }

  Future<void> _syncCookiesToStorage() async {
    final controller = _mobileController;
    if (controller == null) return;
    try {
      final raw = await controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final normalized = _normalizeJsString(raw);
      if (normalized.trim().isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cookieStorageKey, normalized);
    } catch (_) {
      // Falha silenciosa: alguns cookies podem ser HttpOnly e indisponíveis no JS.
    }
  }

  Future<void> _restoreCookies() async {
    final manager = _cookieManager;
    if (manager == null) return;
    final prefs = await SharedPreferences.getInstance();
    final serialized = prefs.getString(_cookieStorageKey);
    if (serialized == null || serialized.trim().isEmpty) return;

    final pairs = serialized.split(';');
    for (final pair in pairs) {
      final token = pair.trim();
      if (token.isEmpty || !token.contains('=')) continue;
      final idx = token.indexOf('=');
      final name = token.substring(0, idx).trim();
      final value = token.substring(idx + 1).trim();
      if (name.isEmpty) continue;

      await manager.setCookie(
        WebViewCookie(
          name: name,
          value: value,
          domain: '.caixa.gov.br',
          path: '/',
        ),
      );
      await manager.setCookie(
        WebViewCookie(
          name: name,
          value: value,
          domain: 'loterias.caixa.gov.br',
          path: '/',
        ),
      );
    }
  }

  String _normalizeJsString(Object value) {
    var text = value.toString().trim();
    if ((text.startsWith('"') && text.endsWith('"')) ||
        (text.startsWith("'") && text.endsWith("'"))) {
      text = text.substring(1, text.length - 1);
    }
    return text;
  }

  @override
  void codeUpdated() {
    final current = code;
    if (current == null || current.trim().isEmpty) return;
    _injectOtpCode(current);
  }

  Future<void> _injectOtpCode(String incoming) async {
    final controller = _mobileController;
    if (controller == null) return;

    final otp = _extractOtp(incoming);
    if (otp == null) return;

    final escaped = otp.replaceAll("'", "\\'");
    final js =
        '''
      (function(code) {
        const selectors = [
          'input[autocomplete="one-time-code"]',
          'input[name*="otp" i]',
          'input[name*="token" i]',
          'input[name*="codigo" i]',
          'input[id*="otp" i]',
          'input[id*="token" i]',
          'input[id*="codigo" i]',
          'input[type="tel"]',
          'input[type="number"]'
        ];
        let target = null;
        for (const s of selectors) {
          target = document.querySelector(s);
          if (target) break;
        }
        if (!target) {
          const inputs = Array.from(document.querySelectorAll('input'));
          target = inputs.find((el) => {
            const text = ((el.name || '') + ' ' + (el.id || '') + ' ' + (el.placeholder || '')).toLowerCase();
            return text.includes('codigo') || text.includes('token') || text.includes('otp') || text.includes('sms');
          });
        }
        if (!target) return false;
        target.focus();
        target.value = code;
        target.dispatchEvent(new Event('input', { bubbles: true }));
        target.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
      })('$escaped');
    ''';

    try {
      await controller.runJavaScript(js);
    } catch (_) {
      // Falha silenciosa para manter fluxo de navegação estável.
    }
  }

  String? _extractOtp(String source) {
    final match = RegExp(r'\b\d{4,8}\b').firstMatch(source);
    return match?.group(0);
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      cancel();
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      _cefController.dispose();
      // NÃO chamar WebviewManager().quit() aqui — encerraria o processo CEF
      // inteiro e derrubaria o app ao voltar da tela
    }
    super.dispose();
  }

  Widget _buildApostaOverlay(Size viewport) {
    if (widget.jogos == null || widget.jogos!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalJogos = widget.jogos!.length;
    final currentIndex = jogoAtualOverlay.clamp(0, totalJogos - 1);
    final jogoAtual = List<int>.from(
      widget.jogos![currentIndex]['jogo'] as List,
    );

    final bool isCompact = viewport.width < 430;
    final double margin = isCompact ? 10 : 16;
    final double contentPadding = isCompact ? 12 : 14;
    final double fullOverlayWidth = isCompact
        ? (viewport.width * 0.92).clamp(280.0, 360.0)
        : 360.0;
    final double miniOverlayWidth = isCompact ? 170 : 188;
    final double miniOverlayHeight = 52;
    final double bubbleSize = isCompact ? 30 : 32;

    final double numberAreaWidth = fullOverlayWidth - (contentPadding * 2);
    final int numbersPerRow = ((numberAreaWidth + 8) / (bubbleSize + 8))
        .floor()
        .clamp(1, 15);
    final int rows = (jogoAtual.length / numbersPerRow).ceil();
    final double numbersHeight = (rows * bubbleSize) + ((rows - 1) * 8);
    final double fullOverlayHeight =
        contentPadding + 62 + 8 + numbersHeight + contentPadding;

    final Size overlaySize = overlayMinimizado
        ? Size(miniOverlayWidth, miniOverlayHeight)
        : Size(fullOverlayWidth, fullOverlayHeight);

    final double maxX = (viewport.width - overlaySize.width - margin).clamp(
      margin,
      double.infinity,
    );
    final double maxY = (viewport.height - overlaySize.height - margin).clamp(
      margin,
      double.infinity,
    );

    final double initialY = (margin + 24).clamp(margin, maxY);
    final Offset posicaoInicial = Offset(maxX, initialY);
    final Offset posicaoAtual = overlayOffset ?? posicaoInicial;
    final Offset posicaoAjustada = Offset(
      posicaoAtual.dx.clamp(margin, maxX),
      posicaoAtual.dy.clamp(margin, maxY),
    );

    void moverOverlay(DragUpdateDetails details) {
      setState(() {
        final base = overlayOffset ?? posicaoAjustada;
        overlayOffset = Offset(
          (base.dx + details.delta.dx).clamp(margin, maxX),
          (base.dy + details.delta.dy).clamp(margin, maxY),
        );
      });
    }

    if (overlayOffset == null || overlayOffset != posicaoAjustada) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => overlayOffset = posicaoAjustada);
      });
    }

    return Positioned(
      left: posicaoAjustada.dx,
      top: posicaoAjustada.dy,
      child: MouseRegion(
        onEnter: (_) => setState(() => overlayHovered = true),
        onExit: (_) => setState(() => overlayHovered = false),
        child: AnimatedOpacity(
          opacity: overlayHovered ? 1.0 : 0.94,
          duration: const Duration(milliseconds: 180),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: moverOverlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: overlayMinimizado ? miniOverlayWidth : fullOverlayWidth,
              height: overlayMinimizado ? miniOverlayHeight : fullOverlayHeight,
              decoration: BoxDecoration(
                color:
                    (isDark ? const Color(0xFF1E293B) : const Color(0xFF334155))
                        .withOpacity(overlayHovered ? 0.92 : 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.78),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: EdgeInsets.all(contentPadding),
              child: overlayMinimizado
                  ? Row(
                      children: [
                        Container(
                          width: 34,
                          alignment: Alignment.center,
                          child: Container(
                            width: 18,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ver Jogo',
                            style: GoogleFonts.robotoMono(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: isCompact ? 12 : 13,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Restaurar volante',
                          onPressed: () =>
                              setState(() => overlayMinimizado = false),
                          icon: const Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              Center(
                                child: Container(
                                  width: 38,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white30,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: currentIndex > 0
                                        ? () =>
                                              setState(() => jogoAtualOverlay--)
                                        : null,
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Jogo anterior',
                                  ),
                                  Expanded(
                                    child: Text(
                                      'JOGO ${(currentIndex + 1).toString().padLeft(2, '0')} / $totalJogos',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.robotoMono(
                                        color: Colors.white,
                                        fontSize: isCompact ? 12 : 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: currentIndex < (totalJogos - 1)
                                        ? () =>
                                              setState(() => jogoAtualOverlay++)
                                        : null,
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Próximo jogo',
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Minimizar volante',
                                    onPressed: () => setState(
                                      () => overlayMinimizado = true,
                                    ),
                                    icon: const Icon(
                                      Icons.remove,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: numberAreaWidth,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: jogoAtual.map((numero) {
                              return Container(
                                width: bubbleSize,
                                height: bubbleSize,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF7B1FA2,
                                  ).withOpacity(0.72),
                                  border: Border.all(
                                    color: kLotofacilPurpleGlow,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kLotofacilPurpleGlow.withOpacity(
                                        0.28,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 0.4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  numero.toString().padLeft(2, '0'),
                                  style: GoogleFonts.robotoMono(
                                    color: Colors.white,
                                    fontSize: isCompact ? 11 : 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Windows/Desktop: navegador CEF embutido com overlay das apostas
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _cefController,
                  builder: (context, ready, _) {
                    return ready
                        ? SizedBox.expand(child: _cefController.webviewWidget)
                        : const Center(child: CircularProgressIndicator());
                  },
                ),
                _buildApostaOverlay(viewport),
              ],
            );
          },
        ),
      );
    }

    // Mobile: WebView nativo
    final Widget browser = _mobileController != null
        ? WebViewWidget(controller: _mobileController!)
        : const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(children: [browser, _buildApostaOverlay(viewport)]);
        },
      ),
    );
  }
}

class LotoApp extends StatelessWidget {
  const LotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) => ListenableBuilder(
        listenable: kThemeService,
        builder: (context, _) {
          return MaterialApp(
            title: 'LotoSmart',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: kThemeService.themeMode,
            home: const ComplianceGate(),
          );
        },
      ),
    );
  }
}

class ComplianceGate extends StatefulWidget {
  const ComplianceGate({super.key});

  @override
  State<ComplianceGate> createState() => _ComplianceGateState();
}

class _ComplianceGateState extends State<ComplianceGate> {
  late final Future<bool> _acceptedFuture;

  @override
  void initState() {
    super.initState();
    _acceptedFuture = _loadAccepted();
  }

  Future<bool> _loadAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kComplianceAcceptedKey) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _acceptedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF050505),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kLotofacilPurpleGlow),
              ),
            ),
          );
        }

        final accepted = snapshot.data ?? false;
        if (accepted) {
          return const HomePage();
        }
        return const CompliancePage();
      },
    );
  }
}

class CompliancePage extends StatefulWidget {
  const CompliancePage({super.key});

  @override
  State<CompliancePage> createState() => _CompliancePageState();
}

class _CompliancePageState extends State<CompliancePage> {
  bool _salvando = false;
  static final Uri _jogoResponsavelUri = Uri.parse(
    'https://www.caixa.gov.br/loterias/Paginas/jogo-responsavel.aspx',
  );

  Future<void> _aceitarTermos() async {
    if (_salvando) return;
    setState(() => _salvando = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kComplianceAcceptedKey, true);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  Future<void> _abrirJogoResponsavel() async {
    await launchUrl(_jogoResponsavelUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E12),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final pad = c.maxWidth * 0.06;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, 24, pad, 24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF121A23),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF334155),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: kLotofacilPurple.withOpacity(0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '+18',
                              style: TextStyle(
                                color: kLotofacilPurpleGlow,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Uso Consciente e Responsabilidade',
                            style: GoogleFonts.robotoMono(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Este aplicativo é uma ferramenta de auxílio estatístico e análise de tendências. Não realizamos apostas, não temos vínculo com a Caixa Econômica Federal e não garantimos acertos, prêmios ou lucros de qualquer natureza. Loterias são jogos de azar onde a sorte é o fator determinante. Utilize os dados com responsabilidade.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[300],
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Identidade do Produto: Simulador e Analista de Probabilidades.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[300],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Limitação de Responsabilidade: O uso desta ferramenta é de inteira responsabilidade do usuário. As sugestões de jogos são baseadas puramente em cálculos matemáticos sobre dados históricos.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[300],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Proibição: Venda proibida para menores de 18 anos.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFFCA5A5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'O jogo deve ser uma forma de entretenimento, não uma fonte de renda. Se precisar de ajuda, acesse o Jogo Responsável da Caixa.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey[300],
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _abrirJogoResponsavel,
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text(
                              'Abrir Link do Jogo Responsável da Caixa',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _salvando ? null : _aceitarTermos,
                        style: FilledButton.styleFrom(
                          backgroundColor: kLotofacilPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _salvando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Eu tenho +18 anos e aceito os termos',
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: SystemNavigator.pop,
                        child: const Text('Sair'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── MODELOS DE DADOS ────────────────────────────────────────────────────────

class JogoIA {
  final List<int> numeros;
  final int iaRating;
  final String tagEstrategica;
  final String tag;

  JogoIA({
    required this.numeros,
    required this.iaRating,
    required this.tagEstrategica,
    required this.tag,
  });

  factory JogoIA.fromJson(Map<String, dynamic> json) {
    return JogoIA(
      numeros: List<int>.from(json['jogo']),
      iaRating: (json['ia_rating'] as num).toInt(),
      tagEstrategica: json['tag_estrategica'] ?? '',
      tag: json['tag'] ?? '',
    );
  }
}

class Diagnostico {
  final String regimeLabel;
  final double regimeIndex;
  final String regimeDescricao;
  final List<Map<String, dynamic>> hot;
  final List<Map<String, dynamic>> cold;
  final String faixaSoma;
  final String paridadeSugerida;
  final int concursosAnalisados;
  final List<int> atrasadasDetectadas;
  final List<String> melhoresTrincas;
  final String alertaPadrao;
  final double probabilidadePadrao;
  final String faixaDominante;
  final int proximoConcurso;
  final double desvioPadraoSoma;
  final String similaridadeTexto;

  Diagnostico({
    required this.regimeLabel,
    required this.regimeIndex,
    required this.regimeDescricao,
    required this.hot,
    required this.cold,
    required this.faixaSoma,
    required this.paridadeSugerida,
    required this.concursosAnalisados,
    required this.atrasadasDetectadas,
    required this.melhoresTrincas,
    required this.alertaPadrao,
    required this.probabilidadePadrao,
    required this.faixaDominante,
    required this.proximoConcurso,
    required this.desvioPadraoSoma,
    required this.similaridadeTexto,
  });

  factory Diagnostico.fromJson(Map<String, dynamic> json) {
    final inteligencia = (json['inteligencia'] as Map<String, dynamic>?) ?? {};
    final alerta =
        (inteligencia['alerta_padrao'] as Map<String, dynamic>?) ?? {};
    final similaridade =
        (inteligencia['similaridade_ciclica'] as Map<String, dynamic>?) ?? {};
    final similaridadeAnalise =
        (similaridade['analise'] as Map<String, dynamic>?) ?? {};

    return Diagnostico(
      regimeLabel: json['regime']['label'],
      regimeIndex: (json['regime']['index'] as num).toDouble(),
      regimeDescricao: json['regime']['descricao_humana'],
      hot: List<Map<String, dynamic>>.from(json['tendencias']['hot']),
      cold: List<Map<String, dynamic>>.from(json['tendencias']['cold']),
      faixaSoma: json['equilibrio']['faixa_soma'],
      paridadeSugerida: json['equilibrio']['paridade_sugerida'],
      concursosAnalisados: (json['concursos_analisados'] as num).toInt(),
      atrasadasDetectadas: List<int>.from(
        ((inteligencia['atrasadas_detectadas'] as List?) ?? []).map(
          (item) => (item['dezena'] as num).toInt(),
        ),
      ),
      melhoresTrincas: List<String>.from(
        ((inteligencia['melhores_trincas'] as List?) ?? []).map(
          (item) => (item['dezenas'] as List)
              .map((n) => (n as num).toInt().toString().padLeft(2, '0'))
              .join(' '),
        ),
      ),
      alertaPadrao: alerta['mensagem'] ?? '',
      probabilidadePadrao:
          (alerta['probabilidade_percentual'] as num?)?.toDouble() ?? 0,
      faixaDominante: alerta['intervalo'] ?? 'N/D',
      proximoConcurso: (inteligencia['proximo_concurso'] as num?)?.toInt() ?? 0,
      desvioPadraoSoma:
          (json['equilibrio']['desvio_padrao_soma'] as num?)?.toDouble() ?? 0,
      similaridadeTexto: similaridadeAnalise['texto_autoridade'] ?? '',
    );
  }
}

class ProcessingConsole extends StatefulWidget {
  final List<JogoIA> jogos;
  final Diagnostico? diagnostico;
  final String estrategia;
  final int concursosAnalisados;
  final DateTime? dataHoraBase;

  const ProcessingConsole({
    super.key,
    required this.jogos,
    required this.diagnostico,
    required this.estrategia,
    required this.concursosAnalisados,
    this.dataHoraBase,
  });

  @override
  State<ProcessingConsole> createState() => _ProcessingConsoleState();
}

class _ProcessingConsoleState extends State<ProcessingConsole> {
  static const Duration _lineDelay = Duration(milliseconds: 180);
  static const Duration _bootDelay = Duration(milliseconds: 1200);
  final List<String> _linhas = [];
  int _linhasVisiveis = 0;
  bool _finalizando = false;

  @override
  void initState() {
    super.initState();
    final totalConcursos = widget.concursosAnalisados > 0
        ? widget.concursosAnalisados
        : 0;
    _linhas.addAll([
      '> INICIALIZANDO PIPELINE DE INFERENCIA...',
      '> CONECTANDO AO NUCLEO ESTATISTICO (FASTAPI)...',
      '> CARREGANDO HISTORICO: $totalConcursos REGISTROS...',
      '> ANALISANDO DISTANCIA EUCLIDIANA DOS VETORES...',
      '> EXECUTANDO SIMULACAO DE MONTE CARLO...',
      '> FILTRO ANTI-DIVISAO APLICADO COM SUCESSO.',
      '> CALCULANDO IA RATING FINAL...',
      '> SUCESSO: ${widget.jogos.length} COMBINACOES OTIMIZADAS.',
    ]);
    _executarLog();
  }

  Future<void> _executarLog() async {
    await Future.delayed(_bootDelay);
    for (int i = 0; i < _linhas.length; i++) {
      if (!mounted) return;
      setState(() {
        _linhasVisiveis = i + 1;
        _finalizando = i == _linhas.length - 1;
      });
      await Future.delayed(_lineDelay);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultadosPage(
          jogos: widget.jogos,
          diagnostico: widget.diagnostico,
          estrategia: widget.estrategia,
          dataHoraBase: widget.dataHoraBase,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> buffer = _linhas.take(_linhasVisiveis).toList();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxWidth < 420;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 24,
                  vertical: compact ? 14 : 20,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kSignalGreen.withOpacity(0.45)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF071108),
                        const Color(0xFF030503),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROCESSING CONSOLE :: LOTOFACIL IA',
                          style: GoogleFonts.robotoMono(
                            fontSize: compact ? 10 : 12,
                            color: kSignalGreen,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: buffer
                                  .map(
                                    (linha) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        linha,
                                        style: GoogleFonts.robotoMono(
                                          fontSize: compact ? 10.5 : 12,
                                          color: kSignalGreen,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _finalizando
                              ? 'TRANSICAO PARA RESULTADOS...'
                              : 'PROCESSANDO...',
                          style: GoogleFonts.robotoMono(
                            fontSize: compact ? 10 : 11,
                            color: kSignalGreen.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── HOME PAGE ───────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<JogoIA> jogos = [];
  bool carregando = false;
  bool carregandoDiagnostico = false;
  Diagnostico? diagnostico;
  String estrategiaSelecionada = 'equilibrado';

  // Textos rotativos durante o carregamento
  static const _loadingTexts = [
    'Analisando Janelas de Tempo...',
    'Calculando Scores de Trincas...',
    'Identificando Dezenas Quentes...',
    'Avaliando Padrões de Atraso...',
    'Otimizando Volantes...',
    'Aplicando Filtros Estatísticos...',
    'Finalizando IA Rating...',
  ];
  int _loadingTextIndex = 0;
  late AnimationController _loadingAnimController;
  late AnimationController _tickerController;
  DateTime? _serverTimeAtSync;
  DateTime? _deviceTimeAtSync;

  DateTime get _dataHoraServidorAtual {
    final server = _serverTimeAtSync;
    final deviceSync = _deviceTimeAtSync;
    if (server == null || deviceSync == null) {
      return DateTime.now();
    }
    final elapsed = DateTime.now().difference(deviceSync);
    return server.add(elapsed);
  }

  void _syncClockFromResponse(http.Response response) {
    final headerDate = response.headers['date'];
    if (headerDate == null) return;
    try {
      final parsedUtc = HttpDate.parse(headerDate);
      _serverTimeAtSync = parsedUtc.toLocal();
      _deviceTimeAtSync = DateTime.now();
    } catch (_) {
      // Mantem fallback para horario local.
    }
  }

  Future<http.Response?> _getFromProductionBackend(String endpoint) async {
    try {
      return await http
          .get(Uri.parse('$kProductionApiBaseUrl$endpoint'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 55),
    )..repeat();
    _fetchDiagnostico();
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _loadingAnimController.dispose();
    super.dispose();
  }

  String get _tickerText {
    final d = diagnostico;
    if (d == null) {
      return 'INICIALIZANDO CENTRAL DE PROBABILIDADES  |  SINCRONIZANDO BASE HISTORICA  |  AGUARDANDO DIAGNOSTICO';
    }

    final atrasadas = d.atrasadasDetectadas.isEmpty
        ? 'SEM ATRASOS CRITICOS'
        : d.atrasadasDetectadas
              .map((n) => n.toString().padLeft(2, '0'))
              .join(', ');
    final trincas = d.melhoresTrincas.isEmpty
        ? 'TRINCAS INDEFINIDAS'
        : d.melhoresTrincas.join(' / ');
    final payload = [
      'MONITORANDO CONCURSO ${d.proximoConcurso}',
      'DESVIO PADRAO DE SOMA: ${d.desvioPadraoSoma.toStringAsFixed(1)}',
      'ATRASOS DETECTADOS: $atrasadas',
      'MELHORES TRINCAS: $trincas',
      'CORREDOR DOMINANTE: ${d.faixaDominante} (${d.probabilidadePadrao.toStringAsFixed(1)}%)',
      d.alertaPadrao.toUpperCase(),
    ];
    return '${payload.join('  |  ')}  |  ${payload.join('  |  ')}';
  }

  // ── Serviços ────────────────────────────────────────────────────────────────

  Future<void> _fetchDiagnostico() async {
    setState(() => carregandoDiagnostico = true);
    try {
      final response = await _getFromProductionBackend('/diagnostico');
      if (response != null && response.statusCode == 200) {
        _syncClockFromResponse(response);
        final data = json.decode(response.body);
        setState(() {
          diagnostico = Diagnostico.fromJson(data);
          carregandoDiagnostico = false;
        });
      } else {
        setState(() => carregandoDiagnostico = false);
      }
    } catch (_) {
      setState(() => carregandoDiagnostico = false);
    }
  }

  Future<List<JogoIA>?> _buscarJogos() async {
    setState(() {
      carregando = true;
      _loadingTextIndex = 0;
    });

    // Cicla os textos a cada 900ms
    final ticker = Stream.periodic(const Duration(milliseconds: 900), (i) => i);
    final sub = ticker.listen((i) {
      if (mounted) {
        setState(() => _loadingTextIndex = i % _loadingTexts.length);
      }
    });

    try {
      final response = await _getFromProductionBackend(
        '/gerar-jogos?estrategia=$estrategiaSelecionada',
      );
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final novosJogos = (data['jogos'] as List)
            .map((j) => JogoIA.fromJson(j))
            .toList();
        setState(() {
          jogos = novosJogos;
        });
        return novosJogos;
      } else {
        final code = response?.statusCode;
        _showRetrySnack(
          code == null
              ? '❌ Backend indisponível. Verifique Wi-Fi/USB e tente novamente.'
              : 'Erro do servidor: $code',
        );
      }
    } catch (e) {
      _showRetrySnack('❌ Sem conexão com o backend. Tente novamente.');
    } finally {
      sub.cancel();
      if (mounted) setState(() => carregando = false);
    }
    return null;
  }

  Future<void> _tentarGerarJogos() async {
    await _showSimulatedAdDialog();
    if (!mounted) return;

    final novosJogos = await _buscarJogos();
    if (!mounted || novosJogos == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProcessingConsole(
          jogos: novosJogos,
          diagnostico: diagnostico,
          estrategia: estrategiaSelecionada,
          concursosAnalisados: diagnostico?.concursosAnalisados ?? 0,
          dataHoraBase: _dataHoraServidorAtual,
        ),
      ),
    );
  }

  Future<void> _showSimulatedAdDialog() async {
    final completer = Completer<void>();
    bool fechado = false;

    void finalizar() {
      if (fechado) return;
      fechado = true;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.smart_toy, color: Color(0xFF4A148C)),
              SizedBox(width: 8),
              Text('Preparando IA'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill, size: 64, color: Color(0xFF4A148C)),
              SizedBox(height: 16),
              Text('Assistindo vídeo promocional...'),
              SizedBox(height: 8),
              Text('⏱️ Aguarde...', style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!completer.isCompleted) {
                  completer.complete();
                }
                Navigator.of(ctx).pop();
                fechado = true;
              },
              child: const Text('PULAR (SIMULAÇÃO)'),
            ),
          ],
        );
      },
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      finalizar();
    });

    await completer.future;
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showRetrySnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Tentar novamente',
          onPressed: () {
            _buscarJogos();
          },
        ),
      ),
    );
  }

  Future<void> _copiarParaClipboard(List<int> numeros) async {
    final texto = numeros.join(', ');
    await Clipboard.setData(ClipboardData(text: texto));
    _showMsg('✓ Números copiados: $texto');
  }

  Future<void> _gerarPDFVolante(List<int> numeros) async {
    try {
      final pdf = pw.Document();
      final sorted = List<int>.from(numeros)..sort();
      List<List<int>> matriz = List.generate(
        3,
        (i) => sorted.sublist(i * 5, i * 5 + 5),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'LOTOSMART',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF4A148C),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'VOLANTE — 15 NÚMEROS',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFF000000),
                  width: 2,
                ),
                children: matriz
                    .map(
                      (linha) => pw.TableRow(
                        children: linha
                            .map(
                              (n) => pw.Container(
                                padding: const pw.EdgeInsets.all(15),
                                child: pw.Center(
                                  child: pw.Text(
                                    n.toString().padLeft(2, '0'),
                                    style: pw.TextStyle(
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Gerado por: LotoSmart',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'lotofacil_volante.pdf');
    } catch (e) {
      _showMsg('❌ Erro ao gerar PDF: $e');
    }
  }

  void _abrirSiteCaixa() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          url:
              'https://loterias.caixa.gov.br/wps/portal/loterias/landing/lotofacil',
          title: 'Lotofácil - Caixa',
          jogos: jogos
              .map((j) => {'jogo': j.numeros, 'ia_rating': j.iaRating})
              .toList(),
        ),
      ),
    );
  }

  void _mostrarVolanteFlutante(int jogoInicial) {
    int jogoAtual = jogoInicial;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final jogo = jogos[jogoAtual];
          final Set<int> nums = Set.from(jogo.numeros);
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jogo ${jogoAtual + 1}/10',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A148C),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRatingBar(jogo.iaRating, compact: true),
                    const SizedBox(height: 4),
                    _buildTagChip(jogo.tagEstrategica),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF4A148C),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: 25,
                        itemBuilder: (_, idx) {
                          final n = idx + 1;
                          final sel = nums.contains(n);
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sel
                                  ? const Color(0xFF4A148C)
                                  : Colors.grey[200],
                              border: Border.all(
                                color: const Color(0xFF4A148C),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                n.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: sel ? Colors.white : Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _copiarParaClipboard(jogo.numeros),
                            icon: const Icon(Icons.content_copy, size: 18),
                            label: const Text('Copiar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _gerarPDFVolante(jogo.numeros),
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (jogoAtual > 0)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => setS(() => jogoAtual--),
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label: const Text('Anterior'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          )
                        else
                          const Expanded(child: SizedBox.shrink()),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (jogoAtual < jogos.length - 1) {
                                setS(() => jogoAtual++);
                              } else {
                                Navigator.of(ctx).pop();
                                _showMsg('✅ Todos os jogos revisados!');
                              }
                            },
                            icon: Icon(
                              jogoAtual < jogos.length - 1
                                  ? Icons.arrow_forward
                                  : Icons.check,
                              size: 18,
                            ),
                            label: Text(
                              jogoAtual < jogos.length - 1
                                  ? 'Próximo'
                                  : 'Concluído',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Widgets auxiliares ───────────────────────────────────────────────────────

  Widget _buildRatingBar(int rating, {bool compact = false}) {
    final theme = Theme.of(context);
    final Color cor = rating >= 800
        ? kSignalGreen
        : rating >= 600
        ? const Color(0xFFFFA500)
        : const Color(0xFFFF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.auto_graph, size: compact ? 14 : 16, color: cor),
            const SizedBox(width: 4),
            Text(
              'IA Rating: $rating / 1000',
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rating / 1000,
            backgroundColor: theme.dividerColor.withOpacity(0.5),
            valueColor: AlwaysStoppedAnimation<Color>(cor),
            minHeight: compact ? 5 : 8,
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip(String tag) {
    final theme = Theme.of(context);
    return Chip(
      label: Text(
        tag,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Dashboard de Diagnóstico (flat data) ───────────────────────────────────

  Widget _buildDashboard({required bool compact, required BoxConstraints c}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool disabled = carregando || carregandoDiagnostico;
    final Diagnostico? d = diagnostico;
    final double w = c.maxWidth;
    final bool verySmall = w < 360;
    final double cardPad = compact ? w * 0.032 : w * 0.04;
    final double ballSize = (w * (verySmall ? 0.085 : 0.07)).clamp(28.0, 40.0);
    final int gridCols = w < 700 ? 1 : 3;
    final List<double> hotSeries =
        d?.hot.map((item) => (item['frequencia'] as num).toDouble()).toList() ??
        [0, 0, 0, 0, 0];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.fromLTRB(
        w * 0.04,
        compact ? w * 0.02 : w * 0.04,
        w * 0.04,
        compact ? w * 0.015 : w * 0.03,
      ),
      padding: EdgeInsets.all(cardPad),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF121A23).withOpacity(disabled ? 0.65 : 0.82)
            : Colors.white.withOpacity(disabled ? 0.75 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFDCE3EE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? kLotofacilPurpleGlow.withOpacity(0.12)
                : Colors.black12,
            blurRadius: isDark ? 18 : 10,
            spreadRadius: isDark ? 1 : 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRect(
        child: SingleChildScrollView(
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: d == null
              ? Row(
                  children: [
                    Icon(Icons.wifi_off, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Servidor offline. Inicie o Python para carregar o diagnóstico.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchDiagnostico,
                      child: const Text('Recarregar'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insights,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PULSO OPERACIONAL DO SISTEMA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: verySmall ? 12 : 14,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.titleMedium?.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 8 : 12),

                    AnimationLimiter(
                      child: GridView.count(
                        crossAxisCount: gridCols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: gridCols == 1 ? 2.7 : 1.8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: List.generate(3, (index) {
                          final item = [
                            (
                              'PULSO OPERACIONAL DO SISTEMA',
                              d.regimeLabel,
                              Icons.health_and_safety,
                            ),
                            (
                              'CORREDOR DE CONVERGENCIA (SOMA)',
                              d.faixaSoma,
                              Icons.calculate,
                            ),
                            (
                              'ARQUITETURA OTIMA DE PARIDADE',
                              d.paridadeSugerida,
                              Icons.balance,
                            ),
                          ][index];

                          return AnimationConfiguration.staggeredGrid(
                            position: index,
                            duration: const Duration(milliseconds: 520),
                            columnCount: gridCols,
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _buildDataReadPanel(
                                  label: item.$1,
                                  value: item.$2,
                                  icon: item.$3,
                                  sparklineData: hotSeries,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    if (!compact) ...[
                      const SizedBox(height: 10),
                      Text(
                        d.regimeDescricao,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Text(
                      'DEZENAS QUENTES',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: w * 0.016,
                      runSpacing: w * 0.016,
                      children: d.hot.map((item) {
                        final int dez = item['dezena'] as int;
                        return Container(
                          width: ballSize,
                          height: ballSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(
                                0.45,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              dez.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: verySmall ? 10 : 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      height: compact ? 90 : 130,
                      child: BarChart(
                        BarChartData(
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= d.hot.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final dez = d.hot[idx]['dezena'] as int;
                                  return Text(
                                    dez.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(d.hot.length, (i) {
                            final y = (d.hot[i]['frequencia'] as num)
                                .toDouble();
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: y,
                                  width: compact ? 10 : 14,
                                  borderRadius: BorderRadius.circular(4),
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),

                    if (!compact) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          'A IA está analisando os últimos ${d.concursosAnalisados} concursos para otimizar estes parâmetros.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    _buildSignalPanel(
                      titulo: 'ATRASOS DETECTADOS',
                      conteudo: d.atrasadasDetectadas.isEmpty
                          ? 'N/D'
                          : d.atrasadasDetectadas
                                .map((n) => n.toString().padLeft(2, '0'))
                                .join(', '),
                    ),
                    const SizedBox(height: 10),
                    _buildSignalPanel(
                      titulo: 'MELHORES TRINCAS',
                      conteudo: d.melhoresTrincas.isEmpty
                          ? 'N/D'
                          : d.melhoresTrincas.join('   |   '),
                    ),
                    const SizedBox(height: 10),
                    _buildSignalPanel(
                      titulo: 'ALERTA PROBABILISTICO',
                      conteudo: d.alertaPadrao,
                      subtitulo: d.similaridadeTexto,
                    ),

                    if (disabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                kLotofacilPurpleGlow,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _loadingTexts[_loadingTextIndex],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDataReadPanel({
    required String label,
    required String value,
    required IconData icon,
    required List<double> sparklineData,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        final compactHeight = maxHeight == 0.0 || maxHeight < 112;
        if (compactHeight) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF111827).withOpacity(0.45)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF64748B).withOpacity(0.45)
                    : const Color(0xFFD1D9E6),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark
                      ? const Color(0xFF1F2937).withOpacity(0.45)
                      : Colors.white,
                  isDark
                      ? const Color(0xFF0F172A).withOpacity(0.15)
                      : const Color(0xFFF1F5F9),
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 11, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF111827).withOpacity(0.45)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF64748B).withOpacity(0.45)
                  : const Color(0xFFD1D9E6),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark
                    ? const Color(0xFF1F2937).withOpacity(0.45)
                    : Colors.white,
                isDark
                    ? const Color(0xFF0F172A).withOpacity(0.15)
                    : const Color(0xFFF1F5F9),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 12, color: theme.colorScheme.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: compactHeight ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compactHeight ? 9 : 10,
                        color: theme.textTheme.bodySmall?.color,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compactHeight ? 3 : 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compactHeight ? 12 : 14,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 28,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          sparklineData.length,
                          (i) => FlSpot(i.toDouble(), sparklineData[i]),
                        ),
                        isCurved: true,
                        dotData: const FlDotData(show: false),
                        color: theme.colorScheme.primary,
                        barWidth: 1.8,
                        belowBarData: BarAreaData(
                          show: true,
                          color: theme.colorScheme.primary.withOpacity(0.18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSignalPanel({
    required String titulo,
    required String conteudo,
    String? subtitulo,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withOpacity(0.55)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFD1D9E6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 10.sp,
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            conteudo,
            style: TextStyle(
              fontSize: 11.sp,
              color: theme.textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitulo != null && subtitulo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitulo,
              style: TextStyle(
                fontSize: 10.sp,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTickerTape(BoxConstraints c) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = c.maxWidth;
    final text = _tickerText;
    final style = TextStyle(
      fontSize: 11.sp,
      color: isDark ? kLotofacilPurpleGlow : const Color(0xFF5B1A7A),
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final textWidth = textPainter.width;
    final travelDistance = textWidth + width + 24;

    return Container(
      height: 34,
      margin: EdgeInsets.fromLTRB(width * 0.04, 6, width * 0.04, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1419) : const Color(0xFFF3EEFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCEB9E6),
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _tickerController,
              builder: (context, _) {
                final dx = width - (_tickerController.value * travelDistance);
                return OverflowBox(
                  maxWidth: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(dx, 0),
                    child: SizedBox(
                      width: textWidth + 24,
                      child: Text(
                        text,
                        maxLines: 1,
                        softWrap: false,
                        style: style,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (!isDark)
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 1.5,
                  width: double.infinity,
                  child: ColoredBox(color: Color(0xFFB88ED9)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyCard(
    BuildContext context,
    String id,
    String titulo,
    String sub,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = estrategiaSelecionada == id;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => estrategiaSelecionada = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: selected
                ? [
                    kLotofacilPurple,
                    isDark ? const Color(0xFF221032) : const Color(0xFFEEE4F8),
                  ]
                : isDark
                ? [const Color(0xFF111827), const Color(0xFF0B1220)]
                : [Colors.white, const Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: selected
                ? kLotofacilPurpleGlow
                : isDark
                ? const Color(0xFF334155)
                : const Color(0xFFD1D9E6),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kLotofacilPurpleGlow.withOpacity(0.24),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : isDark
              ? []
              : const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: kLotofacilPurpleGlow),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : theme.textTheme.titleMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.sp,
                color: selected
                    ? Colors.white70
                    : theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build principal ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool hasResultados = jogos.isNotEmpty;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final double h = c.maxHeight;
          final double expanded = (h * 0.35).clamp(180.0, 320.0);
          final double horizontalPad = c.maxWidth * 0.04;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: false,
                expandedHeight: expanded,
                collapsedHeight: 64,
                backgroundColor: theme.appBarTheme.backgroundColor,
                surfaceTintColor: theme.appBarTheme.surfaceTintColor,
                foregroundColor: theme.appBarTheme.foregroundColor,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      tooltip: isDark
                          ? 'Ativar modo claro'
                          : 'Ativar modo escuro',
                      onPressed: kThemeService.toggleTheme,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          key: ValueKey(isDark),
                        ),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _buildTickerTape(c),
                        Expanded(
                          child: SizedBox.expand(
                            child: _buildDashboard(
                              compact: hasResultados,
                              c: c,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    8,
                    horizontalPad,
                    6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SETUPS ESTRATEGICOS',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: const Color(0xFF6B7280),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final useTwoCols = c.maxWidth >= 480;
                          final cardWidth = useTwoCols
                              ? ((c.maxWidth - (horizontalPad * 2) - 10) / 2)
                              : double.infinity;

                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _buildStrategyCard(
                                  context,
                                  'equilibrado',
                                  'Setup: Equilibrio Estatistico',
                                  'Filtro de Bayes aplicado. Otimizacao para janelas curta/longa simultaneas.',
                                  Icons.balance,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildStrategyCard(
                                  context,
                                  'atrasados',
                                  'Setup: Explosao de Atraso',
                                  'Foco em dezenas maduras (Atraso > 4). Algoritmo de compensacao ciclica.',
                                  Icons.bolt,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildStrategyCard(
                                  context,
                                  'quentes',
                                  'Setup: Fluxo Recente (Hotness)',
                                  'Maximizacao de momento. Segue a tendencia das ultimas 10 extracoes.',
                                  Icons.trending_up,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildStrategyCard(
                                  context,
                                  'anti_divisao',
                                  'Setup: Anti-Divisao (Low Crowd)',
                                  'Geracao de combinacoes de baixa densidade populacional. Foco em premio liquido.',
                                  Icons.shield,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          SizedBox(
                            width: hasResultados
                                ? (c.maxWidth - (horizontalPad * 2) - 220)
                                      .clamp(140.0, c.maxWidth)
                                : c.maxWidth - (horizontalPad * 2),
                            child: Text(
                              hasResultados
                                  ? '${jogos.length} jogos gerados • role para analisar'
                                  : (carregando
                                        ? _loadingTexts[_loadingTextIndex]
                                        : 'Painel pronto. Dispare o motor para gerar jogos.'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          if (hasResultados)
                            FilledButton.icon(
                              onPressed: _abrirSiteCaixa,
                              icon: const Icon(Icons.open_in_browser, size: 16),
                              style: FilledButton.styleFrom(
                                backgroundColor: kCaixaBlue,
                                foregroundColor: Colors.white,
                              ),
                              label: const Text('Finalizar Site Oficial'),
                            ),
                        ],
                      ),
                      if (hasResultados) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Este app não armazena suas senhas. O login é processado com total segurança pelos servidores da Caixa Econômica Federal.',
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasResultados)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    4,
                    horizontalPad,
                    110,
                  ),
                  sliver: SliverList.builder(
                    itemCount: jogos.length,
                    itemBuilder: (ctx, i) => _buildJogoCard(i, c),
                  ),
                )
              else
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      18,
                      horizontalPad,
                      110,
                    ),
                    child: Center(
                      child: Text(
                        carregando
                            ? _loadingTexts[_loadingTextIndex]
                            : 'O dashboard está pronto. Toque em GERAR 10 JOGOS.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: buildResponsibleFooter(c, bottom: 120)),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1.0),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: FloatingActionButton.extended(
          onPressed: carregando ? null : _tentarGerarJogos,
          backgroundColor: kLotofacilPurple,
          foregroundColor: Colors.white,
          elevation: 14,
          icon: carregando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00110A),
                    ),
                  ),
                )
              : const Icon(Icons.play_circle_fill),
          label: Text(
            carregando ? 'PROCESSANDO IA...' : 'GERAR 10 JOGOS',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _loadingTexts[_loadingTextIndex],
              key: ValueKey(_loadingTextIndex),
              style: const TextStyle(fontSize: 15, color: Color(0xFF4A148C)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_loadingTextIndex + 1} / ${_loadingTexts.length}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum jogo gerado ainda.',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'Clique em "GERAR 10 JOGOS" para iniciar a análise.',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJogoCard(int i, BoxConstraints c) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final jogo = jogos[i];
    final double w = c.maxWidth;
    final bool tiny = w < 360;
    final double numBall = (w * 0.085).clamp(30.0, 38.0);
    final double tagMaxWidth = w * 0.42;
    final double actionWidth = tiny
        ? ((w - 44) / 2).clamp(112.0, 150.0)
        : ((w - 68) / 3).clamp(112.0, 160.0);

    return Card(
      margin: EdgeInsets.only(bottom: w * 0.03),
      child: Padding(
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.03,
                    vertical: w * 0.015,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'JOGO ${i + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: tiny ? 11 : 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: tagMaxWidth),
                  child: _buildTagChip(jogo.tagEstrategica),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRatingBar(jogo.iaRating),
            const SizedBox(height: 12),
            Wrap(
              spacing: w * 0.015,
              runSpacing: w * 0.015,
              children: jogo.numeros
                  .map(
                    (n) => Container(
                      width: numBall,
                      height: numBall,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? kLotofacilPurple
                            : theme.colorScheme.primary.withOpacity(0.1),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFFCE93D8)
                              : theme.colorScheme.primary,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          n.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : theme.colorScheme.primary,
                            fontSize: tiny ? 10 : 11,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actionBtn(
                  Icons.grid_3x3,
                  'Volante',
                  Colors.deepPurple,
                  () => _mostrarVolanteFlutante(i),
                  width: actionWidth,
                  compact: tiny,
                ),
                _actionBtn(
                  Icons.content_copy,
                  'Copiar',
                  Colors.blue,
                  () => _copiarParaClipboard(jogo.numeros),
                  width: actionWidth,
                  compact: tiny,
                ),
                _actionBtn(
                  Icons.picture_as_pdf,
                  'PDF',
                  Colors.red,
                  () => _gerarPDFVolante(jogo.numeros),
                  width: actionWidth,
                  compact: tiny,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    double? width,
    bool compact = false,
  }) {
    return SizedBox(
      width: width,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: compact ? 14 : 16),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: compact ? 11 : 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 7 : 8,
          ),
          minimumSize: Size(width ?? 0, compact ? 34 : 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
        ),
      ),
    );
  }
}
