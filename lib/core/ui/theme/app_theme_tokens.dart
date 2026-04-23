import 'package:flutter/material.dart';

enum AppTone {
  neutral,
  primary,
  success,
  warning,
  danger,
  cash,
  pix,
  note,
  sync,
  info,
}

@immutable
class AppToneColors {
  const AppToneColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  AppToneColors lerp(AppToneColors other, double t) {
    return AppToneColors(
      background: Color.lerp(background, other.background, t) ?? background,
      foreground: Color.lerp(foreground, other.foreground, t) ?? foreground,
      border: Color.lerp(border, other.border, t) ?? border,
    );
  }
}

class TatuzinSpacing {
  const TatuzinSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class TatuzinRadius {
  const TatuzinRadius._();

  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;
}

@immutable
class TatuzinThemeTokens extends ThemeExtension<TatuzinThemeTokens> {
  const TatuzinThemeTokens({
    required this.canvas,
    required this.canvasMuted,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.borderSoft,
    required this.borderStrong,
    required this.heroStart,
    required this.heroEnd,
    required this.heroForeground,
    required this.shadowColor,
    required this.pagePadding,
    required this.sectionPadding,
    required this.cardRadius,
    required this.panelRadius,
    required this.heroRadius,
    required this.chipRadius,
    required this.primaryTone,
    required this.successTone,
    required this.warningTone,
    required this.dangerTone,
    required this.cashTone,
    required this.pixTone,
    required this.noteTone,
    required this.syncTone,
    required this.infoTone,
  });

  final Color canvas;
  final Color canvasMuted;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color borderSoft;
  final Color borderStrong;
  final Color heroStart;
  final Color heroEnd;
  final Color heroForeground;
  final Color shadowColor;
  final EdgeInsets pagePadding;
  final EdgeInsets sectionPadding;
  final double cardRadius;
  final double panelRadius;
  final double heroRadius;
  final double chipRadius;
  final AppToneColors primaryTone;
  final AppToneColors successTone;
  final AppToneColors warningTone;
  final AppToneColors dangerTone;
  final AppToneColors cashTone;
  final AppToneColors pixTone;
  final AppToneColors noteTone;
  final AppToneColors syncTone;
  final AppToneColors infoTone;

  factory TatuzinThemeTokens.light() {
    return const TatuzinThemeTokens(
      canvas: Color(0xFFFBF5EF),
      canvasMuted: Color(0xFFF3E8DC),
      surfaceRaised: Color(0xFFFFFBF8),
      surfaceSunken: Color(0xFFF6EEE6),
      borderSoft: Color(0xFFE2D4C7),
      borderStrong: Color(0xFFC9B09E),
      heroStart: Color(0xFF8E4B38),
      heroEnd: Color(0xFFC9855F),
      heroForeground: Color(0xFFFFF8F3),
      shadowColor: Color(0x290F0805),
      pagePadding: EdgeInsets.all(TatuzinSpacing.xl),
      sectionPadding: EdgeInsets.all(TatuzinSpacing.lg),
      cardRadius: TatuzinRadius.lg,
      panelRadius: TatuzinRadius.md,
      heroRadius: TatuzinRadius.xl,
      chipRadius: TatuzinRadius.pill,
      primaryTone: AppToneColors(
        background: Color(0xFFF2D2C8),
        foreground: Color(0xFF5D2417),
        border: Color(0xFFD7A798),
      ),
      successTone: AppToneColors(
        background: Color(0xFFD7F0DD),
        foreground: Color(0xFF184A26),
        border: Color(0xFF8FC7A0),
      ),
      warningTone: AppToneColors(
        background: Color(0xFFF6E5B8),
        foreground: Color(0xFF5C4307),
        border: Color(0xFFD8BC66),
      ),
      dangerTone: AppToneColors(
        background: Color(0xFFF6D4D2),
        foreground: Color(0xFF6B201C),
        border: Color(0xFFD8928E),
      ),
      cashTone: AppToneColors(
        background: Color(0xFFF2DEAA),
        foreground: Color(0xFF5D4308),
        border: Color(0xFFD0B36B),
      ),
      pixTone: AppToneColors(
        background: Color(0xFFCDEDE0),
        foreground: Color(0xFF0F4C39),
        border: Color(0xFF82C8AE),
      ),
      noteTone: AppToneColors(
        background: Color(0xFFE7D2C8),
        foreground: Color(0xFF61372A),
        border: Color(0xFFC69B89),
      ),
      syncTone: AppToneColors(
        background: Color(0xFFD8E5F1),
        foreground: Color(0xFF23415F),
        border: Color(0xFF9FB8D2),
      ),
      infoTone: AppToneColors(
        background: Color(0xFFE2E7EF),
        foreground: Color(0xFF334255),
        border: Color(0xFFB0BCCB),
      ),
    );
  }

  factory TatuzinThemeTokens.dark() {
    return const TatuzinThemeTokens(
      canvas: Color(0xFF161211),
      canvasMuted: Color(0xFF211A18),
      surfaceRaised: Color(0xFF221B19),
      surfaceSunken: Color(0xFF2A221F),
      borderSoft: Color(0xFF4A3B35),
      borderStrong: Color(0xFF68544B),
      heroStart: Color(0xFFC98460),
      heroEnd: Color(0xFF5F3024),
      heroForeground: Color(0xFFFFF7F2),
      shadowColor: Color(0x4D000000),
      pagePadding: EdgeInsets.all(TatuzinSpacing.xl),
      sectionPadding: EdgeInsets.all(TatuzinSpacing.lg),
      cardRadius: TatuzinRadius.lg,
      panelRadius: TatuzinRadius.md,
      heroRadius: TatuzinRadius.xl,
      chipRadius: TatuzinRadius.pill,
      primaryTone: AppToneColors(
        background: Color(0xFF5E372B),
        foreground: Color(0xFFFFE5DA),
        border: Color(0xFF9B6654),
      ),
      successTone: AppToneColors(
        background: Color(0xFF284A34),
        foreground: Color(0xFFE2F7E6),
        border: Color(0xFF5A906D),
      ),
      warningTone: AppToneColors(
        background: Color(0xFF574417),
        foreground: Color(0xFFFFF3D5),
        border: Color(0xFF9D7C2D),
      ),
      dangerTone: AppToneColors(
        background: Color(0xFF5F2C2A),
        foreground: Color(0xFFFFE2DF),
        border: Color(0xFFA05C58),
      ),
      cashTone: AppToneColors(
        background: Color(0xFF5E4915),
        foreground: Color(0xFFFFF1C9),
        border: Color(0xFFA88A3A),
      ),
      pixTone: AppToneColors(
        background: Color(0xFF1E4C3F),
        foreground: Color(0xFFDDF8EE),
        border: Color(0xFF4E8E79),
      ),
      noteTone: AppToneColors(
        background: Color(0xFF5B372F),
        foreground: Color(0xFFFFE9E1),
        border: Color(0xFFA06E61),
      ),
      syncTone: AppToneColors(
        background: Color(0xFF293E54),
        foreground: Color(0xFFE2EEF9),
        border: Color(0xFF6786A6),
      ),
      infoTone: AppToneColors(
        background: Color(0xFF313943),
        foreground: Color(0xFFEEF3F9),
        border: Color(0xFF6C7B8D),
      ),
    );
  }

  AppToneColors tone(AppTone tone) {
    return switch (tone) {
      AppTone.primary => primaryTone,
      AppTone.success => successTone,
      AppTone.warning => warningTone,
      AppTone.danger => dangerTone,
      AppTone.cash => cashTone,
      AppTone.pix => pixTone,
      AppTone.note => noteTone,
      AppTone.sync => syncTone,
      AppTone.info => infoTone,
      AppTone.neutral => AppToneColors(
        background: surfaceSunken,
        foreground: borderStrong,
        border: borderSoft,
      ),
    };
  }

  @override
  TatuzinThemeTokens copyWith({
    Color? canvas,
    Color? canvasMuted,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? borderSoft,
    Color? borderStrong,
    Color? heroStart,
    Color? heroEnd,
    Color? heroForeground,
    Color? shadowColor,
    EdgeInsets? pagePadding,
    EdgeInsets? sectionPadding,
    double? cardRadius,
    double? panelRadius,
    double? heroRadius,
    double? chipRadius,
    AppToneColors? primaryTone,
    AppToneColors? successTone,
    AppToneColors? warningTone,
    AppToneColors? dangerTone,
    AppToneColors? cashTone,
    AppToneColors? pixTone,
    AppToneColors? noteTone,
    AppToneColors? syncTone,
    AppToneColors? infoTone,
  }) {
    return TatuzinThemeTokens(
      canvas: canvas ?? this.canvas,
      canvasMuted: canvasMuted ?? this.canvasMuted,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      borderSoft: borderSoft ?? this.borderSoft,
      borderStrong: borderStrong ?? this.borderStrong,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      heroForeground: heroForeground ?? this.heroForeground,
      shadowColor: shadowColor ?? this.shadowColor,
      pagePadding: pagePadding ?? this.pagePadding,
      sectionPadding: sectionPadding ?? this.sectionPadding,
      cardRadius: cardRadius ?? this.cardRadius,
      panelRadius: panelRadius ?? this.panelRadius,
      heroRadius: heroRadius ?? this.heroRadius,
      chipRadius: chipRadius ?? this.chipRadius,
      primaryTone: primaryTone ?? this.primaryTone,
      successTone: successTone ?? this.successTone,
      warningTone: warningTone ?? this.warningTone,
      dangerTone: dangerTone ?? this.dangerTone,
      cashTone: cashTone ?? this.cashTone,
      pixTone: pixTone ?? this.pixTone,
      noteTone: noteTone ?? this.noteTone,
      syncTone: syncTone ?? this.syncTone,
      infoTone: infoTone ?? this.infoTone,
    );
  }

  @override
  TatuzinThemeTokens lerp(
    covariant ThemeExtension<TatuzinThemeTokens>? other,
    double t,
  ) {
    if (other is! TatuzinThemeTokens) {
      return this;
    }

    return TatuzinThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      canvasMuted: Color.lerp(canvasMuted, other.canvasMuted, t) ?? canvasMuted,
      surfaceRaised:
          Color.lerp(surfaceRaised, other.surfaceRaised, t) ?? surfaceRaised,
      surfaceSunken:
          Color.lerp(surfaceSunken, other.surfaceSunken, t) ?? surfaceSunken,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t) ?? borderSoft,
      borderStrong:
          Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      heroStart: Color.lerp(heroStart, other.heroStart, t) ?? heroStart,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t) ?? heroEnd,
      heroForeground:
          Color.lerp(heroForeground, other.heroForeground, t) ??
          heroForeground,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t) ?? shadowColor,
      pagePadding:
          EdgeInsets.lerp(pagePadding, other.pagePadding, t) ?? pagePadding,
      sectionPadding:
          EdgeInsets.lerp(sectionPadding, other.sectionPadding, t) ??
          sectionPadding,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t),
      heroRadius: lerpDouble(heroRadius, other.heroRadius, t),
      chipRadius: lerpDouble(chipRadius, other.chipRadius, t),
      primaryTone: primaryTone.lerp(other.primaryTone, t),
      successTone: successTone.lerp(other.successTone, t),
      warningTone: warningTone.lerp(other.warningTone, t),
      dangerTone: dangerTone.lerp(other.dangerTone, t),
      cashTone: cashTone.lerp(other.cashTone, t),
      pixTone: pixTone.lerp(other.pixTone, t),
      noteTone: noteTone.lerp(other.noteTone, t),
      syncTone: syncTone.lerp(other.syncTone, t),
      infoTone: infoTone.lerp(other.infoTone, t),
    );
  }

  static double lerpDouble(double a, double b, double t) {
    return a + ((b - a) * t);
  }
}

extension TatuzinThemeContext on BuildContext {
  TatuzinThemeTokens get tatuzinTokens {
    final tokens = Theme.of(this).extension<TatuzinThemeTokens>();
    assert(tokens != null, 'TatuzinThemeTokens were not found in ThemeData.');
    return tokens!;
  }
}
