import 'package:flutter/material.dart';

/// Shell colors: base, highlight, shadow for each of the six piece types.
class ShellColors {
  final Color base;
  final Color highlight;
  final Color shadow;
  const ShellColors(this.base, this.highlight, this.shadow);
}

const List<ShellColors> shellColors = [
  ShellColors(Color(0xFFE45C5C), Color(0xFFFFAAAA), Color(0xFF962828)), // coral
  ShellColors(Color(0xFF468CDC), Color(0xFFAAD2FF), Color(0xFF1E5096)), // ocean
  ShellColors(Color(0xFFF0C450), Color(0xFFFFEBAA), Color(0xFFA06E14)), // sand
  ShellColors(Color(0xFFA05AC8), Color(0xFFDCB4F5), Color(0xFF5A2882)), // purple
  ShellColors(Color(0xFFF082B4), Color(0xFFFFC8E1), Color(0xFFAA3C6E)), // pink
  ShellColors(Color(0xFF50B496), Color(0xFFB4E6D2), Color(0xFF1E6E5A)), // teal
];

const int numColors = 6;

// Board & UI palette
const Color bgTop = Color(0xFF14203A);
const Color bgBottom = Color(0xFF0A0F1E);
const Color panelBg = Color(0xFF19243C);
const Color panelBorder = Color(0xFF5A78B4);
const Color textColor = Color(0xFFEBEBF5);
const Color textDim = Color(0xFFA0AAC8);
const Color highlightColor = Color(0xFFFFE678);
const Color urgentColor = Color(0xFFFF7864);
