import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para clipboard
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:lotofacil_app/ads/banner_ad_strip.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;

// Base única de produção (HTTPS). Para trocar sem editar código,
// use: --dart-define=API_BASE_URL=https://seu-dominio.app
const String kProductionApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue:
      'https://lotosmart-api-1024099909943.southamerica-east1.run.app',
);

const kLotofacilPurple = Color(0xFF7B1FA2);
const kLotofacilPurpleGlow = Color(0xFFA855F7);
const kSignalGreen = Color(0xFF16C784);
const kComplianceHideMessageKey = 'compliance_hide_message_v3';
const kCaixaBlue = Color(0xFF005CA9);
const kAppLoteriasOrange = Color(0xFFF57C00);
const kThemeModeStorageKey = 'isDarkMode';
const String kLotofacilCaixaUrl =
    'https://loterias.caixa.gov.br/wps/portal/loterias/landing/lotofacil';
const MethodChannel _pipChannel = MethodChannel('lotosmart/pip');
const String kLoteriasCaixaPackage = 'br.gov.caixa.loterias.apostas';

Future<bool> abrirAppLoteriasOficial() async {
  try {
    return await _pipChannel.invokeMethod<bool>('openPackage', {
          'packageName': kLoteriasCaixaPackage,
        }) ??
        false;
  } catch (_) {}

  return false;
}

Future<bool> abrirSiteOficialCaixa() async {
  try {
    final abriuNativo =
        await _pipChannel.invokeMethod<bool>('openUrl', {
          'url': kLotofacilCaixaUrl,
        }) ??
        false;
    if (abriuNativo) return true;
  } catch (_) {}

  final uri = Uri.parse(kLotofacilCaixaUrl);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> abrirLotofacilEmCanalOficial() async {
  final abriuApp = await abrirAppLoteriasOficial();
  if (abriuApp) return true;
  return abrirSiteOficialCaixa();
}

Future<bool> _isPipSupported() async {
  try {
    return await _pipChannel.invokeMethod<bool>('isPipSupported') ?? false;
  } catch (_) {
    return false;
  }
}

Future<bool> _enterPipMode({int numerator = 16, int denominator = 9}) async {
  try {
    return await _pipChannel.invokeMethod<bool>('enterPip', {
          'numerator': numerator,
          'denominator': denominator,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

Future<void> _configurePipActions({
  required bool canGoPrevious,
  required bool canGoNext,
}) async {
  try {
    await _pipChannel.invokeMethod('setPipActions', {
      'canGoPrevious': canGoPrevious,
      'canGoNext': canGoNext,
    });
  } catch (_) {}
}

Future<void> _clearPipActions() async {
  try {
    await _pipChannel.invokeMethod('clearPipActions');
  } catch (_) {}
}

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
      titleTextStyle: GoogleFonts.roboto(
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
    textTheme: GoogleFonts.robotoTextTheme(
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
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF0F1419),
      foregroundColor: const Color(0xFFE5E7EB),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFE5E7EB),
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1F2E),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.5),
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
      hintStyle: TextStyle(
        color: const Color(0xFFAEB9C7).withValues(alpha: 0.6),
      ),
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
    textTheme: GoogleFonts.robotoTextTheme(
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
      'LotoSmart é um software independente de análise estatística. Não realiza apostas, não recebe pagamentos e não possui vínculo com a CEF. Dados extraidos de: loterias.caixa.gov.br. Este app nao representa o governo. O uso dos dados é de inteira responsabilidade do usuário.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: (c.maxWidth * 0.028).clamp(10.0, 12.0),
        color: Colors.grey[500],
      ),
    ),
  );
}

Future<void> mostrarAvisoAmbienteExterno(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Servico Externo de Terceiros'),
      content: const Text(
        'Voce sera redirecionado para uma fonte publica externa da Caixa. O LotoSmart e independente, sem vinculo com a Caixa, e nao coleta nem armazena suas credenciais.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double pixelsPerSecond;
  final Duration pause;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.pixelsPerSecond = 6, // Mais lento para leitura confortável
    this.pause = const Duration(milliseconds: 900),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  double _availableWidth = 0;
  // ignore: unused_field
  static const double _gap = 0; // Mantém sem espaço visível

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateMetrics(BoxConstraints constraints) {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final nextTextWidth = textPainter.width;
    final nextAvailableWidth = constraints.maxWidth;

    if ((_textWidth - nextTextWidth).abs() < 0.5 &&
        (_availableWidth - nextAvailableWidth).abs() < 0.5) {
      return;
    }

    _textWidth = nextTextWidth;
    _availableWidth = nextAvailableWidth;

    // O ciclo deve cobrir 2x o texto para garantir continuidade perfeita
    if (_textWidth <= _availableWidth) {
      _controller.stop();
      _controller.value = 0;
      return;
    }

    final cycleWidth = _textWidth * 2;
    final durationMs = (cycleWidth / widget.pixelsPerSecond * 1000).round();
    _controller.duration = Duration(
      milliseconds: durationMs.clamp(5000, 60000),
    );
    _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateMetrics(constraints);
        });

        if (_textWidth <= 0 || _textWidth <= constraints.maxWidth) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // O deslocamento cobre 2x o texto para garantir ciclo perfeito
              final offsetX = -_textWidth * 2 * _controller.value;
              return Transform.translate(
                offset: Offset(offsetX, 0),
                child: child,
              );
            },
            child: SizedBox(
              width: _textWidth * 2,
              child: Row(
                children: [
                  Text(
                    widget.text,
                    maxLines: 1,
                    style: widget.style,
                    textDirection: TextDirection.ltr,
                  ),
                  Text(
                    widget.text,
                    maxLines: 1,
                    style: widget.style,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await kThemeService.load();
  await initializeMobileAds();
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
      buffer.writeln('Combinacao ${i + 1} | IA Rating: ${j.iaRating}/1000');
      buffer.writeln(j.numeros.join(', '));
      buffer.writeln('');
    }
    Share.share(buffer.toString());
  }

  void _compartilharUm(int i) {
    final jogo = jogos[i];
    Share.share(
      'Combinacao ${i + 1} | IA Rating: ${jogo.iaRating}/1000\n${jogo.numeros.join(', ')}',
    );
  }

  String _doisDigitos(int n) => n.toString().padLeft(2, '0');

  String _dataHoraEmissao() {
    final agora = dataHoraBase ?? DateTime.now();
    return '${_doisDigitos(agora.day)}/${_doisDigitos(agora.month)}/${agora.year} '
        '${_doisDigitos(agora.hour)}:${_doisDigitos(agora.minute)}';
  }

  Future<pw.MemoryImage?> _carregarLogoTimbrado() async {
    try {
      final bytes = await rootBundle.load('assets/icon/app_icon.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _fundoTimbrado(pw.MemoryImage? logo) {
    return pw.Positioned.fill(
      child: pw.Opacity(
        opacity: 0.08,
        child: pw.Center(
          child: pw.Transform.rotateBox(
            angle: -0.40,
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (logo != null)
                  pw.SizedBox(
                    width: 170,
                    height: 170,
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  )
                else
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
                      'LS',
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
    required pw.MemoryImage? timbreLogo,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.fromLTRB(16, 16, 16, 16),
      build: (_) => pw.Stack(
        children: [
          _fundoTimbrado(timbreLogo),
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
                'COMBINACAO ${index + 1}  |  IA Rating: ${jogo.iaRating}/1000',
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
                'Uso pessoal | Nao garante premiacao | Confira sempre em fonte publica da Caixa',
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
      final timbreLogo = await _carregarLogoTimbrado();

      pdf.addPage(
        _buildPaginaJogo(
          index: i,
          jogo: jogo,
          emissao: emissao,
          timbreLogo: timbreLogo,
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'lotofacil_combinacao_${i + 1}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF da combinacao: $e')),
        );
      }
    }
  }

  Future<void> _gerarPDFTodos(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final emissao = _dataHoraEmissao();
      final timbreLogo = await _carregarLogoTimbrado();

      for (int i = 0; i < jogos.length; i++) {
        final jogo = jogos[i];
        pdf.addPage(
          _buildPaginaJogo(
            index: i,
            jogo: jogo,
            emissao: emissao,
            timbreLogo: timbreLogo,
          ),
        );
      }

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'lotofacil_10_combinacoes.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF das combinacoes: $e')),
        );
      }
    }
  }

  Future<void> _abrirSiteCaixa(BuildContext context) async {
    if (context.mounted && jogos.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PipVolantePage(jogos: jogos, initialIndex: 0),
        ),
      );
      return;
    }

    final abriu = await abrirLotofacilEmCanalOficial();
    if (!context.mounted || abriu) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir a fonte pública da Lotofácil.'),
        behavior: SnackBarBehavior.floating,
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
          backgroundColor: kLotofacilPurple,
          foregroundColor: Colors.white,
          elevation: 10,
          icon: const Icon(Icons.account_balance_wallet, size: 22),
          label: const Text(
            'Abrir Fonte Publica da Caixa',
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
                            Text(
                              'ESTRATÉGIA APLICADA',
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              estrategia.toUpperCase(),
                              style: GoogleFonts.roboto(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: kLotofacilPurple,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              diagnostico?.regimeDescricao ??
                                  'Analise estatística aplicada às combinações geradas.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
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
                    'Este app nao armazena senhas nem processa login. Se voce abrir um canal oficial externo da Caixa, qualquer autenticacao ocorrera diretamente no servico de terceiros.',
                    style: GoogleFonts.roboto(
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
                                    'COMBINAÇÃO ${i + 1}',
                                    style: GoogleFonts.roboto(
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
                                    style: GoogleFonts.roboto(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
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
                                                  .withValues(alpha: 0.18),
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
                                            style: GoogleFonts.roboto(
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
                                    label: Text(
                                      'Compartilhar Combinação',
                                      style: GoogleFonts.roboto(),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _gerarPDFUm(context, i),
                                    icon: const Icon(
                                      Icons.picture_as_pdf,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'PDF Combinação',
                                      style: GoogleFonts.roboto(),
                                    ),
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

class LotoApp extends StatelessWidget {
  const LotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) => ListenableBuilder(
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
  late final Future<bool> _hideMessageFuture;

  @override
  void initState() {
    super.initState();
    _hideMessageFuture = _loadHideMessagePreference();
  }

  Future<bool> _loadHideMessagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kComplianceHideMessageKey) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hideMessageFuture,
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

        final hideMessage = snapshot.data ?? false;
        if (hideMessage) {
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
  bool _naoMostrarNovamente = false;
  bool _confirmouMaioridade = false;
  static final Uri _lotofacilFontePublicaUri = Uri.parse(kLotofacilCaixaUrl);
  static final Uri _jogoResponsavelUri = Uri.parse(
    'https://www.caixa.gov.br/jogo-responsavel/Paginas/default.aspx',
  );

  Future<void> _abrirFontePublica(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nao foi possivel abrir a fonte publica no momento.'),
      ),
    );
  }

  Future<void> _abrirJogoResponsavel() async {
    await _abrirFontePublica(_jogoResponsavelUri);
  }

  Future<void> _abrirLotofacilFontePublica() async {
    await _abrirFontePublica(_lotofacilFontePublicaUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181C2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181C2A),
        elevation: 0,
        title: Text(
          'Termos de Responsabilidade',
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kLotofacilPurple.withValues(alpha: 0.22),
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
                      style: GoogleFonts.roboto(
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
                'Este aplicativo é uma ferramenta de estudo estatístico e análise de tendências. Não realizamos registros, não temos vínculo com a Caixa Econômica Federal e não garantimos convergência de resultados. Utilize os dados com responsabilidade.',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Identidade do Produto: Software de Pesquisa e Estudo Estatístico.',
                style: GoogleFonts.roboto(
                  fontSize: 12.5,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Limitação de Responsabilidade: O uso desta ferramenta é de inteira responsabilidade do usuário. As sugestões de combinação são baseadas em cálculos matemáticos sobre dados históricos.',
                style: GoogleFonts.roboto(
                  fontSize: 12.5,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Recomendação: uso responsável preferencial para maiores de 18 anos. A classificação indicativa pode variar por país.',
                style: GoogleFonts.roboto(
                  fontSize: 12.5,
                  color: const Color(0xFFFCA5A5),
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
                      'O uso deve ser estritamente informativo. Para orientações públicas, consulte a fonte de uso responsável da Caixa.',
                      style: GoogleFonts.roboto(
                        fontSize: 12.5,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _abrirJogoResponsavel,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text(
                        'Abrir fonte publica de uso responsavel da Caixa',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fonte oficial de dados: https://loterias.caixa.gov.br',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: const Color(0xFF93C5FD),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _abrirFontePublica(
                        Uri.parse('https://loterias.caixa.gov.br'),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Abrir fonte oficial de dados'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fontes governamentais publicas (Caixa):',
                      style: GoogleFonts.roboto(
                        fontSize: 12.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lotofacil (fonte publica):',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    SelectableText(
                      kLotofacilCaixaUrl,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: const Color(0xFF93C5FD),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _abrirLotofacilFontePublica,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Abrir fonte publica da Lotofacil'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Jogo responsavel (fonte publica):',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    SelectableText(
                      _jogoResponsavelUri.toString(),
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: const Color(0xFF93C5FD),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _abrirJogoResponsavel,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text(
                        'Abrir fonte publica de uso responsavel',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmouMaioridade,
                activeColor: kLotofacilPurple,
                checkColor: Colors.white,
                title: Text(
                  'Confirmo que sou maior de 18 anos e compreendo que não há garantia de resultados.',
                  style: GoogleFonts.roboto(
                    fontSize: 12.5,
                    color: Colors.white,
                  ),
                ),
                onChanged: _salvando
                    ? null
                    : (value) {
                        setState(() => _confirmouMaioridade = value ?? false);
                      },
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _naoMostrarNovamente,
                activeColor: kLotofacilPurple,
                checkColor: Colors.white,
                title: Text(
                  'Não mostrar esta mensagem novamente',
                  style: GoogleFonts.roboto(
                    fontSize: 12.5,
                    color: Colors.white,
                  ),
                ),
                onChanged: _salvando
                    ? null
                    : (value) {
                        setState(() => _naoMostrarNovamente = value ?? false);
                      },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _salvando || !_confirmouMaioridade
                      ? null
                      : _aceitarTermos,
                  style: FilledButton.styleFrom(
                    backgroundColor: kLotofacilPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Confirmo +18 e aceito os termos de uso responsável',
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('Sair'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _aceitarTermos() async {
    if (_salvando) return;
    setState(() => _salvando = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kComplianceHideMessageKey, _naoMostrarNovamente);
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }
}

class PipVolantePage extends StatefulWidget {
  final List<JogoIA> jogos;
  final int initialIndex;

  const PipVolantePage({super.key, required this.jogos, this.initialIndex = 0});

  @override
  State<PipVolantePage> createState() => _PipVolantePageState();
}

class _PipVolantePageState extends State<PipVolantePage>
    with WidgetsBindingObserver {
  late final PageController _controller;
  late int _current;
  bool _launching = false;
  bool _pipFocusMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _current = widget.initialIndex.clamp(0, widget.jogos.length - 1);
    _controller = PageController(initialPage: _current);

    _pipChannel.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'pipPrevious':
          if (_current > 0) {
            await _controller.previousPage(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            );
          }
          break;
        case 'pipNext':
          if (_current < (widget.jogos.length - 1)) {
            await _controller.nextPage(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            );
          }
          break;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipChannel.setMethodCallHandler(null);
    _clearPipActions();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quando o app vai para background sem PIP ativo, volta à tela normal
    // para não segurar recursos. Se PIP estiver ativo, é o comportamento esperado.
    if (state == AppLifecycleState.paused && !_pipFocusMode) {
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _entrarEmPipSomente() async {
    final suportaPip = await _isPipSupported();
    if (!suportaPip) {
      _pipFocusMode = false;
      if (mounted) setState(() {});
      return;
    }

    await _configurePipActions(
      canGoPrevious: _current > 0,
      canGoNext: _current < (widget.jogos.length - 1),
    );
    _pipFocusMode = true;
    if (mounted) setState(() {});
    await _enterPipMode(numerator: 3, denominator: 5);
  }

  Future<void> _abrirDestinoComPip({required bool abrirApp}) async {
    if (_launching) return;
    setState(() => _launching = true);

    await mostrarAvisoAmbienteExterno(context);
    if (!mounted) return;

    await _entrarEmPipSomente();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final abriu = abrirApp
        ? await abrirAppLoteriasOficial()
        : await abrirSiteOficialCaixa();

    if (!mounted) return;
    setState(() => _launching = false);

    if (!abriu) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            abrirApp
                ? 'Não foi possível abrir o App Loterias da Caixa neste dispositivo.'
                : 'Não foi possível abrir a fonte pública da Caixa neste dispositivo.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copiarJogoAtual() async {
    final texto = widget.jogos[_current].numeros.join(', ');
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Números copiados: $texto'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: _pipFocusMode
          ? null
          : AppBar(title: const Text('Volante Flutuante • Acessibilidade')),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          _pipFocusMode ? 6 : 12,
          _pipFocusMode ? 6 : 12,
          _pipFocusMode ? 6 : 12,
          _pipFocusMode ? 6 : 12,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxHeight < 520 || constraints.maxWidth < 360;
            final ballSize = _pipFocusMode ? 28.0 : (compact ? 32.0 : 38.0);

            return Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.jogos.length,
                    onPageChanged: (value) {
                      setState(() => _current = value);
                      _configurePipActions(
                        canGoPrevious: value > 0,
                        canGoNext: value < (widget.jogos.length - 1),
                      );
                    },
                    itemBuilder: (_, i) {
                      final jogo = widget.jogos[i];
                      return Card(
                        elevation: _pipFocusMode ? 0 : (compact ? 1 : 2),
                        child: Padding(
                          padding: EdgeInsets.all(
                            _pipFocusMode ? 6 : (compact ? 8 : 12),
                          ),
                          child: Column(
                            children: [
                              if (!_pipFocusMode)
                                Text(
                                  'COMBINACAO ${(i + 1).toString().padLeft(2, '0')} / ${widget.jogos.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: compact ? 13 : 15,
                                  ),
                                ),
                              if (!_pipFocusMode)
                                SizedBox(height: compact ? 4 : 8),
                              Expanded(
                                child: Center(
                                  child: Wrap(
                                    spacing: _pipFocusMode
                                        ? 3
                                        : (compact ? 4 : 6),
                                    runSpacing: _pipFocusMode
                                        ? 3
                                        : (compact ? 4 : 6),
                                    alignment: WrapAlignment.center,
                                    children: jogo.numeros
                                        .map(
                                          (n) => Container(
                                            width: ballSize,
                                            height: ballSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isDark
                                                  ? const Color(0xFF7B1FA2)
                                                  : const Color(0xFFEDE7F6),
                                              border: Border.all(
                                                color: kLotofacilPurple,
                                                width: 1.2,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              n.toString().padLeft(2, '0'),
                                              style: TextStyle(
                                                fontSize: _pipFocusMode
                                                    ? 10.5
                                                    : (compact ? 11 : 13),
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF4A148C),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!_pipFocusMode) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _launching
                              ? null
                              : () => _abrirDestinoComPip(abrirApp: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: kLotofacilPurple,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.apps),
                          label: const Text('Abrir app externo da Caixa'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _launching
                              ? null
                              : () => _abrirDestinoComPip(abrirApp: false),
                          style: FilledButton.styleFrom(
                            backgroundColor: kLotofacilPurple,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Abrir fonte publica da Caixa'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _copiarJogoAtual,
                      icon: const Icon(Icons.content_copy),
                      label: const Text('Copiar combinacao atual'),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  height: 24,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: const Color(0xFF0F172A),
                  child: const MarqueeText(
                    text:
                        'Este app é independente. Registro somente nos canais oficiais. Este app fornece simulações matemáticas e não garante resultados. O usuário é o único responsável pelo uso dos dados obtidos neste app, estando este app isento de responsabilidade por eventuais prejuízos decorrentes das aplicações financeiras realizadas pelo usuário. Fonte: loterias.caixa.gov.br.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontFamily: 'Roboto',
                      fontFamilyFallback: ['Arial', 'sans-serif'],
                    ),
                    pixelsPerSecond: 14, // Mais lento ainda
                  ),
                ),
              ],
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
      numeros: List<int>.from(json['combinacao'] ?? json['jogo'] ?? []),
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
  final int ultimoConcurso;
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
    required this.ultimoConcurso,
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
      ultimoConcurso:
          (inteligencia['ultimo_concurso'] as num?)?.toInt() ??
          (json['ultimo_concurso'] as num?)?.toInt() ??
          (json['concursos_analisados'] as num).toInt(),
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
    final diagnostico = widget.diagnostico;
    final concursoAtual = diagnostico?.ultimoConcurso ?? totalConcursos;
    final proximoConcurso = diagnostico?.proximoConcurso ?? (concursoAtual + 1);
    _linhas.addAll([
      '> INICIALIZANDO PIPELINE DE INFERENCIA...',
      '> CONECTANDO AO NUCLEO ESTATISTICO (FASTAPI)...',
      '> CARREGANDO HISTORICO: $totalConcursos REGISTROS...',
      '> ANALISANDO DISTANCIA EUCLIDIANA DOS VETORES...',
      '> EXECUTANDO SIMULACAO DE MONTE CARLO...',
      '> FILTRO ANTI-DIVISAO APLICADO COM SUCESSO.',
      '> CALCULANDO IA RATING FINAL...',
      '> SUCESSO: ${widget.jogos.length} COMBINACOES OTIMIZADAS.',
      '> CONCURSO ATUAL: $concursoAtual',
      '> PRÓXIMO CONCURSO: $proximoConcurso',
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
                    border: Border.all(
                      color: kSignalGreen.withValues(alpha: 0.45),
                    ),
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
                              ? 'TRANSICAO PARA REFERENCIAS...'
                              : 'PROCESSANDO...',
                          style: GoogleFonts.robotoMono(
                            fontSize: compact ? 10 : 11,
                            color: kSignalGreen.withValues(alpha: 0.85),
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

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<JogoIA> jogos = [];
  bool carregando = false;
  bool carregandoDiagnostico = false;
  Diagnostico? diagnostico;
  String estrategiaSelecionada = 'equilibrado';

  // Textos rotativos durante o carregamento
  static const _loadingTexts = [
    'Analisando frequências históricas...',
    'Calculando distribuição das trincas...',
    'Identificando dezenas mais recorrentes...',
    'Avaliando padrões de intervalo...',
    'Otimizando distribuição dos volantes...',
    'Aplicando filtros de consistência...',
    'Calculando indice de aderencia estatistica...',
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
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickerController.dispose();
    _loadingAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _tickerController.stop();
      _loadingAnimController.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_tickerController.isAnimating) {
        _tickerController.repeat();
      }
      if (carregando && !_loadingAnimController.isAnimating) {
        _loadingAnimController.repeat();
      }
    }
  }

  String get _tickerText {
    final d = diagnostico;
    if (d == null) {
      return 'PREPARANDO ANALISE ESTATISTICA  |  SINCRONIZANDO BASE HISTORICA  |  CARREGANDO PARAMETROS';
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
      'PRÓXIMO CONCURSO: ${d.proximoConcurso}',
      'DESVIO PADRÃO DE SOMA: ${d.desvioPadraoSoma.toStringAsFixed(1)}',
      'MAIOR INTERVALO: $atrasadas',
      'TRINCAS RECORRENTES: $trincas',
      'FAIXA DE SOMA DOMINANTE: ${d.faixaDominante} (${d.probabilidadePadrao.toStringAsFixed(1)}%)',
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
      http.Response? response = await _getFromProductionBackend(
        '/gerar-combinacoes?estrategia=$estrategiaSelecionada',
      );

      // Compatibilidade: backend em produção pode ainda estar no endpoint antigo.
      if (response == null || response.statusCode == 404) {
        response = await _getFromProductionBackend(
          '/gerar-jogos?estrategia=$estrategiaSelecionada',
        );
      }

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final novosJogos = ((data['combinacoes'] ?? data['jogos']) as List)
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
    final liberado = await showFullscreenRewardedAdGate(context);
    if (!mounted || !liberado) return;

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
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(msg)),
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
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
      pw.MemoryImage? timbreLogo;
      try {
        final logoBytes = await rootBundle.load('assets/icon/app_icon.png');
        timbreLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        timbreLogo = null;
      }

      List<List<int>> matriz = List.generate(
        3,
        (i) => sorted.sublist(i * 5, i * 5 + 5),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => pw.Stack(
            children: [
              if (timbreLogo != null)
                pw.Positioned.fill(
                  child: pw.Opacity(
                    opacity: 0.08,
                    child: pw.Center(
                      child: pw.SizedBox(
                        width: 250,
                        height: 250,
                        child: pw.Image(timbreLogo, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              pw.Center(
                child: pw.Column(
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

  Future<void> _abrirSiteCaixa() async {
    if (jogos.isNotEmpty && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PipVolantePage(jogos: jogos, initialIndex: 0),
        ),
      );
      return;
    }

    final abriu = await abrirLotofacilEmCanalOficial();
    if (abriu) return;
    _showMsg('❌ Não foi possível abrir a fonte pública da Lotofácil.');
  }

  void _mostrarVolanteFlutante(int jogoInicial) {
    int jogoAtual = jogoInicial;
    final pageController = PageController(initialPage: jogoInicial);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
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
                          'Combinacao ${jogoAtual + 1}/10',
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
                    Text(
                      'Arraste para esquerda/direita para navegar',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 520,
                      child: PageView.builder(
                        controller: pageController,
                        itemCount: jogos.length,
                        onPageChanged: (idx) => setS(() => jogoAtual = idx),
                        itemBuilder: (_, idx) {
                          final jogoPagina = jogos[idx];
                          final Set<int> numsPagina = Set.from(
                            jogoPagina.numeros,
                          );

                          return Column(
                            children: [
                              _buildRatingBar(
                                jogoPagina.iaRating,
                                compact: true,
                              ),
                              const SizedBox(height: 4),
                              _buildTagChip(jogoPagina.tagEstrategica),
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
                                  itemBuilder: (_, nIdx) {
                                    final n = nIdx + 1;
                                    final sel = numsPagina.contains(n);
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
                                            color: sel
                                                ? Colors.white
                                                : Colors.grey[700],
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
                                      onPressed: () => _copiarParaClipboard(
                                        jogoPagina.numeros,
                                      ),
                                      icon: const Icon(
                                        Icons.content_copy,
                                        size: 18,
                                      ),
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
                                      onPressed: () =>
                                          _gerarPDFVolante(jogoPagina.numeros),
                                      icon: const Icon(
                                        Icons.picture_as_pdf,
                                        size: 18,
                                      ),
                                      label: const Text('PDF'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (jogoAtual > 0)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => pageController.previousPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                              ),
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label: const Text('Ver Sequencia'),
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
                                pageController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                );
                              } else {
                                Navigator.of(ctx).pop();
                                _showMsg('✅ Todas as combinacoes revisadas!');
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
                                  ? 'Proxima Sugestao'
                                  : 'Concluido',
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
    ).whenComplete(pageController.dispose);
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
            backgroundColor: theme.dividerColor.withValues(alpha: 0.5),
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

  // ── Painel de Analise de Tendencias (flat data) ───────────────────────────

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
            ? const Color(0xFF121A23).withValues(alpha: disabled ? 0.65 : 0.82)
            : Colors.white.withValues(alpha: disabled ? 0.75 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFDCE3EE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? kLotofacilPurpleGlow.withValues(alpha: 0.12)
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
                            'PAINEL DE ANALISE DE TENDENCIAS',
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
                              'CONSISTÊNCIA DO PADRÃO',
                              d.regimeLabel,
                              Icons.health_and_safety,
                            ),
                            (
                              'FAIXA DE SOMA RECORRENTE',
                              d.faixaSoma,
                              Icons.calculate,
                            ),
                            (
                              'PARIDADE MAIS FREQUENTE',
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
                      'DEZENAS COM MAIOR FREQUÊNCIA RECENTE',
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
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.45,
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
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Text(
                          'Combinacoes otimizadas com base no historico ate o concurso ${d.ultimoConcurso}.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    _buildSignalPanel(
                      titulo: 'DEZENAS COM MAIOR INTERVALO',
                      conteudo: d.atrasadasDetectadas.isEmpty
                          ? 'N/D'
                          : d.atrasadasDetectadas
                                .map((n) => n.toString().padLeft(2, '0'))
                                .join(', '),
                    ),
                    const SizedBox(height: 10),
                    _buildSignalPanel(
                      titulo: 'TRINCAS MAIS RECORRENTES',
                      conteudo: d.melhoresTrincas.isEmpty
                          ? 'N/D'
                          : d.melhoresTrincas.join('   |   '),
                    ),
                    const SizedBox(height: 10),
                    _buildSignalPanel(
                      titulo: 'PADRÃO ESTATÍSTICO ATUAL',
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
                  ? const Color(0xFF111827).withValues(alpha: 0.45)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF64748B).withValues(alpha: 0.45)
                    : const Color(0xFFD1D9E6),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark
                      ? const Color(0xFF1F2937).withValues(alpha: 0.45)
                      : Colors.white,
                  isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.15)
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
                ? const Color(0xFF111827).withValues(alpha: 0.45)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF64748B).withValues(alpha: 0.45)
                  : const Color(0xFFD1D9E6),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark
                    ? const Color(0xFF1F2937).withValues(alpha: 0.45)
                    : Colors.white,
                isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.15)
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
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.18,
                          ),
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
            ? const Color(0xFF0F172A).withValues(alpha: 0.55)
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
                    color: kLotofacilPurpleGlow.withValues(alpha: 0.24),
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
      bottomNavigationBar: const BannerAdStrip(),
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
                                  'Geracao de combinacoes de baixa densidade populacional. Foco em convergencia estatistica.',
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
                                  ? '${jogos.length} combinacoes geradas • role para analisar'
                                  : (carregando
                                        ? _loadingTexts[_loadingTextIndex]
                                        : 'Painel pronto. Dispare o motor para gerar combinacoes.'),
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
                              label: const Text('Abrir Fonte Publica'),
                            ),
                        ],
                      ),
                      if (hasResultados) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Este app e independente e nao armazena credenciais. Ao abrir a fonte externa da Caixa, qualquer login ocorre diretamente no servico de terceiros.',
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
                            : 'O painel está pronto. Toque em Gerar 10 Combinações (Após vídeo).',
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
            carregando
                ? 'PROCESSANDO IA...'
                : 'Gerar 10 Combinações (Após vídeo)',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
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

  // ignore: unused_element
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
              'Nenhuma combinacao gerada ainda.',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'Clique em "Gerar 10 Combinações (Após vídeo)" para iniciar a análise.',
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
                      'COMBINACAO ${i + 1}',
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
                            : theme.colorScheme.primary.withValues(alpha: 0.1),
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
