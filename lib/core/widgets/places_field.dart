import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/env.dart';
import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/json.dart';
import 'ui.dart';

class PlaceResult {
  const PlaceResult({required this.description, this.city, this.state, this.lat, this.lng, this.placeId});
  final String description;
  final String? city;
  final String? state;
  final double? lat;
  final double? lng;
  final String? placeId;
}

/// Google Places autocomplete text field (GooglePlacesAutocompleteSimple /
/// react-native-google-places-textinput). With [citiesOnly] it searches
/// Indian cities and reports city + state.
class PlacesField extends StatefulWidget {
  const PlacesField({
    super.key,
    required this.label,
    required this.onSelected,
    this.initialValue,
    this.citiesOnly = false,
    this.onChanged,
    this.required = false,
    this.hint,
    this.maxLines = 1,
  });

  final String label;
  final String? initialValue;
  final bool citiesOnly;
  final ValueChanged<PlaceResult> onSelected;
  final ValueChanged<String>? onChanged;
  final bool required;
  final String? hint;
  final int maxLines;

  @override
  State<PlacesField> createState() => _PlacesFieldState();
}

class _PlacesFieldState extends State<PlacesField> {
  static final _dio = Dio(BaseOptions(baseUrl: 'https://maps.googleapis.com/maps/api/place'));
  late final _c = TextEditingController(text: widget.initialValue);
  final _focus = FocusNode();
  Timer? _debounce;
  List<Json> _predictions = [];
  bool _loading = false;

  @override
  void didUpdateWidget(covariant PlacesField old) {
    super.didUpdateWidget(old);
    if (widget.initialValue != old.initialValue && widget.initialValue != _c.text && !_focus.hasFocus) {
      _c.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    widget.onChanged?.call(v);
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final r = await _dio.get(
        '/autocomplete/json',
        queryParameters: {
          'input': q,
          'key': Env.googlePlacesKey,
          'language': 'en',
          if (widget.citiesOnly) 'types': '(cities)',
          if (widget.citiesOnly) 'components': 'country:in',
        },
      );
      final d = obj(r.data);
      if (mounted && _focus.hasFocus) setState(() => _predictions = str(d['status']) == 'OK' ? objList(d['predictions']) : []);
    } catch (_) {
      if (mounted) setState(() => _predictions = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(Json p) async {
    final desc = str(p['description']);
    final parts = desc.split(',').map((e) => e.trim()).toList();
    setState(() => _predictions = []);
    Json? details;
    try {
      final r = await _dio.get(
        '/details/json',
        queryParameters: {'place_id': str(p['place_id']), 'key': Env.googlePlacesKey, 'fields': 'formatted_address,geometry,name,place_id', 'language': 'en'},
      );
      final d = obj(r.data);
      if (str(d['status']) == 'OK') details = obj(d['result']);
    } catch (_) {}
    final city = strOrNull(details?['name']) ?? parts.first;
    final state = parts.length > 1 ? parts[1] : null;
    final loc = obj(pick(details, ['geometry', 'location']));
    _c.text = widget.citiesOnly ? city : (strOrNull(details?['formatted_address']) ?? desc);
    widget.onSelected(
      PlaceResult(
        description: _c.text,
        city: city,
        state: state,
        lat: loc.isEmpty ? null : dbl(loc['lat']),
        lng: loc.isEmpty ? null : dbl(loc['lng']),
        placeId: str(p['place_id']),
      ),
    );
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppTextField(
        controller: _c,
        label: widget.label,
        hint: widget.hint ?? t('start_typing', 'Start typing to search'),
        required: widget.required,
        maxLines: widget.maxLines,
        onChanged: _onChanged,
        suffix: _loading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : const Icon(LucideIcons.mapPin, size: 18, color: AppColors.mutedForeground),
      ).withFocus(_focus),
      if (_predictions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            children: [
              for (final p in _predictions.take(5))
                ListTile(
                  dense: true,
                  leading: const Icon(LucideIcons.mapPin, size: 18, color: AppColors.bluntRed),
                  title: Text(
                    str(pick(p, ['structured_formatting', 'main_text'])).isNotEmpty
                        ? str(pick(p, ['structured_formatting', 'main_text']))
                        : str(p['description']),
                    style: AppText.body(size: 14, weight: FontWeight.w600),
                  ),
                  subtitle: Text(str(pick(p, ['structured_formatting', 'secondary_text'])), style: AppText.body(size: 12, color: AppColors.mutedForeground)),
                  onTap: () => _select(p),
                ),
            ],
          ),
        ),
    ],
  );
}

extension on AppTextField {
  Widget withFocus(FocusNode f) => Focus(focusNode: f, child: this);
}
