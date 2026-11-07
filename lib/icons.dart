import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The same stroke icons the website draws (src/js/dashboard/components/icons.js).
const _paths = <String, String>{
  'grid': '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  'package': '<path d="m21 8-9-5-9 5 9 5 9-5Z"/><path d="m3 8 9 5 9-5v9l-9 5-9-5V8Z"/><path d="M12 13v9"/>',
  'key': '<circle cx="7.5" cy="15.5" r="4.5"/><path d="m11 12 8.5-8.5M15 8l3 3M17 6l3 3"/>',
  'card': '<rect x="2.5" y="5" width="19" height="14" rx="3"/><path d="M2.5 10h19M7 15h3"/>',
  'settings': '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.83 2.83-.06-.06A1.7 1.7 0 0 0 15 19.4a1.7 1.7 0 0 0-1 .6 1.7 1.7 0 0 0-.4 1.1V21h-4v-.09A1.7 1.7 0 0 0 8.6 19.4a1.7 1.7 0 0 0-1.88.34l-.06.06-2.83-2.83.06-.06A1.7 1.7 0 0 0 4.6 15a1.7 1.7 0 0 0-.6-1 1.7 1.7 0 0 0-1.1-.4H3v-4h.09A1.7 1.7 0 0 0 4.6 8.6a1.7 1.7 0 0 0-.34-1.88l-.06-.06 2.83-2.83.06.06A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-.6 1.7 1.7 0 0 0 .4-1.1V3h4v.09A1.7 1.7 0 0 0 15.4 4.6a1.7 1.7 0 0 0 1.88-.34l.06-.06 2.83 2.83-.06.06A1.7 1.7 0 0 0 19.4 9c.15.37.37.7.69.96.3.25.68.4 1.08.4H21v4h-.09A1.7 1.7 0 0 0 19.4 15Z"/>',
  'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.42 1.42M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.42-1.41M17.66 6.34l1.41-1.41"/>',
  'moon': '<path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8Z"/>',
  'bell': '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M10 21h4"/>',
  'unlock': '<rect x="3.5" y="10" width="17" height="11" rx="3"/><path d="M8 10V7a4 4 0 0 1 7.5-2"/>',
  'arrow': '<path d="M5 12h14M13 6l6 6-6 6"/>',
  'weight': '<path d="M6 8h12l2 13H4L6 8Z"/><path d="M9 8a3 3 0 0 1 6 0"/>',
  'shield': '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Zm-3-10 2 2 4-5"/>',
  'power': '<path d="M12 3v9"/><path d="M7.5 6.3a7 7 0 1 0 9 0"/>',
  'wifi': '<path d="M2.5 8.5a15 15 0 0 1 19 0"/><path d="M6 12.2a10 10 0 0 1 12 0"/><path d="M9.3 15.8a5 5 0 0 1 5.4 0"/><circle cx="12" cy="19.5" r="1"/>',
  'sliders': '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>',
  'activity': '<path d="M3 12h4l3-7 4 14 3-7h4"/>',
  'refresh': '<path d="M20 11a8 8 0 1 0-2.3 6.3"/><path d="M20 5v6h-6"/>',
  'file': '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8l-5-5Z"/><path d="M14 3v5h5M9 13h6M9 17h4"/>',
  'list': '<path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01"/>',
  'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  'menu': '<path d="M4 6h16M4 12h16M4 18h16"/>',
  'eye': '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
  'eyeOff': '<path d="M3 3l18 18"/><path d="M10.6 5.1A10 10 0 0 1 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3.2 4M6.6 6.6C3.9 8.4 2 12 2 12s3.5 7 10 7a9.7 9.7 0 0 0 5.4-1.6"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
  'logout': '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3"/><path d="M10 17l-5-5 5-5M5 12h11"/>',
  'thermo': '<path d="M14 14.76V5a2 2 0 0 0-4 0v9.76a4 4 0 1 0 4 0Z"/><path d="M12 10v7"/>',
  'fan': '<circle cx="12" cy="12" r="1.6"/><path d="M12 10.4C12 6 13 3 15.5 3S19 5.5 17 8l-3.6 3.2"/><path d="M13.6 12c4.4 0 7.4 1 7.4 3.5S18.5 19 16 17l-3.2-3.6"/><path d="M12 13.6C12 18 11 21 8.5 21S5 18.5 7 16l3.6-3.2"/><path d="M10.4 12C6 12 3 11 3 8.5S5.5 5 8 7l3.2 3.6"/>',
  'minus': '<path d="M5 12h14"/>',
  'plus': '<path d="M12 5v14M5 12h14"/>',
  'back':'<path d="M19 12H5M11 6l-6 6 6 6"/>',
};

class PIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const PIcon(this.name, {super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color!;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" '
      'stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${_paths[name] ?? _paths['grid']}</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}
